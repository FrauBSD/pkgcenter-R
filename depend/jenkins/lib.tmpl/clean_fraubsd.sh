#!/bin/sh
############################################################ IDENT(1)
#
# $Title: Script to clean Virtual CRAN package binaries $
# $Copyright: 2019 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/jenkins/lib.tmpl/clean_fraubsd.sh 2019-07-12 16:36:35 -0700 freebsdfrau $
#
############################################################ INCLUDES

. ./etc/cran.subr || exit 1

############################################################ GLOBALS

#
# ANSI
#
ESC=$( :| awk 'BEGIN { printf "%c", 27 }' )
ANSI_BLD_ON="$ESC[1m"
ANSI_BLD_OFF="$ESC[22m"
ANSI_GRN_ON="$ESC[32m"
ANSI_FGC_OFF="$ESC[39m"

############################################################ FUNCTIONS

eval2()
{
        echo "$ANSI_BLD_ON$ANSI_GRN_ON==>$ANSI_FGC_OFF $*$ANSI_BLD_OFF"
        eval "$@"
}

############################################################ MAIN

set -e
for item in \
	$CRAN_INSTALLDIR \
	$CRAN_TMPDIR \
;do
        eval2 rm -Rf "$item"
done

eval2 renv_destroy

################################################################################
# END
################################################################################
