DESTDIR = /usr
INSTALL = install -C
RM = rm
SH = sh

.PHONY: all install

all:

install:
	$(SH) -n Rvenv
	$(INSTALL) Rvenv $(DESTDIR)/bin/Rvenv

uninstall:
	$(RM) -f $(DESTDIR)/bin/Rvenv
