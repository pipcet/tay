: io-init ;
: r/o   s" r" drop ;

\ If you change the definition of docol, you also need to update the
\ offset to the runtime code in the metacompiler(s).
: docol,   'docol , ;
: dovar,   'dovar , ;
: docon,   'docon , ;
: dodef,   'dodef , ;

: name, ( a u -- )     1 , js"" , ;
: header, ( a u -- )   align here >r name, r> link, 0 , ;
: header,, ( a u -- )  here >r name, r> link, 0 , ;

: >nfa ;
: >xt drop 0 ;
: >name    1+ @ fth"" ;

: noheader,   s" " header, ;
: sysdir   s" /usr/local/share/lbForth/" ;
