#!/bin/sh
PWD=`dirname $0`
export PYTHONHOME="$PWD/../Resources"
export PYTHON="$PWD/python"
exec "$PYTHON" "$PWD/rungramps.py" $@
