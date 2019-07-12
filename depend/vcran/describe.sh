#!/bin/sh
#-
############################################################ IDENT(1)
#
# $Title: Script to describe CRAN package sources $
# $Copyright: 2019 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/vcran/describe.sh 2019-07-12 16:22:23 -0700 freebsdfrau $
#
############################################################ INCLUDES

. ./etc/cran.subr || exit 1

############################################################ GLOBALS

#
# Command-line options
#
PIPETO=cat	# -s

############################################################ FUNCTIONS

usage()
{
	local optfmt="\t%-5s %s\n"
	exec >&2
	echo "Usage: $pgm [-hs] config-file"
	echo "Options:"
	printf "$optfmt" "-h" "Print usage statement to stderr and exit."
	printf "$optfmt" "-s" "Sort output using sort(1)."
	die
}

############################################################ MAIN

#
# Process command-line options
#
while getopts hs flag; do
	case "$flag" in
	s) PIPETO=sort ;;
	*) usage # NOTREACHED
	esac
done
shift $(( $OPTIND - 1 ))
[ $# -gt 0 ] || usage # NOTREACHED

#
# Read configuration file
#
conf_read "$1" # sets $[N]PACKAGES globals
set -e # errexit

#
# Describe requested package source tarballs
#
echo "# $NPACKAGES pacakges"
n=0
serialize_packages # sets ${name,vers}[$n] globals
while [ $n -lt $NPACKAGES ]; do
	n=$(( $n + 1 ))
	eval name=\"\$name$n\"
	eval vers=\"\$vers$n\"
	case "$vers" in
	[Ll][Aa][Tt][Ee][Ss][Tt]) # latest
		latest_file="$CRAN_ARCHIVE/$name-latest.txt"
		src_name=$( cat "$latest_file" )
		;;
	*)
		src_name="${name}_$vers.tar.gz"
	esac
	echo "${src_name%.t*}"
done | $PIPETO | awk '{ printf "%4u %s\n", NR, $0 }'

exit $SUCCESS

################################################################################
# END
################################################################################
