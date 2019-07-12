#!/bin/sh
#-
############################################################ IDENT(1)
#
# $Title: Script to build apache-mxnet and install it to package sandbox $
# $Copyright: 2019 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/apache-mxnet-legacy/build_fraubsd.sh 2019-07-12 16:08:35 -0700 freebsdfrau $
#
############################################################ INCLUDES

case "$( cat /etc/redhat-release )" in
*" 6."*) . /opt/rh/devtoolset-2/enable || exit 1 ;;
esac

############################################################ CONFIGURATION

R_HOME_DIR=/opt/R/3.3.1/lib64/R
DESTDIR=install/$R_HOME_DIR/library

############################################################ GLOBALS

cwd=$( pwd ) # Current working directory

#
# ANSI
#
ESC=$( :| awk 'BEGIN { printf "%c", 27 }' )
ANSI_BLD_ON="$ESC[1m"
ANSI_BLD_OFF="$ESC[22m"
ANSI_GRN_ON="$ESC[32m"
ANSI_FGC_OFF="$ESC[39m"

############################################################ FUNCTIONS

die()
{
	local fmt="$1"
	if [ "$fmt" ]; then
		shift 1 # fmt
		printf "\e[1;31mFATAL!\e[m $fmt\n" "$@" >&2
	fi
	exit $FAILURE
}

have(){ type "$@" > /dev/null 2>&1; }

if have readlink; then
realpath(){ readlink -f "$@"; }
elif have realpath; then
realpath(){ command realpath "$@"; }
elif have perl; then
realpath(){ perl -le 'use Cwd; print Cwd::abs_path(@ARGV);' -- "$@"; }
fi

renv_create()
{
	[ "$R_HOME_DIR" ] || die "R_HOME_DIR is NULL or unset"
	[ -e "$R_HOME_DIR" ] || die "$R_HOME_DIR: No such file or directory"
	[ -d "$R_HOME_DIR/" ] || die "$R_HOME_DIR: Not a directory"

	mkdir -p "$cwd/renv/bin" || die
	touch "$cwd/renv/bin/R" || die

	local path
	for path in "$( realpath "$R_HOME_DIR" )"/*; do
		case "$path" in
		*/bin) continue ;;
		esac
		ln -nsf "$path" "$cwd/renv/"
	done
	for path in "$( realpath "$R_HOME_DIR/bin" )"/*; do
		case "$path" in
		*/R) continue ;;
		esac
		ln -nsf "$path" "$cwd/renv/bin/"
	done

	sed -e "
		s:^\\(R_HOME_DIR=\\).*:\\1\"$cwd/renv\":
		s:^\\(R_SHARE_DIR=\\).*:\\1\"\$R_HOME/share\":
		s:^\\(R_INCLUDE_DIR=\\).*:\\1\"\$R_HOME/include\":
		s:^\\(R_DOC_DIR=\\).*:\\1\"\$R_HOME/doc\":
	" "$R_HOME_DIR/bin/R" > "$cwd/renv/bin/R" ||
		die "Unable to read bin/R in R_HOME_DIR"
	chmod +x "$cwd/renv/bin/R" ||
		die "Unable to make renv/bin/R executable"
}

renv_destroy()
{
	rm -f "$cwd/renv"
}

serialize_args()
{
	while [ $# -gt 0 ]; do
		printf "nextArg%s" "$1"
		shift 1
	done
}

R()
{
	[ -e "$cwd/renv/bin/R" ] || renv_create ||
		die "Unable to create virtual R environment (renv)"
	"$cwd/renv/bin/R" --slave --no-restore "$@"
}

eval2()
{
	echo "$ANSI_BLD_ON$ANSI_GRN_ON==>$ANSI_FGC_OFF $*$ANSI_BLD_OFF" >&3
	eval "$@"
}

############################################################ MAIN

exec 3<&1
set -e

#
# Install dependencies
#
items_needed=
#	bin=someprog:pkg=somepkg \
#	file=/path/to/some_file:pkg=somepkg \
#	lib=somelib.so:pkg=somepkg \
for entry in \
	bin=cmake3:pkg=cmake3 \
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
[ -e Makefile ] || ./update_fraubsd.sh

#
# Build software
#
[ -e /usr/bin/cmake ] || eval2 sudo ln -sf cmake3 /usr/bin/cmake
[ -e lib/libmxnet.so ] ||
	eval2 make USE_OPENCV=0 USE_MKLDNN=1 USE_BLAS=mkl lib/libmxnet.so

#
# Prepare R-package for installation
#
[ -e R-package/inst/libs ] || eval2 mkdir -p R-package/inst/libs
[ -e R-package/src/image_recordio.h -a \
     R-package/src/image_recordio.h -nt src/io/image_recordio.h ] ||
	eval2 cp src/io/image_recordio.h R-package/src
[ -e R-package/inst/libs/libmxnet.so -a \
     R-package/inst/libs/libmxnet.so -nt lib/libmxnet.so ] ||
	eval2 cp -rf lib/libmxnet.so R-package/inst/libs
[ -e R-package/inst/include ] || eval2 mkdir -p R-package/inst/include
eval2 cp -rf include/* R-package/inst/include
eval2 cp -rf dmlc-core/include/* R-package/inst/include
eval2 cp -rf ps-lite/include/* R-package/inst/include

#
# Install software to package sandbox
#
[ -e install ] || eval2 mkdir -p install
pkgname="$cwd"
pkgname="${pkgname%/}"
pkgname="${pkgname##*/}"
[ -e "$DESTDIR" ] || eval2 mkdir -p "$DESTDIR"
echo 'tools:::.install_packages()' | eval2 R --args $(
	serialize_args --no-test-load -l "$DESTDIR" R-package
) || die "%s: Unable to install R-package" "$pkgname"
eval2 : SUCCESS

################################################################################
# END
################################################################################
