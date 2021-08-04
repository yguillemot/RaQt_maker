


#include "externc.h"



struct StrBuffer {
    int size;
    char * buffer;
};


EXTERNC void * QWStrBufferAlloc();
        
EXTERNC void QWStrBufferWrite(void * strBuffer, char * data);
         
EXTERNC char * QWStrBufferRead(void * strBuffer);

EXTERNC void QWStrBufferFree(void * strBuffer);
 
