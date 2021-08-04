cpp: QFileDialog::getSaveFileName(QWidget*, const QString&, const QString&, const QString&, QString*, Options)

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



This function is implemented as an exception because it uses a C buffer
to return the content of a QString.
Currently, the generation of such a code is not automated.

BEGIN

void QWQFileDialoggetSaveFileName(
        void * retBuffer,
        void * parent, 
        char * caption,
        char * dir,
        char * filter,
        void * sfBuffer,
        int32_t options)
{
    QWidget * xparent = reinterpret_cast<QWidget *>(parent);
    QString xcaption = QString(caption);
    QString xdir = QString(dir);
    QString xfilter = QString(filter);
    
    QString * xselectedFilter = nullptr;
    if (sfBuffer) {
        char * selectedFilter = 
                reinterpret_cast<struct StrBuffer *>(sfBuffer)->buffer;
        xselectedFilter = new QString(selectedFilter);
    }
    
    QFileDialog::Options xoptions = static_cast<QFileDialog::Options>(options);
    
    QString  retVal = QFileDialog::getSaveFileName(
        xparent, xcaption, xdir, xfilter, xselectedFilter, xoptions);
    
    if (sfBuffer) {
        QWStrBufferWrite(sfBuffer, xselectedFilter->toUtf8().data());
        delete xselectedFilter;                   // Delete the QString
    }

    if (!retVal.isNull()) {
        QWStrBufferWrite(retBuffer, retVal.toUtf8().data());
    } 
}

