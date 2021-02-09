rakumod: QPainter::ctor(QPaintDevice*)

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

multi sub ctor(RaQtBase $this, QPaintDevice $arg1) {
    if !$arg1 {
        ctor($this);
        return;
    }

    given $arg1.qtType {
        when RaQt::QWidget {
            $this.address = QWQPainterCtor_QWidget($arg1.addres);
        }
        when RaQt::QImage {
            $this.address = QWQPainterCtor_QImage($arg1.addres);
        }
        default {
            die "QPainter({$arg1.qtType} is unsupported";
        }
    }

    $this.ownedByRaku = True;
    $this.qtType = ::?CLASS.^name;
}
