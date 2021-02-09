
cpp: QPainter::begin(QPaintDevice*)

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

int8_t QWQPainterbegin_null(void * obj)
{
    QPainter * ptr = reinterpret_cast<QPainter *>(obj);
    bool  retVal = ptr->begin(nullptr);
    return retVal;
}

int8_t QWQPainterbegin_QWidget(void * obj, void * arg1)
{
    QPainter * ptr = reinterpret_cast<QPainter *>(obj);
    QPaintDevice * xarg1 = reinterpret_cast<QWidget *>(arg1);
    bool  retVal = ptr->begin(xarg1);
    return retVal;
}

int8_t QWQPainterbegin_QImage(void * obj, void * arg1)
{
    QPainter * ptr = reinterpret_cast<QPainter *>(obj);
    QPaintDevice * xarg1 = reinterpret_cast<QImage *>(arg1);
    bool  retVal = ptr->begin(xarg1);
    return retVal;
}
