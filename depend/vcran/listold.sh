#!/bin/sh
#-
############################################################ IDENT(1)
#
# $Title: Script to check CRAN package source versions $
# $Copyright: 2019 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/vcran/listold.sh 2019-07-12 16:22:23 -0700 freebsdfrau $
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
conf_read "$1" # sets $[N]PACKAGES globals
set -e # errexit

#
# Check requested package source tarball versions
#
step "Checking package versions" >&2
old=0
n=0
serialize_packages # sets ${name,vers}[$n] globals
while [ $n -lt $NPACKAGES ]; do
	n=$(( $n + 1 ))
	eval name=\"\$name$n\"
	eval wanted_vers=\"\$vers$n\"
	latest_file="$CRAN_ARCHIVE/$name-latest.txt"
	[ -e "$latest_file" ] || continue
	case "$wanted_vers" in
	[Ll][Aa][Tt][Ee][Ss][Tt]) # latest
		wanted_vers=$( cat "$latest_file" )
		wanted_vers="${wanted_vers#"${name}_"}"
		wanted_vers="${wanted_vers%.tar.gz}"
		;;
	esac
	for file in $CRAN_ARCHIVE/${name}_*.tar.gz; do
		case "$file" in
		"$CRAN_ARCHIVE/${name}_$wanted_vers.tar.gz") continue ;;
		*) echo "$file"
		esac
		old=$(( $old + 1 ))
	done
	for file in $CRAN_ARCHIVE/${name}_*-deps.txt; do
		case "$file" in
		"$CRAN_ARCHIVE/${name}_$wanted_vers-deps.txt") continue ;;
		*) echo "$file"
		esac
		old=$(( $old + 1 ))
	done
done

[ $old -eq 0 ] || die "$old old packages"

step SUCCESS >&2
exit $SUCCESS

################################################################################
# END
################################################################################
