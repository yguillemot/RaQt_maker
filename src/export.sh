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

LIBNAME=Qt/QtWidgets
CPPNAME=QtWidgetsWrapper

mkdir -p $DEST/lib/$LIBNAME
cp -f ./$LIBNAME.rakumod $DEST/lib/Qt
cp -f ./$LIBNAME/QtWrappers.rakumod $DEST/lib/Qt/QtWidgets
cp -f ./$LIBNAME/QtHelpers.rakumod $DEST/lib/Qt/QtWidgets

mkdir -p $DEST/src
cp -f ./$CPPNAME.h $DEST/src
cp -f ./$CPPNAME.hpp $DEST/src
cp -f ./$CPPNAME.cpp $DEST/src
cp -f ./$CPPNAME.pro $DEST/src


mkdir -p $DEST/examples
cp -f ./examples/*.raku $DEST/examples

mkdir -p $DEST/t
cp -f ./tests/*.t $DEST/t

mkdir -p $DEST/doc/$LIBNAME
cat ./Title.md ./Classes.md > $DEST/doc/$LIBNAME/Classes.md

# Is hoedown installed ?
hoedown --version >/dev/null 2>&1
if [ $? != 0 ]
then
    echo "hoedown utility not found."
    echo "Skip making Classes.html from Classes.md"
    exit
fi

# If yes, build an html list of implemented classes

cat << END > $DEST/doc/$LIBNAME/Classes.html
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
END

hoedown ./Title.md >> $DEST/doc/$LIBNAME/Classes.html
hoedown -t 2 --html-toc ./Classes.md >> $DEST/doc/$LIBNAME/Classes.html
hoedown -t 2 ./Classes.md >> $DEST/doc/$LIBNAME/Classes.html


