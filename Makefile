ifeq ($(shell uname),Darwin)
  LIBTOOL ?= glibtool
else
  LIBTOOL ?= libtool
endif

ifneq ($(VERBOSE),1)
  LIBTOOL +=--quiet
endif

CFLAGS +=-Wall -Iinclude -std=c99

ifeq ($(DEBUG),1)
  CFLAGS +=-ggdb -DDEBUG
endif

ifeq ($(PROFILE),1)
  CFLAGS +=-pg
  LDFLAGS+=-pg
endif

ifeq ($(shell pkg-config --atleast-version=0.1.0 unibilium && echo 1),1)
  CFLAGS +=$(shell pkg-config --cflags unibilium) -DHAVE_UNIBILIUM
  LDFLAGS+=$(shell pkg-config --libs   unibilium)
else ifeq ($(shell pkg-config ncursesw && echo 1),1)
  CFLAGS +=$(shell pkg-config --cflags ncursesw)
  LDFLAGS+=$(shell pkg-config --libs   ncursesw)
else
  LDFLAGS+=-lncurses
endif

CFILES=$(wildcard src/*.c)
HFILES=$(wildcard include/*.h)
OBJECTS=$(CFILES:.c=.lo)
LIBRARY=libtickit.la

HFILES_INT=$(wildcard src/*.h) $(HFILES)

TESTSOURCES=$(wildcard t/[0-9]*.c)
TESTFILES=$(TESTSOURCES:.c=.t)

EXAMPLESOURCES=$(wildcard examples/*.c)

VERSION_CURRENT=0
VERSION_REVISION=0
VERSION_AGE=0

PREFIX=/usr/local
BINDIR=$(PREFIX)/bin
LIBDIR=$(PREFIX)/lib
INCDIR=$(PREFIX)/include

all: $(LIBRARY)

$(LIBRARY): $(OBJECTS)
	$(LIBTOOL) --mode=link --tag=CC $(CC) -rpath $(LIBDIR) -version-info $(VERSION_CURRENT):$(VERSION_REVISION):$(VERSION_AGE) -o $@ $^ $(LDFLAGS)

src/%.lo: src/%.c $(HFILES_INT)
	$(LIBTOOL) --mode=compile --tag=CC $(CC) $(CFLAGS) -o $@ -c $<

t/%.t: t/%.c $(LIBRARY) t/taplib.lo
	$(LIBTOOL) --mode=link --tag=CC gcc -o $@ -Iinclude $^

t/taplib.lo: t/taplib.c
	$(LIBTOOL) --mode=compile --tag=CC gcc $(CFLAGS) -o $@ -c $^

.PHONY: test
test: $(TESTFILES)
	prove -e ""

.PHONY: clean-test
clean-test:
	$(LIBTOOL) --mode=clean rm -f $(TESTFILES) t/taplib.lo

.PHONY: clean
clean: clean-test
	$(LIBTOOL) --mode=clean rm -f $(OBJECTS)
	$(LIBTOOL) --mode=clean rm -f $(LIBRARY)

.PHONY: examples
examples: $(EXAMPLESOURCES:.c=)

examples/%.lo: examples/%.c $(HFILES)
	$(LIBTOOL) --mode=compile --tag=CC $(CC) $(CFLAGS) -o $@ -c $<

examples/%: examples/%.lo $(LIBRARY)
	$(LIBTOOL) --mode=link --tag=CC gcc -o $@ $^

.PHONY: install
install: install-inc install-lib
	$(LIBTOOL) --mode=finish $(DESTDIR)$(LIBDIR)

install-inc: $(HFILES)
	install -d $(DESTDIR)$(INCDIR)
	install -m644 $(HFILES) $(DESTDIR)$(INCDIR)
	install -d $(DESTDIR)$(LIBDIR)/pkgconfig
	sed "s,@LIBDIR@,$(LIBDIR),;s,@INCDIR@,$(INCDIR)," <tickit.pc.in >$(DESTDIR)$(LIBDIR)/pkgconfig/tickit.pc

# rm the old binary first in case it's still in use
install-lib: $(LIBRARY)
	install -d $(DESTDIR)$(LIBDIR)
	$(LIBTOOL) --mode=install cp --remove-destination $(LIBRARY) $(DESTDIR)$(LIBDIR)/
