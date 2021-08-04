rakumod: QFileDialog::getSaveFileName(QWidget*, const QString&, const QString&, const QString&, QString*, Options)

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



QFileDialog::getSaveFileName is implemented as an exception for three reasons:

 - The parameter $selectedFilter is optional with a default
   value AND rw which needs to implement it with a multimethod.
 - We can't assume the QString whose reference is returned by the
   getOpenFileName static method is not allocated on the stack and will
   still be here when back in the caller. An external buffer is needed.
 - rw parameters passed by pointer are scarce in the Qt API.

BEGIN 

    multi method getSaveFileName(
        RQWidget $parent = (RQWidget), 
        Str $caption = "", 
        Str $dir = "", 
        Str $filter = "" 
        --> Str)
    {
        my Pointer $retBuffer = QWStrBufferAlloc;

        my $a1 = ?$parent ?? $parent.address !! QWInt2Pointer(0);
        QWQFileDialoggetSaveFileName(
            $retBuffer,
            $a1, 
            $caption, 
            $dir,
            $filter, 
            QWInt2Pointer(0),  
            Options());
            
        my Str $returnedString = QWStrBufferRead($retBuffer);
        QWStrBufferFree($retBuffer);
        
        return $returnedString;
    }


    multi method getSaveFileName(
        RQWidget $parent, 
        Str $caption, 
        Str $dir, 
        Str $filter, 
        Str $selectedFilter is rw, 
        Int $options = Options() 
        --> Str)
    {
        my Pointer $retBuffer = QWStrBufferAlloc;
        
        my Pointer $sfBuffer;
        if $selectedFilter !=== (Str) {
            $sfBuffer = QWStrBufferAlloc;
            QWStrBufferWrite($sfBuffer, $selectedFilter);
        } else {
            $sfBuffer = QWInt2Pointer(0);
        }

        my $a1 = ?$parent ?? $parent.address !! QWInt2Pointer(0);
        QWQFileDialoggetSaveFileName(
            $retBuffer,
            $a1, 
            $caption, 
            $dir,
            $filter, 
            $sfBuffer,
            $options);

        if $selectedFilter !=== (Str) {
            $selectedFilter = QWStrBufferRead($sfBuffer);
            QWStrBufferFree($sfBuffer);
        }

        my Str $returnedString = QWStrBufferRead($retBuffer);
        QWStrBufferFree($retBuffer);
            
        return $returnedString;
    }


