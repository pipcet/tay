TARGET = c
OS = .

-include conf.mk

prefix ?= /usr/local
DESTDIR = $(prefix)
bindir = $(DESTDIR)/bin
sharedir = $(DESTDIR)/share
sysdir ?= $(sharedir)/lbForth

TFORTH = $(TARGET)-forth
TDIR = targets/$(TARGET)
TSTAMP = $(TARGET)-$(OS)-stamp
META = $(TDIR)/meta.fth
FORTH = $(TDIR)/run.sh ./forth
DEPS = src/kernel.fth src/dictionary.fth $(TDIR)/nucleus.fth
PARAMS = params.fth jump.fth threading.fth target.fth

GREP = grep -a
ERROR_PATTERNS = -e 'INCORRECT RESULT' -e 'WRONG NUMBER'


all: b-forth forth

b-forth:
	$(MAKE) -ftargets/c/bootstrap.mk
	cp $@ forth

tforth: $(TFORTH)

forth: $(TFORTH)
	rm -f forth.exe
	cp $< $@

$(TSTAMP): $(wildcard conf.mk)
	rm -f *-stamp
	touch $@

install: $(TFORTH)
	install $< $(bindir)/forth
	install -d $(sysdir)
	cp src/* $(sysdir)
	cp -r lib $(sysdir)
	cp -r targets $(sysdir)

uninstall:
	rm $(bindir)/forth
	rm -rf $(sysdir)

tay:
	js ./forth > forth2.js
	echo "include targets/js/meta-tay.fth" | js ./forth2.js | tail +3 > 2tay.js
	js 2tay.js  > tay.js

web:
	make tforth TARGET=asmjs
	cp asmjs-forth forth.js
	cp targets/asmjs/forth.html .

include $(TDIR)/forth.mk

include check.mk

clean: t-clean
	rm -f forth *-forth test-* *-stamp *.exe conf.mk forth.html forth.js

.PHONY: tay
