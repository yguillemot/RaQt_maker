#!/usr/bin/bash

if [ "$1" = "" ] || [ "$2" != "" ]
then
    echo "Syntax : bash export.sh <target_directory>"
    exit
fi
DEST=$1

if [ ! -d "$DEST" ]
then
  echo "Directory $DEST not found";
fi

mkdir -p $DEST/lib/Qt/QtWidgets
cp -f ./Qt/QtWidgets.rakumod $DEST/lib/Qt
cp -f ./Qt/QtWidgets/QtWrappers.rakumod $DEST/lib/Qt/QtWidgets
cp -f ./Qt/QtWidgets/QtHelpers.rakumod $DEST/lib/Qt/QtWidgets

mkdir -p $DEST/src
cp -f ./QtWidgetsWrapper.h $DEST/src
cp -f ./QtWidgetsWrapper.hpp $DEST/src
cp -f ./QtWidgetsWrapper.cpp $DEST/src
cp -f ./QtWidgetsWrapper.pro $DEST/src


mkdir -p $DEST/examples
cp -f ./ex/*.raku $DEST/examples

mkdir -p $DEST/t
cp -f ./t/*.t $DEST/t

mkdir -p $DEST/doc/Qt
cat ./Title.md ./Classes.md > $DEST/doc/Qt/Classes.md

# Is hoedown installed ?
hoedown --version >/dev/null 2>&1
if [ $? != 0 ]
then
    echo "hoedown utility not found."
    echo "Skip making Classes.html from Classes.md"
    exit
fi

# If yes, build an html list of implemented classes

cat << END > $DEST/doc/Qt/Classes.html
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
END

hoedown ./Title.md >> $DEST/doc/Qt/Classes.html
hoedown -t 2 --html-toc ./Classes.md >> $DEST/doc/Qt/Classes.html
hoedown -t 2 ./Classes.md >> $DEST/doc/Qt/Classes.html


