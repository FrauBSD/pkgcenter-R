#!/bin/sh
#-
############################################################ IDENT(1)
#
# $Title: Script to download CRAN package sources $
# $Copyright: 2019 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/vcran/download.sh 2019-07-12 16:22:23 -0700 freebsdfrau $
#
############################################################ INCLUDES

. ./etc/cran.subr || exit 1

############################################################ GLOBALS

#
# Command-line options
#
UPDATE=		# -u

############################################################ FUNCTIONS

usage()
{
	local optfmt="\t%-5s %s\n"
	exec >&2
	echo "Usage: $pgm [-hu] config-file"
	echo "Options:"
	printf "$optfmt" "-h" "Print usage statement to stderr and exit."
	printf "$optfmt" "-u" "Update latest versions."
	die
}

############################################################ MAIN

#
# Process command-line options
#
while getopts hu flag; do
	case "$flag" in
	u) UPDATE=1 ;;
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
# Download requested package source tarballs
#
n=0
serialize_packages # sets ${name,vers}[$n] globals
while [ $n -lt $NPACKAGES ]; do
	n=$(( $n + 1 ))
	eval name=\"\$name$n\"
	step "$name [$n/$NPACKAGES]"
	eval vers=\"\$vers$n\"
	index_url=$( printf "$CRAN_PROJECT_INDEX" "$name" )
	case "$vers" in
	[Ll][Aa][Tt][Ee][Ss][Tt]) # latest
		latest_file="$CRAN_ARCHIVE/$name-latest.txt"
		if [ "$UPDATE" -o ! -e "$latest_file" ]; then
			src_uri=$( eval2 curl -sLo- "$index_url" |
				grep -o 'href="../../../src/contrib/[^"]*' ) ||
				die "%s: No such CRAN package" "$name"
			src_uri="${src_uri#href=\"}"
			src_name="${src_uri##*/}"
			echo "$src_name" > "$latest_file"
		else
			src_name=$( cat "$latest_file" )
			src_uri="../../../src/contrib/$src_name"
		fi
		;;
	*)
		src_name="${name}_$vers.tar.gz"
		src_uri="../../../src/contrib/$src_name"
	esac
	src_url="${index_url%/*}/$src_uri"
	src_file="$CRAN_ARCHIVE/$src_name"
	[ -e "$src_file" ] && continue
	trap 'rm -f "$src_file"' SIGINT EXIT
	eval2 curl -Lo "$src_file" "$src_url" ||
		die "%s: Unable to download %s" "$name" "$src_name"
	trap - SIGINT EXIT
	case "$( file "$src_file" )" in
	*HTML*) # Check the Archive
		src_uri="${src_uri%/*}/Archive/$name/$src_name"
		src_url="${index_url%/*}/$src_uri"
		eval2 curl -Lo "$src_file" "$src_url" ||
			die "%s: Unable to download %s" "$name" "$src_name"
		;;
	esac
done

step SUCCESS
exit $SUCCESS

################################################################################
# END
################################################################################
