#!/bin/bash

set -e
TOP=`dirname $0`

export DEBFULLNAME="${DEBFULLNAME:-FlightAware build automation}"
export DEBEMAIL="${DEBEMAIL:-adsb-devs@flightaware.com}"

shallow_clone() {
  repo=$1
  branch=$2
  target=$3

  echo "Retrieving $branch from $repo"
  rm -fr $target
  git clone -c advice.detachedHead=false --depth=1 --branch $branch $repo $target
  (cd $target && git checkout --detach $branch)
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

shallow_clone https://github.com/flightaware/piaware.git dev $OUTDIR/piaware

shallow_clone https://github.com/flightaware/tcllauncher.git v1.8 $OUTDIR/tcllauncher

shallow_clone https://github.com/flightaware/dump1090.git dev $OUTDIR/dump1090

shallow_clone https://github.com/mutability/mlat-client.git v0.2.11 $OUTDIR/mlat-client

shallow_clone https://github.com/flightaware/dump978.git dev $OUTDIR/dump978

fetch_archive() {
    name=$1
    url=$2
    hash=$3

    if [ ! -f $OUTDIR/archives/$name.tar.gz ]; then
        echo "Fetching $name .."
        wget -nv -O $OUTDIR/archives/$name.tar.gz.unchecked --prefer-family=IPv4 --connect-timeout=30 $url
        echo "$hash $OUTDIR/archives/$name.tar.gz.unchecked" | sha256sum -c -
        mv $OUTDIR/archives/$name.tar.gz.unchecked $OUTDIR/archives/$name.tar.gz
    fi

    rm -fr $OUTDIR/$name/
    tar -C $OUTDIR -zxf $OUTDIR/archives/$name.tar.gz $name/
}

# get cxfreeze version and dependencies matching the system python version
# this is a bit of a nightmare due to interactions between Debian / venv / pip / setuptools et al
# the simplest approach seems to be:
#   - use a venv with system site packages and no pip
#   - install packages via setup.py; patch setup.cfg on some packages so that the version is set,
#     as we're missing the metadata stuff that pip will do via setuptools_scm

# all versions need importlib_metadata updated, and transitively zipp needs installing too
fetch_archive importlib_metadata-4.3.1 \
              https://files.pythonhosted.org/packages/a4/8b/1d63614ef7ced52a7da2d40753968c40a4bbc14fd9c0ba85d612b44ffd9a/importlib_metadata-4.3.1.tar.gz \
              2d932ea08814f745863fd20172fe7de4794ad74567db78f2377343e24520a5b6

patch $OUTDIR/importlib_metadata-4.3.1/setup.cfg <<EOF
--- importlib_metadata-4.3.1/setup.cfg.orig	2021-11-29 05:18:24.378089233 +0000
+++ importlib_metadata-4.3.1/setup.cfg	2021-11-29 05:18:31.548214419 +0000
@@ -1,4 +1,5 @@
 [metadata]
+version = 4.3.1
 license_files = 
 	LICENSE
 name = importlib_metadata
EOF

fetch_archive zipp-0.5.0 \
              https://files.pythonhosted.org/packages/44/65/799bbac4c284c93ce9cbe67956a3625a4e1941d580832656bea202554117/zipp-0.5.0.tar.gz \
              d7ac25f895fb65bff937b381353c14eb1fa23d35f40abd72a5342cd57eb57fd1
patch -d $OUTDIR/zipp-0.5.0 -p1 <<EOF
diff -ur zipp-0.5.0/setup.cfg zipp-0.5.0.new/setup.cfg
--- zipp-0.5.0/setup.cfg	2019-05-09 02:41:39.000000000 +0800
+++ zipp-0.5.0.new/setup.cfg	2021-11-29 14:13:17.238423388 +0800
@@ -2,6 +2,7 @@
 universal = 1
 
 [metadata]
+version = 0.5.0
 license_file = LICENSE
 name = zipp
 author = Jason R. Coombs
@@ -22,7 +23,6 @@
 include_package_data = true
 python_requires = >=2.7
 install_requires = 
-setup_requires = setuptools_scm >= 1.15.0
 
 [options.extras_require]
 testing = 
diff -ur zipp-0.5.0/setup.py zipp-0.5.0.new/setup.py
--- zipp-0.5.0/setup.py	2019-05-09 02:41:19.000000000 +0800
+++ zipp-0.5.0.new/setup.py	2021-11-29 14:11:14.026908611 +0800
@@ -3,4 +3,4 @@
 import setuptools
 
 if __name__ == "__main__":
-    setuptools.setup(use_scm_version=True)
+    setuptools.setup()
EOF

case $debdist in
    stretch)
        # stretch has Python 3.5; cx-freeze 6.3 is the last version supporting Python 3.5
        # typing_extensions need updating on python <3.8
        fetch_archive typing_extensions-3.6.5 \
                      https://files.pythonhosted.org/packages/a9/b0/c98f86c94706784699bff1262506ceab6e8101386e984a773b10be7500fc/typing_extensions-3.6.5.tar.gz \
                      1c0a8e3b4ce55207a03dd0dcb98bc47a704c71f14fe4311ec860cc8af8f4bd27
        fetch_archive cx_Freeze-6.3 \
                      https://github.com/anthony-tuininga/cx_Freeze/archive/6.3.tar.gz \
                      ac6212e44e072869de5153dd81e5d1c369b2ef73e75ed58cbb81ab59b4eaf6e1
        ;;
    buster)
        # Buster has Python 3.7; cx_Freeze 6.8.3 supports this
        # typing_extensions need updating on python <3.8
        fetch_archive typing_extensions-3.6.5 \
                      https://files.pythonhosted.org/packages/a9/b0/c98f86c94706784699bff1262506ceab6e8101386e984a773b10be7500fc/typing_extensions-3.6.5.tar.gz \
                      1c0a8e3b4ce55207a03dd0dcb98bc47a704c71f14fe4311ec860cc8af8f4bd27
        fetch_archive cx_Freeze-6.8.3 \
                      https://github.com/anthony-tuininga/cx_Freeze/archive/6.8.3.tar.gz \
                      d39c59fdfc82106dfe1e5dce09f2537a3cc82dc8295024f40f639d94193979c3
        ;;

    bullseye)
        # Bullseye has Python 3.9; cx_Freeze 6.8.3 will support this
        # only importlib_metadata needs updating, no other dependencies
        fetch_archive cx_Freeze-6.8.3 \
                      https://github.com/anthony-tuininga/cx_Freeze/archive/6.8.3.tar.gz \
                      d39c59fdfc82106dfe1e5dce09f2537a3cc82dc8295024f40f639d94193979c3
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
echo "run 'dpkg-buildpackage -b --no-sign' there (or move it to a Pi and do so there, or use pbuilder, etc)"
