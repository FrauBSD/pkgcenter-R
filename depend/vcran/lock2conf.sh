#!/bin/sh
############################################################ IDENT(1)
#
# $Title: Script to convert .lock file into vcran .conf file $
# $Copyright: 2019 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/vcran/lock2conf.sh 2019-07-12 16:22:23 -0700 freebsdfrau $
#
############################################################ CONFIGURATION

TEMPLATE=etc/vcran_conf.tmpl

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
FORCE=		# -f
CONFFILE=	# -o file

#
# Command-line arguments
#
FILE=

#
# Miscellaneous
#
CONFFILE_SET=

############################################################ FUNCTIONS

usage()
{
	local optfmt="\t%10s %s\n"
	exec >&2
	printf "Usage: %s [-fh] [-o file] blah.lock\n" "$pgm"
	printf "Options:\n"
	printf "$optfmt" "-f" \
		"Force. Overwrite output conf if it already exists."
	printf "$optfmt" "-h" \
		"Print this usage statement to stderr and exit."
	printf "$optfmt" "-o file" \
		"Save output to file instead of generated conf path."
	exit $FAILURE
}

############################################################ MAIN

#
# Parse command-line options
#
while getopts fho: flag; do
	case "$flag" in
	f) FORCE=1 ;;
	o) CONFFILE_SET=1 CONFFILE="$OPTARG" ;;
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
	exit 1
fi
if [ -d "$FILE" ]; then
	echo "$FILE: Is a directory" >&2
	exit 1
fi

#
# Form the path to the config file based on the name of the lock file
#
R_VERS="${FILE%.lock}"
R_VERS="${R_VERS##*_}"
if [ ! "$CONFFILE_SET" ]; then
	CONFFILE="${FILE%.lock}.conf"
	if [ -e "$CONFFILE" -a ! "$FORCE" ]; then
		echo "$CONFFILE: Already exists (use \`-f' to override)"
		exit $FAILURE
	fi
elif [ "$CONFFILE" = "-" ]; then
	CONFFILE="/dev/stdout"
fi
ORIGIN=$( git config remote.origin.url )
PROJECT="${ORIGIN##*:}"
REPO="${PROJECT%.[Gg][Ii][Tt]}"
REPONAME="${REPO##*/}"
REPONAME="${REPONAME#pkgcenter-}"
awk -v R_VERS="$R_VERS" -v REPONAME="$REPONAME" -v TEMPLATE="$TEMPLATE" '
	BEGIN {
		ex = ex "|KernSmooth"
		ex = ex "|MASS"
		ex = ex "|Matrix"
		ex = ex "|base"
		ex = ex "|boot"
		ex = ex "|class"
		ex = ex "|cluster"
		ex = ex "|codetools"
		ex = ex "|compiler"
		ex = ex "|datasets"
		if (R_VERS != "3.1.1") ex = ex "|foreign"
		ex = ex "|grDevices"
		ex = ex "|graphics"
		ex = ex "|grid"
		ex = ex "|lattice"
		ex = ex "|methods"
		ex = ex "|mgcv"
		ex = ex "|mgvc"
		ex = ex "|nlme"
		ex = ex "|nnet"
		ex = ex "|parallel"
		ex = ex "|rpart"
		ex = ex "|spatial"
		ex = ex "|splines"
		ex = ex "|stats"
		ex = ex "|stats4"
		ex = ex "|survival"
		ex = ex "|tcltk"
		ex = ex "|tools"
		if (R_VERS != "2.15.3") ex = ex "|translations"
		ex = ex "|utils"
		ex = sprintf("(%s)", substr(ex, 2))
	}
	$1 ~ /^-/ { next }
	{ sub(/[[:space:]]*#.*/, "") }
	$1 ~ "^" ex "$" || $1 ~ "^" ex "[^[:alnum:]_]" { next }
	split($0, req, /==/) > 1 {
		tab = "\t"
		len = length(req[1])
		if (len < 16) tab = tab "\t"
		if (len < 8) tab = tab "\t"
		$0 = sprintf("%s%s%s", req[1], tab, req[2])
		R_REQS = R_REQS "\n" (n++ == 0 ? "" : "\t") $0
	}
	END {
		R_REQS = substr(R_REQS, 2)
		while (getline < TEMPLATE) {
			gsub(/@R_VERS@/, R_VERS)
			gsub(/@REPONAME@/, REPONAME)
			gsub(/@R_REQS@/, R_REQS)
			print
		}
	}
' "$FILE" > "$CONFFILE"

#
# Remove/reset keywords inherited from template
#
if [ -f "$CONFFILE" ]; then
	../../.git-filters/keywords -d "$CONFFILE"
fi

exit $SUCCESS

################################################################################
# END
################################################################################
