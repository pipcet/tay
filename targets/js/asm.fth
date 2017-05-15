\ Copyright 2017 Pip Cet

\ Assembler for asm.js

vocabulary assembler

variable scount  0 scount !

: ?refill   refill 0= abort" Refill?" ;
: more?   source s" end-code" compare ;
: start-code   begin ?refill more? while source ." c += `" type ." \n`;" cr repeat ;

: end-code ;

: [meta]   also meta ; immediate
: [host]   previous ; immediate
: header   parse-name header, scount @ , reveal ;
: .case   ." c += `" ." () => {\n`" cr [meta] 1 scount +!  [host]
    ." c += `var addr = 0;\n`;" cr
    ." c += `var x = 0;\n`;" cr
    ." c += `var y = 0;\n`;" cr
    ." c += `var z = 0;\n`;" cr
    ." c += `var i = 0;\n`;" cr
    ." c += `var top = H[SP];\n`;"
    ;
: .break  ." c += `" ." }," ." \n`;" cr cr ;
: code   header .case start-code .break ;
