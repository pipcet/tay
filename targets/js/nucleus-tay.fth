\ -*- forth -*- Copyright 2017 Pip Cet

\ Nucleus for asm.js.

include targets/js/next-tay.fth

." var c = ``;" cr
." var HEAP = [];" cr

start-code
"use strict";
var top_of_memory = 1024 * 1024;
var gThreadDeque = [];

function PipeException()
{
}

function Pipe()
{
    Array.call(this);
    this.deque = [];
}

Pipe.prototype = Object.create(Array.prototype);

Pipe.prototype.pop = function ()
{
    if (this.length)
        return Array.prototype.pop.call(this);
    else
        throw new PipeException();
};

Pipe.prototype.shift = function ()
{
    if (this.length)
        return Array.prototype.shift.call(this);
    else
        throw new PipeException();
};

Pipe.prototype.wakeup = function ()
{
    var deque = this.deque;
    this.deque = [];

    for (var thread of deque) {
        console.log("waking up " + thread);
        thread.wakeup();
    }
};

Pipe.prototype.wait = function (thread)
{
    this.deque.push(thread);
};

Pipe.prototype.push = function (x)
{
    Array.prototype.push.call(this, x);
    if (this.length === 1)
        this.wakeup();
};

Pipe.prototype.unshift = function (x)
{
    Array.prototype.unshift.call(this, x);
    if (this.length === 1)
        this.wakeup();
};

var gStdin = new Pipe();

function MainScope()
{
    Array.call(this);
    for (var i = 0; i < 1024*1024; i++) this[i] = 0;
}

MainScope.prototype = Object.create(Array.prototype);

function Thread(IP)
{
    this.S = new Array();
    for (var i = 0; i < 256; i++)
        this.S[i] = 0;
    this.SP = 0;

    this.R = new Array();
    for (var i = 0; i < 256; i++)
        this.R[i] = 0;
    this.RP = 256;

    this.IP = IP;
}

Thread.prototype.resume = function ()
{
    try {
        return asmmodule.asmmain(this.IP, this.SP, this.RP, this);
    } catch (e) {
        put_string(e);
    }
};

Thread.prototype.wakeup = function ()
{
    gThreadDeque.push(this);
};

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
        if (gLine.startsWith("Undefined")) {
            var i;
            for (i = 0; i < 4096; i++)
                console.log(i + ": " + HEAP[i]);
            for (i = 96 * 1024; i < 96 * 1024 + 4096; i++)
                console.log(i + ": " + HEAP[i]);
        }
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

    for (i = 0; i < u1; i++) {
        if ((addr.o[addr.i + i] = HEAP[fileid + off + 32 + i]) == 0)
           break;
    }

    fhs[fileid].offset += i;
    return i;
}

function lbForth(stdlib, foreign, buffer)
{
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
            return new Reference(a.o, a.i - b);
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

function asmmain(IP, SP, RP, thread)
{
    var word = 0;
    var H = HEAP;
    var S = thread.S;
    var R = thread.R;

    var f = [
end-code

code exit
    IP = R[RP];
    RP = RP - 1;
end-code

code sp@
    SP = SP + 1;
    S[SP] = new Reference(S, SP - 1);
end-code

code sp!
    if (top instanceof Reference)
        top = top.i;
    SP = top;
end-code

code rp@
    SP = SP + 1;
    S[SP] = new Reference(R, RP);
end-code

code rp!
    if (top instanceof Reference)
        top = top.i;
    RP = top;
    SP = SP - 1;
end-code

code dodoes
    SP = SP + 1;
    S[SP] = add(word, 5);
    RP = RP + 1;
    R[RP] = IP;
    IP = deref(word, 3);
end-code

code docol
    RP = RP + 1;
    R[RP] = IP;
    IP = add(word, 5);
end-code

code dovar
    SP = SP + 1;
    S[SP] = add(word, 5);
end-code

code docon
    SP = SP + 1;
    S[SP] = deref(word, 5);
end-code

code dodef
    word = deref(word, 5);
    RP = RP + 1;
    R[RP] = IP;
    IP = new Reference([0, word, 1024], 1);
end-code

code 0branch
    //console.log("0branch " + top);
    addr = deref(IP, 0);
    SP = SP - 1;
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
    SP = SP + 1;
    S[SP] = deref(IP, 0);
    IP = add(IP, 1);
end-code

code !
    SP = SP - 1;
    x = S[SP];
    SP = SP - 1;
    if (top instanceof Reference)
        top.o[top.i] = x;
    else
        H[top] = x;
    //console.log("! " + top + " " + x);
end-code

code @
    if (top instanceof Reference)
        S[SP] = top.o[top.i];
    else
        S[SP] = H[top];
    //console.log("@ " + top + " " + S[SP]);
end-code

code +
    SP = SP - 1;
    S[SP] = add(S[SP], top);
end-code

code -
    SP = SP - 1;
    S[SP] = sub(S[SP], top);
end-code

code js+
    SP = SP - 1;
    S[SP] = S[SP] + top;
end-code

code negate
    S[SP] = sub(0, top);
    //console.log("negate " + top + " = " + S[SP]);
end-code

code -
    SP = SP - 1;
    S[SP] = sub(S[SP], top);
end-code

code >r  ( x -- ) ( R: -- x )
    SP = SP - 1;
    RP = RP + 1;
    R[RP] = top;
end-code

code r> ( -- x ) ( R: x -- )
    x = R[RP];
    RP = RP - 1;
    SP = SP + 1;
    S[SP] = x;
end-code

code 2r>
    x = R[RP];
    RP = RP - 1;
    y = R[RP];
    RP = RP - 1;
    SP = SP + 1;
    S[SP] = y;
    SP = SP + 1;
    S[SP] = x;
end-code

code 2>r
    SP = SP - 1;
    y = S[SP];
    SP = SP - 1;
    RP = RP + 1;
    R[RP] = y;
    RP = RP + 1;
    R[RP] = top;
end-code

code c!
    SP = SP - 1;
    x = S[SP];
    SP = SP - 1;
    if (top instanceof Reference)
        top.o[top.i] = x;
    else
        H[top] = x;
    //console.log("c! " + top + " " + c);
end-code

code c@
    if (top instanceof Reference)
        S[SP] = top.o[top.i]&255;
    else
        S[SP] = H[top]&255;
    //console.log("c@ " + top + " " + S[SP]);
end-code

code (loop)
    //console.log("loop " + R[RP] + " " + R[RP - 1]);

    R[RP] = add(R[RP], 1);
    SP = SP + 1;
    if ((R[RP] instanceof Reference) &&
             R[RP].i >= R[RP - 1].i)
        S[SP] = -1;
    else if (R[RP] instanceof Reference)
        S[SP] = 0;
    else if (R[RP] >= R[RP - 1])
        S[SP] = -1;
    else
        S[SP] = 0;
    ////console.log("loop " + S[SP]);
end-code

code 2rdrop
    RP = RP - 2;
end-code

code emit
    SP = SP - 1;
    foreign_putchar (top);
end-code

\ optional words

code dup
    SP = SP + 1;
    S[SP] = top;
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
    S[SP] = c;
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
    S[SP] = c;
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
    S[SP] = c;
end-code

code <
    var c;
    SP = SP - 1;
    ////console.log("< " + top + " " + S[SP]);
    if (top instanceof Reference)
        c = (top.i > S[SP].i) ? -1 : 0;
    else if ((top>>0) > (S[SP]>>0))
        c = -1;
    else
        c = 0;
    S[SP] = c;
end-code

code rot
    S[SP] = S[SP - 2];
    S[SP - 2] = S[SP - 1];
    S[SP - 1] = top;
end-code

code -rot
    S[SP] = S[SP - 1];
    S[SP - 1] = S[SP - 2];
    S[SP - 2] = top;
end-code

code nip
    SP = SP - 1;
    S[SP] = top;
end-code

code drop
    SP = SP - 1;
end-code

code 2dup
    SP=SP + 2;
    S[SP - 1] = S[SP - 3];
    S[SP] = top;
end-code

code ?dup
    if (top) {
        SP = SP + 1;
        S[SP] = top;
    }
end-code

code swap
    S[SP] = S[SP - 1];
    S[SP - 1] = top;
end-code

code over
    SP = SP + 1;
    S[SP] = S[SP - 2];
end-code

code invert
    ////console.log("invert " + top);
    S[SP] = ~(top);
end-code

code xor
    SP=SP - 1;
    S[SP] = S[SP]^top;
end-code

code or
    SP=SP - 1;
    S[SP] = S[SP]|top;
end-code

code and
    SP=SP - 1;
    S[SP] = S[SP]&top;
end-code

code nand
    SP=SP - 1;
    ////console.log("nand " + top + " " + S[SP]);
    S[SP] = ~(S[SP]&top);
end-code

code =
    SP=SP - 1;
    ////console.log("= " + top + " " + S[SP]);
    if ((top instanceof Reference) &&
        S[SP].i == top.i)
        S[SP] = -1;
    else
        S[SP] = ((S[SP]) == (top)) ? -1 : 0;
end-code

code <>
    SP=SP - 1;
    ////console.log("<> " + top + " " + S[SP]);
    if ((top instanceof Reference) &&
        S[SP].i == top.i)
        S[SP] = 0;
    else
        S[SP] = ((S[SP]) != (top)) ? -1 : 0;
end-code

code 1+
    S[SP] = add(top, 1);
end-code

code 2*
    S[SP] = add(top, top);
end-code

code *
    SP=SP - 1;
    S[SP] = imul(top, S[SP]);
end-code

code tuck
    SP=SP + 1;
    S[SP - 1] = S[SP - 2];
    S[SP - 2] = top;
    S[SP] = top;
end-code

code bye
    foreign_bye(0);
end-code

code close-file
    S[SP] = 0;
end-code

code open-file
    var c;
    SP = SP - 1;
    y = S[SP];
    SP = SP - 1;
    c = S[SP];
    SP = SP - 1;

    if (!(c instanceof Reference))
        c = new Reference(H, c);

    //console.log("open-file " + c + z + addr + x );

    addr = foreign_open_file(c, y, top);
    if ((addr) == -2) {
        SP = SP + 4;
        S[SP] = IP;
        SP = SP + 1;
        S[SP] = RP;
        SP = SP + 1;
        S[SP] = word;

        return SP;
    }
    SP = SP + 1;
    S[SP] = addr;
    SP = SP + 1;
    if ((addr) == 0)
        S[SP] = 1;
    else
        S[SP] = 0;
    //console.log("read-file " + S[SP]);
end-code

code read-file
    var c;
    c = S[SP];
    SP = SP - 1;
    z = S[SP];
    SP = SP - 1;
    addr = S[SP];
    SP = SP - 1;

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
            SP = SP + 4;
            S[SP] = IP;
            SP = SP + 1;
            S[SP] = RP;
            SP = SP + 1;
            S[SP] = word;

            return SP;
        }
    } else {
        if ((z>>>0) > ((x-y)>>>0))
            z = (x-y);
        for (i = 0; (i>>>0) < (z>>>0); i = (i+1)) {
            addr.o[addr.i+i] = c.o[c.i+32+y+i];
            //console.log(String.fromCharCode(addr.o[addr.i+i]));
        }
        c.o[c.i+4] = y + i;
    }

    SP = SP + 1;
    S[SP] = i;
    //console.log("read-file " + addr + " " + z + " " + c + " -> " + i);
    SP = SP + 1;
    S[SP] = 0;
end-code

code js-array
    SP = SP + 1;
    S[SP] = [];
end-code

code js-in
    SP = SP - 1;
    //console.log(top + "(" + typeof(top) + ")");
    //console.log(S[SP] + "(" + typeof(S[SP]) + ")");
    S[SP] = ((typeof(S[SP]) === "object") && (top in S[SP])) ? -1 : 0;
end-code

code js-object
    SP = SP + 1;
    S[SP] = {};
end-code

code $ref
    SP = SP - 1;
    S[SP] = new Reference(S[SP], top);
end-code

code $o
    S[SP] = top.o;
end-code

code $i
    S[SP] = top.i;
end-code

code js.
    SP = SP - 1;
    console.log(top); // + "(" + typeof(top) + ")");
end-code

code jsexp
    SP = SP - 1;
    if (typeof top === "number")
        console.log(top);
    else if (typeof top === "string")
        console.log("\\"" + top.replace(/\\"/g, "\\\\\\\"") + "\\"");
end-code

code $!
    SP = SP - 1;
    S[SP][top] = S[SP - 1];
    SP = SP - 2;
end-code

code $@
    SP = SP - 1;
    S[SP] = S[SP][top];
end-code

code $here
    S[SP] = top.length;
end-code

code $#
    S[SP] = top.length;
end-code

code $0
    S[SP] = top[0];
end-code

code $?
    S[SP] = top[top.length-1];
end-code

code $last
    S[SP] = top[top.length-1];
end-code

code $truncate
    SP = SP - 1;
    while (top.length > S[SP])
        top.pop();
    SP = SP - 1;
end-code

code $#!
    SP = SP - 1;
    while (top.length > S[SP])
        top.pop();
    SP = SP - 1;
end-code

code $,
    SP = SP - 1;
    top.push(S[SP]);
    SP = SP - 1;
end-code

code $in
    var res = [];
    for (var prop in top)
        res.push(prop);
    S[SP] = res;
end-code

code $of
    var res = [];
    for (var prop of top)
        res.push(prop);
    S[SP] = res;
end-code

code $>
    try {
        var x = top.pop();
        S[SP] = x;
    } catch (e) {
        thread.IP = IP - 1;
        thread.SP = SP;
        thread.RP = RP;
        top.wait(thread);
        return SP;
    }
end-code

code <$
    try {
        var x = top.shift();
        S[SP] = x;
    } catch (e) {
        thread.IP = IP - 1;
        thread.SP = SP;
        thread.RP = RP;
        top.wait(thread);
        return SP;
    }
end-code

code >$
    SP = SP - 1;
    top.push(S[SP]);
    SP = SP - 1;
end-code

code $<
    SP = SP - 1;
    top.unshift(S[SP]);
    SP = SP - 1;
end-code

code &
    SP = SP - 1;
    S[SP] = new Reference(S[SP], top);
end-code

code ref
    SP = SP - 1;
    S[SP] = new Reference(S[SP], top);
end-code

code js""
    var ret = "";
    SP = SP - 1;
    if (!(S[SP] instanceof Reference))
        S[SP] = new Reference(H, S[SP]);
    for (var i = 0; i < top; i++)
        ret += String.fromCharCode(S[SP].o[S[SP].i + i]);
    S[SP] = ret;
end-code

code fth""
    if (typeof(top) === "number" && top !== 0) {
        var i = 0;
        for (i = 0; i < 64; i++)
            console.log("rstk " + i + " = " + R[RP+i]);
        for (i = 0; i < 4096; i++)
            console.log(i + ": " + HEAP[i]);
        for (i = 96 * 1024; i < 96 * 1024 + 4096; i++)
            console.log(i + ": " + HEAP[i]);
        console.log("forthifying " + top + typeof(top));
    }
    S[SP] = [];
    for (var i = 0; i < top.length; i++)
        S[SP][i+1] = top.charCodeAt(i);
    S[SP] = new Reference(S[SP], 1);
    SP = SP + 1;
    S[SP] = top.length || 0;
end-code

code js[]
    SP = SP + 1;
    S[SP] = [];
end-code

code js{}
    SP = SP + 1;
    S[SP] = {};
end-code

code js<>
    SP = SP + 1;
    S[SP] = new Pipe();
end-code

code js()
    var args = [];

    for (i = 0; i < top; i++)
        args.push(S[SP+i-top]);

    SP -= top + 1;

    //console.log(S[SP] + "(" + typeof(S[SP]) + ")");
    //console.log(args + "(" + typeof(args) + ")");
    S[SP] = S[SP].apply(undefined, args);
end-code

code js{}()
    var args = [];

    for (i = 0; i < top; i++)
        args.push(S[SP+i-top]);

    SP -= top + 1;

    //console.log(S[SP] + "(" + typeof(S[SP]) + ")");
    //console.log(args + "(" + typeof(args) + ")");
    var t = args.shift();
    S[SP] = S[SP].apply(t, args);
end-code

code jsnew()
    var args = [];

    for (i = 0; i < top; i++)
        args.push(S[SP+i-top]);

    SP -= top + 1;

    //console.log(S[SP] + "(" + typeof(S[SP]) + ")");
    //console.log(args + "(" + typeof(args) + ")");
    S[SP] = new S[SP](...args);
end-code

code find-own-level
    SP = SP - 1;
    for (i = S[SP].length - 1; i >= 0; i--) {
        if (S[SP][i].hasOwnProperty(top))
            break;
    }
    S[SP] = i;
end-code

code js
    SP = SP + 1;
    S[SP] = global;
end-code

code js===
    SP = SP - 1;
    //console.log(S[SP] + typeof(S[SP]) + "===" + top + typeof(top) + "?" + (S[SP] === top));
    if (S[SP] === top)
        S[SP] = -1;
    else
        S[SP] = 0;
end-code

code fork
    var nt = new Thread(IP);

    gThreadDeque.push(nt);

    nt.SP = nt.SP + 1;
    nt.S[nt.SP] = 0;

    SP = SP + 1;
    S[SP] = 1;
end-code

code yield
    thread.IP = IP;
    thread.SP = SP;
    thread.RP = RP;

    gThreadDeque.push(thread);

    return 0;
end-code

start-code
    ];

    var start = Date.now();
    while (1) {
        word = deref(IP, 0);
        IP = add(IP, 1);
        var ret = f[deref(word,4)|0]();
        if (ret !== undefined)
            return ret;
    }

    return 0;
}

    return { asmmain: asmmain };
}

var asmmodule;

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
    });


function resume()
{
    while (gThreadDeque.length) {
        var thread = gThreadDeque.shift();
        var ret = thread.resume();
    }
}

end-code
