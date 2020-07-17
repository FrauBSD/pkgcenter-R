#!/bin/sh
############################################################ IDENT(1)
#
# $Title: Script to clean CRAN package binaries $
# $Copyright: 2019-2020 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/vcran/clean_fraubsd.sh 2020-07-16 20:18:43 -0700 freebsdfrau $
#
############################################################ GLOBALS

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

############################################################ FUNCTIONS

eval2()
{
        echo "$ANSI_BLD_ON$ANSI_GRN_ON==>$ANSI_FGC_OFF $*$ANSI_BLD_OFF"
        eval "$@"
}

############################################################ MAIN

set -e
for item in \
	install-* \
;do
        eval2 rm -Rf "$item"
done

################################################################################
# END
################################################################################
