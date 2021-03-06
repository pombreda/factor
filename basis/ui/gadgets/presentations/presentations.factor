! Copyright (C) 2005, 2009 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors kernel namespaces ui.commands ui.gadgets
ui.gadgets.buttons ui.gadgets.buttons.private ui.gadgets.menus
ui.gadgets.status-bar ui.gadgets.worlds ui.gestures
ui.operations ;
IN: ui.gadgets.presentations

TUPLE: presentation < button object hook ;

: invoke-presentation ( presentation command -- )
    [ [ dup hook>> call( presentation -- ) ] [ object>> ] bi ] dip
    invoke-command ;

: invoke-primary ( presentation -- )
    dup object>> primary-operation
    invoke-presentation ;

: invoke-secondary ( presentation -- )
    dup object>> secondary-operation
    invoke-presentation ;

: show-mouse-help ( presentation -- )
    [ [ object>> ] keep show-summary ] [ button-update ] bi ;

: <presentation> ( label object -- button )
    [ [ invoke-primary ] presentation new-button ] dip
        >>object
        [ drop ] >>hook
        roll-button-theme ;

M: presentation ungraft*
    dup hand-gadget get-global child? [ dup hide-status ] when
    call-next-method ;

: show-presentation-menu ( presentation -- )
    [ ] [ object>> ] [ dup hook>> curry ] tri
    show-operations-menu ;

presentation H{
    { T{ button-down f f 3 } [ show-presentation-menu ] }
    { mouse-leave [ [ hide-status ] [ button-update ] bi ] }
    { mouse-enter [ show-mouse-help ] }
    ! Responding to motion too allows nested presentations to
    ! display status help properly, when the mouse leaves a
    ! nested presentation and is still inside the parent, the
    ! parent doesn't receive a mouse-enter
    { motion [ show-mouse-help ] }
} set-gestures
