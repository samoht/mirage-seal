VERSION = $(shell grep 'Version:' _oasis | sed 's/Version: *//')
VFILE   = src/version.ml
SFILE   = src/static.ml
SETUP   = ocaml setup.ml
CRUNCH  = ocaml-crunch

build: setup.data $(SFILE) $(VFILE)
	$(SETUP) -build $(BUILDFLAGS)

doc: setup.data build
	$(SETUP) -doc $(DOCFLAGS)

test: setup.data build
	$(SETUP) -test $(TESTFLAGS)

all:
	$(SETUP) -all $(ALLFLAGS)

install: setup.data
	$(SETUP) -install $(INSTALLFLAGS)

uninstall: setup.data
	$(SETUP) -uninstall $(UNINSTALLFLAGS)

reinstall: setup.data
	$(SETUP) -reinstall $(REINSTALLFLAGS)

clean:
	$(SETUP) -clean $(CLEANFLAGS)
	rm -f $(VFILE) $(SFILE)

distclean:
	$(SETUP) -distclean $(DISTCLEANFLAGS)

setup.data:
	$(SETUP) -configure $(CONFIGUREFLAGS)

configure:
	$(SETUP) -configure $(CONFIGUREFLAGS)

.PHONY: build doc test all install uninstall reinstall clean distclean configure

src/static.ml: static
	$(CRUNCH) static -o $(SFILE) -m plain

$(VFILE): _oasis
	echo "let current = \"$(VERSION)\"" > $@
