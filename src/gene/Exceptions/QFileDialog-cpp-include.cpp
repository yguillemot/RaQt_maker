cpp-include: QFileDialog

The first line of this file identify the code and its destination.
It should be :
    "keyword:    Whitelist_line

    keyword say where to insert the code :
        "rakumod"       ==> main raku module
        "use"           ==> List of module names to add to the "use" statements
        "wrappers"      ==> Native wrappers module
        "cpp"           ==> C++ .cpp code
        "cpp-include"   ==> "#include" statements for cpp code
        "h"             ==> C/C++ .h code
        ".hpp"          ==> C++ .hpp code

    Whitelist line is the description of the method as seen in the whitelist
    i.e. "class name" ~ "::" ~ "method name" ~ "(Qt C++ signature)"

All text before the "BEGIN" line will be ignored

All text after the "BEGIN" line will be inserted in the target file.
Except for the "use" keyword, the text will not be modified before insertion
except for the addition of some indentation.

When the keyword is "use", each word following "BEGIN" will be embedded in
a raku "use" statement before to be inserted in the destination file.

Currently, the "use" and "cpp-include" keywords should only be use with a
class destination, never with a method destination.


BEGIN

#include "StrBuffer.h"

