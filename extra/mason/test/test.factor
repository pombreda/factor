! Copyright (C) 2008, 2010 Eduardo Cavazos, Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors assocs benchmark bootstrap.stage2 command-line
compiler.errors generic help.html help.lint io io.directories
io.encodings.utf8 io.files kernel locals mason.common namespaces
parser.notes sequences sets sorting source-files.errors system
tools.errors tools.test tools.time vocabs.errors
vocabs.hierarchy vocabs.refresh words ;
IN: mason.test

: do-load ( -- )
    "" (load)
    [ keys load-all-vocabs-file to-file ]
    [ load-all-errors-file utf8 [ load-failures. ] with-file-writer ]
    bi ;

GENERIC: word-vocabulary ( word -- vocabulary )

M: word word-vocabulary vocabulary>> ;

M: method word-vocabulary "method-generic" word-prop word-vocabulary ;

:: do-step ( errors summary-file details-file -- )
    errors
    [ error-type +linkage-error+ eq? not ] filter
    [ file>> ] map members natural-sort summary-file to-file
    errors details-file utf8 [ errors. ] with-file-writer ;

: do-tests ( -- )
    forget-tests? on
    test-all test-failures get
    test-all-vocabs-file
    test-all-errors-file
    do-step ;

: do-help-lint ( -- )
    help-lint-all lint-failures get values
    help-lint-vocabs-file
    help-lint-errors-file
    do-step ;

: do-benchmarks ( -- )
    run-timing-benchmarks
    [ benchmarks-file to-file ] [
        [ keys benchmark-error-vocabs-file to-file ]
        [ benchmark-error-messages-file utf8 [ benchmark-errors. ] with-file-writer ] bi
    ] bi* ;

: do-compile-errors ( -- )
    compiler-errors get values
    compiler-errors-file
    compiler-error-messages-file
    do-step ;

: outdated-core-vocabs ( -- modified-sources modified-docs any? )
    "" to-refresh drop 2dup [ empty? not ] either? ;

: outdated-boot-image. ( modified-sources modified-docs -- )
    "Boot image is out of date. Changed vocabs:" print
    union [ print ] each
    flush ;

: check-boot-image ( -- ? )
    outdated-core-vocabs [ outdated-boot-image. t ] [ 2drop f ] if ;

: run-mason-rc ( -- )
    t "user-init" [
        ".factor-mason-rc" rc-path try-user-init
    ] with-variable ;

: check-user-init-errors ( -- ? )
    user-init-errors get-global assoc-empty?
    [ f ] [ :user-init-errors t ] if ;

: do-all ( -- )
    f parser-quiet? set-global
    ".." [
        run-mason-rc check-user-init-errors [ 1 exit ] when
        bootstrap-time get boot-time-file to-file
        check-boot-image [ 1 exit ] when
        [ do-load ] benchmark load-time-file to-file
        [ generate-help ] benchmark html-help-time-file to-file
        [ do-tests ] benchmark test-time-file to-file
        [ do-help-lint ] benchmark help-lint-time-file to-file
        [ do-benchmarks ] benchmark benchmark-time-file to-file
        do-compile-errors
    ] with-directory ;

MAIN: do-all
