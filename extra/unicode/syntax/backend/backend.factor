USING: kernel parser sequences definitions ;
IN: unicode.syntax.backend

: VALUE:
    CREATE-WORD { f } clone [ first ] curry define ; parsing

: set-value ( value word -- )
    word-def first set-first ;
