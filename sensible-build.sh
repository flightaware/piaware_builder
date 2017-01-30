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
  (cd $target && git --no-pager log -1 --oneline)
}

# setup:

if [ $# -lt 1 ]
then
  echo "syntax: $0 <wheezy|jessie>" >&2
  exit 1
fi

case $1 in
  wheezy|jessie) dist=$1 ;;
  *)
    echo "unknown build distribution $1" >&2
    echo "syntax: $0 <wheezy|jessie>" >&2
    exit 1
    ;;
esac


OUTDIR=$TOP/package-$dist

mkdir -p $OUTDIR

clone_or_update https://github.com/flightaware/piaware.git origin/dev $OUTDIR/piaware

clone_or_update https://github.com/flightaware/tcllauncher.git 460debe4d350f06f9c7e54e5400992cac4f1d328 $OUTDIR/tcllauncher

clone_or_update https://github.com/flightaware/dump1090.git origin/dev $OUTDIR/dump1090

clone_or_update https://github.com/mutability/mlat-client.git origin/dev $OUTDIR/mlat-client

# get a copy of cxfreeze and patch it for building on Debian
if [ ! -d $OUTDIR/cx_Freeze-4.3.4 ]
then
    echo "Retrieving and patching cxfreeze"
    wget -nv -O - 'https://pypi.python.org/packages/source/c/cx_Freeze/cx_Freeze-4.3.4.tar.gz#md5=5bd662af9aa36e5432e9144da51c6378' | tar -C $OUTDIR -zxf -
    patch -d $OUTDIR/cx_Freeze-4.3.4 -p1 <$TOP/common/cxfreeze-link-fix.patch
    patch -d $OUTDIR/cx_Freeze-4.3.4 -p1 <$TOP/common/cxfreeze-python35-fix.patch
fi

# copy our control files
rm -fr $OUTDIR/debian
mkdir $OUTDIR/debian
cp -r \
 $TOP/changelog \
 $TOP/common/* \
 $TOP/$dist/* \
  $OUTDIR/debian

# copy over the init.d / systemd files from the piaware source
cp $OUTDIR/piaware/scripts/piaware-rc-script $OUTDIR/debian/piaware.init
cp $OUTDIR/piaware/scripts/piaware.service $OUTDIR/debian/piaware.service

case $dist in
  wheezy)
    echo "Updating changelog for wheezy backport build"
    dch --changelog $OUTDIR/debian/changelog --bpo --distribution wheezy-backports "Automated backport build via piaware_builder"
    ;;
  jessie)
    ;;
  *)
    echo "You should fix the script so it knows about a distribution of $dist" >&2
    ;;
esac

# ok, ready to go.
echo "Ok, package is ready to be built in $OUTDIR"
echo "run 'dpkg-buildpackage -b' there (or move it to a Pi and do so there, or use pbuilder, etc)"
