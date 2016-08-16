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

clone_or_update https://github.com/flightaware/dump1090.git v3.0.3 $OUTDIR/dump1090

clone_or_update https://github.com/mutability/mlat-client.git v0.2.6 $OUTDIR/mlat-client

# get a copy of cxfreeze and patch it for building on Debian
if [ ! -d $OUTDIR/cx_freeze ]
then
    CXFREEZEHASH=adb1d5716a84
    echo "Retrieving cxfreeze at hash $CXFREEZEHASH"
    wget -nv -O $OUTDIR/cx_freeze.zip https://bitbucket.org/anthony_tuininga/cx_freeze/get/$CXFREEZEHASH.zip
    unzip -d $OUTDIR $OUTDIR/cx_freeze.zip
    mv $OUTDIR/anthony_tuininga-cx_freeze-$CXFREEZEHASH $OUTDIR/cx_freeze
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
