#!/bin/sh
#-
############################################################ IDENT(1)
#
# $Title: Script to install CRAN package sources $
# $Copyright: 2019 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/jenkins/lib.tmpl/build_fraubsd.sh 2019-07-12 16:36:35 -0700 freebsdfrau $
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
conf_read "$1" # sets $PACKAGE* globals
set -e # errexit

#
# Download package sources
#
step "Download $PKGNAME"
( set +e; ./download.sh "$@"; echo "EXIT:$?" ) | awk '
	/curl/ && !/==>/
	sub(/^EXIT:/, "") { status = $0 }
	END { exit status }
' # END-QUOTE

#
# Check package dependencies
#
step "Check dependencies"
( set +e; ./checkdeps.sh "$@"; echo "EXIT:$?" ) | awk '
	/tar/ && !/==>/
	sub(/^EXIT:/, "") { status = $0 }
	END { exit status }
' # END-QUOTE

#
# Create target directory
#
cran_destdir="$CRAN_INSTALLDIR/${DESTDIR#/}"
mkdir -p "$cran_destdir"

#
# Install package source tarball
#
step "$PACKAGEFILENAME"
[ -e "$PACKAGEFILE" ] || die "$PACKAGEFILE: No such file or directory"
echo 'tools:::.install_packages()' | eval2 R --args $( serialize_args \
	--no-test-load -l "$cran_destdir" "$PACKAGEFILE"
) || die "%s: Unable to install %s" "$PKGNAME" "$PACKAGEFILENAME"

step SUCCESS
exit $SUCCESS

################################################################################
# END
################################################################################
