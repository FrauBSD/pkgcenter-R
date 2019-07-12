#!/bin/sh
############################################################ IDENT(1)
#
# $Title: Script to clean apache-mxnet $
# $Copyright: 2019 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/apache-mxnet/clean_fraubsd.sh 2019-07-12 16:02:39 -0700 freebsdfrau $
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
	3rdparty/*/*/build/ \
	3rdparty/*/*/external/ \
	3rdparty/*/*/lib/ \
	3rdparty/*/build/ \
	3rdparty/*/external/ \
	3rdparty/dmlc-core/*.o \
	3rdparty/dmlc-core/libdmlc.a \
	CMakeCache.txt \
	CMakeFiles/ \
	R-package/NAMESPACE \
	R-package/inst/ \
	R-package/src/*.o \
	R-package/src/image_recordio.h \
	R-package/src/mxnet.so \
	build/ \
	install \
	lib/ \
	mklml/ \
	renv/ \
;do
        eval2 rm -Rf "$item"
done

[ -e .keep_stage ] && exit
for item in \
	.clang-tidy \
	.codecov.yml \
	.mxnet_root \
	.travis.yml \
	3rdparty/ \
	CMakeLists.txt \
	CODEOWNERS \
	CONTRIBUTORS.md \
	DISCLAIMER \
	Jenkinsfile \
	KEYS \
	LICENSE \
	MKLDNN_README.md \
	Makefile \
	NEWS.md \
	NOTICE \
	R-package/ \
	README.md \
	amalgamation/ \
	appveyor.yml \
	benchmark/ \
	ci/ \
	cmake/ \
	contrib/ \
	cpp-package/ \
	dev_menu.py* \
	docker/ \
	docs/ \
	example/ \
	include/ \
	julia/ \
	make/ \
	matlab/ \
	mkldnn.mk \
	perl-package/ \
	plugin/ \
	python/ \
	readthedocs.yml \
	scala-package/ \
	setup-utils/ \
	snap.python* \
	snapcraft.yaml \
	src/ \
	tests/ \
	tools/ \
;do
	eval2 rm -Rf "$item"
done


################################################################################
# END
################################################################################
