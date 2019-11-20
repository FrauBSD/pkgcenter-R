#!/bin/sh
#-
############################################################ IDENT(1)
#
# $Title: Script to build R and install it to package sandbox $
# $Copyright: 2019 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/R-2.15.3/build_fraubsd.sh 2019-11-19 23:13:01 -0800 freebsdfrau $
#
############################################################ GLOBALS

#
# ANSI
#
ESC=$( :| awk 'BEGIN { printf "%c", 27 }' )
ANSI_BLD_ON="$ESC[1m"
ANSI_BLD_OFF="$ESC[22m"
ANSI_GRN_ON="$ESC[32m"
ANSI_FGC_OFF="$ESC[39m"

############################################################ FUNCTIONS

eval2()
{
	echo "$ANSI_BLD_ON$ANSI_GRN_ON==>$ANSI_FGC_OFF $*$ANSI_BLD_OFF"
	eval "$@"
}

############################################################ MAIN

set -e

#
# Install dependencies
#
items_needed=
#	bin=someprog:pkg=somepkg \
#	file=/path/to/some_file:pkg=somepkg \
#	lib=somelib.so:pkg=somepkg \
for entry in \
	bin=make:pkg=make \
	file=/usr/include/zlib.h:pkg=zlib-devel \
; do
	check="${entry%%:*}"
	item="${check#*=}"
	case "$check" in
	 bin=*) type "$item" > /dev/null 2>&1 && continue ;;
	file=*) [ -e "$item" ] && continue ;;
	 lib=*) ldconfig -p | awk -v lib="$item" \
		'$1==lib{exit f++}END{exit !f}' && continue ;;
	     *) continue
	esac
	pkg="${entry#*:}"
	pkgname="${pkg#*=}"
	items_needed="$items_needed $pkgname"
done
[ "$items_needed" ] && eval2 sudo yum install $items_needed

#
# Obtain software
#
[ -e configure ] || ./update_fraubsd.sh

#
# Configure options
#
[ -e Makefile ] || eval2 ./configure \
	--prefix=/opt/R/$( cat VERSION ) \
	--enable-memory-profiling \
	--enable-R-shlib \
	--with-blas \
	--with-lapack

#
# Build software
#
eval2 make

#
# Install software to package sandbox
#
[ -e sandbox ] || eval2 mkdir -p sandbox
eval2 make DESTDIR=$PWD/sandbox install
eval2 : SUCCESS

################################################################################
# END
################################################################################
