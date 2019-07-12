#!/bin/sh
############################################################ IDENT(1)
#
# $Title: Script to clean apache-mxnet $
# $Copyright: 2019 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/apache-mxnet-legacy/clean_fraubsd.sh 2019-07-12 16:08:35 -0700 freebsdfrau $
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
	R-package/inst/ \
	R-package/src/image_recordio.h \
	build/ \
	dmlc-core/*.o \
	dmlc-core/libdmlc.a \
	install \
	lib/ \
	renv/ \
;do
        eval2 rm -Rf "$item"
done

[ -e .keep_stage ] && exit
for item in \
	.travis.yml \
	CMakeLists.txt \
	CONTRIBUTORS.md \
	LICENSE \
	Makefile \
	NEWS.md \
	R-package/ \
	README.md \
	amalgamation/ \
	appveyor.yml \
	cmake/ \
	dmlc-core/ \
	docker/ \
	docs/ \
	example/ \
	include/ \
	make/ \
	matlab/ \
	mshadow/ \
	plugin/ \
	ps-lite/ \
	python/ \
	readthedocs.yml \
	scala-package/ \
	src/ \
	tests/ \
	tools/ \
;do
	eval2 rm -Rf "$item"
done

################################################################################
# END
################################################################################
