\ -*- forth -*- Copyright 2017 Pip Cet

\ Nucleus for asm.js.

include targets/js/next.fth

." var c = ``;" cr
." var HEAP = [];" cr

start-code
"use strict";

function Reference(o, i)
{
    this.o = o;
    this.i = i;
}

Reference.prototype.get = function ()
{
    return this.o[this.i];
};

Reference.prototype.set = function (x)
{
    this.o[this.i] = x;
};

Reference.prototype.add = function (n)
{
    return new Reference(this.o, this.i + n);
};

Reference.prototype.toString = function ()
{
    return "{ " + "X" + ":" + this.i + "}";
};

var global = this;
var DICT = new Array();


var params = {
    memsize: 1024 * 1024,
    fsoff: 768 * 1024,
    dictoff: 16 * 1024,
    sp0: 763 * 1024,
    rp0: 767 * 1024,
};

var read_file_async;
var read_line;
var bye;
var gInputLines = [];
var resume_string = undefined;
var put_string;

function forth_input(str)
{
    str = str.replace(/\\n$/, "");
    gInputLines.push(str);
    resume("//line");
}

if (typeof(os) !== "undefined") {
    /* SpiderMonkey shell */

    read_file_async = function (path, cb) {
        try {
            cb(os.file.readFile(path, "utf-8"));
        } catch (e) {
            cb();
        }
    };
    read_line = readline;
    if (typeof console === "undefined") {
        this.console = {};
        this.console.log = print;
    }
    bye = function () { quit(0); };
    put_string = this.console.log;
} else if (typeof(require) !== "undefined") {
    /* Node.js */

    var fs = require('fs');
    read_file_async = function (path, cb) {
        return fs.readFile(path, "utf-8", function (error, str) { return cb(str) });
    };
    bye = function () { process.exit(0); };

    var readline = require('readline');
    var rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
        terminal: false,
    });
    rl.on('line', function (data) {
        gInputLines.push(data);
        resume("//line");
    });
    put_string = console.log;
} else if (typeof(snarf) !== "undefined") {
    /* old SpiderMonkey shell */

    read_file_async = function (path, cb) {
        try {
            cb(snarf(path, "utf-8"));
        } catch (e) {
            cb();
        }
    };
    read_line = readline;
    this.console = {};
    this.console.log = print;
    bye = function () { quit(0); };
    put_string = this.console.log;
} else if (typeof(readFile) !== "undefined") {
    /* JavaScriptCore */

    read_file_async = function (path, cb) {
        try {
            cb(readFile(path));
        } catch (e) {
            cb();
        }
    };
    read_line = readline;
    if (typeof console === "undefined") {
        this.console = {};
        this.console.log = print;
    }
    bye = function () { quit(); };
    put_string = this.console.log;
} else if (false && typeof(fetch) !== "undefined") {
    /* Web */

    read_file_async = function (path, cb) {
        fetch(path).then(function(x) { return x.text(); }).then(function(str) { return cb(str); }).catch(function (str) { cb() });
    };
    put_string = function (str) {
        forth_output(str + "\\n");
    };
} else {
    /* Web */

    read_file_async = function (path, cb) {
        var req = new XMLHttpRequest();
        req.onreadystatechange = function () {
            if (req.readyState == 4 && req.status == 200)
                cb(req.responseText);
            else if (req.readyState == 4)
                cb();
        };
        req.open("GET", path);
        req.send();
    };
    put_string = function (str) {
        forth_output(str + "\\n");
    };
}

var heap = new ArrayBuffer(params.memsize);

/* console I/O */

var gLine = "";

function clog(addr) /* unused? */
{
    put_string(CStringAt(HEAP, addr));
}

function foreign_putchar(c)
{
    if (c == 10) {
        put_string(gLine);
        gLine = "";
    } else {
        gLine += String.fromCharCode(c);
    }
}

/* Library functions */

function CStringTo(str, heap, offset)
{
    var i0;

    for (i0 = 0; i0 < str.length; i0++) {
        heap[offset + i0] = str.charCodeAt(i0);
    }

    heap[offset + i0] = 0;

    return i0+1;
}

function CStringAt(heap, offset)
{
    var ret = '';

    for (var i0 = offset; heap[i0]; i0++) {
        ret += String.fromCharCode(heap[i0]);
    }

    return ret;
}

function StringAt(heap, offset, length)
{
    var ret = '';

    for (var i0 = offset; length--; i0++) {
        ret += String.fromCharCode(heap[i0]);
    }

    return ret;
}

var startDate = new Date();

function foreign_bye(c)
{
    bye();
}

function foreign_dump(c)
{
    var s = "";
    for (var i = 0; i < (params.memsize + 3) / 4; i++) {
        if (HEAP[i])
            s += "HEAP["+i+"] = 0x"+HEAP[i].toString(16)+";\\n";
    }
    put_string(s);
}

var loaded = {};
var load_address = {};
var next_load_address = params.fsoff;
var load_size = {};

function load_file(heapu8, path)
{
    var str;
    var succ;
    read_file_async(path, function (str) {
        if (str === undefined || str === null) {
            loaded[path] = 1;
            resume(path);
            return;
        }

        next_load_address += 31;
        next_load_address &= -32;
        load_size[path] = CStringTo(str, heapu8, next_load_address + 32);
        load_address[path] = next_load_address;;
        HEAP[next_load_address+4] = 0; // position
        HEAP[next_load_address+8] = load_size[path]-1; // size
        HEAP[next_load_address+12] = 1; // call slow_read flag
        next_load_address += 32 + load_size[path];

        succ = true;
        loaded[path] = 1;
        resume(path);
    });

    if (succ)
        return true;

    resume_string = path;
    return;
}

var fhs = {}; /* file handles */

function foreign_open_file(addr, u, mode)
{
    var path = StringAt(addr.o, addr.i, u);
    //var mode = CStringAt(mode.o, mode.i);

    //console.log("opening " + path);

    var fileid = 0;

    if (!loaded[path]) {
        loaded[path] = .5;

        load_file(HEAP, path);
    }
    if (loaded[path] == .5) {
        resume_string = path;
        return -2;
    }

    if (path in load_address) {
        fileid = load_address[path];
        fhs[fileid] = { offset: 0 };
        HEAP[load_address[path]+4] = 0; // reset position.
    }

    return fileid;
}

function foreign_read_file(addr, u1, fileid)
{
    var i;

    if (fileid instanceof Reference)
        fileid = fileid.i;

    if (fileid === 0 && (!fhs[fileid] || HEAP[fhs[fileid].offset + 32] === 0)) {
       fhs[0] = { offset: 1023 * 1024 };
       for (var i = 0; i < 1024; i++)
           HEAP[1023 * 1024 + i] = 0;
       var str;
       do {
           if (gInputLines.length)
               str = gInputLines.shift();
           else {
               if (read_line)
                   str = read_line();
               else {
                   resume_string = "//line";
                   return -2;
               }
           }
       } while (str === "");

       if (!str)
          foreign_bye(0);
       var len = CStringTo(str, HEAP, fhs[0].offset + 32);
       HEAP[1024 * 1023 + 32 + len - 1] = "\\n".charCodeAt(0);
       HEAP[1024 * 1023 + 32 + len] = 0;
    }
    var off = fhs[fileid].offset;

    for (i = 0; i < u1; i++)
        if ((addr.o[addr.i + i] = HEAP[fileid + off + 32 + i]) == 0)
           break;

    fhs[fileid].offset += i;
    return i;
}

function lbForth(stdlib, foreign, buffer)
{
    "use asm";
    var imul = stdlib.Math.imul;
    var add = function (a, b)
    {
        //console.log("add " + a + " " + b);

        if (a instanceof Reference)
            return a.add(b);
        else if (b instanceof Reference) {
            //console.log("-> " + b.add(a));

            return b.add(a);
        }

        return (a|0)+(b|0);
    };
    var sub = function (a, b)
    {
        //console.log("add " + a + " " + b);

        if ((a instanceof Reference) && (b instanceof Reference))
            return a.i - b.i;
        else if (a instanceof Reference)
            return a.i - b;
        else if (b instanceof Reference)
            return a - b.i;
        else
            return (a|0) - (b|0);
    };

    var deref = function (r, o)
    {
        if (r instanceof Reference)
            return r.o[r.i+o];
        else
            return (HEAP[r + o]);
    };
    var foreign_putchar = foreign.putchar;
    var foreign_open_file = foreign.open_file;
    var foreign_read_file = foreign.read_file;
    var foreign_bye = foreign.bye;
    var foreign_dump = foreign.dump;

function asmmain(word, IP, SP, RP)
{
    word = word;
    IP = IP;
    SP = SP;
    RP = RP;
    var H = HEAP;

    var f = [
end-code

code exit
    IP = H[RP];
    RP = RP+1;
end-code

code sp@
    SP = SP-1;
    H[SP] = SP+1;
end-code

code sp!
    SP = top;
end-code

code rp@
    SP = SP-1;
    H[SP] = RP;
end-code

code rp!
    RP = top;
    SP = SP+1;
end-code

code dodoes
    SP = SP-1;
    H[SP] = add(word, 19);
    RP = RP-1;
    H[RP] = IP;
    IP = deref(word, 17);
end-code

code docol
    RP = RP-1;
    H[RP] = IP;
    IP = add(word, 19);
end-code

code dovar
    SP = SP-1;
    H[SP] = add(word, 19);
end-code

code docon
    SP = SP-1;
    H[SP] = deref(word, 19);
end-code

code dodef
    word = deref(word, 19);
    RP = RP-1;
    H[RP] = IP;
    IP = new Reference([0, word, 1024], 1);
end-code

code 0branch
    //console.log("0branch " + top);
    addr = deref(IP, 0);
    SP = SP+1;
    if (top instanceof Reference)
      IP = add(IP, 1);
    else if (top == 0)
      IP = addr;
    else
      IP = add(IP, 1);
end-code

code branch
    IP = deref(IP, 0);
end-code

code (literal)
    SP = SP-1;
    H[SP] = deref(IP, 0);
    IP = add(IP, 1);
end-code

code !
    SP = SP+1;
    x = H[SP];
    SP = SP+1;
    if (top instanceof Reference)
        top.o[top.i] = x;
    else
        H[top] = x;
    //console.log("! " + top + " " + x);
end-code

code @
    if (top instanceof Reference)
        H[SP] = top.o[top.i];
    else
        H[SP] = H[top];
    //console.log("@ " + top + " " + H[SP]);
end-code

code +
    SP = SP+1;
    H[SP] = add(H[SP], top);
end-code

code negate
    H[SP] = sub(0, top);
    //console.log("negate " + top + " = " + H[SP]);
end-code

code -
    SP = SP+1;
    H[SP] = sub(H[SP], top);
end-code

code >r  ( x -- ) ( R: -- x )
    SP = SP+1;
    RP = RP - 1;
    H[RP] = top;
end-code

code r> ( -- x ) ( R: x -- )
    x = H[RP];
    RP = RP+1;
    SP = SP-1;
    H[SP] = x;
end-code

code 2r>
    x = H[RP];
    RP = RP+1;
    y = H[RP];
    RP = RP+1;
    SP = SP-1;
    H[SP] = y;
    SP = SP-1;
    H[SP] = x;
end-code

code 2>r
    SP = SP+1;
    y = H[SP];
    SP = SP+1;
    RP = RP-1;
    H[RP] = y;
    RP = RP-1;
    H[RP] = top;
end-code

code c!
    SP = SP+1;
    x = H[SP];
    SP = SP+1;
    if (top instanceof Reference)
        top.o[top.i] = x;
    else
        H[top] = x;
    //console.log("c! " + top + " " + c);
end-code

code c@
    if (top instanceof Reference)
        H[SP] = top.o[top.i]&255;
    else
        H[SP] = H[top]&255;
    //console.log("c@ " + top + " " + H[SP]);
end-code

code (loop)
    ////console.log("loop " + H[RP] + " " + H[RP+1]);

    H[RP] = add(H[RP], 1);
    SP = SP-1;
    if ((H[RP] instanceof Reference) &&
             H[RP].i >= H[RP+1].i)
        H[SP] = -1;
    else if (H[RP] instanceof Reference)
        H[SP] = 0;
    else if (H[RP] >= H[RP+1])
        H[SP] = -1;
    else
        H[SP] = 0;
    ////console.log("loop " + H[SP]);
end-code

code 2rdrop
    RP = RP+2;
end-code

code emit
    SP = SP+1;
    foreign_putchar (top);
end-code

\ optional words

code dup
    SP = SP-1;
    H[SP] = top;
end-code

code 0=
    var c;
    ////console.log("0= " + top);
    if (top instanceof Reference)
        c = (top.i == 0) ? -1 : 0;
    else if ((top) == 0)
        c = -1;
    else
        c = 0;
    H[SP] = c;
end-code

code 0<>
    var c;
    ////console.log("0<> " + top);
    if (top instanceof Reference)
        c = (top.i != 0) ? -1 : 0;
    else if ((top) == 0)
        c = 0;
    else
        c = -1;
    H[SP] = c;
end-code

code 0<
    var c;
    ////console.log("0< " + top);
    if (top instanceof Reference)
        c = (top.i < 0) ? -1 : 0;
    else if (0 > (top))
        c = -1;
    else
        c = 0;
    H[SP] = c;
end-code

code <
    var c;
    SP = SP+1;
    ////console.log("< " + top + " " + H[SP]);
    if (top instanceof Reference)
        c = (top.i > H[SP].i) ? -1 : 0;
    else if ((top>>0) > (H[SP]>>0))
        c = -1;
    else
        c = 0;
    H[SP] = c;
end-code

code rot
    H[SP] = H[SP+2];
    H[SP+2] = H[SP+1];
    H[SP+1] = top;
end-code

code -rot
    H[SP] = H[SP+1];
    H[SP+1] = H[SP+2];
    H[SP+2] = top;
end-code

code nip
    SP = SP+1;
    H[SP] = top;
end-code

code drop
    SP = SP+1;
end-code

code 2dup
    SP=SP-2;
    H[SP+1] = H[SP+3];
    H[SP] = top;
end-code

code ?dup
    if (top) {
        SP = SP-1;
        H[SP] = top;
    }
end-code

code swap
    H[SP] = H[SP+1];
    H[SP+1] = top;
end-code

code over
    SP = SP-1;
    H[SP] = H[SP+2];
end-code

code invert
    ////console.log("invert " + top);
    H[SP] = ~(top);
end-code

code xor
    SP=SP+1;
    H[SP] = H[SP]^top;
end-code

code or
    SP=SP+1;
    H[SP] = H[SP]|top;
end-code

code and
    SP=SP+1;
    H[SP] = H[SP]&top;
end-code

code nand
    SP=SP+1;
    ////console.log("nand " + top + " " + H[SP]);
    H[SP] = ~(H[SP]&top);
end-code

code =
    SP=SP+1;
    ////console.log("= " + top + " " + H[SP]);
    if ((top instanceof Reference) &&
        H[SP].i == top.i)
        H[SP] = -1;
    else
        H[SP] = ((H[SP]) == (top)) ? -1 : 0;
end-code

code <>
    SP=SP+1;
    ////console.log("<> " + top + " " + H[SP]);
    if ((top instanceof Reference) &&
        H[SP].i == top.i)
        H[SP] = 0;
    else
        H[SP] = ((H[SP]) != (top)) ? -1 : 0;
end-code

code 1+
    H[SP] = add(top, 1);
end-code

code 2*
    H[SP] = add(top, top);
end-code

code *
    SP=SP+1;
    H[SP] = imul(top, H[SP]);
end-code

code tuck
    SP=SP-1;
    H[SP+1] = H[SP+2];
    H[SP+2] = top;
    H[SP] = top;
end-code

code bye
    foreign_bye(0);
end-code

code close-file
    H[SP] = 0;
end-code

code open-file
    var c;
    SP = SP+1;
    y = H[SP];
    SP = SP+1;
    c = H[SP];
    SP = SP+1;

    if (!(c instanceof Reference))
        c = new Reference(H, c);

    //console.log("read-file " + c + z + addr + x );

    addr = foreign_open_file(c, y, top);
    if ((addr) == -2) {
        SP = SP-4;
        H[SP] = IP;
        SP = SP-1;
        H[SP] = RP;
        SP = SP-1;
        H[SP] = word;

        return SP;
    }
    SP = SP-1;
    H[SP] = addr;
    SP = SP-1;
    if ((addr) == 0)
        H[SP] = 1;
    else
        H[SP] = 0;
    //console.log("read-file " + H[SP]);
end-code

code read-file
    var c;
    c = H[SP];
    SP = SP+1;
    z = H[SP];
    SP = SP+1;
    addr = H[SP];
    SP = SP+1;

    //console.log("read-file " + addr + " " + z + " " + c + " -> " + i);
    if (!(c instanceof Reference))
        c = new Reference(H, c);
    if (!(addr instanceof Reference))
        addr = new Reference(H, addr);

    x = c.o[c.i+8];
    y = c.o[c.i+4];

    if ((x) == (y)) {
        if ((c.o[c.i+12]) != 0)
            i = 0;
        else
            i = foreign_read_file(addr, z, c);
        if ((i) == -2) {
            SP = SP-4;
            H[SP] = IP;
            SP = SP-1;
            H[SP] = RP;
            SP = SP-1;
            H[SP] = word;

            return SP;
        }
    } else {
        if ((z>>>0) > ((x-y)>>>0))
            z = (x-y);
        for (i = 0; (i>>>0) < (z>>>0); i = (i+1)) {
            addr.o[addr.i+i] = c.o[c.i+32+y+i];
        }
        c.o[c.i+4] = y + i;
    }

    SP = SP-1;
    H[SP] = i;
    //console.log("read-file " + addr + " " + z + " " + c + " -> " + i);
    SP = SP-1;
    H[SP] = 0;
end-code

code js-array
    SP = SP-1;
    H[SP] = [];
    for (var i = 0; i < 32; i++) H[i] = 0;
end-code

code js-in
    SP = SP+1;
    //console.log(top + "(" + typeof(top) + ")");
    //console.log(H[SP] + "(" + typeof(H[SP]) + ")");
    H[SP] = ((typeof(H[SP]) === "object") && (top in H[SP])) ? -1 : 0;
end-code

code js-object
    SP = SP-1;
    H[SP] = {};
end-code

code $ref
    SP = SP+1;
    H[SP] = new Reference(H[SP], top);
end-code

code $o
    H[SP] = top.o;
end-code

code $i
    H[SP] = top.i;
end-code

code js.
    SP = SP+1;
    console.log(top); // + "(" + typeof(top) + ")");
end-code

code jsexp
    SP = SP+1;
    if (typeof top === "number")
        console.log(top);
    else if (typeof top === "string")
        console.log("\\"" + top.replace(/\\"/g, "\\\\\\\"") + "\\"");
end-code

code $!
    SP = SP+1;
    H[SP][top] = H[SP+1];
    SP = SP+2;
end-code

code $@
    SP = SP+1;
    H[SP] = H[SP][top];
end-code

code $here
    H[SP] = top.length;
end-code

code $#
    H[SP] = top.length;
end-code

code $0
    H[SP] = top[0];
end-code

code $?
    H[SP] = top[top.length-1];
end-code

code $last
    H[SP] = top[top.length-1];
end-code

code $truncate
    SP = SP+1;
    while (top.length > H[SP])
        top.pop();
    SP = SP+1;
end-code

code $#!
    SP = SP+1;
    while (top.length > H[SP])
        top.pop();
    SP = SP+1;
end-code

code $,
    SP = SP+1;
    top.push(H[SP]);
    SP = SP+1;
end-code

code $in
    var res = [];
    for (var prop in top)
        res.push(prop);
    H[SP] = res;
end-code

code $of
    var res = [];
    for (var prop of top)
        res.push(prop);
    H[SP] = res;
end-code

code $>
    H[SP] = top.pop();
end-code

code <$
    H[SP] = top.shift();
end-code

code >$
    SP = SP+1;
    top.push(H[SP]);
    SP = SP+1;
end-code

code $<
    SP = SP+1;
    top.unshift(H[SP]);
    SP = SP+1;
end-code

code &
    SP = SP+1;
    H[SP] = new Reference(H[SP], top);
end-code

code ref
    SP = SP+1;
    H[SP] = new Reference(H[SP], top);
end-code

code fth""
    H[SP] = top.length;
    SP = SP-1;
    H[SP] = [];
    for (var i = 0; i < top.length; i++)
        H[SP][i+1] = top.charCodeAt(i);
    H[SP] = new Reference(H[SP], 1);
end-code

code js""
    var ret = "";
    SP = SP+1;
    for (var i = 0; i < top; i++)
        ret += String.fromCharCode(H[H[SP] + i]);
    H[SP] = ret;
end-code

code js[]
    SP = SP - 1;
    H[SP] = [];
end-code

code js{}
    SP = SP - 1;
    H[SP] = {};
end-code

code js()
    var args = [];

    for (i = 0; i < top; i++)
        args.push(H[SP+top-i]);

    SP += top + 1;

    //console.log(H[SP] + "(" + typeof(H[SP]) + ")");
    //console.log(args + "(" + typeof(args) + ")");
    H[SP] = H[SP].apply(undefined, args);
end-code

code js{}()
    var args = [];

    for (i = 0; i < top; i++)
        args.push(H[SP+top-i]);

    SP += top + 1;

    console.log(H[SP] + "(" + typeof(H[SP]) + ")");
    console.log(args + "(" + typeof(args) + ")");
    var t = args.shift();
    H[SP] = H[SP].apply(t, args);
end-code

code find-own-level
    SP = SP + 1;
    for (i = H[SP].length - 1; i >= 0; i--) {
        if (H[SP][i].hasOwnProperty(top))
            break;
     }
     H[SP] = i;
end-code

code js
    SP = SP - 1;
    H[SP] = global;
end-code

code js===
    SP = SP + 1;
    H[SP] = H[SP] === top;
end-code

start-code
    ];

    while (1) {
        f[deref(word,18)|0]();
        word = deref(IP, 0);
        IP = add(IP, 1);
    }

    return 0;
}

    return { asmmain: asmmain };
}

var asmmodule;
var global_sp;

function run(turnkey)
{
    asmmodule = lbForth({
            Uint8Array: Uint8Array,
            Uint32Array: Uint32Array,
            Math: {
                imul: Math.imul || function(a, b) {
                    var ah = (a >>> 16) & 0xffff;
                    var al = a & 0xffff;
                    var bh = (b >>> 16) & 0xffff;
                    var bl = b & 0xffff;
                    return ((al * bl) + (((ah * bl + al * bh) << 16) >>> 0)|0);
                }
            }
        }, {
            clog: clog,
            putchar: foreign_putchar,
            open_file: foreign_open_file,
            read_file: foreign_read_file,
            bye: foreign_bye,
            dump: foreign_dump
        }, heap);

    //try {
        return global_sp = asmmodule.asmmain(turnkey,
        new Reference(HEAP, 0), params.sp0, params.rp0);
    //} catch (e) {
    //    put_string(e);
    //}
}

function resume(str)
{
    if (str !== resume_string)
        return;

    if (str === undefined)
        return;

    resume_string = undefined;

    var sp = global_sp;
    if (!global_sp)
        return;

    var word = HEAP[sp];
    sp += 1;
    var RP = HEAP[sp];
    sp += 1;
    var IP = HEAP[sp];
    sp += 1;
    var SP = sp;

    try {
        global_sp = 0;
        global_sp = asmmodule.asmmain(word, IP, SP, RP);
    } catch (e) {
        put_string(e);
    }
}
end-code
