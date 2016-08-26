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

* build-essential
* debhelper
* tcl8.6-dev
* autoconf
* python3-dev
* python3-venv
* dh-systemd
* libz-dev

If you use pdebuild it will do this for you.

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

## Installing

```
$ sudo dpkg -i piaware_3.0.4_armhf.deb
```

## Fixing problems

If the build fails and you need to make some changes to fix it, you can
directly edit the contents of the package directory and rebuild. Once
you're happy you should commit the changes to the main repositories and
rerun sensible-build.sh - it will update / re-checkout the clones in
package/

The repositories under package/ are deliberately checked out in detached-
HEAD mode, both for sensibleness of updates and to discourage you from
doing any major changes directly in there!
