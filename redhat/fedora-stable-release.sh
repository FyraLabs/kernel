#!/bin/bash

releasenum=$1

if [ -z "$releasenum" ]; then
	releasenum="0"
fi

ApplyPatches="0"

for release in $( cat redhat/release_targets );  do 
	case "$release" in
	36) build=20$releasenum
	    ;;
	35) build=10$releasenum
	    ApplyPatches="1"	
	    ;;
	esac
	if [[ $ApplyPatches == "1" ]] ; then
		for patch in redhat/patches/* ; do patch -p1 < $patch ; done
	fi
	RHJOBS=24 make IS_FEDORA=1 DIST=".fc$release" BUILDID="" BUILD=$build RHDISTGIT_BRANCH=f$release dist-git;
	sleep 60;
	git checkout .
done
