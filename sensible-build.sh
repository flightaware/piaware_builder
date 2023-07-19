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
  echo "syntax: $0 <stretch|buster|bullseye|bookworm|xenial|bionic|disco>" >&2
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
  bookworm)
    debdist=bookworm
    targetdist=bookworm
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
    echo "syntax: $0 <stretch|buster|bullseye|bookworm|xenial|bionic|disco>" >&2
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

shallow_clone https://github.com/flightaware/piaware.git v8.2 $OUTDIR/piaware

shallow_clone https://github.com/flightaware/tcllauncher.git v1.8 $OUTDIR/tcllauncher

shallow_clone https://github.com/flightaware/dump1090.git v8.2 $OUTDIR/dump1090

shallow_clone https://github.com/mutability/mlat-client.git v0.2.13 $OUTDIR/mlat-client

shallow_clone https://github.com/flightaware/dump978.git v8.2 $OUTDIR/dump978

fetch_archive() {
    name=$1
    url=$2
    hash=$3

    if [ ! -f $OUTDIR/archives/$name.tar.gz ]; then
        echo "Fetching $name .."
        wget -nv -O $OUTDIR/archives/$name.tar.gz.unchecked --connect-timeout=30 $url
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
        # Bookworm has Python 3.11; cx_Freeze 6.15.4 supports this
        fetch_archive flit_core-3.9.0 \
                      https://files.pythonhosted.org/packages/c4/e6/c1ac50fe3eebb38a155155711e6e864e254ce4b6e17fe2429b4c4d5b9e80/flit_core-3.9.0.tar.gz \
                      72ad266176c4a3fcfab5f2930d76896059851240570ce9a98733b658cb786eba
        fetch_archive wheel-0.40.0 \
                      https://files.pythonhosted.org/packages/fc/ef/0335f7217dd1e8096a9e8383e1d472aa14717878ffe07c4772e68b6e8735/wheel-0.40.0.tar.gz \
                      cd1196f3faee2b31968d626e1731c94f99cbdb67cf5a46e4f5656cbee7738873
        fetch_archive setuptools-68.0.0 \
                      https://files.pythonhosted.org/packages/dc/98/5f896af066c128669229ff1aa81553ac14cfb3e5e74b6b44594132b8540e/setuptools-68.0.0.tar.gz \
                      baf1fdb41c6da4cd2eae722e135500da913332ab3f2f5c7d33af9b492acb5235
        fetch_archive setuptools_scm-7.1.0 \
                      https://files.pythonhosted.org/packages/98/12/2c1e579bb968759fc512391473340d0661b1a8c96a59fb7c65b02eec1321/setuptools_scm-7.1.0.tar.gz \
                      6c508345a771aad7d56ebff0e70628bf2b0ec7573762be9960214730de278f27
        fetch_archive packaging-23.1 \
                      https://files.pythonhosted.org/packages/b9/6c/7c6658d258d7971c5eb0d9b69fa9265879ec9a9158031206d47800ae2213/packaging-23.1.tar.gz \
                      a392980d2b6cffa644431898be54b0045151319d1e7ec34f0cfed48767dd334f
        fetch_archive typing_extensions-4.7.1 \
                      https://files.pythonhosted.org/packages/3c/8b/0111dd7d6c1478bf83baa1cab85c686426c7a6274119aceb2bd9d35395ad/typing_extensions-4.7.1.tar.gz \
                      b75ddc264f0ba5615db7ba217daeb99701ad295353c45f9e95963337ceeeffb2
        fetch_archive patchelf-0.17.2.1 \
                      https://files.pythonhosted.org/packages/83/ec/ac383eb82792e092d8037649b382cf78a7b79c2ce4e5b861f61519b9b14e/patchelf-0.17.2.1.tar.gz \
                      a6eb0dd452ce4127d0d5e1eb26515e39186fa609364274bc1b0b77539cfa7031
        fetch_archive scikit_build-0.17.6 \
                      https://files.pythonhosted.org/packages/85/05/dc8f28b19f3f06b8a157a47f01f395444f0bae234c4d44674453fa7eeae3/scikit_build-0.17.6.tar.gz \
                      b51a51a36b37c42650994b5047912f59b22e3210b23e321f287611f9ef6e5c9d
        fetch_archive hatchling-1.18.0 \
                      https://files.pythonhosted.org/packages/e3/57/87da2c5adc173950ebe9f1acce4d5f2cd0a960783992fd4879a899a0b637/hatchling-1.18.0.tar.gz \
                      50e99c3110ce0afc3f7bdbadff1c71c17758e476731c27607940cfa6686489ca
        fetch_archive editables-0.4 \
                      https://files.pythonhosted.org/packages/43/8a/a060ff3e75328015150f680b4b4bc4617644aaef199ece380342a334d78f/editables-0.4.tar.gz \
                      dc322c42e7ccaf19600874035a4573898d88aadd07e177c239298135b75da772
        fetch_archive trove-classifiers-2023.7.6 \
                      https://files.pythonhosted.org/packages/8b/2b/46dde7e5df5f2b22e35d060d1e3ec2ec68c6c89f85e00273ea67585e4237/trove-classifiers-2023.7.6.tar.gz \
                      8a8e168b51d20fed607043831d37632bb50919d1c80a64e0f1393744691a8b22
        fetch_archive calver-2022.6.26 \
                      https://files.pythonhosted.org/packages/b5/00/96cbed7c019c49ee04b8a08357a981983db7698ae6de402e57097cefc9ad/calver-2022.6.26.tar.gz \
                      e05493a3b17517ef1748fbe610da11f10485faa7c416b9d33fd4a52d74894f8b
        fetch_archive pluggy-1.2.0 \
                      https://files.pythonhosted.org/packages/8a/42/8f2833655a29c4e9cb52ee8a2be04ceac61bcff4a680fb338cbd3d1e322d/pluggy-1.2.0.tar.gz \
                      d12f0c4b579b15f5e054301bb226ee85eeeba08ffec228092f8defbaa3a4c4b3
        fetch_archive pathspec-0.11.1 \
                      https://files.pythonhosted.org/packages/95/60/d93628975242cc515ab2b8f5b2fc831d8be2eff32f5a1be4776d49305d13/pathspec-0.11.1.tar.gz \
                      2798de800fa92780e33acca925945e9a19a133b715067cf165b8866c15a31687
        fetch_archive hatch_fancy_pypi_readme-23.1.0 \
                      https://files.pythonhosted.org/packages/85/a6/58d585eba4321bf2e7a4d1ed2af141c99d88c1afa4b751926be160f09325/hatch_fancy_pypi_readme-23.1.0.tar.gz \
                      b1df44063094af1e8248ceacd47a92c9cf313d6b9823bf66af8a927c3960287d
        fetch_archive hatch_vcs-0.3.0 \
                      https://files.pythonhosted.org/packages/04/33/b68d68e532392d938472d16a03e4ce0ccd749ea31b42d18f8baa6547cbfd/hatch_vcs-0.3.0.tar.gz \
                      cec5107cfce482c67f8bc96f18bbc320c9aa0d068180e14ad317bbee5a153fee
        fetch_archive distro-1.8.0 \
                      https://files.pythonhosted.org/packages/4b/89/eaa3a3587ebf8bed93e45aa79be8c2af77d50790d15b53f6dfc85b57f398/distro-1.8.0.tar.gz \
                      02e111d1dc6a50abb8eed6bf31c3e48ed8b0830d1ea2a1b78c61765c2513fdd8
        fetch_archive zipp-3.16.2 \
                      https://files.pythonhosted.org/packages/e2/45/f3b987ad5bf9e08095c1ebe6352238be36f25dd106fde424a160061dce6d/zipp-3.16.2.tar.gz \
                      ebc15946aa78bd63458992fc81ec3b6f7b1e92d51c35e6de1c3804e73b799147
        fetch_archive importlib_metadata-6.8.0 \
                      https://files.pythonhosted.org/packages/33/44/ae06b446b8d8263d712a211e959212083a5eda2bf36d57ca7415e03f6f36/importlib_metadata-6.8.0.tar.gz \
                      dbace7892d8c0c4ac1ad096662232f831d4e64f4c4545bd53016a3e9d4654743
        fetch_archive cx_Freeze-6.15.4 \
                      https://github.com/marcelotduarte/cx_Freeze/archive/refs/tags/6.15.4.tar.gz \
                      fa102e66d71faeef8ed6daf434510a42ccc6d5c9b8f2f243f16101ca3463796a
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
