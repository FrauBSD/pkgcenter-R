DESTDIR = /usr
INSTALL = install -C
RM = rm
SH = sh

.PHONY: all install

all:

install:
	$(SH) -n Renv
	$(INSTALL) Renv $(DESTDIR)/bin/Renv

uninstall:
	$(RM) -f $(DESTDIR)/bin/Renv
