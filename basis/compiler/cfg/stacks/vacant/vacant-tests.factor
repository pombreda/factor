USING: accessors arrays assocs compiler.cfg
compiler.cfg.dataflow-analysis.private compiler.cfg.instructions
compiler.cfg.linearization compiler.cfg.registers
compiler.cfg.utilities compiler.cfg.stacks.vacant kernel math sequences sorting
tools.test vectors ;
IN: compiler.cfg.stacks.vacant.tests

{
    { { } { } }
} [
    { { 4 { 3 2 1 -3 0 -2 -1 } } { 0 { -1 } } } state>gc-data
] unit-test

{ { { 1 0 0 } { 0 } } } [
    { { 3 { 0 } } { 1 { } } } state>gc-data
] unit-test

! visit-insn should set the gc info.
{ { 0 0 } { } } [
    { { 2 { } } { 0 { } } }
    T{ ##alien-invoke { gc-map T{ gc-map } } }
    [ gc-map>> set-gc-map ] keep gc-map>> [ scrub-d>> ] [ scrub-r>> ] bi
] unit-test
