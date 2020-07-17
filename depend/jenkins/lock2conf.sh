#!/bin/sh
############################################################ IDENT(1)
#
# $Title: Script to convert .lock file into library .conf file $
# $Copyright: 2019-2020 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/jenkins/lock2conf.sh 2020-07-16 20:52:14 -0700 freebsdfrau $
#
############################################################ INCLUDES

. ./build.conf || exit 1

############################################################ CONFIGURATION

TEMPLATE=lib_build_conf.tmpl

############################################################ GLOBALS

pgm="${0##*/}" # Program basename

#
# Global exit status
#
SUCCESS=0
FAILURE=1

#
# Command-line options
#
LIST=		# -l

#
# Command-line arguments
#
FILE=

#
# OS Glue
#
case "$( cat /etc/redhat-release )" in
*" 6."*) LINUX="rhel6" ;;
*" 7."*) LINUX="rhel7" ;;
*)
	echo "Unknown RedHat/CentOS Linux release" >&2
	exit $FAILURE
esac
case "$( uname -m )" in
x86_64) LINUX="$LINUX-x86_64" ;;
*)
	echo "Unknown machine architecture" >&2
	exit $FAILURE
esac

#
# Literals
#
NL="
" # END-QUOTE

############################################################ FUNCTIONS

if [ -t 1 ]; then # stdout is a tty
note(){ printf "\e[31m>\e[m %s\n" "$*"; }
else
note(){ printf "> %s\n" "$*"; }
fi

usage()
{
	local optfmt="\t%-5s %s\n"
	exec >&2
	printf "Usage: %s [-hl] blah.lock\n" "$pgm"
	printf "Options:\n"
	printf "$optfmt" "-h" \
		"Print this usage statement to stderr and exit."
	printf "$optfmt" "-l" \
		"List the names of libraries contained in lock file."
	exit $FAILURE
}

getlockopts()
{
	local OPTIND=1 OPTARG flag

	unset lockoptu
	while getopts u: flag; do
		case "$flag" in
		u) lockoptu="$OPTARG" ;;
		esac
	done

	return $SUCCESS
}

template()
{
	local tmpl=
	local tmpl_vars=
	local awk_script
	local OPTIND=1 OPTARG flag

	while getopts t: flag; do
		case "$flag" in
		t) tmpl="$OPTARG" ;;
		esac
	done
	shift $(( $OPTIND - 1 ))

	while [ $# -gt 0 ]; do
		case "$1" in
		*=*)
			local "$1"
			export "${1%%=*}"
			tmpl_vars="$tmpl_vars ${1%%=*}"
			;;
		*)
			local "$1=1"
			export "$1"
			tmpl_vars="$tmpl_vars $1"
			;;
		esac
		shift 1
	done
	tmpl_vars="${tmpl_vars# }"

	[ "$tmpl" = "-" ] && tmpl=
	awk -v vars="$tmpl_vars" '
		BEGIN {
			nvars = split(vars, var_list)
		}
		{
			for (n = 1; n <= nvars; n++) {
				var = var_list[n]
				gsub("@" var "@", ENVIRON[var])
			}
			print
		}
	' ${tmpl:+"$tmpl"}
}

transform()
{
	local file="$1" update
	update=$( awk -v file="$file" '
		!/^[[:space:]]*(#|$)/ {
			nx++
			from[nx] = $1
			getline
			chto[nx] = $1
		}
		END {
			while (getline < file) {
				for (n = 1; n <= nx; n++)
					gsub(from[n], chto[n])
				print
			}
		}
	' )
	echo "$update" > "$file"
}

############################################################ MAIN

#
# Parse command-line options
#
while getopts hl flag; do
	case "$flag" in
	f) FORCE=1 ;;
	l) LIST=1 ;;
	*) usage # NOTREACHED
	esac
done

#
# Check command-line argument
#
shift $(( $OPTIND - 1 ))
[ $# -gt 0 ] || usage # NOTREACHED
FILE="$1"
if [ ! -e "$FILE" ]; then
	echo "$FILE: No such file or directory" >&2
	exit $FAILURE
fi
if [ -d "$FILE" ]; then
	echo "$FILE: Is a directory" >&2
	exit $FAILURE
fi

#
# Form the path to the config file based on the name of the lock file
#
R_VERS="${FILE%.lock}"
R_VERS="${R_VERS##*_}"
if [ ! "$R_VERS" ]; then
	echo "$pgm: Cannot determine R version from lock file name" >&2
	exit $FAILURE
fi

#
# Produce configs for each of the external libs in the lock file
#
oldIFS="$IFS"
IFS="$NL"
set -- $( awk '!/^[[:space:]]*(#|$)/&&$1~/^-/' "$FILE" )
IFS="$oldIFS"
for line in "$@"; do
	getlockopts $line
	url="$lockoptu"
	[ "$url" ] || continue

	# build dir
	tarball="${url##*/}"
	name="${tarball%%_*}"
	[ -e "../$name" ] || mkdir "../$name"
	[ -e "../$name/etc" ] || mkdir "../$name/etc"

	# build version
	vers="${tarball#"$name"}"
	vers="${vers%.tar.*}" # .tar.gz .tar.bz2 .tar.xz .tar.lzma
	vers="${vers%.t*}" # .tgz .tbz .txz

	# Process `-l' command-line option
	if [ "$LIST" ]; then
		echo "$name$vers"
		continue
	fi

	# R config
	r_conf="../$name/etc/R-$R_VERS-$LINUX.conf"
	note "Generating $r_conf"
	ORIGIN=$( git config remote.origin.url )
	PROJECT="${ORIGIN##*:}"
	REPO="${PROJECT%.[Gg][Ii][Tt]}"
	REPONAME="${REPO##*/}"
	REPONAME="${REPONAME#pkgcenter-}"
	template -t lib.tmpl/etc/R.tmpl \
		ARCHIVE="${url%/contrib/*}/contrib/" \
		PKGNAME="$name" \
		PKGSUFF="${tarball#"$name$vers"}" \
		R_VERS="$R_VERS" \
		REPONAME="$REPONAME" \
		PKGVERS="$vers" \
		> "$r_conf"
	../../.git-filters/keywords -d "$r_conf"

	# Optionally transform
	if [ "$URL_XFORM" ]; then
		note "Transforming URLs in $r_conf"
		echo "$URL_XFORM"
		echo "$URL_XFORM" | transform "$r_conf"
	fi

	# fakeroot R config
	fakeroot_conf="../$name/etc/fakeroot-R-$R_VERS-$LINUX.conf"
	note "Generating $fakeroot_conf"
	template -t lib.tmpl/etc/fakeroot-R.tmpl \
		R_VERS="$R_VERS" \
		LINUX="$LINUX" \
		> "$fakeroot_conf"
	../../.git-filters/keywords -d "$fakeroot_conf"

	# Required files
	note "Copying required files for $name"
	for file in \
		build_fraubsd.sh \
		checkdeps.sh \
		clean_fraubsd.sh \
		download.sh \
		etc/cran.subr \
	; do
		[ -e "../$name/$file" ] && continue
		cp -v "lib.tmpl/$file" "../$name/$file"
	done
done

exit $SUCCESS

################################################################################
# END
################################################################################
