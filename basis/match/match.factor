! Copyright (C) 2006 Chris Double.
! See http://factorcode.org/license.txt for BSD license.
!
! Based on pattern matching code from Paul Graham's book 'On Lisp'.
USING: assocs classes.tuple combinators kernel lexer macros make
math namespaces parser sequences words ;
IN: match

SYMBOL: _

: define-match-var ( name -- )
    create-in
    dup t "match-var" set-word-prop
    dup [ get ] curry ( -- value ) define-declared ;

: define-match-vars ( seq -- )
    [ define-match-var ] each ;

SYNTAX: MATCH-VARS: ! vars ...
    ";" [ define-match-var ] each-token ;

: match-var? ( symbol -- bool )
    dup word? [ "match-var" word-prop ] [ drop f ] if ;

: set-match-var ( value var -- ? )
    building get ?at [ = ] [ ,, t ] if ;

: (match) ( value1 value2 -- matched? )
    {
        { [ dup match-var? ] [ set-match-var ] }
        { [ over match-var? ] [ swap set-match-var ] }
        { [ 2dup = ] [ 2drop t ] }
        { [ 2dup [ _ eq? ] either? ] [ 2drop t ] }
        { [ 2dup [ sequence? ] both? ] [
            2dup [ length ] same?
            [ [ (match) ] 2all? ] [ 2drop f ] if ] }
        { [ 2dup [ tuple? ] both? ]
          [ [ tuple>array ] bi@ [ (match) ] 2all? ] }
        { [ t ] [ 2drop f ] }
    } cond ;

: match ( value1 value2 -- bindings )
    [ (match) ] H{ } make swap [ drop f ] unless ;

MACRO: match-cond ( assoc -- )
    <reversed>
    [ "Fall-through in match-cond" throw ]
    [
        first2
        [ [ dupd match ] curry ] dip
        [ with-variables ] curry rot
        [ ?if ] 2curry append
    ] reduce ;

: replace-patterns ( object -- result )
    {
        { [ dup number? ] [ ] }
        { [ dup match-var? ] [ get ] }
        { [ dup sequence? ] [ [ replace-patterns ] map ] }
        { [ dup tuple? ] [ tuple>array replace-patterns >tuple ] }
        [ ]
    } cond ;

: match-replace ( object pattern1 pattern2 -- result )
    [ match [ "Pattern does not match" throw ] unless* ] dip swap
    [ replace-patterns ] with-variables ;

: ?rest ( seq -- tailseq/f )
    [ f ] [ rest ] if-empty ;

: (match-first) ( seq pattern-seq -- bindings leftover/f )
    2dup shorter? [ 2drop f f ] [
        2dup length head over match
        [ swap ?rest ] [ [ rest ] dip (match-first) ] ?if
    ] if ;

: match-first ( seq pattern-seq -- bindings )
    (match-first) drop ;

: (match-all) ( seq pattern-seq -- )
    [ nip ] [ (match-first) swap ] 2bi
    [ , [ swap (match-all) ] [ drop ] if* ] [ 2drop ] if* ;

: match-all ( seq pattern-seq -- bindings-seq )
    [ (match-all) ] { } make ;
