#!/bin/sh
############################################################ IDENT(1)
#
# $Title: Jenkins build script $
# $Copyright: 2019 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/jenkins/download.sh 2019-07-12 16:36:35 -0700 freebsdfrau $
#
############################################################ INCLUDES

. ./build.conf || exit 1

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
PULL=1		# -n

############################################################ FUNCTIONS

if [ -t 1 ]; then # stdout is a tty
step(){ printf "\e[32;1m==>\e[39m %s\e[m\n" "$*"; }
eval2(){ printf "\e[2m%s\e[m\n" "$*"; eval "$@"; }
else
step(){ printf "==> %s\n" "$*"; }
eval2(){ printf "%s\n" "$*"; eval "$@"; }
fi

usage()
{
	local optfmt="\t%-5s %s\n"
	exec >&2
	printf "Usage: %s [-hn]\n" "$pgm"
	printf "Options:\n"
	printf "$optfmt" "-h" "Print this usage statement and exit."
	printf "$optfmt" "-n" "Do not pull sweng repo updates."
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

############################################################ MAIN

set -e # errexit

#
# Process command-line options
#
while getopts hn flag; do
	case "$flag" in
	n) PULL= ;;
	*) usage # NOTREACHED
	esac
done
shift $(( $OPTIND - 1 ))

#
# Determine if a pull is required
#
n=1
all_exist=1
while : fund build lock files; do
	# Lock file
	getvar BUILD${n}_NAME name || break

	if [ ! -e "$name" ]; then
		all_exist=
		break
	fi

	n=$(( $n + 1 ))
done
if [ "$all_exist" ]; then
	PULL=
fi

#
# Update repos
#
if [ "$PULL" -a "$SWENG" ]; then
	if [ "$SWENG_REMOTE" -a ! -e "$SWENG" ]; then
		step "Cloning $SWENG repository"
		case "$SWENG" in
		*/) SWENG="${SWENG%/}" ;;
		esac
		mkdir -p "${SWENG%/*}"
		( cd "${SWENG%/*}" &&
			git clone "$SWENG_REMOTE" "${SWENG##*/}" )
	elif [ ! -e "$SWENG" ]; then
		echo "$SWENG: No such file or directory" >&2
		exit $FAILURE
	elif [ ! -d "$SWENG" ]; then
		echo "$SWENG: Not a directory" >&2
		exit $FAILURE
	fi

	step "Updating $SWENG repository"
	( cd $SWENG && git pull )
fi

#
# Download lock files
#
n=1
while : fund build lock files ; do
	# Lock file
	getvar BUILD${n}_NAME name || break
	[ "$name" ] || break

	# Download
	if [ -e "$name" ]; then
		ls -l "$name"
	else
		step "Download $name"
		getvar BUILD${n}_PATH path
		cp -fv "$path" "$name"
	fi

	n=$(( $n + 1 ))
done

exit $SUCCESS

################################################################################
# END
################################################################################
