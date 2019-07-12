#!/bin/sh
if [ ! "$1" -o $# -ne 1 ]; then
	echo "Usage: ${0##*/} /path/to/R-X.Y.Z" >&2
	exit 1
fi
awk '
	/^Version:/ {
		vers = $NF
		name = FILENAME
		sub("/[^/]*$", "", name)
		gsub(".*/", "", name)
		print name, vers
		nextfile
	}
' "$1"/lib64/R/library/*/DESCRIPTION | sort
