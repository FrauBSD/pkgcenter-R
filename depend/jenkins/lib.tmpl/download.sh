#!/bin/sh
#-
############################################################ IDENT(1)
#
# $Title: Script to download CRAN package sources $
# $Copyright: 2019 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/jenkins/lib.tmpl/download.sh 2019-07-12 16:36:35 -0700 freebsdfrau $
#
############################################################ INCLUDES

. ./etc/cran.subr || exit 1

############################################################ FUNCTIONS

usage()
{
	local optfmt="\t%-5s %s\n"
	exec >&2
	echo "Usage: $pgm [-h] config-file"
	echo "Options:"
	printf "$optfmt" "-h" "Print usage statement to stderr and exit."
	die
}

download()
{
	trap 'rm -f "$PACKAGEFILE"' SIGINT EXIT
	eval2 curl -Lo "$PACKAGEFILE" "$PACKAGE" ||
		die "%s: Unable to download %s" "$PKGNAME" "$PACKAGEFILENAME"
	trap - SIGINT EXIT
}

############################################################ MAIN

#
# Process command-line options
#
while getopts h flag; do
	case "$flag" in
	*) usage # NOTREACHED
	esac
done
shift $(( $OPTIND - 1 ))
[ $# -gt 0 ] || usage # NOTREACHED

#
# Read configuration file
#
conf_read "$1" # sets $PACKAGE and $PKG*
set -e # errexit

#
# Download package source tarball
#
step "$PKGNAME"
case "$PACKAGE" in
???://*|????://*|?????://*)
	eval2 mkdir -p "$CRAN_TMPDIR"
	if [ ! -e "$PACKAGEFILE" ]; then
		download
		case "$( file -b "$PACKAGEFILE" )" in
		"ASCII text")
			rm -f "$PACKAGEFILE"
			PACKAGE="${ARCHIVE%/}/Archive/$PKGNAME/${PKGVERS#_}"
			PACKAGE="$PACKAGE/$PKGNAME$PKGVERS$PKGSUFF"
			download
			;;
		esac
	fi
	;;
*)
	eval2 [ -e "$PACKAGEFILE" ] ||
		die "$PACKAGEFILE: No such file or directory"
esac

step SUCCESS
exit $SUCCESS

################################################################################
# END
################################################################################
