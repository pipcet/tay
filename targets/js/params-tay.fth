1 constant cell-size
2 constant next-offset
3 constant does-offset
4 constant code-offset
5 constant body-offset

\ This target holds a special primitive ID in the code field.
\ The inner interpreter looks up this ID to make a dispatch jump.
: code@   code-offset + @ ;

1024 constant load-address
: exe-header ;
: entry-point 0 ;
: exe-code ;
: extra-bytes ;
: exe-end ;
