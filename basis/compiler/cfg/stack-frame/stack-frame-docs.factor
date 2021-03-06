USING: cpu.x86 help.markup help.syntax layouts math ;
IN: compiler.cfg.stack-frame

HELP: stack-frame
{ $class-description "Counts of, among other things, how much stack a compiled word needs. The stack frame is organized in the following fashion:"
  { $list
    "Parameter space:"
    "Allocation area: space for local allocations."
    "Spill area: space for register spills."
    { "Reserved stack space: only applicable on Windows x86.64. See " { $link reserved-stack-space } "." }
    { "One final " { $link cell } " of padding." }
  }
  "The stack frame is also aligned to a 16 byte boundary. It has the following slots:"
  { $table
    { { $slot "total-size" } { "Total size of the stack frame." } }
    { { $slot "allot-area-base" } { "Base offset of the allocation area." } }
    { { $slot "allot-area-size" } { "Number of bytes requires for the allocation area." } }
    { { $slot "allot-area-align" } { "This slot is always at least " { $link cell } " bytes." } }
    { { $slot "spill-area-base" } { "Base offset for the spill area." } }
    { { $slot "spill-area-size" } { "Number of bytes requires for all spill slots." } }
    { { $slot "spill-area-align" } { "This slot is always at least " { $link cell } " bytes." } }
  }
}
{ $see-also align-stack } ;

HELP: (stack-frame-size)
{ $values { "stack-frame" stack-frame } { "n" integer } }
{ $description "Base stack frame size, without padding and alignment." } ;

HELP: spill-offset
{ $values { "n" integer } { "offset" integer } }
{ $description "Offset in the current " { $link stack-frame } " to byte at index 'n' in the spill area." } ;

ARTICLE: "compiler.cfg.stack-frame" "Stack frames"
"This vocab contains definitions for constructing stack frames." ;

ABOUT: "compiler.cfg.stack-frame"
