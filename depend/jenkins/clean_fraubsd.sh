#!/bin/sh
############################################################ IDENT(1)
#
# $Title: Script to clean jenkins files $
# $Copyright: 2019-2020 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/jenkins/clean_fraubsd.sh 2020-07-16 20:52:14 -0700 freebsdfrau $
#
############################################################ INCLUDES

. ./build.conf || exit 1

############################################################ GLOBALS

#
# Global exit status
#
SUCCESS=0
FAILURE=1

pgm="${0##*/}" # Program basename

#
# ANSI
#
if [ -t 1 ]; then # stdout is a tty
	ESC=$( :| awk 'BEGIN { printf "%c", 27 }' )
	ANSI_BLD_ON="$ESC[1m"
	ANSI_BLD_OFF="$ESC[22m"
	ANSI_GRN_ON="$ESC[32m"
	ANSI_FGC_OFF="$ESC[39m"
else
	ESC=
	ANSI_BLD_ON=
	ANSI_BLD_OFF=
	ANSI_GRN_ON=
	ANSI_FGC_OFF=
fi

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
# Command-line options
#
ALL=		# -a

############################################################ FUNCTIONS

if [ -t 1 ]; then # stdout is a tty
eval2()
{
        echo "$ANSI_BLD_ON$ANSI_GRN_ON==>$ANSI_FGC_OFF $*$ANSI_BLD_OFF"
        eval "$@"
}
hdr1(){ printf "\e[31;1m>>>\e[39m %s\e[m\n" "$*"; }
else
eval2()
{
	printf "%s\n" "$*"
	eval "$@"
}
hdr1(){ printf ">>> %s\n" "$*"; }
fi

usage()
{
	local optfmt="\t%-5s %s\n"
	exec >&2
	printf "Usage: %s [-ha]\n" "$pgm"
	printf "Options:\n"
	printf "$optfmt" "-a" "Clean all unknown files."
	printf "$optfmt" "-h" "Print this help text and exit."
	exit $FAILURE
}

getvar()
{
        local __var_to_get="$1" __var_to_set="$2"
        [ "$__var_to_set" ] || local value
        eval [ \"\${$__var_to_get+set}\" ]
        local __retval=$?
        eval ${__var_to_set:-value}=\"\${$__var_to_get}\"
        [ "$__var_to_set" ] || { [ "$value" ] && echo "$value"; }
        return $__retval
}

untracked()
{
	local dir="$1"
	case "$dir" in
	*/) : good ;;
	*) dir="$dir/"
	esac
	git status "$dir" | awk -v dir="$dir" '
		BEGIN { xdir = dir; gsub(/\./, "\\.", xdir) }
		/^#?[[:space:]]*Untracked files:/ { p = 1; next }
		!p { next } !/^#?([[:space:]]+|$)/ { p = 0; next }
		sub("^#?[[:space:]]*" xdir, dir)
	' # END-QUOTE
}

############################################################ MAIN

#
# Command-line options
#
while getopts ah flag; do
	case "$flag" in
	a) ALL=1 ;;
	*) usage # NOTREACHED
	esac
done
shift $(( $OPTIND - 1 ))

#
# Default build prefix is the repo name minus `pkgcenter-' prefix
#
if [ ! "$RPMPREFIX" ]; then
	ORIGIN=$( git config remote.origin.url )
	PROJECT="${ORIGIN##*:}"
	REPO="${PROJECT%.[Gg][Ii][Tt]}"
	RPMPREFIX="${REPO##*/}"
	RPMPREFIX="${RPMPREFIX#pkgcenter-}"
	: ${RPMPREFIX:=R}
fi
RPMBASE="../../redhat/$LINUX/$RPMGROUP"

#
# Clean vcran
#
lib=vcran
hdr1 "Cleaning in ../$lib"
( cd "../$lib" && ./clean_fraubsd.sh )

#
# Gather list of lock file names and optionally clean their targets
#
n=1
names=
while : fund build lock files ; do
	# Lock file
	getvar BUILD${n}_NAME name || break
	[ "$name" ] || break
	if [ ! -e "$name" ]; then
		n=$(( $n + 1 ))
		continue
	fi

	names="$names $name"

	# R version
	r_vers="${name##*_}"
	r_vers="${r_vers%.lock}"
	r_vers_short=$( echo "$r_vers" | sed -e 's/[^0-9]//g' )

	rpm="$RPMBASE/$RPMPREFIX$r_vers_short-$lib"
	if [ -d "$rpm" ]; then
		hdr1 "Cleaning in $rpm"
		( cd "$rpm" && make distclean )
	fi

	for lib in $( ./lock2conf.sh -l "$name" ); do
		lib="${lib%%_*}"
		if [ -d "../$lib" ]; then
			hdr1 "Cleaning in ../$lib"
			( cd "../$lib" && ./clean_fraubsd.sh )
		fi

		[ ! "$ALL" ] || names="$names $( untracked "../$lib" )"

		rpm="$RPMBASE/$RPMPREFIX$r_vers_short-$lib"
		if [ -d "$rpm" ]; then
			hdr1 "Cleaning in $rpm"
			( cd "$rpm" && make distclean )
		fi

		[ ! "$ALL" ] || names="$names $( untracked "$rpm" )"
	done

	n=$(( $n + 1 ))
done

[ ! "$ALL" ] || names="$names $(
	untracked ../vcran
	untracked "$RPMBASE"
)"

set -e
for item in \
	$names \
;do
        eval2 rm -Rf "$item"
done

exit $SUCCESS

################################################################################
# END
################################################################################
