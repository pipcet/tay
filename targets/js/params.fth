[defined] final [if]
1 constant cell-size
2 constant next-offset
3 constant does-offset
4 constant code-offset
5 constant body-offset
[else]
1 constant cell-size
16 constant next-offset
17 constant does-offset
18 constant code-offset
19 constant body-offset
[then]

\ This target holds a special primitive ID in the code field.
\ The inner interpreter looks up this ID to make a dispatch jump.
: code@   code-offset + @ ;

1024 constant load-address
: exe-header ;
: entry-point 0 ;
: exe-code ;
: extra-bytes ;
: exe-end ;
