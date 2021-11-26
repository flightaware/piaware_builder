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
  echo "syntax: $0 <stretch|buster|bullseye|xenial|bionic|disco>" >&2
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
mkdir -p $OUTDIR/archives

clone_or_update https://github.com/flightaware/piaware.git origin/dev $OUTDIR/piaware

clone_or_update https://github.com/flightaware/tcllauncher.git v1.8 $OUTDIR/tcllauncher

clone_or_update https://github.com/flightaware/dump1090.git origin/dev $OUTDIR/dump1090

clone_or_update https://github.com/mutability/mlat-client.git v0.2.11 $OUTDIR/mlat-client

clone_or_update https://github.com/flightaware/dump978.git origin/dev $OUTDIR/dump978

fetch_archive() {
    name=$1
    url=$2
    hash=$3

    if [ ! -f $OUTDIR/$name.tar.gz ]; then
        echo "Fetching $name .."
        wget -nv -O $OUTDIR/archives/$name.tar.gz.unchecked $url
        echo "$hash $OUTDIR/archives/$name.tar.gz.unchecked" | sha256sum -c -
        mv $OUTDIR/archives/$name.tar.gz.unchecked $OUTDIR/archives/$name.tar.gz
    fi

    tar -C $OUTDIR -zxf $OUTDIR/archives/$name.tar.gz $name/
}

# get a copy of cxfreeze and patch it for building on Debian
case $debdist in
    stretch)
        # stretch has Python 3.5; cx-freeze 6.3 is the latest version supporting Python 3.5
        fetch_archive cx_Freeze-6.3 https://github.com/anthony-tuininga/cx_Freeze/archive/6.3.tar.gz ac6212e44e072869de5153dd81e5d1c369b2ef73e75ed58cbb81ab59b4eaf6e1
        ;;
    buster|bullseye)
        # Buster has Python 3.7, Bullseye has Python 3.9; both are supported by the latest cx-freeze at the time of writing (6.8)
        fetch_archive more-itertools-8.12.0 https://github.com/more-itertools/more-itertools/archive/refs/tags/v8.12.0.tar.gz b708a64c95508d4f1fef137acbe3b482b6a95d0cd1b54400c50534cb0ae05923
        fetch_archive zipp-3.6.0 https://github.com/jaraco/zipp/archive/refs/tags/v3.6.0.tar.gz fd1af7ebc49a73dd0cd35f31d44a28022566e5114bdef64129fab0d9dc524486
        fetch_archive importlib_metadata-4.8.2 https://github.com/python/importlib_metadata/archive/refs/tags/v4.8.2.tar.gz d490678f0f37b0508571fda77e37542898acfa20c8716cff349d357ecb781dcd
        fetch_archive cx_Freeze-6.8.3 https://github.com/anthony-tuininga/cx_Freeze/archive/6.8.3.tar.gz d39c59fdfc82106dfe1e5dce09f2537a3cc82dc8295024f40f639d94193979c3
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
