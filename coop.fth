variable ticks js<> ticks !
: tick fork if exit then begin 1 ticks @ >$ ." tock" cr 1000 sleep repeat ;
: tickee fork if exit then begin ticks @ $> drop ." tick" cr repeat ;


tick
tickee
