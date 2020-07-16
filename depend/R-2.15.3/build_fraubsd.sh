#!/bin/sh
#-
############################################################ IDENT(1)
#
# $Title: Script to build R and install it to package sandbox $
# $Copyright: 2019-2020 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/R-2.15.3/build_fraubsd.sh 2020-07-16 16:44:53 -0700 freebsdfrau $
#
############################################################ TOOLCHAIN

case "$( cat /etc/redhat-release )" in
*" 6."*)
	RHEL6=1
	. /opt/rh/devtoolset-2/enable || exit ;;
esac

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
# Patch software
#
if [ ! -e .patch_done ]; then
	for file in patch/*.patch; do
		[ -e "$file" ] || continue
		eval2 patch -b -p0 -N \< $file
	done
	eval2 touch .patch_done
fi

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
[ -e install ] || eval2 mkdir -p install
eval2 make DESTDIR=$PWD/install install
eval2 : SUCCESS

################################################################################
# END
################################################################################
