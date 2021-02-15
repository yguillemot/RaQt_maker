rakumod: QPainter::begin(QPaintDevice*)

The first line of this file identify the code and its destination.
It should be :
    "keyword:    Whitelist_line

    keyword say where to insert the code :
        "rakumod"   ==> main raku module
        "wrappers"  ==> Native wrappers module
        "cpp"       ==> C++ .cpp code
        "h"         ==> C/C++ .h code
        ".hpp"      ==> C++ .hpp code

    Whitelist line is the description of the method as seen in the whitelist
    i.e. "class name" ~ "::" ~ "method name" ~ "(Qt C++ signature)"

All text before the "BEGIN" line will be ignored

All text after the "BEGIN" line will be inserted in the target file.
The text will not be modified before insertion except for the addition of
some indentation.

BEGIN

method begin(QPaintDevice $arg1 --> Bool) {
    if !$arg1 {
        return ?QWQPainterbegin_null(self.address);
    }

    given $arg1.qtType {
        when "RaQt::QLabel"  {
            return ?QWQPainterbegin_QWidget(self.address, $arg1.address);
        }
        when "RaQt::QWidget"  {
            return ?QWQPainterbegin_QWidget(self.address, $arg1.address);
        }
        when "RaQt::QImage" {
            return ?QWQPainterbegin_QImage(self.address, $arg1.address);
        }
        default {
            note "QPainter::begin : arg type {$arg1.qtType} is unsupported";
            die "QPainter({$arg1.qtType}) is unsupported";
        }
    }
}

