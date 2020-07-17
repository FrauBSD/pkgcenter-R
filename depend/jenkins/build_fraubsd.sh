#!/bin/sh
############################################################ IDENT(1)
#
# $Title: Jenkins build script $
# $Copyright: 2019-2020 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/jenkins/build_fraubsd.sh 2020-07-16 20:52:14 -0700 freebsdfrau $
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
DEBUG=		# -D
FORCE=		# -f
FORCE_UPLOAD=	# -U
IMPORT=		# -i|-a
MAKE_BIN=	# -B
NOPULL=		# -n
NOPUSH=		# -n
NORPMS=		# -N
REBUILD_BIN=	# -R
UPLOAD=		# -u|-a

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
: "${UNAME_s:=$( uname -s )}"
SYSTEM=$( echo "$UNAME_s" | awk '{print tolower($0)}' )
case "${UNAME_p:=$( uname -p )}" in
i?86)
	LINUX="$LINUX-x86"
	R_PLATFORM="R_x86-pc-$SYSTEM-gnu"
	;;
x86_64)
	LINUX="$LINUX-x86_64"
	R_PLATFORM="R_x86_64-pc-$SYSTEM-gnu"
	;;
*)
	echo "Unknown machine architecture" >&2
	exit $FAILURE
esac
PLATFORM="$LINUX"

#
# Miscellaneous
#
BUILD_SUCCESS=
DATE=$( date +"%a %b %e %Y" )
: ${HOSTNAME:=$( hostname )}
: ${ID:=$( id -nu )}

############################################################ FUNCTIONS

have(){ type "$@" > /dev/null 2>&1; }

if [ -t 1 ]; then # stdout is a tty
ban1(){ have figlet || return $SUCCESS; printf "\e[${BAN1COLOR:-36};1m\n";
	figlet -w 200 "$*"; printf "\e[m\n"; }
hdr1(){ printf "\e[32;1m>>>\e[39m %s\e[m\n" "$*"; }
step(){ printf "\e[32;1m->\e[39m %s\e[m\n" "$*"; }
note(){ printf "\e[32;1m>\e[m %s\n" "$*"; }
warn(){ printf "\e[33;1mACHTUNG!\e[m %s\n" "$*" >&2; }
else
ban1(){ have figlet || return $SUCCESS; figlet -w 200 "$*"; }
hdr1(){ printf ">>> %s\n" "$*"; }
step(){ printf -- "-> %s\n" "$*"; }
note(){ printf "> %s\n" "$*"; }
warn(){ printf "ACHTUNG! %s\n" "$*" >&2; }
fi

usage()
{
	local optfmt="\t%-5s %s\n"
	exec >&2
	printf "Usage: %s [-aBDFfhiNnUu] [name ...]\n" "$pgm"
	printf "Options:\n"
	printf "$optfmt" "-a" "Perform all actions. Same as \`-iu'."
	printf "$optfmt" "-B" "Make binary R packages only. Implies \`-N'."
	printf "$optfmt" "-D" "Enable debug statements from vcr."
	printf "$optfmt" "-f" "Force. Always build even if no changes."
	printf "$optfmt" "-h" "Print this usage statement and exit."
	printf "$optfmt" "-i" "Import results to git."
	printf "$optfmt" "-N" "Disable RPM creation."
	printf "$optfmt" "-n" "Disable git pull/push actions."
	printf "$optfmt" "-R" "Rebuild local binary packages."
	printf "$optfmt" "-U" "Force Upload to Artifactory."
	printf "$optfmt" "-u" \
		"Upload RPMs and/or binary packages to Artifactory."
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

die()
{
	local fmt="$1"
	if [ "$fmt" ]; then
		shift 1 # fmt
		if [ -t 1 ]; then # stdout is a tty
			printf "\e[31;1mFATAL!\e[m $fmt\n" "$@"
		else
			printf "FATAL! $fmt\n" "$@"
		fi
	fi
	exit $FAILURE
}

vcran_transform()
{
	local file="$1" update

	# Transform versions in vcran configuration file
	update=$( awk -v file="$file" '
		!/^[[:space:]]*(#|$)/ {
			nx++
			name[nx] = $1
			from[nx] = $2
			chto[nx] = $3
		}
		END {
			while (getline < file) {
				if (/^[[:space:]]*(#|$)/) {
					print
					continue
				}
				for (n = 1; n <= nx; n++) {
					if ($1 != name[n]) continue
					if ($2 != from[n]) continue
					sub(/[^[:space:]]+$/, chto[n])
					break
				}
				print
			}
		}
	' )
	echo "$update" > "$file"
}

create()
{
	local rpm="$1" update

	step "Creating $LINUX/$RPMGROUP/$rpm"
	cd ../../redhat/$LINUX
	../create.sh "$RPMGROUP/$rpm"
	cd "$RPMGROUP/$rpm"

	# Update SPECFILE
	update=$( awk -v arch="$( uname -m )" -v id="$ID" -v linux="$LINUX" \
		-v R=R$r_vers_short -v vcran=$RPMPREFIX$r_vers_short-vcran '
		match(tolower($0), /^buildarch:[[:space:]]*/) {
			$0 = substr($0, 1, RSTART + RLENGTH - 1) arch
		}
		{ gsub(/First Last|flast/, id) }
		tolower($0) ~ /^buildroot:/ {
			print
			while (getline) {
				if ($0 == "") continue
				break
			}
			print ""
			print "Requires:", R
			print "Requires:", vcran
			print ""
		}
		tolower($0) ~ /^release:/ {
			if (linux ~ /rhel7/ && !/\.el7/) {
				$0 = $0 ".el7"
			}
		}
	1' SPECFILE )
	echo "$update" > SPECFILE

	# Update SRCDIR in pkgcenter.conf
	update=$( awk -v lib="$lib" '
		match($0, /^SRCDIR=/) {
			$0 = sprintf("%s=$PKGCENTER/depend/%s/install",
			substr($0, 1, RSTART + RLENGTH - 2), lib)
		}
	1' pkgcenter.conf )
	echo "$update" > pkgcenter.conf
}

build_rpm()
{
	local repo repos

	# Update SPECFILE %files
	step "Updating %files section of SPECFILE"
	make srcfiles

	# Update pkgcenter.conf
	step "Updating pkgcenter.conf with %files section of SPECFILE"
	note "This may take several minutes for large RPMs"
	echo " Start: $( date )"
	make conf
	echo "Finish: $( date )"

	# Build RPM and copy to local storage
	step "Making $rpm"
	make

	# Upload it if given `-u'
	if [ "$UPLOAD$FORCE_UPLOAD" ]; then
		step "Upload $rpm to Artifactory"
		case "$LINUX" in
		rhel6-x86_64) repos="
			yum-fraubsd/centos/6/x86_64/x86_64/
			yum-fraubsd-el6-x86_64/
		" ;;
		rhel7-x86_64) repos="
			yum-fraubsd-el7-x86_64/Packages/
		" ;;
		*) echo "Unknown linux arch \`$LINUX'"
		esac
		for repo in $repos; do
			afput -r "$repo" $rpm*
		done
	fi

	# Move RPM to landing directory
	step "Moving $rpm to $RPM_ROOT/$LINUX"
	mkdir -p $RPM_ROOT/$LINUX/
	mv $rpm* $RPM_ROOT/$LINUX/

	# Import and tag
	if [ "$IMPORT" ]; then
		step "Cleaning up package build"
		make distclean
		step "Importing package update"
		git fetch && git merge --ff-only origin/master
		make autoimport
		make tag || echo "(errors ignored)"
		if [ ! "$NOPUSH" ]; then
			git fetch && git merge --ff-only origin/master
			git push origin master --tags
		fi
	fi
}

build_vcran_rpm()
{
	local update

	# Update SPECFILE Release and %changelog
	update=$( awk -v date="$DATE" -v id="$ID" '
		match($0, /^Version:[[:space:]]*/) {
			vers = substr($0, RSTART + RLENGTH)
			sub(/[[:space:]]*#.*$/, "", vers)
		}
		match($0, /^Release:[[:space:]]*/) {
			sub(/[[:space:]]*#.*$/, "")
			pre = substr($0, 1, RSTART + RLENGTH - 1)
			rel = substr($0, RSTART + RLENGTH)
			suf = ""
			if (match(rel, /[^[:digit:]]/)) {
				suf = substr(rel, RSTART)
				rel = substr(rel, 1, RSTART - 1)
			}
			$0 = sprintf("%s%u%s", pre, ++rel, suf)
		}
		/^%changelog$/ {
			$0 = $0 sprintf("\n* %s %s <%s@fraubsd.org> - %s-%s",
				date, id, id, vers, rel)
			$0 = $0 "\n- jenkins/build_fraubsd.sh auto build"
		}
	1' SPECFILE )
	echo "$update" > SPECFILE

	build_rpm
}

build_lib_rpm()
{
	local update

	# Update SPECFILE Version and %changelog
	update=$( awk -v vers="$vers" -v date="$DATE" -v id="$ID" '
		BEGIN { gsub(/-/, "_", vers) }
		match($0, /^Version:[[:space:]]*/) {
			$0 = substr($0, RSTART, RLENGTH) vers
		}
		match($0, /^Release:[[:space:]]*/) {
			rel = substr($0, RSTART + RLENGTH)
			sub(/[[:space:]]*#.*$/, "", rel)
		}
		/^%changelog$/ {
			$0 = $0 sprintf("\n* %s %s <%s@fraubsd.org> - %s-%s",
				date, id, id, vers, rel)
			$0 = $0 "\n- jenkins/build_fraubsd.sh auto build"
		}
	1' SPECFILE )
	echo "$update" > SPECFILE

	build_rpm
}

build_lib_tar()
{
	local api
	local binpkg bindir binfile
	local patchelf=-p
	local platform

	binpkg="${lib}_${vers}_$R_PLATFORM.tar.gz"
	bindir="../../redhat/$LINUX/$RPMGROUP/R$r_vers_short-$lib"
	bindir="$bindir/src/opt/R/$r_vers/lib64/R/library/$lib"
	binfile="$BIN_ROOT/$PLATFORM/$r_vers/${lib}_${vers}.tgz"

	[ -e "$binfile" ] && return $FAILURE

	case "$LINUX" in
	rhel6*) patchelf= ;;
	esac

	step "Create R binary package"
	( set +e
		vcr-$r_vers ${DEBUG:+-D} pack $pathcelf "$bindir"
		echo "EXIT:$?"
	) | awk '
		!/==>/ && !/^EXIT:/
		sub(/^EXIT:/, "") { status = $0 }
		END { exit status }
	' # END-QUOTE
	[ -e "${binfile%/*}" ] || mkdir -p "${binfile%/*}"
	mv "$binpkg" "$binfile" || die "Unable to archive binary R package"

	[ "$UPLOAD$FORCE_UPLOAD" ] && afput -r "$bin_repo" "$binfile"

	return $SUCCESS
}

build_stats()
{
	echo
	if [ "$BUILD_SUCCESS" ]; then
		BAN1COLOR=32
		ban1 "Success"
	else
		BAN1COLOR=31
		ban1 "Failure"
	fi
	hdr1 "Build time"
	if [ -t 1 ]; then # stdout is a tty
		printf "\e[1mStart:\e[m %s\n" "$START"
		printf "\e[1m  End:\e[m %s\n" "$( date )"
	else
		printf "Start: %s\n" "$START"
		printf "  End: %s\n" "$( date )"
	fi
	if [ "$BUILD_SUCCESS" ]; then
		hdr1 "Build succeeded"
	else
		hdr1 "Build failed"
	fi
}

############################################################ MAIN

set -e # errexit

#
# Process command-line options
#
while getopts aBDfhiNnRUu flag; do
	case "$flag" in
	a) IMPORT=1 UPLOAD=1 ;;
	B) MAKE_BIN=1 ;;
	D) DEBUG=1 ;;
	f) FORCE=1 ;;
	i) IMPORT=1 ;;
	N) NORPMS=1 ;;
	n) NOPUSH=1 NOPULL=1 ;;
	R) REBUILD_BIN=1 ;;
	U) FORCE_UPLOAD=1 ;;
	u) UPLOAD=1 ;;
	*) usage # NOTREACHED
	esac
done
shift $(( $OPTIND - 1 ))

START=$( date )
hdr1 "Build started on $START"
trap build_stats EXIT

#
# Dependency checks
#
have awk || die "awk not installed [yum install gawk]"
if [ "$UPLOAD$FORCE_UPLOAD" ]; then
	have afput || die "afput not installed [yum install afput]"
fi
have make || die "make not installed [yum install make]"
have curl || die "curl not installed [yum install curl]"
have rpmbuild || die "rpmbuild not installed [yum install rpm-build]"
have vcr || die "vcr not installed [yum install vcr]"

#
# Fixup paths
#
case "$RPM_ROOT" in
/) : ok ;;
*) RPM_ROOT="${RPM_ROOT%/}"
esac
case "$BIN_ROOT" in
/) : ok ;;
*) BIN_ROOT="${BIN_ROOT%/}"
esac

#
# Download
#
step "Download lock files"
( set +e; ./download.sh ${NOPULL:+-n} "$@"; echo "EXIT:$?" ) | awk '
	!/==>/ && !/^EXIT:/
	sub(/^EXIT:/, "") { status = $0 }
	END { exit status }
' # END-QUOTE

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

#
# Build
#
thisdir=$( pwd )
n=0
while : fund build lock files ; do
	n=$(( $n + 1 ))

	#
	# Lock file
	#
	getvar BUILD${n}_NAME name || break
	[ "$name" ] || break
	if [ $# -eq 0 ]; then
		skip=
	else
		skip=1
		for arg in "$@"; do
			[ "$name" = "$arg" ] || continue
			skip=
			break
		done
	fi
	[ ! "$skip" ] || continue

	#
	# vcran config
	#
	vcran=
	xform=
	case "$LINUX" in
	rhel6*)
		getvar BUILD${n}_RHEL6_VCRAN vcran
		getvar BUILD${n}_RHEL6_VCRAN_XFORM xform
		;;
	rhel7*)
		getvar BUILD${n}_RHEL7_VCRAN vcran
		getvar BUILD${n}_RHEL7_VCRAN_XFORM xform
		;;
	esac || : error check below
	[ "$vcran" ] || continue

	#
	# Banner
	#
	ban1 "${name%.lock}"
	hdr1 "Build $name"

	#
	# R version
	#
	r_vers="${name##*_}"
	r_vers="${r_vers%.lock}"
	bin_repo="$BIN_REPO/bin/$PLATFORM/contrib/$r_vers"
	r_vers_short=$( echo "$r_vers" | sed -e 's/[^0-9]//g' )

	#
	# Build libraries
	# NB: Using for-loop to allow break
	#
	for vcran in $vcran; do
		vcran_conf="etc/$vcran"

		# Convert
		step "Create ../vcran/$vcran_conf"
		( cd ../vcran &&
			./lock2conf.sh -o "$vcran_conf" "$thisdir/$name" )

		# Optionally transform
		if [ "$xform" ]; then
			note "Transforming versions in ../vcran/$vcran_conf"
			echo "$xform"
			echo "$xform" | vcran_transform "../vcran/$vcran_conf"
		fi

		# Check for changes
		step "Checking for changes in ../vcran/$vcran_conf"
		changed=$( git status "../vcran/$vcran_conf" | awk '
			BEGIN { s = "[[:space:]]*" }
			sub("^#?" s "(modified:" s ")?\\.\\./", "../")
		' )
		if [ "$changed" ]; then
			echo "Changes detected (build required)"
			echo "$changed"
			if [ -t 0 ] && have vimcat; then # stdout is a tty
				git diff "../vcran/$vcran_conf" | vimcat
			else
				git diff "../vcran/$vcran_conf" | cat
			fi
		elif [ "$FORCE" ]; then
			warn "NO change detected (building anyways; \`-f')"
		else
			warn "NO change detected (skipping)"
			break
		fi

		# Build
		( cd ../vcran && ./build_fraubsd.sh \
			${DEBUG:+-D} \
			${FORCE_UPLOAD:+-I} \
			${IMPORT:+-i} \
			${MAKE_BIN:+-B} \
			${REBUILD_BIN:+-R} \
			${UPLOAD:+-i} \
			"$vcran_conf"
		)
		[ ! "$MAKE_BIN$NORPMS" ] || continue

		# Package build
		rpm="$RPMPREFIX$r_vers_short-vcran"
		rpmdir="../../redhat/$LINUX/$RPMGROUP/$rpm"
		[ -e "$rpmdir" ] || ( lib=vcran create "$rpm" )
		( cd "$rpmdir" && build_vcran_rpm )

		# Import and tag
		if [ "$IMPORT" ]; then
			step "Importing ../vcran updates"
			(
				cd ../vcran
				git fetch && git merge --ff-only origin/master
				../import -m "Autoimport by $ID" \
					"$vcran_conf"
				../tag $( date +%Y.%m.%d-%H_%M_%S ) ||
					echo "(errors ignored)"
				if [ ! "$NOPUSH" ]; then
					git fetch && git merge \
						--ff-only origin/master
					git push origin master --tags
				fi
			)
		fi
	done
	[ ! "$MAKE_BIN$NORPMS" ] || continue

	#
	# External libraries
	#
	step "Create R build configs"
	./lock2conf.sh "$name"
	for lib in $( ./lock2conf.sh -l "$name" ); do
		vers="${lib#*_}"
		lib="${lib%%_*}"

		# Check for changes
		r_conf="etc/R-$r_vers-$LINUX.conf"
		step "Checking for changes in ../$lib/$r_conf"
		changed=$( git status "../$lib/$r_conf" | awk '
			BEGIN { s = "[[:space:]]*" }
			sub("^#?" s "(modified:" s ")?\\.\\./", "../")
		' )
		if [ "$changed" ]; then
			echo "Changes detected (build required)"
			echo "$changed"
			if [ -t 0 ] && have vimcat; then # stdout is a tty
				git diff "../$lib/$r_conf" | vimcat
			else
				git diff "../$lib/$r_conf" | cat
			fi
		else
			build_lib_tar $lib ||
				warn "NO changes detected (skipping)"
			continue
		fi

		# Build the library for this R version
		step "Rebuilding ../$lib"
		( cd ../$lib && ./build_fraubsd.sh "$r_conf" )

		# Package build
		rpm="$RPMPREFIX$r_vers_short-$lib"
		rpmdir="../../redhat/$LINUX/$RPMGROUP/$rpm"
		[ -e "$rpmdir" ] || ( create "$rpm" )
		( cd "$rpmdir" && build_lib_rpm )

		# R binary package build
		build_lib_tar $lib

		# Package clean (else building next R version will fail)
		step "Clean ../$lib"
		( cd "../$lib" && ./clean_fraubsd.sh )

		# Import and tag
		if [ "$IMPORT" ]; then
			step "Importing ../$lib updates"
			(
				cd "../$lib"
				git fetch && git merge --ff-only origin/master
				../import -m "Autoimport by $ID" \
					*.sh etc
				../tag $vers || echo "(errors ignored)"
				if [ ! "$NOPUSH" ]; then
					git fetch && git merge \
						--ff-only origin/master
					git push origin master --tags
				fi
			)
		fi
	done
done

BUILD_SUCCESS=1
exit $SUCCESS

################################################################################
# END
################################################################################
