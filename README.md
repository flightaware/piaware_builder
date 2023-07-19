# Piaware Debian Package Builder

This handles assembling and building the piaware Debian package.

## Checking everything is up to date

Update piaware_builder/changelog if needed.

Check the clone_or_update calls in sensible-build.sh to check that it is
including the correct repositories / branches.

## Prepare the package tree

Run piaware_builder/sensible-build.sh. It will:

* create piaware_builder/package/, the package directory
* check out the various parts of piaware from git into package/
* copy some control files from piaware_builder/sensible/ to package/debian/
* copy the changelog from piaware_builder/changelog to package/debian/changelog

If you are going to be building on another machine, you can copy the
package directory there; it is selfcontained.

## Check build prerequisites

Ensure that your build machine has the build dependencies mentioned in
package/debian/control:

* devscripts (this is not listed as a build-dep and needs manual handling)
* build-essential
* debhelper
* tcl8.6-dev
* autoconf
* python3-dev
* python3-venv
* python3-pip (only on debian for versions >= bookworm)
* libz-dev (also known as `zlib1g-dev`)
* cmake (only on debian for versions >= bookworm)

If you use pdebuild it will do this for you.

## Caveat about tcl-tls

The tcl-tls versions currently packaged by Debian include a bug that
can cause Piaware to hang indefinitely under some network conditions.
FlightAware provides rebuilt tcl-tls packages to work around this bug
for Raspbian systems that are using the FlightAware package repository,
and the Piaware package has a version dependency that requires at least
this rebuilt version.

For other systems where there is no prebuilt fixed package available,
you will need to build a fixed tcl-tls package yourself.
See https://github.com/flightaware/tcltls-rebuild for a suitable package.
The main change is to configure tcltls with `--enable-ssl-fastpath`

If you are running a version of Debian that includes packages newer than
those in Debian Buster, then the version constraint won't matter - but you
should still check that you have a package version that actually fixes
the problem!

For background, see the upstream bug report at
https://core.tcl-lang.org/tcltls/tktview?name=6dd5588df6

## Build it

Change to the package directory on your build machine and build with a
debian package building tool of your choice:

```
  $ dpkg-buildpackage -b
```

or

```
  $ debuild
```

or

```
  $ pdebuild
```

etc.

## Fixing problems

If the build fails and you need to make some changes to fix it, you can
directly edit the contents of the package directory and rebuild. Once
you're happy you should commit the changes to the main repositories and
rerun sensible-build.sh - it will update / re-checkout the clones in
package/

The repositories under package/ are deliberately checked out in detached-
HEAD mode, both for sensibleness of updates and to discourage you from
doing any major changes directly in there!
