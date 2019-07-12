#!/bin/sh
#-
############################################################ IDENT(1)
#
# $Title: Script to update apache-mxnet $
# $Copyright: 2019 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/apache-mxnet-legacy/update_fraubsd.sh 2019-07-12 16:08:35 -0700 freebsdfrau $
#
############################################################ CONFIGURATION

REPO=https://github.com/apache/incubator-mxnet.git
RELEASE=v0.7.0 # Use `master' for bleeding edge

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
	bin=git:pkg=git \
	bin=rsync:pkg=rsync \
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
# Update software
#
thisdir=$( pwd )
eval2 cd ..
eval2 git clone --depth=1 --branch=$RELEASE --recursive \"$REPO\" mxnet.$$
eval2 rsync -crlDvH --delete  \
	--exclude=\".git/\*\"			\
	--exclude=\".git\"			\
	--exclude=\".gitattributes\"		\
	--exclude=\".github/\*\"		\
	--exclude=\".gitignore\"		\
	--exclude=\".github\"			\
	--exclude=\".gitmodules\"		\
	--exclude=\"\*/.git/\*\"		\
	--exclude=\"\*/.git\"			\
	--exclude=\"\*/.gitattributes\"		\
	--exclude=\"\*/.github/\*\"		\
	--exclude=\"\*/.github\"		\
	--exclude=\"\*/.gitignore\"		\
	--exclude=\"\*/.gitmodules\"		\
	--exclude=\"\*fraubsd.sh\"		\
	mxnet.$$/ $thisdir/
eval2 rm -Rf mxnet.$$

################################################################################
# END
################################################################################
