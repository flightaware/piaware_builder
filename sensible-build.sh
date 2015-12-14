#!/bin/bash

set -e
TOP=`dirname $0`

clone_or_update() {
  repo=$1
  branch=$2
  target=$3

  echo "Retrieving $branch from $repo"

  if [ -d $target/.git ]
  then
    (cd $target && git fetch origin)
  else
    git clone $repo $target
  fi

  (cd $target && git checkout -q --detach $branch --)
  (cd $target && git log -1 --oneline)
}

# setup:

OUTDIR=$TOP/package

mkdir -p $OUTDIR

clone_or_update https://github.com/flightaware/piaware.git v2.1-4 $OUTDIR/piaware

clone_or_update https://github.com/flightaware/tcllauncher.git 460debe4d350f06f9c7e54e5400992cac4f1d328 $OUTDIR/tcllauncher

clone_or_update https://github.com/mutability/dump1090.git faup1090-2.1-4 $OUTDIR/dump1090

clone_or_update https://github.com/mutability/mlat-client.git v0.2.4 $OUTDIR/mlat-client

# get a copy of cxfreeze and patch it for building on Debian
if [ ! -d $OUTDIR/cx_Freeze-4.3.4 ]
then
    echo "Retrieving and patching cxfreeze"
    wget -nv -O - 'https://pypi.python.org/packages/source/c/cx_Freeze/cx_Freeze-4.3.4.tar.gz#md5=5bd662af9aa36e5432e9144da51c6378' | tar -C $OUTDIR -zxf -
    patch -d $OUTDIR/cx_Freeze-4.3.4 -p1 <$TOP/sensible/cxfreeze-link-fix.patch
fi

# copy our control files
rm -fr $OUTDIR/debian
mkdir $OUTDIR/debian
cp -r \
 $TOP/changelog \
 $TOP/sensible/* \
  $OUTDIR/debian

# ok, ready to go.
echo "Ok, package is ready to be built in $OUTDIR"
echo "run 'dpkg-buildpackage -b' there (or move it to a Pi and do so there, or use pbuilder, etc)"
