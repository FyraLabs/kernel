#!/usr/bin/bash

[ -z "${RHDISTDATADIR}" ] && echo "ERROR: RHDISTDATADIR undefined." && exit 1

# This script generates 'dist-dump-variables' output for various configurations
# using known ark commit IDs.  It uses this information as well as setting
# different values for DISTRO and DIST.
#
# The ark commit IDs are
#
#    78e36f3b0dae := 5.17.0 merge window (5.16 + additional changes before -rc1)
#    2585cf9dfaad := 5.16-rc5
#    df0cc57e057f := 5.16
#    fce15c45d3fb := 5.16 + 2 additional commits
#

for DISTRO in fedora rhel centos
do
	for commit in 78e36f3b0dae 2585cf9dfaad df0cc57e057f fce15c45d3fb
	do
		for DIST in .fc25 .el7
		do
			varfilename="${RHDISTDATADIR}/${DISTRO}-${commit}${DIST}"
			# Have to unset environment variables that may be inherited from supra-make:
			make dist-dump-variables | grep "=" | cut -d"=" -f1 | while read VAR; do unset "$VAR"; done
			echo "building $varfilename"
			# CURDIR is a make special target and cannot be easily changed.
			# Omit it from the output.
			make RHSELFTESTDATA=1 DIST="${DIST}" DISTRO="${DISTRO}" HEAD=${commit} dist-dump-variables | grep "=" | grep -v CURDIR >& ${varfilename}
		done
	done
done

exit 0
