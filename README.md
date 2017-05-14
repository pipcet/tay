This is an experimental extension of Lars Brinkhoff's excellent
lbForth to support JavaScript values as primitive types; that way, we
gain first-class functions, nested functions and local variables, some
degree of object orientation, garbage collection, string values,
floating point support (in the future) and dynamic memory management,
all in a few modified lines of code.

== Build instructions ==

(This isn't very polished right now.)

Make sure `js` is in the path *and refers to the SpiderMonkey shell*. Nodejs is currently broken.  Also make sure to give the build process enough time (several minutes); the final product isn't that slow, but the intermediate Forth-y abomination is.

```
$ make clean
$ make TARGET=js
$ make tay
$ js tay.js
```

== ok ==

There should be an `ok` prompt. You can enter most Forth expressions and they should work fine, but there are additional data types, words, and semantics:

=== Data types ===

Forth treats all cells as integers. Tay treats every cell as a JavaScript value: a floating-point number, string, or object; two particular kinds of object are arrays and references.

=== First-class functions ===

You can build a function by placing a word (which can be anonymous, but doesn't have to be) in an array, and not linking it to the main dictionary.  Unlike Forth, you can do so in the middle of building another dictionary entry in another array.  The words `::(` and `);;` provide a convenient way of doing so:

```
: inc ::( 1 + );; execute ;
```

