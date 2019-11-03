#!/bin/bash

set -e
TOP=`dirname $0`

export DEBFULLNAME=${DEBFULLNAME:-FlightAware build automation}
export DEBEMAIL=${DEBEMAIL:-adsb-devs@flightaware.com}

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
  echo "syntax: $0 <wheezy|jessie|stretch|xenial|bionic|buster>" >&2
  exit 1
fi

case $1 in
  wheezy|jessie|stretch|xenial|bionic|buster) dist=$1 ;;
  *)
    echo "unknown build distribution $1" >&2
    echo "syntax: $0 <wheezy|jessie|stretch|xenial|bionic|buster>" >&2
    exit 1
    ;;
esac

if [ -z "$2" ]
then
  OUTDIR=$TOP/package-$dist
else
  OUTDIR="$2"
fi

mkdir -p $OUTDIR

clone_or_update https://github.com/flightaware/piaware.git v3.7.2 $OUTDIR/piaware

clone_or_update https://github.com/flightaware/tcllauncher.git v1.8 $OUTDIR/tcllauncher

clone_or_update https://github.com/flightaware/dump1090.git v3.7.2 $OUTDIR/dump1090

clone_or_update https://github.com/mutability/mlat-client.git v0.2.10 $OUTDIR/mlat-client

clone_or_update https://github.com/flightaware/dump978.git v3.7.2 $OUTDIR/dump978

# get a copy of cxfreeze and patch it for building on Debian
case $dist in
    wheezy|jessie)
        if [ ! -d $OUTDIR/cx_Freeze-4.3.4 ]
        then
            echo "Retrieving and patching cxfreeze"
            wget -nv -O - 'https://pypi.python.org/packages/source/c/cx_Freeze/cx_Freeze-4.3.4.tar.gz#md5=5bd662af9aa36e5432e9144da51c6378' | tar -C $OUTDIR -zxf -
            patch -d $OUTDIR/cx_Freeze-4.3.4 -p1 <$TOP/common/cxfreeze-link-fix.patch
            patch -d $OUTDIR/cx_Freeze-4.3.4 -p1 <$TOP/common/cxfreeze-python35-fix.patch
        fi
        ;;

    stretch|xenial|bionic)
        if [ ! -d $OUTDIR/cx_Freeze-5.1.1 ]
        then
            echo "Retrieving cxfreeze"
            wget -nv -O - 'https://files.pythonhosted.org/packages/5f/16/eab51d6571dfec2554248cb027c51babd04d97f594ab6359e0707361297d/cx_Freeze-5.1.1.tar.gz' | tar -C $OUTDIR -zxf -
        fi
        ;;
    buster)
        if [ ! -d $OUTDIR/cx_Freeze-6.0 ]
        then
            echo "Retrieving cxfreeze"
            wget -nv -O - 'https://files.pythonhosted.org/packages/14/74/a76c12e4e357c79999191d5db259e66b46c57708515395c023d38e6bbbd7/cx_Freeze-6.0.tar.gz' | tar -C $OUTDIR -zxf -
        fi
        ;;
esac

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
cp $OUTDIR/piaware/scripts/piaware.service $OUTDIR/debian/piaware.piaware.service
cp $OUTDIR/piaware/scripts/generate-pirehose-cert.service $OUTDIR/debian/piaware.generate-pirehose-cert.service

case $dist in
  wheezy)
    echo "Updating changelog for wheezy backport build"
    dch --changelog $OUTDIR/debian/changelog --local ~bpo7+ --distribution wheezy-backports --force-distribution "Automated backport build via piaware_builder"
    ;;
  jessie)
    echo "Updating changelog for jessie backport build"
    dch --changelog $OUTDIR/debian/changelog --local ~bpo8+ --distribution jessie-backports --force-distribution "Automated backport build via piaware_builder"
    ;;
  stretch|buster)
    ;;
  xenial)
    echo "Updating changelog for xenial (16.04) build"
    dch --changelog $OUTDIR/debian/changelog --local ~ubuntu1604+ --distribution xenial --force-distribution "Automated build via piaware_builder"
    ;;
  bionic)
    echo "Updating changelog for bionic (18.04) build"
    dch --changelog $OUTDIR/debian/changelog --local ~ubuntu1804+ --distribution bionic --force-distribution "Automated build via piaware_builder"
    ;;
  *)
    echo "You should fix the script so it knows about a distribution of $dist" >&2
    ;;
esac

# ok, ready to go.
echo "Ok, package is ready to be built in $OUTDIR"
echo "run 'dpkg-buildpackage -b' there (or move it to a Pi and do so there, or use pbuilder, etc)"
