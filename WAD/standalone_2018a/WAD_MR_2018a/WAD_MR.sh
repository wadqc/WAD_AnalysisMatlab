#!/bin/bash
# wrapper script for MATLAB compiled WAD analysis modules
moduleExe="for_redistribution_files_only/WAD_MR_mcr94_x64.exe"

# MCR version
MCRVERSION="v94"

# WAD recommended installation location
MCRROOT_WAD="$HOME/MATLAB_Runtime"

# default installation location
MCRROOT_DEFAULT="/usr/local/MATLAB/MATLAB_Runtime"


echo 'Starting' $0 'MCR wrapper script'
echo 'Check for Matlab runtime engine in home directory:' $HOME
if [ -d $MCRROOT_WAD/$MCRVERSION ] ; then
    MCRROOT=$MCRROOT_WAD
elif [ -d $MCRROOT_DEFAULT/$MCRVERSION ] ; then
    MCRROOT=$MCRROOT_DEFAULT
else
    echo 'ERROR: Matlab Runtime engine not found.'
    echo 'Download version' $MCRVERSION 'from http://www.mathworks.com/products/compiler/mcr/index.html'
    echo 'and install in' $MCRROOT_WAD 'or in' $MCRROOT_DEFAULT
    exit 1
fi

echo 'Matlab runtime engine found:' $MCRROOT/$MCRVERSION

# set library path for MCR
LD_LIBRARY_PATH=$MCRROOT/$MCRVERSION/runtime/glnxa64:$MCRROOT/$MCRVERSION/bin/glnxa64:$MCRROOT/$MCRVERSION/sys/os/glnxa64:$MCRROOT/$MCRVERSION/extern/bin/glnxa64:${LD_LIBRARY_PATH} 
export LD_LIBRARY_PATH;

# full path to exe
myPath=`dirname "$0"`

# make sure the module exe is executable
chmod +x "$myPath/$moduleExe"

# start exe
"$myPath/$moduleExe" "$@"
