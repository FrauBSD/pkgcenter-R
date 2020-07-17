#!/bin/sh
############################################################ IDENT(1)
#
# $Title: Script to check machine for required software before building $
# $Copyright: 2019-2020 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/jenkins/preflight.sh 2020-07-16 20:52:14 -0700 freebsdfrau $
#
############################################################ GLOBALS

#
# Global exit status
#
SUCCESS=0
FAILURE=1

#
# Miscellaneous
#
ALL_GOOD=1

############################################################ MAIN

case "${UNAME_s:=$( uname -s )}" in
Linux) : ok ;;
*)
	echo "Unknown system"
	exit $FAILURE
esac

#
# Check Linux software
#
RPMS="
	R311
	R311-vcran
	R331
	R331-vcran
	afput
	blas-devel
	figlet
	gsl-devel
	lapack-devel
	libcurl-devel
	libxml2-devel
	mesa-libGL-devel
	mesa-libGLU-devel
	openssl-devel
	postgresql-devel
	vimcat
	vcr
" # END-QUOTE
case "${LINUX:=$( cat /etc/redhat-release )}" in
*" 6."*) # CentOS 6
	RPMS="$RPMS
		mysql-devel
	" ;;
*" 7."*) # CentOS 7
	RPMS="$RPMS
		mysql-community-devel\|mysql-devel\|mariadb-devel
	" ;;
*)
	echo "Unknown architecture."
	exit $FAILURE
esac
for rpm in $RPMS; do
	case "$rpm" in
	*"|"*)
		oldIFS="$IFS"
		IFS="|"
		set -- $rpm
		IFS="$oldIFS"
		;;
	*)
		set -- "$rpm"
	esac
	RPM_FOUND=
	for rpmx in "$@"; do
		rpm -q -- "$rpmx" > /dev/null || continue
		RPM_FOUND=1
		break
	done
	[ "$RPM_FOUND" ] && continue
	echo "$rpm not installed"
	ALL_GOOD=
done

[ "$ALL_GOOD" ] || exit $FAILURE
echo "All good for $LINUX"
exit $SUCCESS

################################################################################
# END
################################################################################
