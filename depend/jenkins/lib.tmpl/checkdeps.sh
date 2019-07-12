#!/bin/sh
# -*- tab-width: 4 -*- ;; Emacs
# vi: set noexpandtab  :: Vi/ViM
#-
############################################################ IDENT(1)
#
# $Title: Script to check CRAN package dependencies $
# $Copyright: 2019 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/jenkins/lib.tmpl/checkdeps.sh 2019-07-12 16:36:35 -0700 freebsdfrau $
#
############################################################ INCLUDES

. ./etc/cran.subr || exit 1

############################################################ MAIN

[ $# -gt 0 ] || die "Usage: %s config-file" "$pgm" >&2
conf_read "$1" # sets $PACKAGE* globals

#
# Get a list of what packages are already installed
#
step "R libPaths"
library=$( eval2 R -e "'cat(.libPaths(.Library))'" ) ||
	die "Unable to determine library path"
[ "$DEBUG" ] && echo "library=[$library]"
installed="R
$(
	for dir in "$library"/*; do
		[ -e "$dir/DESCRIPTION" ] || continue
		echo "${dir##*/}"
	done
)" || die "Something went wrong in $library"
[ "$DEBUG" ] && echo "installed=[$installed]"

#
# Check package source tarball
#
set -e # errexit
exec 3<&1
n=0
missing=
if [ "$DEBUG" ]; then
	descr=$( exec 2>&1; eval2 tar zxfO "$PACKAGEFILE" \
		"$PKGNAME/DESCRIPTION" | tee /dev/stderr )
else
	descr=$( eval2 tar zxfO "$PACKAGEFILE" "$PKGNAME/DESCRIPTION" )
fi || die "Unable to extract DESCRIPTION file"
depinfo=$( exec 2>&1; echo "$descr" | awk '
	BEGIN { catch = "^(Depends|Imports):" }
	$0 ~ catch && start = 1, $0 ~ /^[^[:space:]]/ &&
	    $1 !~ catch && stop = 1 { }
	!start { next }
	!stop { print; next }
	{ start = stop = 0 }
' | tee /dev/stderr )
deps=$( echo "$depinfo" | awk '
	{
		sub(/^[^[:space:]]+:/, "")
		buf = buf " " $0
	}
	END {
		gsub(/\([^)]+\)/, "", buf)
		gsub(/,/, " ", buf)
		sub(/^[[:space:]]*/, "", buf)
		sub(/[[:space:]]*$/, "", buf)
		ndeps = split(buf, deps, /[[:space:]]+/)
		delete seen
		for (i = 1; i <= ndeps; i++) {
			if (!((dep = deps[i]) in seen))
				print dep
			seen[dep]
		}
	}
' )
[ "$DEBUG" ] && echo "deps=[$deps]"
for dep in $deps; do 
	echo "$installed" | matches "$dep" && continue
	echo "$missing" | matches "$dep" && continue
	missing="$missing$NL$dep"
done
missing="${missing#$NL}"

#
# Produce list of missing packages
#
step "Check for missing dependencies"
if [ ! "$missing" ]; then
	echo "None"
	step SUCCESS
	exit $SUCCESS
fi
warn "Missing packages in config!"
echo "$missing" | sort | awk '$0="\t"$0' >&2
die Exiting.

################################################################################
# END
################################################################################
