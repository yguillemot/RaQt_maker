 
cpp: QPainter::ctor(QPaintDevice*)

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

void * QWQPainterCtor_QWidget(void * arg1)
{
    QWidget * xarg1 = reinterpret_cast<QWidget *>(arg1);
    QPainter * ptr = new QPainter(xarg1);
    return reinterpret_cast<void *>(ptr);
}

void * QWQPainterCtor_QImage(void * arg1)
{
    QImage * xarg1 = reinterpret_cast<QImage *>(arg1);
    QPainter * ptr = new QPainter(xarg1);
    return reinterpret_cast<void *>(ptr);
}
