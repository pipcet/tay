: js" parse" js"" ;
: js" parse" js"" postpone literal ; compile-only

variable js-markers js[] js-markers !
variable () js[] () !

: ) () @ $? execute ;

: js) () @ $> drop js-markers @ $> sp@ 1+ - js() ;
: js( sp@ js-markers @ >$ ['] js) () @ >$ ;

: js{}) () @ $> drop js-markers @ $> sp@ 1+ - js{}() ;
: js{}( sp@ js-markers @ >$ ['] js{}) () @ >$ ;

: jsnew) () @ $> drop js-markers @ $> sp@ 1+ - jsnew() ;
: jsnew( sp@ js-markers @ >$ ['] jsnew) () @ >$ ;

: $$ parse-name js"" $@ ; immediate
: $$ parse-name js"" postpone literal postpone $@ ; compile-only

: $js( dup parse-name js"" $@ js{}( over ; immediate
: $( dup parse-name js"" $@ js{}( over ; immediate
: $js( postpone dup parse-name js"" postpone literal postpone $@ postpone js{}( postpone over ; compile-only
: $( postpone dup parse-name js"" postpone literal postpone $@ postpone js{}( postpone over ; compile-only

: $$. dup parse-name js"" $@ $( bind over ) ; immediate

js[] to l-dicts
js{} l-dicts $,

: new{} >r js $$ Object $$ create js( r> ) ;
: n{} ( proto previous -- new ) swap >r >r js $$ Object $$ create js( r> ) dup js" proto" r> -rot $! ;

: { l-dicts $? new{} dup l-dicts $, postpone literal postpone l-dicts postpone $? postpone n{} postpone l-dicts postpone $, ; immediate
: } l-dicts $> drop postpone l-dicts postpone $> ; immediate

: constant-function latest dp @ js[] 8 $ref dp ! s" " header,, docol, rot postpone literal ['] exit , dp ! latest swap dup latest! ;

: compose swap latest dp @ js[] 8 $ref dp ! s" " header,, docol, rot , rot , ['] exit , dp ! latest swap dup latest! ;

\ 3 ' 1+ ' 1+ compose execute js.

: create-reference swap drop l-dicts $? swap $ref ;

: variable state @ 0 = if variable else parse-name js"" l-dicts $# 1- constant-function over constant-function compose ['] create-reference compose l-dicts $? rot $! then ; immediate

: : state @ 0 = if ['] : execute else latest dp @ parse-name 2dup js[] 8 $ref dp ! header,, docol, js"" [ ' ] , ] then ; immediate

: ; state @ 1 <> if ['] exit , [ ' [ , ] latest swap l-dicts $? swap $! dp ! dup latest! else ['] ; execute then ; immediate

: {}-execute ( scope xt -- * ) swap l-dicts $, execute l-dicts $> drop ;
: $ dup js" proto" $@ parse-name js"" $@ {}-execute ;
: $ parse-name js"" postpone dup js" proto" postpone literal postpone $@ postpone literal postpone $@ postpone {}-execute ; compile-only

: this l-dicts $? ;

: :( latest dp @ s" " 2dup js[] 8 $ref dp ! header,, docol, js"" drop ['] ] execute ; immediate
: ); ['] exit , ['] [ execute latest >r dp ! dup latest! r> postpone literal ; immediate

: list {
  variable a js[] a !
  : push a @ >$ ;
  : pop a @ $> ;
  : shift a @ <$ ;
  : unshift a @ >$ ;
  : n a @ $# ;
  : nth a @ swap $@ ;
  : for a @ $# 0 2dup <> if do a @ i $@ over execute loop else 2drop then ;
  : += dup $ n 0 2dup <> if do i over $ nth dup js. a @ >$ loop else 2drop then drop ;
} ;
\ : inc :( 1 + ); execute ;
