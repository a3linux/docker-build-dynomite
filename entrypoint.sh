#!/bin/bash
set -e
# 
# The dynomite build container performs the following actions:
# 1. Checkout repo
# 2. Compile binary
# 3. Package binary in .tgz
#
# Options:
# -v: tag version
# -d: debug
# -t <target>: add a make target
#

BUILD=/build/dynomite

# Reset getopts option index
OPTIND=1

# If set, then build a specific tag version. If unset, then build dev branch
version="dev"
fake_version="0.0.0"
# If the -d flag is set then create a debug build of dynomite
mode="production"
# Additional make target
target=""

while getopts "v:F:d:t:" opt; do
    case "$opt" in
    v)  version=$OPTARG
	;;
    d)  mode=$OPTARG
        ;;
    t)  target=$OPTARG
        ;;
    esac
done

#
# Get the source code
#
mkdir -p $BUILD
git clone https://github.com/Netflix/dynomite.git
cd $BUILD
if [ "$version" != "dev" ] ; then
	echo "Building tagged version:  $version"
	git checkout tags/$version
else
	echo "Building branch: $version"
fi

autoreconf -fvi

if [ "$mode" == "debug" ] ; then
    CFLAGS="-ggdb3 -O0" ./configure --enable-debug=full
elif [ "$mode" == "log" ] || [ "$mode" == "production" ] ; then
    ./configure --enable-debug=log
else
    ./configure --enable-debug=no
fi

# Default target == ""
make $target

# Create package
mkdir -p /src/dynomite-binary

# Binaries
for b in "dynomite" "dynomite-test"
do
	cp $BUILD/src/$b /src/dynomite-binary/
	if [ "$mode" == "production" ] ; then
		cp /src/dynomite-binary/$b /src/dynomite-binary/${b}-debug
		strip --strip-debug --strip-unneeded /src/dynomite-binary/$b
	fi
done

cp $BUILD/src/tools/dynomite-hash-tool /src/dynomite-binary/
if [ "$mode" == "production" ] ; then
	cp /src/dynomite-binary/dynomite-hash-tool /src/dynomite-binary/dynomite-hash-tool-debug
	strip --strip-debug --strip-unneeded  /src/dynomite-binary/dynomite-hash-tool
fi

# Static files
for s in "README.md" "LICENSE" "NOTICE"
do
	cp $BUILD/$s /src/dynomite-binary/
done

# Configuration files
cp -R $BUILD/conf /src/dynomite-binary/

#
# Create .tgz package
#
cd /src
rm -f dynomite_ubuntu-18.04-x64.tgz
tar -czf dynomite_ubuntu-18.04-x64.tgz -C /src dynomite-binary/
