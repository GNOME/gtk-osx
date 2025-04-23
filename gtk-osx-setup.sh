#!/usr/bin/env bash
 ####################################################################
 # gtk-osx-setup.sh: gtk-osx setup with python virtual environments.#
 #                                                                  #
 # Copyright 2018 John Ralls <jralls@ceridwen.us>                   #
 #                                                                  #
 # This program is free software; you can redistribute it and/or    #
 # modify it under the terms of the GNU General Public License as   #
 # published by the Free Software Foundation; either version 2 of   #
 # the License, or (at your option) any later version.              #
 #                                                                  #
 # This program is distributed in the hope that it will be useful,  #
 # but WITHOUT ANY WARRANTY; without even the implied warranty of   #
 # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the    #
 # GNU General Public License for more details.                     #
 #                                                                  #
 # You should have received a copy of the GNU General Public License#
 # along with this program; if not, contact:                        #
 #                                                                  #
 # Free Software Foundation           Voice:  +1-617-542-5942       #
 # 51 Franklin Street, Fifth Floor    Fax:    +1-617-542-2652       #
 # Boston, MA  02110-1301,  USA       gnu@gnu.org                   #
 ####################################################################

# Function envvardir. Tests environment variable, sets default value if unset,
# and creates the specified directory if it doesn't already exist. This
# will barf if the name indicates a file that isn't a directory.
envvar ()
{
    local _varname=$1
    eval local _var=\$$_varname
    if test -z "$_var"; then
        eval export $_varname="$2"
        _var=$2
    fi
    if test ! -d "$_var"; then
        mkdir -p "$_var"
    fi
}

pip_remove()
{
    local _package=$1
    local _local_package=`$PIP show $_package | grep Location | grep $PYTHONUSERBASE`
    if test -n "$_local_package"; then
        echo $_local_package
        $PIP uninstall -y $_package
    fi
}

# Environment variable defaults:
#
envvar DEVROOT "$HOME"
envvar DEVPREFIX "$DEVROOT/.new_local"
envvar PYTHONUSERBASE "$DEVROOT/.new_local"
envvar DEV_SRC_ROOT "$DEVROOT/Source"
envvar PYENV_INSTALL_ROOT "$DEV_SRC_ROOT/pyenv"
envvar PYENV_ROOT "$DEVPREFIX/share/pyenv"
envvar PIP_CONFIG_DIR "$HOME/.config/pip"
envvar PYTHON_VERSION 3.13.2

export PYTHONWARNINGS=ignore:DEPRECATION::pip._internal.cli.base_command

if test ! -d "$DEVPREFIX/bin" ; then
    mkdir -p "$DEVPREFIX/bin"
fi

ARCH=arm64
if test "$(arch)x" = "i386x"; then
    ARCH=x86_64
elif test "$(arch)x" != "arm64x"; then
    echo "Unknown architecture $(arch), aborting!"
    exit 1
fi

GITLAB="https://gitlab.gnome.org/GNOME"
GITHUB="https://github.com"

# We need to have a local copy of bash when compiling to prevent SIP problems.
if test ! -x "$DEVPREFIX/bin/bash"; then
    ln -s /bin/bash "$DEVPREFIX/bin"
fi

# Since macOS 13, groff isn't present on the system. By symlinking 'true', we get
# a dummy groff that's succesfully executed in affected makefiles.
if test ! -x /usr/bin/groff -a ! -x "$DEVPREFIX/bin/groff"; then
    ln -s /usr/bin/true "$DEVPREFIX/bin/groff"
fi

# Setup pyenv
if test ! -x "$PYENV_INSTALL_ROOT/libexec/pyenv"; then
  if test -d "$PYENV_INSTALL_ROOT"; then
     rm -rf "$PYENV_INSTALL_ROOT";
  fi
  git clone $GITHUB/pyenv/pyenv.git "$PYENV_INSTALL_ROOT"
else
    pushd "$PYENV_INSTALL_ROOT"
    git pull --ff-only
    popd
fi

PYENV="$DEVPREFIX/bin/pyenv"

if test ! -x "$PYENV" ; then
    ln -s "$PYENV_INSTALL_ROOT/bin/pyenv" "$DEVPREFIX/bin"
fi

#Force installation and we hope use of Python with PyEnv. We must
#avoid using the Apple-provided Python2 because jhbuild doesn't work
#with python2 any more, and the Apple-provided python3 because it
#doesn't include a usable libpython for libxml2 to link against.

export PYTHON_CONFIGURE_OPTS="--enable-shared"
#This really means pyenv's *python* version. It's poorly named but
#it's defined by pyenv so it can't be changed.
export PYENV_VERSION=$PYTHON_VERSION
$PYENV install -v $PYENV_VERSION
$PYENV global $PYENV_VERSION
PIP="$PYENV_ROOT/shims/pip3"

$PIP install --upgrade --user pip

# Install pipenv
$PIP install --upgrade --user pipenv==2024.4.1
PIPENV="$PYTHONUSERBASE/bin/pipenv"
export WORKON_HOME=$DEVPREFIX/share/virtualenvs

JHBUILD_RELEASE_VERSION="master"
# Install jhbuild
if test ! -d "$DEV_SRC_ROOT/jhbuild/.git" ; then
    git clone -b $JHBUILD_RELEASE_VERSION $GITLAB/jhbuild.git "$DEV_SRC_ROOT/jhbuild"
    cd "$DEV_SRC_ROOT/jhbuild"
else #Get the latest if it's already installed
    cd "$DEV_SRC_ROOT/jhbuild"
    git pull
    git reset --hard $JHBUILD_RELEASE_VERSION
fi

# Install Ninja
NINJA=`which ninja`
if test ! -x "$NINJA" -a ! -x "$DEVPREFIX/bin/ninja"; then
    curl -kLs https://github.com/ninja-build/ninja/releases/download/v1.11.1/ninja-mac.zip -o "$DEVPREFIX/ninja-mac.zip"
    unzip -d "$DEVPREFIX/bin" "$DEVPREFIX/ninja-mac.zip"
    rm "$DEVPREFIX/ninja-mac.zip"
fi

# Install Rust (required for librsvg, which gtk needs to render its icons.)
# Cross compilation note: To enable x86_64 rust builds on an Apple Silicon mac, run
# rustup toolchain install stable-x86_64-apple-darwin
# and edit the default toolchain in $DEVPREFIX/settings.toml to match.
RUSTUP=`which rustup`
if test -x "$RUSTUP"; then
    case `dirname "$RUSTUP"` in
        "$DEVPREFIX"*)
            DEFAULT_CARGO_HOME=$(dirname $(dirname "$RUSTUP"))
            envvar CARGO_HOME "$DEFAULT_CARGO_HOME"
            CARGO_HOME_DIR=$(basename "$CARGO_HOME")
            if test "$CARGO_HOME_DIR" == "cargo"; then
                CARGO_HOME_BASE=$(dirname "$CARGO_HOME")
                envvar RUSTUP_HOME "$CARGO_HOME_BASE"/rustup
            else
                envvar RUSTUP_HOME "$CARGO_HOME"
            fi
            ;;
        *)
            envvar CARGO_HOME "$HOME/.cargo"
            envvar RUSTUP_HOME "$HOME/.rustup"
            ;;
    esac
else
    envvar CARGO_HOME "$DEVPREFIX"
    envvar RUSTUP_HOME "$DEVPREFIX"
    curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal --no-modify-path > /dev/null
fi
# Install the Build C package, C integration required to build librsvg
$DEVPREFIX/bin/cargo install cargo-c --features=vendored-openssl

if test ! -d "$DEVPREFIX/etc" ; then
    mkdir -p "$DEVPREFIX/etc"
fi

PYENV_MINOR_VERSION=$(echo $PYENV_VERSION | cut -d . -f 1,2)
cat  <<EOF > "$DEVPREFIX/etc/Pipfile"
[[source]]
url = "https://pypi.python.org/simple"
verify_ssl = true
name = "pypi"

[packages]
pygments = "*"
meson = {version=">=0.56.0"}
docutils = "*"
gi-docgen = "*"
setuptools = "*"
packaging = "*"

[scripts]
jhbuild = "$DEVPREFIX/libexec/run_jhbuild.py"

[requires]
python_version = "$PYENV_MINOR_VERSION"
EOF
cat <<EOF > "$DEVPREFIX/etc/pipenv-env"
export PYTHONUSERBASE="$PYTHONUSERBASE"
export DEV_SRC_ROOT="$DEV_SRC_ROOT"
export PYENV_ROOT="$PYENV_ROOT"
export PIP_CONFIG_DIR="$PIP_CONFIG_DIR"
export LANG=C
EOF

cat <<EOF > "$DEVPREFIX/bin/jhbuild"
#!/usr/bin/arch -$ARCH $DEVPREFIX/bin/bash
export DEVROOT="$DEVROOT"
export DEVPREFIX="$DEVPREFIX"
export PYTHONUSERBASE="$PYTHONUSERBASE"
export PIPENV_DOTENV_LOCATION="$DEVPREFIX/etc/pipenv-env"
export PIPENV_PIPFILE="$DEVPREFIX/etc/Pipfile"
export PYENV_ROOT="$PYENV_ROOT"
export PYENV_VERSION="$PYENV_VERSION"
export PATH="$PYENV_ROOT/shims:\$PATH"
export CARGO_HOME="$CARGO_HOME"
export RUSTUP_HOME="$RUSTUP_HOME"
export WORKON_HOME="$WORKON_HOME"

exec $DEVPREFIX/bin/pipenv run jhbuild \$@
EOF

if test ! -d "$DEVPREFIX/libexec" ; then
    mkdir -p "$DEVPREFIX/libexec"
fi
cat <<EOF > "$DEVPREFIX/libexec/run_jhbuild.py"
#!/usr/bin/env /usr/bin/arch -$ARCH python3
# -*- coding: utf-8 -*-

import sys
import os
import builtins
sys.path.insert(0, '$DEV_SRC_ROOT/jhbuild')
pkgdatadir = None
datadir = None
import jhbuild
srcdir = os.path.abspath(os.path.join(os.path.dirname(jhbuild.__file__), '..'))
builtins.__dict__['PKGDATADIR'] = pkgdatadir
builtins.__dict__['DATADIR'] = datadir
builtins.__dict__['SRCDIR'] = srcdir

import jhbuild.main
jhbuild.main.main(sys.argv[1:])

EOF

if test ! -x "$DEVPREFIX/bin/jhbuild" ; then
    chmod +x "$DEVPREFIX/bin/jhbuild"
fi
if test ! -x "$DEVPREFIX/libexec/run_jhbuild.py" ; then
    chmod +x "$DEVPREFIX/libexec/run_jhbuild.py"
fi
if test "x`echo $PATH | grep "$DEVPREFIX/bin"`" == x ; then
    echo "***********"
    echo "PATH does not contain $DEVPREFIX/bin. You probably want to fix that.\n*"
    echo "***********"
    export PATH="$DEVPREFIX/bin:$PATH"
fi

SDKROOT=`xcrun --show-sdk-path`

export PIPENV_DOTENV_LOCATION="$DEVPREFIX/etc/pipenv-env"
export PIPENV_PIPFILE="$DEVPREFIX/etc/Pipfile"
export PATH="$PYENV_ROOT/shims:$DEVPREFIX/bin:$PYENV_INSTALL_ROOT/plugins/python-build/bin:$PATH"

if test -d "$SDKROOT"; then
    export CFLAGS="-isysroot $SDKROOT -I$SDKROOT/usr/include"
fi

$PIPENV install

BASEURL="https://gitlab.gnome.org/GNOME/gtk-osx/raw/master"

config_dir=""
if test -n "$XDG_CONFIG_HOME"; then
   config_dir="$XDG_CONFIG_HOME"
else
   config_dir="$HOME/.config"
fi
if test ! -d "$config_dir"; then
    mkdir -p "$config_dir"
fi

if test -e "$HOME/.jhbuildrc"; then
    JHBUILDRC="$HOME/.jhbuildrc"
else
    JHBUILDRC="$config_dir/jhbuildrc"
fi
echo "Installing jhbuild configuration at $JHBUILDRC"
curl -ks $BASEURL/jhbuildrc-gtk-osx -o "$JHBUILDRC"

if test -z "$JHBUILDRC_CUSTOM"; then
    JHBUILDRC_CUSTOM="$config_dir/jhbuildrc-custom"
fi
if test ! -e "$JHBUILDRC_CUSTOM" -a ! -e "$HOME/.jhbuildrc-custom"; then
    JHBUILDRC_CUSTOM_DIR=`dirname $JHBUILDRC_CUSTOM`
    echo "Installing jhbuild custom configuration at $JHBUILDRC_CUSTOM"
    if test ! -d "$JHBUILDRC_CUSTOM_DIR"; then
        mkdir -p "$JHBUILDRC_CUSTOM_DIR"
    fi
    curl -ks $BASEURL/jhbuildrc-gtk-osx-custom-example -o "$JHBUILDRC_CUSTOM"
fi
