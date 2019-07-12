DESTDIR = /usr
INSTALL = install -C
LINKS = \
	$(DESTDIR)/libexec/vcr/compare==cmp \
	$(DESTDIR)/libexec/vcr/diff==cmp \
	$(DESTDIR)/libexec/vcr/eject==rm \
	$(DESTDIR)/libexec/vcr/freeze==ls \
	$(DESTDIR)/libexec/vcr/insert==add \
	$(DESTDIR)/libexec/vcr/install==add \
	$(DESTDIR)/libexec/vcr/list==ls \
	$(DESTDIR)/libexec/vcr/load==add \
	$(DESTDIR)/libexec/vcr/pause==ls \
	$(DESTDIR)/libexec/vcr/rec==ls \
	$(DESTDIR)/libexec/vcr/record==ls \
	$(DESTDIR)/libexec/vcr/remove==rm \
	$(DESTDIR)/libexec/vcr/uninstall==rm \
	$(DESTDIR)/libexec/vcr/unload==rm
LN = ln
MKDIR = mkdir
RM = rm
RMDIR = rmdir
SH = sh

.PHONY: all install

all:

install:
	$(SH) -n bin/vcr
	$(INSTALL) bin/vcr $(DESTDIR)/bin/vcr
	$(MKDIR) -p $(DESTDIR)/libexec/vcr
	$(SH) -n libexec/*
	$(INSTALL) -v libexec/* $(DESTDIR)/libexec/vcr
	@eval2(){ echo "$$@"; eval "$$@"; }; for x in $(LINKS); do \
	 	eval2 $(LN) -sf "$${x##*==}" "$${x%==*}"; \
	 done

uninstall:
	$(RM) -f $(DESTDIR)/bin/vcr
	@eval2(){ echo "$$@"; eval "$$@"; }; for x in $(LINKS); do \
	 	eval2 $(RM) -f "$${x##*==}" "$${x%==*}"; \
	 done
	$(RM) -f $(DESTDIR)/libexec/vcr/add
	$(RM) -f $(DESTDIR)/libexec/vcr/cmp
	$(RM) -f $(DESTDIR)/libexec/vcr/ls
	$(RM) -f $(DESTDIR)/libexec/vcr/play
	$(RM) -f $(DESTDIR)/libexec/vcr/rm
	$(RMDIR) $(DESTDIR)/libexec/vcr || : errors ignored
