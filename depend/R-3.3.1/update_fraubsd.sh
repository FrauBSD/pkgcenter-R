#!/bin/sh
############################################################ IDENT(1)
#
# $Title: Script to update R $
# $Copyright: 2019-2020 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/R-3.3.1/update_fraubsd.sh 2020-07-16 17:04:50 -0700 freebsdfrau $
#
############################################################ CONFIGURATION

REPO=https://cran.cnr.berkeley.edu/src/base/R-3/
RELEASE=3.3.1

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

have(){ type "$@" > /dev/null 2>&1; }

exec 3>&1
eval2()
{
	echo "$ANSI_BLD_ON$ANSI_GRN_ON==>$ANSI_FGC_OFF $*$ANSI_BLD_OFF" >&3
	eval "$@"
}

if have fetch; then
http_get(){ eval2 fetch -o- "$@"; }
elif have wget; then
http_get(){ eval2 wget -O- "$@"; }
else
http_get(){ eval2 curl -Lo- "$@"; }
fi

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
mkdir R-tmp.$$
download="R-$RELEASE-$$.tar.gz"
if [ -e "$download" ]; then
	echo "$download: File already exists" >&2
	exit 1
fi
http_get "${REPO%/}/R-$RELEASE.tar.gz" > "$download"
tar zxvf "$download" -C R-tmp.$$ > /dev/null
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
	--exclude=\"files/\*\"			\
	"R-tmp.$$/R-$RELEASE/" "$thisdir/"
eval2 rm -Rf R-tmp.$$ "$download"

################################################################################
# END
################################################################################
