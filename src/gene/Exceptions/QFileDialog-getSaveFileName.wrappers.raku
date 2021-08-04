wrappers: QFileDialog::getSaveFileName(QWidget*, const QString&, const QString&, const QString&, QString*, Options)

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

sub QWQFileDialoggetSaveFileName(Pointer,
                                 Pointer, Str, Str, Str, Pointer, int32)
        is native(&libwrapper) { * }

