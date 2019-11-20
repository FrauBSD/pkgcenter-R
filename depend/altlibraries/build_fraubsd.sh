#!/bin/sh
#-
############################################################ IDENT(1)
#
# $Title: Script to build R altlibraries inside package sandboxes $
# $Copyright: 2019 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/altlibraries/build_fraubsd.sh 2019-11-19 23:38:36 -0800 freebsdfrau $
#
############################################################ CONFIGURATION

RPMGROUP=Applications/Engineering
RPMPREFIX=R
RPM_ROOT=~/jenkins/

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
IMPORT=		# -i|-a
NOPUSH=		# -n
NOPULL=		# -n
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
case "$( uname -m )" in
x86_64) LINUX="$LINUX-x86_64" ;;
*)
	echo "Unknown machine architecture" >&2
	exit $FAILURE
esac

#
# Miscellaneous
#
BUILD_SUCCESS=
DATE=$( date +"%a %b %e %Y" )
LOCKFILES=
: ${HOSTNAME:=$( hostname )}
: ${ID:=$( id -nu )}

############################################################ FUNCTIONS

have(){ type "$@" > /dev/null 2>&1; }

exec 3<&1
if [ -t 1 ]; then # stdout is a tty
ban1(){ have figlet || return $SUCCESS; printf "\e[${BAN1COLOR:-36};1m\n";
	figlet -w 200 "$*"; printf "\e[m\n"; }
hdr1(){ printf "\e[32;1m>>>\e[39m %s\e[m\n" "$*"; }
step(){ printf "\e[32;1m->\e[39m %s\e[m\n" "$*"; }
eval2(){ printf "\e[2m%s\e[m\n" "$*" >&3; eval "$@"; }
note(){ printf "\e[32;1m>\e[m %s\n" "$*"; }
warn(){ printf "\e[33;1mACHTUNG!\e[m %s\n" "$*" >&2; }
else
ban1(){ have figlet || return $SUCCESS; figlet -w 200 "$*"; }
hdr1(){ printf ">>> %s\n" "$*"; }
step(){ printf -- "-> %s\n" "$*"; }
eval2(){ printf "%s\n" "$*" >&3; eval "$@"; }
note(){ printf "> %s\n" "$*"; }
warn(){ printf "ACHTUNG! %s\n" "$*" >&2; }
fi

usage()
{
	local optfmt="\t%-5s %s\n"
	exec >&2
	printf "Usage: %s [-ahinu] [file ...]\n" "$pgm"
	printf "Options:\n"
	printf "$optfmt" "-a" "Perform all actions. Same as \`-iu'."
	printf "$optfmt" "-h" "Print this usage statement and exit."
	printf "$optfmt" "-i" "Import results to git."
	printf "$optfmt" "-n" "Disable git pull/push actions."
	printf "$optfmt" "-u" "Upload RPMs to artifactory."
	exit $FAILURE
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


build_rpm()
{
	local repo repos

	# Update SPECFILE Release and %changelog
	step "Updating SPECFILE Release and changelog"
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
			$0 = $0 "\n- altlibraries/build_fraubsd.sh auto build"
		}
	1' SPECFILE )
	echo "$update" > SPECFILE

	# Update SPECFILE %files
	step "Updating %files section of SPECFILE"
	eval2 make srcfiles

	# Update pkgcenter.conf
	step "Updating pkgcenter.conf with %files section of SPECFILE"
	note "This may take several minutes for large RPMs"
	echo " Start: $( date )"
	eval2 make conf
	echo "Finish: $( date )"

	# Build RPM and copy to local storage
	step "Making $rpm"
	eval2 make

	# Upload it if given `-u'
	if [ "$UPLOAD" ]; then
		step "Upload $rpm to Artifactory"
		case "$LINUX" in
		rhel6-x86_64) repos="
			yum-fraubsd-el6-x86_64/
		" ;;
		rhel7-x86_64) repos="
			yum-fraubsd-el7-x86_64/Packages/
		" ;;
		*) echo "Unknown linux arch \`$LINUX'"
		esac
		for repo in $repos; do
			eval2 afput -r $repo $rpm*
		done
	fi

	# Move RPM to landing directory
	step "Moving $rpm to $RPM_ROOT/$LINUX"
	eval2 mkdir -p $RPM_ROOT/$LINUX/
	eval2 mv $rpm* $RPM_ROOT/$LINUX/

	# Import and tag
	if [ "$IMPORT" ]; then
		step "Cleaning up package build"
		eval2 make distclean
		step "Importing package update"
		eval2 git fetch && eval2 git merge --ff-only origin/master
		eval2 make autoimport
		eval2 make tag || echo "(errors ignored)"
		[ "$NOPUSH" ] || eval2 git push origin master --tags
	fi
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
while getopts ahinu flag; do
	case "$flag" in
	a) IMPORT=1 UPLOAD=1 ;;
	i) IMPORT=1 ;;
	n) NOPUSH=1 NOPULL=1 ;;
	u) UPLOAD=1 ;;
	*) usage # NOTREACHED
	esac
done
shift $(( $OPTIND - 1 ))

START=$( date )
hdr1 "Build started on $START"
trap build_stats EXIT

#
# Install dependencies
#
items_needed=
#	bin=someprog:pkg=somepkg \
#	file=/path/to/some_file:pkg=somepkg \
#	lib=somelib.so:pkg=somepkg \
for entry in \
	bin=vcr:pkg=vcr \
	file=/usr/bin/R-3.1.1:pkg=R311-fraubsd \
	file=/usr/bin/R-3.3.1:pkg=R331-fraubsd \
	bin=make:pkg=make \
	bin=afput:pkg=afput \
	bin=curl:pkg=curl \
	bin=rpmbuild:pkg=rpm-build \
; do
	check="${entry%%:*}"
	item="${check#*=}"
	case "$check" in
	 bin=*) type "$item" > /dev/null 2>&1 && continue ;;
	file=*) [ -e "$item" ] && continue ;;
	 lib=*) ldconfig -p | awk -v lib="$item" \
		'$1==lib{exit f++}END{exit !f}' && continue ;;
	     *) continue
	esac
	pkg="${entry#*:}"
	pkgname="${pkg#*=}"
	items_needed="$items_needed $pkgname"
done
[ "$items_needed" ] && eval2 sudo yum install $items_needed

#
# Default arguments
#
[ $# -gt 0 ] || set -- */*.lock
LOCKFILES="$*"

#
# Sort arguments alphabetically
#
set -- $( echo $* | xargs -n1 | sort -u )

#
# Build lockfile arguments
#
n=1
r_cur=
r_list=
for path in "$@"; do
	#
	# R version
	#
	r_vers=${path%%/*}
	if [ "$r_vers" != "$r_cur" ]; then
		ban1 "$r_vers/*.lock"
		r_cur=$r_vers
		r_list="$r_list $r_cur"
	fi

	#
	# Create sandbox directories
	#
	hdr1 "Build $path [$n/$#]"
	altlibraries=/opt/R/$r_vers/lib64/R/altlibraries
	destdir=install-$r_vers$altlibraries
	step "Create $destdir"
	[ ! -e $destdir ] || eval2 mkdir -p $destdir


	#
	# Build libraries
	#
	step "Play $path"
	lockfile=${path##*/}
	eval2 vcr-$r_vers play -d $destdir/${lockfile%.lock} $path

	n=$(( $n + 1 ))
done

n=1
set -- $r_list
for r_vers in $*; do
	# Create library-experimental symlinks
	expconf=experimental-$r_vers.conf
	expdir=install-$r_vers/opt/R/$r_vers/lib64/R/library-experimental
	if [ -e "$expconf" ]; then
		ban1 ${expconf%.*}
		awk '!/^[[:space:]]*(#|$)/' $expconf |
			while read NAME DEST REST; do
				hdr1 $NAME
				eval2 mkdir -pv $expdir
				eval2 ln -sfv $DEST $expdir/$NAME
			done
	fi

	# Package build
	r_vers_short=$( echo "$r_vers" | sed -e 's/[^0-9]//g' )
	rpm=$RPMPREFIX$r_vers_short-altlibraries
	ban1 $rpm
	hdr1 "Build $rpm [$n/$#]"
	rpmdir=../../redhat/$LINUX/$RPMGROUP/$rpm
	( eval2 cd $rpmdir && build_rpm )

	n=$(( $n + 1 ))
done

# Import and tag
if [ "$IMPORT" ]; then
	# Package clean (else building next R version will fail)
	step "Clean before import"
	eval2 ./clean_fraubsd.sh

	step "Importing updates"
	eval2 git fetch && git merge --ff-only origin/master
	eval2 git add $LOCKFILES

	# Check for changes
	step "Checking for changes to import"
	changed=$( git status . | awk '
		BEGIN { s = "[[:space:]]*" }
		sub("^#?" s "(modified:" s ")?\\.\\./", "../")
	' )
	if [ "$changed" ]; then
		echo "Changes detected (importing)"
		echo "$changed"
		if [ -t 0 ] && have vimcat; then # stdout is a tty
			git diff "../vcran/$vcran_conf" | vimcat
		else
			git diff "../vcran/$vcran_conf" | cat
		fi

		eval2 ../import -m "Autoimport by $ID on $HOSTNAME" .
		eval2 ../tag $( date +%Y.%m.%d-%H_%M_%S ) ||
			echo "(errors ignored)"
		[ "$NOPUSH" ] || eval2 git push origin master --tags
	else
		warn "NO change detected (skipping import)"
	fi
fi

BUILD_SUCCESS=1
exit $SUCCESS

################################################################################
# END
################################################################################
