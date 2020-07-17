#!/bin/sh
############################################################ IDENT(1)
#
# $Title: Script to clean R $
# $Copyright: 2019-2020 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/R-3.3.1/clean_fraubsd.sh 2020-07-16 17:04:50 -0700 freebsdfrau $
#
############################################################ GLOBALS

#
# ANSI
#
if [ -t 1 ]; then # stdout is a tty
	ESC=$( :| awk 'BEGIN { printf "%c", 27 }' )
	ANSI_BLD_ON="$ESC[1m"
	ANSI_BLD_OFF="$ESC[22m"
	ANSI_GRN_ON="$ESC[32m"
	ANSI_FGC_OFF="$ESC[39m"
else
	ESC=
	ANSI_BLD_ON=
	ANSI_BLD_OFF=
	ANSI_GRN_ON=
	ANSI_FGC_OFF=
fi

############################################################ FUNCTIONS

eval2()
{
        echo "$ANSI_BLD_ON$ANSI_GRN_ON==>$ANSI_FGC_OFF $*$ANSI_BLD_OFF"
        eval "$@"
}

############################################################ MAIN

set -e
for item in \
	*/*/*/*/*/Makefile \
	*/*/*/*/Makefile \
	*/*/*/Makefile \
	*/*/Makefile \
	*/Makefile \
	Makeconf \
	Makefile \
	Makefrag.* \
	bin/ \
	config.log \
	config.status \
	doc/NEWS.rds \
	doc/R.1 \
	doc/html/index.html \
	doc/html/packages.html \
	doc/manual/*-html \
	doc/manual/*.html \
	doc/manual/version.texi \
	etc/Makeconf \
	etc/Renviron \
	etc/javaconf \
	etc/ldpaths \
	include/ \
	install/ \
	lib/ \
	library/ \
	libtool \
	modules/ \
	src/*/*.a \
	src/*/*.d \
	src/*/*.o \
	src/*/*.so \
	src/*/*.ts \
	src/*/*/*.a \
	src/*/*/*.d \
	src/*/*/*.o \
	src/*/*/*.so \
	src/*/*/*.ts \
	src/*/*/*/*.d \
	src/*/*/*/*.o \
	src/*/*/*/*.so \
	src/*/*/*/*/*.d \
	src/*/*/*/*/*.o \
	src/*/*/*/*/*.so \
	src/*/*/*/*/Makedeps \
	src/*/*/*/Makedeps \
	src/*/*/Makedeps \
	src/*/Makedeps \
	src/include/*.tsa \
	src/include/R_ext/stamp-R \
	src/include/Rconfig.h \
	src/include/Rmath.h \
	src/include/Rmath.h0 \
	src/include/Rversion.h \
	src/include/config.h \
	src/include/stamp-R \
	src/include/stamp-h \
	src/library/*.inn \
	src/library/*/DESCRIPTION \
	src/library/*/all.R \
	src/library/Recommended/stamp-recommended \
	src/library/stamp-docs \
	src/main/R.bin \
	src/scripts/R.fe \
	src/scripts/R.sh \
	src/scripts/Rcmd \
	src/scripts/f77_f2c \
	src/scripts/javareconf \
	src/scripts/mkinstalldirs \
	src/scripts/pager \
	src/scripts/rtags \
	src/unix/Rscript \
	stamp-java \
;do
	case "$item" in
	src/gnuwin32/Makefile|src/gnuwin32/*/Makefile) continue ;;
	src/library/stats/SOURCES.ts) continue ;;
	esac
        eval2 rm -Rf "$item"
done
git checkout doc/NEWS 2> /dev/null || : errors ignored
git checkout doc/NEWS.pdf 2> /dev/null || : errors ignored

[ ! -e .keep_stage ] || exit 0
for item in \
	COPYING \
	ChangeLog \
	INSTALL \
	Makeconf.in \
	Makefile.fw \
	Makefile.in \
	README \
	SVN-REVISION \
	VERSION \
	VERSION-NICK \
	config.site \
	configure \
	configure.ac \
	doc/ \
	etc/ \
	m4/ \
	po/ \
	share/ \
	src/ \
	tests/ \
	tools/ \
;do
	eval2 rm -Rf "$item"
done

################################################################################
# END
################################################################################
