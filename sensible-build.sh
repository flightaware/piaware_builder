#!/bin/bash

set -e
TOP=`dirname $0`

export DEBFULLNAME="${DEBFULLNAME:-FlightAware build automation}"
export DEBEMAIL="${DEBEMAIL:-adsb-devs@flightaware.com}"

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
  echo "syntax: $0 <stretch|buster|bullseye|xenial|bionic>" >&2
  exit 1
fi

dist="$1"
case $dist in
  stretch)
    debdist=stretch
    targetdist=stretch-backports
    extraversion="~bpo9+"
    ;;
  buster)
    debdist=buster
    targetdist=buster-backports
    extraversion="~bpo10+"
    ;;
  bullseye)
    debdist=bullseye
    targetdist=bullseye
    extraversion=""
    ;;
  xenial)
    debdist=stretch
    targetdist=xenial
    extraversion="~ubuntu1604+"
    ;;
  bionic)
    debdist=buster
    targetdist=bionic
    extraversion="~ubuntu1804+"
    ;;
  disco)
    debdist=buster
    targetdist=disco
    extraversion="~ubuntu1904+"
    ;;
  *)
    echo "unknown build distribution $1" >&2
    echo "syntax: $0 <stretch|buster|bullseye|xenial|bionic|disco>" >&2
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

clone_or_update https://github.com/flightaware/piaware.git origin/dev $OUTDIR/piaware

clone_or_update https://github.com/flightaware/tcllauncher.git v1.8 $OUTDIR/tcllauncher

clone_or_update https://github.com/flightaware/dump1090.git origin/dev $OUTDIR/dump1090

clone_or_update https://github.com/mutability/mlat-client.git v0.2.11 $OUTDIR/mlat-client

clone_or_update https://github.com/flightaware/dump978.git origin/dev $OUTDIR/dump978

# get a copy of cxfreeze and patch it for building on Debian
case $debdist in
    stretch)
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
            wget -nv -O - 'https://github.com/anthony-tuininga/cx_Freeze/archive/6.0.tar.gz' | tar -C $OUTDIR -zxf -
        fi
        ;;
    bullseye)
        if [ ! -d $OUTDIR/cx_Freeze-6.8 ]
        then
            echo "Retrieving cxfreeze"
            wget -nv -O - 'https://github.com/anthony-tuininga/cx_Freeze/archive/6.8.tar.gz' | tar -C $OUTDIR -zxf -
        fi
        ;;
esac

# copy our control files
rm -fr $OUTDIR/debian
mkdir $OUTDIR/debian
cp -r \
 $TOP/changelog \
 $TOP/common/* \
 $TOP/$debdist/* \
  $OUTDIR/debian

# copy over the init.d / systemd files from the piaware source
cp $OUTDIR/piaware/scripts/piaware-rc-script $OUTDIR/debian/piaware.init
cp $OUTDIR/piaware/scripts/piaware.service $OUTDIR/debian/piaware.piaware.service
cp $OUTDIR/piaware/scripts/generate-pirehose-cert.service $OUTDIR/debian/piaware.generate-pirehose-cert.service

if [ -n "$extraversion" ]
then
    echo "Updating changelog for $targetdist build"
    dch --changelog $OUTDIR/debian/changelog --local "$extraversion" --distribution "$targetdist" --force-distribution "Automated backport build via piaware_builder"
fi

# ok, ready to go.
echo "Ok, package is ready to be built in $OUTDIR"
echo "run 'dpkg-buildpackage -b' there (or move it to a Pi and do so there, or use pbuilder, etc)"
