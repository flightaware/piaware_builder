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

usage() {
  echo "syntax: $0 <buster|bullseye|bookworm>" >&2
  exit 1
}

# setup:

if [ $# -lt 1 ]
then
  usage
fi

dist="$1"
case $dist in
  stretch)
    # EOL, not tested
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
    extraversion="~bpo11+"
    ;;
  bookworm)
    debdist=bookworm
    targetdist=bookworm
    extraversion=""
    ;;
  pixie)
    debdist=pixie
    targetdist=pixie
    extraversion=""
    ;;
  xenial)
    # not tested
    debdist=stretch
    targetdist=xenial
    extraversion="~ubuntu1604+"
    ;;
  bionic)
    # not tested
    debdist=buster
    targetdist=bionic
    extraversion="~ubuntu1804+"
    ;;
  disco)
    # not tested
    debdist=buster
    targetdist=disco
    extraversion="~ubuntu1904+"
    ;;
  noble)
    # not tested
    debdist=pixie
    targetdist=noble
    extraversion="~ubuntu2404+"
    ;;
  *)
    echo "unknown build distribution $1" >&2
    usage
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

shallow_clone https://github.com/flightaware/piaware.git v9.0.1 $OUTDIR/piaware

shallow_clone https://github.com/flightaware/tcllauncher.git v1.10 $OUTDIR/tcllauncher

shallow_clone https://github.com/flightaware/dump1090.git v9.0 $OUTDIR/dump1090

shallow_clone https://github.com/mutability/mlat-client.git v0.2.13 $OUTDIR/mlat-client

shallow_clone https://github.com/flightaware/dump978.git v9.0 $OUTDIR/dump978

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
    if [ -f $TOP/$name.patch ]; then
        echo "applying $name.patch .."
        patch -d $OUTDIR/$name -p1 <$TOP/$name.patch
    fi
}

# get cxfreeze version and dependencies matching the system python version
# this is a bit of a nightmare due to interactions between Debian / venv / pip / setuptools et al
# the simplest approach seems to be:
#   - use a venv with system site packages and no pip
#   - install packages via setup.py; patch setup.cfg on some packages so that the version is set,
#     as we're missing the metadata stuff that pip will do via setuptools_scm

case $debdist in
    stretch)
        # stretch has Python 3.5; cx-freeze 6.3 is the last version supporting Python 3.5
        fetch_archive importlib_metadata-2.1.2 \
                      https://files.pythonhosted.org/packages/6a/3d/21c1170a955a3ae8f5cdec1d89c57d3b146ed0436b25b83e98917af5fe18/importlib_metadata-2.1.2.tar.gz \
                      09db40742204610ef6826af16e49f0479d11d0d54687d0169ff7fddf8b3f557f
        fetch_archive zipp-0.5.0 \
                      https://files.pythonhosted.org/packages/44/65/799bbac4c284c93ce9cbe67956a3625a4e1941d580832656bea202554117/zipp-0.5.0.tar.gz \
                      d7ac25f895fb65bff937b381353c14eb1fa23d35f40abd72a5342cd57eb57fd1
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
        fetch_archive importlib_metadata-4.3.1 \
                      https://files.pythonhosted.org/packages/a4/8b/1d63614ef7ced52a7da2d40753968c40a4bbc14fd9c0ba85d612b44ffd9a/importlib_metadata-4.3.1.tar.gz \
                      2d932ea08814f745863fd20172fe7de4794ad74567db78f2377343e24520a5b6
        fetch_archive zipp-0.5.0 \
                      https://files.pythonhosted.org/packages/44/65/799bbac4c284c93ce9cbe67956a3625a4e1941d580832656bea202554117/zipp-0.5.0.tar.gz \
                      d7ac25f895fb65bff937b381353c14eb1fa23d35f40abd72a5342cd57eb57fd1
        fetch_archive cx_Freeze-6.8.3 \
                      https://github.com/anthony-tuininga/cx_Freeze/archive/6.8.3.tar.gz \
                      d39c59fdfc82106dfe1e5dce09f2537a3cc82dc8295024f40f639d94193979c3
        ;;

    bullseye)
        # Bullseye has Python 3.9; cx_Freeze 6.8.3 supports this
        fetch_archive importlib_metadata-4.3.1 \
                      https://files.pythonhosted.org/packages/a4/8b/1d63614ef7ced52a7da2d40753968c40a4bbc14fd9c0ba85d612b44ffd9a/importlib_metadata-4.3.1.tar.gz \
                      2d932ea08814f745863fd20172fe7de4794ad74567db78f2377343e24520a5b6
        fetch_archive zipp-0.5.0 \
                      https://files.pythonhosted.org/packages/44/65/799bbac4c284c93ce9cbe67956a3625a4e1941d580832656bea202554117/zipp-0.5.0.tar.gz \
                      d7ac25f895fb65bff937b381353c14eb1fa23d35f40abd72a5342cd57eb57fd1
        fetch_archive cx_Freeze-6.8.3 \
                      https://github.com/anthony-tuininga/cx_Freeze/archive/6.8.3.tar.gz \
                      d39c59fdfc82106dfe1e5dce09f2537a3cc82dc8295024f40f639d94193979c3
        ;;

    bookworm)
        fetch_archive cx_Freeze-6.15.9 \
                      https://github.com/marcelotduarte/cx_Freeze/archive/refs/tags/6.15.9.tar.gz \
                      d32b309b355f2b377dae585a839e39e3251b3f9716f2b4983be92972c2863000
        ;;

    pixie)
        fetch_archive setuptools_scm-8.1.0 \
                      https://files.pythonhosted.org/packages/4f/a4/00a9ac1b555294710d4a68d2ce8dfdf39d72aa4d769a7395d05218d88a42/setuptools_scm-8.1.0.tar.gz \
                      42dea1b65771cba93b7a515d65a65d8246e560768a66b9106a592c8e7f26c8a7
        fetch_archive trove_classifiers-2024.7.2 \
                      https://files.pythonhosted.org/packages/78/c9/83f915c3f6f94f4c862c7470284fd714f312cce8e3cf98361312bc02493d/trove_classifiers-2024.7.2.tar.gz \
                      8328f2ac2ce3fd773cbb37c765a0ed7a83f89dc564c7d452f039b69249d0ac35
        fetch_archive pluggy-1.5.0 \
                      https://files.pythonhosted.org/packages/96/2d/02d4312c973c6050a18b314a5ad0b3210edb65a906f868e31c111dede4a6/pluggy-1.5.0.tar.gz \
                      2cffa88e94fdc978c4c574f15f9e59b7f4201d439195c3715ca9e2486f1d0cf1
        fetch_archive flit_core-3.9.0 \
                      https://files.pythonhosted.org/packages/c4/e6/c1ac50fe3eebb38a155155711e6e864e254ce4b6e17fe2429b4c4d5b9e80/flit_core-3.9.0.tar.gz \
                      72ad266176c4a3fcfab5f2930d76896059851240570ce9a98733b658cb786eba
        fetch_archive pathspec-0.12.1 \
                      https://files.pythonhosted.org/packages/ca/bc/f35b8446f4531a7cb215605d100cd88b7ac6f44ab3fc94870c120ab3adbf/pathspec-0.12.1.tar.gz \
                      a482d51503a1ab33b1c67a6c3813a26953dbdc71c31dacaef9a838c4e29f5712
        fetch_archive hatchling-1.25.0 \
                      https://files.pythonhosted.org/packages/a3/51/8a4a67a8174ce59cf49e816e38e9502900aea9b4af672d0127df8e10d3b0/hatchling-1.25.0.tar.gz \
                      7064631a512610b52250a4d3ff1bd81551d6d1431c4eb7b72e734df6c74f4262
        fetch_archive hatch_vcs-0.4.0 \
                      https://files.pythonhosted.org/packages/f5/c9/54bb4fa27b4e4a014ef3bb17710cdf692b3aa2cbc7953da885f1bf7e06ea/hatch_vcs-0.4.0.tar.gz \
                      093810748fe01db0d451fabcf2c1ac2688caefd232d4ede967090b1c1b07d9f7
        fetch_archive filelock-3.15.4 \
                      https://files.pythonhosted.org/packages/08/dd/49e06f09b6645156550fb9aee9cc1e59aba7efbc972d665a1bd6ae0435d4/filelock-3.15.4.tar.gz \
                      2207938cbc1844345cb01a5a95524dae30f0ce089eba5b00378295a17e3e90cb
        fetch_archive cx_freeze-7.2.0 \
                      https://files.pythonhosted.org/packages/6e/23/6947cd90cfe87712099fbeab2061309ab1d2a95d54f3453cb6bb21b00034/cx_freeze-7.2.0.tar.gz \
                      c57f7101b4d35132464b1ec88cb8948c3b7c5b4ece4bb354c16091589cb33583
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
