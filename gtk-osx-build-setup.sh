#!/bin/sh
#
# Script that sets up jhbuild for GTK+ OS X building. Run this to
# checkout jhbuild and the required configuration.
#
# Copyright 2007, 2008, 2009 Imendio AB
#
# Run this whenever you want to update jhbuild or the jhbuild setup;
# it is safe to run it repeatedly. Note that it overwrites
# ~/.jhbuildrc however. Custom settings should be kept in
# ~/.jhbuildrc-custom.
#
# You need Mac OS X 10.4 or newer and Xcode 2.5 or newer. Make sure
# you have subversion (svn) installed, 10.5 has it by default.
#
# Quick HOWTO:
#
# sh gtk-osx-build-setup.sh
#
# jhbuild bootstrap
# jhbuild build meta-gtk-osx-bootstrap
# jhbuild build
#
# See http://live.gnome.org/GTK%2B/OSX for more information.
#

SOURCE=$HOME/Source
BASEURL="http://github.com/jralls/gtk-osx-build/raw/master"

do_exit()
{
    echo $1
    exit 1
}

get_moduleset_from_git()
{
    curl -s "$BASEURL/modulesets/$1" -o $SOURCE/jhbuild/modulesets/$1
}

if test x`which svn` == x; then
    do_exit "Svn (subversion) is not available, please install it and try again."
fi

mkdir -p $SOURCE 2>/dev/null || do_exit "The directory $SOURCE could not be created. Check permissions and try again."

rm -f tmp-jhbuild-revision
curl -s $BASEURL/jhbuild-revision -o tmp-jhbuild-revision
JHBUILD_REVISION=`cat tmp-jhbuild-revision 2>/dev/null`
if test x"$JHBUILD_REVISION" = x; then
    do_exit "Could not find jhbuild revision to use."
fi

JHBUILD_REVISION_OPTION="-r$JHBUILD_REVISION"

echo "Checking out jhbuild ($JHBUILD_REVISION) from subversion..."
if ! test -d $SOURCE/jhbuild; then
    svn co $JHBUILD_REVISION_OPTION http://svn.gnome.org/svn/jhbuild/trunk $SOURCE/jhbuild >/dev/null
else
    (cd $SOURCE/jhbuild && svn up $JHBUILD_REVISION_OPTION >/dev/null)
fi

echo "Installing jhbuild..."
(cd $SOURCE/jhbuild && make -f Makefile.plain DISABLE_GETTEXT=1 install >/dev/null)

echo "Installing jhbuild configuration..."
curl -s $BASEURL/jhbuildrc-gtk-osx -o $HOME/.jhbuildrc
curl -s $BASEURL/jhbuildrc-gtk-osx-fw-10.4 -o $HOME/.jhbuildrc-fw-10.4
curl -s $BASEURL/jhbuildrc-gtk-osx-fw-10.4-test -o $HOME/.jhbuildrc-fw-10.4-test
if [ ! -f $HOME/.jhbuildrc-custom ]; then
    curl -s $BASEURL/jhbuildrc-gtk-osx-custom-example -o $HOME/.jhbuildrc-custom
fi

echo "Installing gtk-osx moduleset files..."
MODULES="gtk-osx-gstreamer.modules gtk-osx-gtkmm.modules gtk-osx-python.modules gtk-osx-random.modules gtk-osx-themes.modules gtk-osx-unsupported.modules gtk-osx-webkit-deps.modules gtk-osx.modules gtk-osx-bootstrap.modules"
for m in $MODULES; do
    get_moduleset_from_git $m
done

if test "x`echo $PATH | grep $HOME/bin`" == x; then
    echo "PATH does not contain $HOME/bin, it is recommended that you add that."
    echo 
fi

echo "Done."
