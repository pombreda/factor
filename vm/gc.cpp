#include "master.hpp"

namespace factor {

gc_event::gc_event(gc_op op, factor_vm* parent)
    : op(op),
      cards_scanned(0),
      decks_scanned(0),
      code_blocks_scanned(0),
      start_time(nano_count()),
      card_scan_time(0),
      code_scan_time(0),
      data_sweep_time(0),
      code_sweep_time(0),
      compaction_time(0) {
  data_heap_before = parent->data_room();
  code_heap_before = parent->code->allocator->as_allocator_room();
  start_time = nano_count();
}

void gc_event::started_card_scan() { temp_time = nano_count(); }

void gc_event::ended_card_scan(cell cards_scanned_, cell decks_scanned_) {
  cards_scanned += cards_scanned_;
  decks_scanned += decks_scanned_;
  card_scan_time = (cell)(nano_count() - temp_time);
}

void gc_event::started_code_scan() { temp_time = nano_count(); }

void gc_event::ended_code_scan(cell code_blocks_scanned_) {
  code_blocks_scanned += code_blocks_scanned_;
  code_scan_time = (cell)(nano_count() - temp_time);
}

void gc_event::started_data_sweep() { temp_time = nano_count(); }

void gc_event::ended_data_sweep() {
  data_sweep_time = (cell)(nano_count() - temp_time);
}

void gc_event::started_code_sweep() { temp_time = nano_count(); }

void gc_event::ended_code_sweep() {
  code_sweep_time = (cell)(nano_count() - temp_time);
}

void gc_event::started_compaction() { temp_time = nano_count(); }

void gc_event::ended_compaction() {
  compaction_time = (cell)(nano_count() - temp_time);
}

void gc_event::ended_gc(factor_vm* parent) {
  data_heap_after = parent->data_room();
  code_heap_after = parent->code->allocator->as_allocator_room();
  total_time = (cell)(nano_count() - start_time);
}

gc_state::gc_state(gc_op op, factor_vm* parent) : op(op) {
  if (parent->gc_events) {
    event = new gc_event(op, parent);
    start_time = nano_count();
  } else
    event = NULL;
}

gc_state::~gc_state() {
  if (event) {
    delete event;
    event = NULL;
  }
}

void factor_vm::end_gc() {
  if (gc_events) {
    current_gc->event->ended_gc(this);
    gc_events->push_back(*current_gc->event);
  }
}

void factor_vm::start_gc_again() {
  end_gc();

  switch (current_gc->op) {
    case collect_nursery_op:
      /* Nursery collection can fail if aging does not have enough
         free space to fit all live objects from nursery. */
      current_gc->op = collect_aging_op;
      break;
    case collect_aging_op:
      /* Aging collection can fail if the aging semispace cannot fit
         all the live objects from the other aging semispace and the
         nursery. */
      current_gc->op = collect_to_tenured_op;
      break;
    default:
      /* Nothing else should fail mid-collection due to insufficient
         space in the target generation. */
      critical_error("in start_gc_again, bad GC op", current_gc->op);
      break;
  }

  if (gc_events)
    current_gc->event = new gc_event(current_gc->op, this);
}

void factor_vm::set_current_gc_op(gc_op op) {
  current_gc->op = op;
  if (gc_events)
    current_gc->event->op = op;
}

void factor_vm::gc(gc_op op, cell requested_size) {
  FACTOR_ASSERT(!gc_off);
  FACTOR_ASSERT(!current_gc);

  /* Important invariant: tenured space must have enough contiguous free
     space to fit the entire contents of the aging space and nursery. This is
     because when doing a full collection, objects from younger generations
     are promoted before any unreachable tenured objects are freed. */
  FACTOR_ASSERT(!data->high_fragmentation_p());

  current_gc = new gc_state(op, this);
  atomic::store(&current_gc_p, true);

  /* Keep trying to GC higher and higher generations until we don't run
     out of space in the target generation. */
  for (;;) {
    try {
      if (gc_events)
        current_gc->event->op = current_gc->op;

      switch (current_gc->op) {
        case collect_nursery_op:
          collect_nursery();
          break;
        case collect_aging_op:
          /* We end up here if the above fails. */
          collect_aging();
          if (data->high_fragmentation_p()) {
            /* Change GC op so that if we fail again, we crash. */
            set_current_gc_op(collect_full_op);
            collect_full();
          }
          break;
        case collect_to_tenured_op:
          /* We end up here if the above fails. */
          collect_to_tenured();
          if (data->high_fragmentation_p()) {
            /* Change GC op so that if we fail again, we crash. */
            set_current_gc_op(collect_full_op);
            collect_full();
          }
          break;
        case collect_full_op:
          collect_full();
          break;
        case collect_compact_op:
          collect_compact();
          break;
        case collect_growing_heap_op:
          collect_growing_heap(requested_size);
          break;
        default:
          critical_error("in gc, bad GC op", current_gc->op);
          break;
      }

      break;
    }
    catch (const must_start_gc_again&) {
      /* We come back here if the target generation is full. */
      start_gc_again();
      continue;
    }
  }

  end_gc();

  atomic::store(&current_gc_p, false);
  delete current_gc;
  current_gc = NULL;

  /* Check the invariant again, just in case. */
  FACTOR_ASSERT(!data->high_fragmentation_p());
}

void factor_vm::primitive_minor_gc() {
  gc(collect_nursery_op, 0 /* requested size */);
}

void factor_vm::primitive_full_gc() {
  gc(collect_full_op, 0 /* requested size */);
}

void factor_vm::primitive_compact_gc() {
  gc(collect_compact_op, 0 /* requested size */);
}

/*
 * It is up to the caller to fill in the object's fields in a meaningful
 * fashion!
 */
/* Allocates memory */
object* factor_vm::allot_large_object(cell type, cell size) {
  /* If tenured space does not have enough room, collect and compact */
  cell requested_size = size + data->high_water_mark();
  if (!data->tenured->can_allot_p(requested_size)) {
    primitive_compact_gc();

    /* If it still won't fit, grow the heap */
    if (!data->tenured->can_allot_p(requested_size)) {
      gc(collect_growing_heap_op, size /* requested size */);
    }
  }

  object* obj = data->tenured->allot(size);

  /* Allows initialization code to store old->new pointers
     without hitting the write barrier in the common case of
     a nursery allocation */
  write_barrier(obj, size);

  obj->initialize(type);
  return obj;
}

void factor_vm::primitive_enable_gc_events() {
  gc_events = new std::vector<gc_event>();
}

/* Allocates memory (byte_array_from_value, result.add) */
/* XXX: Remember that growable_array has a data_root already */
void factor_vm::primitive_disable_gc_events() {
  if (gc_events) {
    growable_array result(this);

    std::vector<gc_event>* gc_events = this->gc_events;
    this->gc_events = NULL;

    std::vector<gc_event>::const_iterator iter = gc_events->begin();
    std::vector<gc_event>::const_iterator end = gc_events->end();

    for (; iter != end; iter++) {
      gc_event event = *iter;
      byte_array* obj = byte_array_from_value(&event);
      result.add(tag<byte_array>(obj));
    }

    result.trim();
    ctx->push(result.elements.value());

    delete this->gc_events;
  } else
    ctx->push(false_object);
}

}
