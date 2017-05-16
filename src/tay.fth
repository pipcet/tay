: js" parse" js"" ;
: js" parse" js"" postpone literal ; compile-only

variable js-markers js[] js-markers !
variable () js[] () !

: immediate immediate ; immediate
: ) () @ $? execute ;

: js) () @ $> drop js-markers @ $> sp@ 1- - negate js() ;
: js( sp@ js-markers @ >$ ['] js) () @ >$ ;

: js{}) () @ $> drop js-markers @ $> sp@ 1- - negate js{}() ;
: js{}( sp@ js-markers @ >$ ['] js{}) () @ >$ ;

: jsnew) () @ $> drop js-markers @ $> sp@ 1- - negate jsnew() ;
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

: {} l-dicts $? postpone literal postpone l-dicts postpone $? postpone n{} ; immediate

: { l-dicts $? new{} dup l-dicts $, postpone literal postpone l-dicts postpone $? postpone n{} postpone l-dicts postpone $, ; immediate
: } l-dicts $> drop postpone l-dicts postpone $> ; immediate

: constant-function latest dp @ js[] 8 $ref dp ! s" " header,, docol, rot postpone literal ['] exit , dp ! latest swap dup latest! ;

: compose swap latest dp @ js[] 8 $ref dp ! s" " header,, docol, rot , rot , ['] exit , dp ! latest swap dup latest! ;

: create-reference swap l-dicts $? begin over over js" proto" $@ js=== 0= while js" __proto__" $@ repeat swap drop swap $ref ;

: {}-variable parse-name js"" l-dicts $? constant-function over constant-function compose ['] create-reference compose l-dicts $? rot $! ;

: {}-named-value l-dicts $? constant-function over dup >r constant-function compose ['] create-reference compose ['] @ compose l-dicts $? rot $! postpone l-dicts postpone $? r> postpone literal postpone $! ;

: variable state @ 0 = if variable else {}-variable then ; immediate

variable ;s
js[] ;s !

: ;after: ;s @ $> drop state @ 1 <> if ['] exit , [ ' [ , ] latest swap l-dicts $? swap $! dp ! dup latest! else ['] ; execute then ; immediate
: : state @ 0 = if ['] : execute else latest dp @ parse-name 2dup js[] 8 $ref dp ! header,, docol, js"" [ ' ] , ] then ['] ;after: ;s @ >$ ; immediate
: ; ;s @ $? execute ;after: immediate

: {}-execute ( scope xt -- * ) swap l-dicts $, execute l-dicts $> drop ;
: $ dup js" proto" $@ parse-name js"" $@ {}-execute ;
: $ parse-name js"" postpone dup js" proto" postpone literal postpone $@ postpone literal postpone $@ postpone {}-execute ; compile-only

: this l-dicts $? ;

: 0; ;s @ $> drop ['] exit , ['] [ execute latest >r dp ! dup latest! r> postpone literal ; immediate
: :0 latest dp @ s" " 2dup js[] 8 $ref dp ! header,, docol, js"" drop ['] ] execute ['] 0; ;s @ >$ ; immediate

: collect-names begin parse-name js"" dup js" )" js=== 0= while over >$ repeat drop ;


: ( js[] collect-names begin dup $# while dup $> {}-named-value repeat drop ; immediate

: list {
  variable a js[] a !
  : push a @ >$ ;
  : pop a @ $> ;
  : shift a @ <$ ;
  : unshift a @ $< ;
  : n a @ $# ;
  : nth a @ swap $@ ;
  : for a @ $# 0 2dup <> if do a @ i $@ over execute loop else 2drop then ;
  : += dup $ n 0 2dup <> if do i over $ nth a @ >$ loop else 2drop then drop ;
} ;
\ : inc :( 1 + ); execute ;

list $$ proto value list{}

: nested { variable a { variable b } { variable b } } drop ;

\ : heap [ list js" proto" $@ l-dicts >$ ] variable here : compile a @ here @ $! here @ 1+ here ! ; {} ;
: heap { variable here : compile this $ a @ here @ $! 1 here !+ ; } ;
: times over 0 do dup execute loop 2drop ;
