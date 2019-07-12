#!/bin/sh
#-
############################################################ IDENT(1)
#
# $Title: Script to check CRAN package source versions $
# $Copyright: 2019 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/vcran/checklatest.sh 2019-07-12 16:22:23 -0700 freebsdfrau $
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
step "Checking latest package versions"
bad=0
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
		index_url=$( printf "$CRAN_PROJECT_INDEX" "$name" )
		src_uri=$( eval2 curl -sLo- "$index_url" |
			grep -o 'href="../../../src/contrib/[^"]*' ) ||
			die "%s: No such CRAN package" "$name"
		latest_vers="${src_uri##*/}"
		;;
	*)
		[ -e "$CRAN_ARCHIVE/${name}_$wanted_vers.tar.gz" ] ||
			warn "missing ${name}_$wanted_vers"
		latest_vers=$( cat "$latest_file" )
		latest_vers="${wanted_vers#"${name}_"}"
		latest_vers="${wanted_vers%.tar.gz}"
	esac
	latest_vers="${latest_vers#"${name}_"}"
	latest_vers="${latest_vers%.tar.gz}"
	[ "$wanted_vers" = "$latest_vers" ] && continue
	warn "$name $wanted_vers -> $latest_vers"
	bad=$(( $bad + 1 ))
done

[ $bad -eq 0 ] || die "$bad packages need updating"

step SUCCESS
exit $SUCCESS

################################################################################
# END
################################################################################
