#!/bin/sh
#-
############################################################ IDENT(1)
#
# $Title: Script to install CRAN package sources $
# $Copyright: 2019-2020 Devin Teske. All rights reserved. $
# $FrauBSD: pkgcenter-R/depend/vcran/build_fraubsd.sh 2020-07-16 20:18:43 -0700 freebsdfrau $
#
############################################################ CONFIGURATION

#
# Artifactory
#
ARTIFACTORY=

#
# Where to store R binary packages
#
BIN_ARCHIVE=~/vcran

#
# Where to upload R binary packages when given `-a' or `-i'
#
BIN_REPO=cran-dev # + /bin/$PLATFORM/contrib/$R_VERS

#
# Where to install packages
#
CRAN_INSTALLDIR=install-%R_VERS%

############################################################ ENVIRONMENT

: "${UNAME_p:=$( uname -p )}"

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
IMPORT=		# -i | -a
NOCLOBBER=1	# -I
REBUILD_BIN=	# -R
USEBIN=		# -B

#
# Miscellaneous
#
NOLOAD=
R_PLATFORM=

############################################################ FUNCTIONS

matches(){ awk -v line="$1" '$0==line{exit ++found}END{exit !found}'; }

usage()
{
	local optfmt="\t%-5s %s\n"
	exec >&2
	printf "Usage: %s [-aBDhIiR] config-file\n" "$pgm"
	printf "Options:\n"
	printf "$optfmt" "-a" "Perform all actions. Same as \`-i'."
	printf "$optfmt" "-B" "Use binary packages when available."
	printf "$optfmt" "-D" "Enable debug statements from vcr."
	printf "$optfmt" "-h" "Print usage statement to stderr and exit."
	printf "$optfmt" "-I" "Force import binary tarballs to Artifactory."
	printf "$optfmt" "-i" "Import binary tarballs to Artifactory."
	printf "$optfmt" "-R" "Rebuild local binary packages."
	die
}

exec 3<&1
if [ -t 1 ]; then # stdout is a tty
step(){ printf "\e[32;1m==>\e[39m %s\e[m\n" "$*"; }
step2(){ printf "\e[32;1m->\e[39m %s\e[m\n" "$*"; }
warn(){ printf "\e[33;1mACHTUNG!\e[m %s\n" "$*" >&2; }

die()
{
	local fmt="$1"
	if [ "$fmt" ]; then
		shift 1 # fmt
		printf "\e[1;31mFATAL!\e[m $fmt\n" "$@" >&2
	fi
	exit $FAILURE
}

eval2()
{
	printf "\e[2m%s\e[m\n" "$*" >&3
	eval "$@"
}
else
step(){ printf "==> %s\n" "$*"; }
step2(){ printf "%s %s\n" "->" "$*"; }
warn(){ printf "ACHTUNG! %s\n" "$*" >&2; }

die()
{
	local fmt="$1"
	if [ "$fmt" ]; then
		shift 1 # fmt
		printf "FATAL! $fmt\n" "$@" >&2
	fi
	exit $FAILURE
}

eval2()
{
	printf "%s\n" "$*" >&3
	eval "$@"
}
fi

conf_read()
{
	local config="$1"

	# Source configuration file
	. "$config" || die "Unable to read %s" "$config"

	# Remove comments from package list
	PACKAGES=$( echo "$PACKAGES" | awk '
		BEGIN { npackages = 0 }
		!/^[[:space:]]*(#|$)/ {
			sub(/[[:space:]]*#.*/, "")
			sub(/^[[:space:]]*/, "")
			sub(/[[:space:]]*$/, "")
			packages[++npackages] = $0
		}
		END { for (i = 1; i <= npackages; i++) print packages[i] }
	' ) || die

	# Count packages
	NPACKAGES=$( echo "$PACKAGES" | awk 'END{print NR}' )
	[ $NPACKAGES -gt 0 ] || die "%s contains no packages" "$CRAN_CONF"
}

serialize_packages()
{
	eval "$( echo "$PACKAGES" | awk -v sq="'" '
		function escape(str)
		{
			gsub(sq, sq "\\" sq sq, str)
			return sq str sq
		}
		function nset(name, vers)
		{
			++n
			printf "name%u=%s\n", n, escape(name)
			printf "vers%u=%s\n", n, escape(vers)
		}
		{ nset($1, $2) }
	' )"
}

url_exists()
{
	${DEBUG:+eval2} curl --output /dev/null --silent \
		--fail -r 0-0 "$@" > /dev/null 2>&1
}

get_deps()
{
	local item name vers path deps desc info data

	for item in $*; do
		name="${item%%==*}"
		vers="${item#*==}"
		path="$BIN_ARCHIVE/${name}_$vers.tar.gz"
		deps="$BIN_ARCHIVE/${name}_$vers-deps.txt"
		echo $name
		if [ -e "$deps" -a -e "$path" -a "$deps" -nt "$path" ]; then
			eval2 cat "$deps"
			continue
		fi
		desc=$( eval2 tar zxfO "$path" "$name/DESCRIPTION" ) ||
			die "Unable to extract DESCRIPTIONS file"
		info=$( echo "$desc" | awk '
			BEGIN { catch = "^(Depends|Imports):" }
			$0 ~ catch && ++start, \
				$0 ~ /^[^[:space:]]/ &&
				$1 !~ catch && stop = 1 { }
			!start { next }
			!stop { prnit; next }
			{ start = stop = 0 }
		' )
		data=$( echo "$info" | awk '
			{
				sub(/^[^[:space:]]+:/, "")
				buf = buf " " $0
			}
			END {
				gsub(/\([^)]+\)/, "", buf)
				gsub(/,/, " ", buf)
				sub(/^[[:space:]]*/, "", buf)
				sub(/[[:space:]]*$/, "", buf)
				n = split(buf, deps, /[[:space:]]+/)
				delete seen
				for (i = 1; i <= n; i++) {
					if (!((dep = deps[i]) in seen))
						print dep
					seen[dep]
				}
			}
		' )
		if [ "$deps" ]; then
			echo "$data" > "$deps"
		fi
	done | awk '!/^[[:space:]]*$/' | sort -u
}

############################################################ MAIN

#
# Process command-line options
#
while getopts aBDhIiR flag; do
	case "$flag" in
	a) IMPORT=1 ;;
	B) USEBIN=1 ;;
	D) DEBUG=1 ;;
	I) IMPORT=1 NOCLOBBER= ;;
	i) IMPORT=1 ;;
	R) REBUILD_BIN=1 ;;
	*) usage # NOTREACHED
	esac
done
shift $(( $OPTIND - 1 ))
[ $# -gt 0 ] || usage # NOTREACHED

#
# Read configuration file
#
conf_read "$1" # sets $DESTDIR, $[N]PACKAGES globals
serialize_packages # sets ${name,vers}[$n] globals
set -e # errexit

#
# Install dependencies
#
items_needed=
#	bin=someprog:pkg=somepkg \
#	file=/path/to/some_file:pkg=somepkg \
#	lib=somelib.so:pkg=somepkg \
for entry in \
	bin=make:pkg=make \
	lib=libparquet.so:pkg=apache-arrow \
	bin=vcr:pkg=vcr \
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
# OS Glue
#
case "$UNAME_p" in
i?86) UNAME_p=x86 ;;
esac
case "$( cat /etc/redhat-release )" in
"") die "Unknown linux" ;;
*" 6."*)
	LINUX=rhel6
	;;
*" 7."*)
	LINUX=rhel7
	;;
*" 8."*)
	LINUX=rhel8
	;;
*)
	die "Unknown RedHat Linux"
esac
PLATFORM=$LINUX-$UNAME_p

#
# Get R version from destination directory
#
R_VERS="${DESTDIR#/opt/R/}"
R_VERS="${R_VERS%%/*}"
BIN_REPO="$BIN_REPO/bin/$PLATFORM/contrib/$R_VERS"

#
# Create target directories
#
export R_VERS
CRAN_INSTALLDIR=$( echo "$CRAN_INSTALLDIR" | awk '{
	gsub(/%R_VERS%/, ENVIRON["R_VERS"])
	print
}' )
cran_destdir="$CRAN_INSTALLDIR/${DESTDIR#/}"
mkdir -p "$cran_destdir"
mkdir -p "$BIN_ARCHIVE"

#
# Download PACKAGES file from Artifactory binary repo
#
if [ "$USEBIN" -a "$NOCLOBBER" ]; then
	step "Download PACKAGES index"
	NOLOAD=$( eval2 curl -sLo- "${ARTIFACTORY%/}/${BIN_REPO%/}/PACKAGES" |
		awk '
			{ sub(/\r$/, "") } # Strip trailing CR from DOS format
			/^[^[:space:]:]+:/, NF < 1 && stop = 1 {
				if (sub(/:$/, "", $1)) _[$1] = $2
			}
			stop, stop-- {
				printf "%s_%s\n", _["Package"], _["Version"]
				delete _
			}
		' # END-QUOTE
	)
	echo "$NOLOAD" | awk 'END{print NR,"packages in repo"}'
fi

#
# Examine requested packages
# NB: If given `-B' (and not `-I') skip binary packages already in Artifactory
#
step "Examine requested packages"
n=0
list=
archive="${ARTIFACTORY%/}/${BIN_REPO%/}/Archive"
while [ $n -lt $NPACKAGES ]; do
	n=$(( $n + 1 ))
	eval name=\"\$name$n\"
	eval vers=\"\$vers$n\"
	case "$vers" in
	[Ll][Aa][Tt][Ee][Ss][Tt]) # latest
		cache_file="$CRAN_ARCVIVE/$name-latest.txt"
		if [ -e "$cache_file" ]; then
			vers=$( cat "$cache_file" )
			eval vers$n=\"\$vers\"
		fi
		name_vers="$name${vers:+==$vers}"
		;;
	*)
		name_vers="$name==$vers"
	esac
	if [ "$USEBIN" -a "$NOCLOBBER" ]; then
		filename="${name}_$vers"
		! echo "$NOLOAD" | matches "$filename" || continue
		! url_exists "$archive/$name/$vers/$filename.tgz" || continue
	fi
	list="$list $name_vers"
done
if [ "$USEBIN" -a "$NOCLOBBER" -a ! "$list" ]; then
	echo "All binary packages exist in Artifactory"
fi

#
# Download requested packages so we can analyze their dependencies
#
step "Download source"
if [ "$list" ]; then
	vcr-$R_VERS ${DEBUG:+-D} fetch $list
else
	echo "Nothing to do (all good)"
fi

#
# Re-examine requested packages
# NB: Only done when given `-B' (and not `-I')
#
if [ "$USEBIN" -a "$NOCLOBBER" -a "$list" ]; then
	step "Get dependencies"
	deps=$( get_deps $list )
	echo "$deps" | awk -v debug=$DEBUG '
		$0 != "" { N++; if (debug) print }
		END { printf "%u dependenc%s\n", N, N == 1 ? "y" : "ies" }
	' # END-QUOTE
	n=0
	list=
	while [ $n -lt $NPACKAGES ]; do
		n=$(( $n + 1 ))
		eval name=\"\$name$n\"
		eval vers=\"\$vers$n\"
		echo "$deps" | matches $name || continue
		list="$list $name${vers:+==$vers}"
	done
fi

#
# Install requested packages to sandbox
#
step "Install sandbox"
if [ "$USEBIN" -a "$list" ]; then
	# Try to install from binary first
	vcr-$R_VERS ${DEBUG:+-D} install -B -i -d "$cran_destdir" $list
fi
if [ "$list" ]; then
	vcr-$R_VERS ${DEBUG:+-D} install -d "$cran_destdir" $list
else
	echo "Nothing to do (all good)"
	step SUCCESS
	exit $SUCCESS
fi

#
# Get R specifics
#
R_PLATFORM=R_$( R-$R_VERS --slave --no-restore \
	-e 'cat(R.version$platform)' ) || die "Unable to determine R platform"

#
# Build binary tarballs
#
step "Building R binary packages"
patchelf=-p
case "$LINUX" in
rhel6) patchelf= ;;
esac
n=0
set -- "$cran_destdir"/*
for dir in "$@"; do
	n=$(( $n + 1 ))
	name="${dir##*/}"
	vers=$( cat "$dir/DESCRIPTION" |
		awk 'sub(/^Version:[[:space:]]*/, "") { print $1 }' )
	step2 "$name==$vers [$n/$#]"
	if [ "$USEBIN" ]; then
		url="${ARTIFACTORY%/}/${BIN_REPO%/}/${name}_$vers.tgz"
		archiveurl="${url%/*}/Archive/$name/$vers/${url##*/}"
		if url_exists "$url" || url_exists "$archiveurl"; then
			# Skip binary package creation
			echo "${url##*/} already in artifactory (skipped)"
			continue
		fi
	fi

	# Create local archive directory
	bindir="$BIN_ARCHIVE/$PLATFORM/$R_VERS"
	[ -e "$bindir" ] || eval2 mkdir -p $bindir || die
	binfile="$bindir/${name}_$vers.tgz"

	# Create binary R package and move it into the local archive directory
	if [ "$REBUILD_BIN" -o ! -e $binfile ]; then
		packfile="${name}_${vers}_$R_PLATFORM.tar.gz"
		if [ "$REBUILD_BIN" -o ! -e $packfile ]; then
			( set +e
				eval2 vcr-$R_VERS ${DEBUG:+-D} pack \
					${REBUILD_BIN:+-f} $patchelf \
					$cran_destdir/$name
				echo "EXIT:$?"
			) | awk '
				/curl/ && !/==>/
				sub(/^EXIT:/, "") { status = $0 }
				END { exit status }
			' # END-QUOTE
		fi
		eval2 mv $packfile $binfile
	fi

	# Upload from local filesystem archive to Artifactory
	if [ "$IMPORT" ]; then
		eval2 afput ${NOCLOBBER:+-n} -r "\"$BIN_REPO\"" $binfile ||
			warn "upload failed (continuing anyway)"
	fi
done

step SUCCESS
exit $SUCCESS

################################################################################
# END
################################################################################
