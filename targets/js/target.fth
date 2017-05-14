: io-init ;
: r/o   s" r" drop ;

\ If you change the definition of docol, you also need to update the
\ offset to the runtime code in the metacompiler(s).
: docol,   'docol , ;
: dovar,   'dovar , ;
: docon,   'docon , ;
: dodef,   'dodef , ;

: NAME_LENGTH 16 ;
: #name ( -- u )       NAME_LENGTH 1 - ;
[defined] final [if]
: name, ( a u -- )     0 , js"" , ;
[else]
: name, ( a u -- )     #name min c,  #name ", ;
[then]
: header, ( a u -- )   align here >r name, r> link, 0 , ;
: header,, ( a u -- )  here >r name, r> link, 0 , ;

: >nfa ;
: >xt drop 0 ;
[defined] final [if]
: >name    1+ @ @ fth"" ;
[else]
: >name    >nfa count cabs ;
[then]

: noheader,   s" " header, ;
