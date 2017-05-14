host

also meta t' latest0 previous  constant 'latest0
also meta t' turnkey previous  constant 'turnkey
also meta t' limit previous  constant 'limit
also meta t' sp0 previous  constant 'sp0
also meta t' rp0 previous  constant 'rp0
also meta t' dp0 previous  constant 'dp0

: final
   ." c += `HEAP[" 'latest0 . ." +5] = " 'turnkey . ." ;\n`;" cr
   ." c += `HEAP[" 'limit . ." +5] = params.sp0;\n`;" cr
   ." c += `HEAP[" 'sp0 . ." +5] = params.sp0;\n`;" cr
   ." c += `HEAP[" 'rp0 . ." +5] = params.rp0;\n`;" cr
   ." c += `HEAP[" 'dp0 . ." +5] = 64 * 1024;\n`" cr
   ." c += `run(" 'turnkey . ." );\n`" cr
   ." console.log(`var HEAP = []; for (var i = 0; i < 1024*1024; i++) HEAP[i] = 0;`);" cr
   ." c += `for (var i = 0; i < 64*1024; i++) DICT[i] = 0;`;" cr
   ." for (var i = 0; i < 64 * 1024; i++) {" cr
   ."     if (HEAP[i])" cr
   ."         console.log(`HEAP[${i}] = ` + ((typeof HEAP[i] === 'string') ? HEAP[i].toSource().replace(/^.*?String./, '').replace(/\)[^)]*?$/, '').replace(/\)[^)]*?$/, '') : HEAP[i]) + `;`);" cr
   ." }" cr
   ." console.log(c);" cr ;

: mask   0 8 4 * 0 do 1 lshift 1 + loop and ;
: rrotate ( u1 u2 -- u3 ) 2dup rshift -rot 32 - negate lshift + ;
: 4@   @ ;

: [meta]   also meta ; immediate
: [host]   previous ; immediate
: t-dp   [meta] t-dp [host] ;
: >host   [meta] >host [host] ;

: .cell   ." HEAP[" swap . ." ] = " u. ." ;" cr ;
: ?.cell   dup if .cell else 2drop then ;
also meta definitions previous
: save-target final ;
