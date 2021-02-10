# RaQt_maker
Generate the code (Raku and C++) of the Raku Qt::RaQt module (a Qt GUI native interface for Raku)

DESCRIPTION
===========

RaQt_maker is a set of scripts which can extract the Qt classes and methods
interfaces from Qt headers then generate a Raku interface for Qt and its
needed native wrapper.

PREREQUISITE
============

A Linux operating system
The Qt5 developpment package
A gcc compiler
Optionally hoedown for creating some HTML documentation

INSTALLATION
============

Just clone the repository somewhere on your system.

`mkdir RaQt_maker`  
`cd RaQt_maker`  
`git clone git://github.com/yvguill/RaQt_maker.git`  

The scripts will be run from this place.

USAGE
=====

The whole process needs 7 steps

 1. Extract the C++ headers from a Qt distribution
 2. Extract the definitions of the Qt classes from the C++ headers
 3. Filter out needless data
 4. Force a few types and size depending of the platform
 5. Select the classes and methods we want to interface with
 6. Generate the code (Raku and C++)
 7. Move the generated code in a place where it can be compiled and used

STEP 1: Extract the C++ headers from a Qt distribution
------------------------------------------------------

1.1 - cd in the data directory then execute the following commands :

    `qmake`  
    `make`  
    
1.2 - Note the compilation command written on the terminal window when make runs.

You should see something like :

`g++ -c -pipe -std=gnu++0x -O2 -g -pipe -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fstack-protector --param=ssp-buffer-size=4 -fno-strict-aliasing -DPIC -fPIC -std=gnu++11 -Wall -W -D_REENTRANT -fPIC -DQT_NO_DEBUG -DQT_WIDGETS_LIB -DQT_GUI_LIB -DQT_CORE_LIB -I. -I/usr/lib64/qt5/include -I/usr/lib64/qt5/include/QtWidgets -I/usr/lib64/qt5/include/QtGui -I/usr/lib64/qt5/include/QtCore -I. -isystem /usr/include/libdrm -I/usr/lib64/qt5/mkspecs/linux-g++ -o main.o main.cpp`

1.3 - Modify it by:  
    - replacing the "-c" flag with "-E" near the beginning of the command  
    - replacing "-o main.o" with "-o main.E" near the end of the command

   You should now get something like this :

`g++ -E -pipe -std=gnu++0x -O2 -g -pipe -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fstack-protector --param=ssp-buffer-size=4 -fno-strict-aliasing -DPIC -fPIC -std=gnu++11 -Wall -W -D_REENTRANT -fPIC -DQT_NO_DEBUG -DQT_WIDGETS_LIB -DQT_GUI_LIB -DQT_CORE_LIB -I. -I/usr/lib64/qt5/include -I/usr/lib64/qt5/include/QtWidgets -I/usr/lib64/qt5/include/QtGui -I/usr/lib64/qt5/include/QtCore -I. -isystem /usr/include/libdrm -I/usr/lib64/qt5/mkspecs/linux-g++ -o main.E main.cpp`

1.4 - Before running this new command, find the qobjectdefs.h file in the Qt5
include files and edit it.

    The location of this file depends of your Linux distribution or of the way
    Qt5 was installed on your system (on my system this file is:
    `/usr/lib64/qt5/include/QtCore/qobjectdefs.h`)

1.5 - Comment out  
      - the 2 lines beginning with :  
            `#define Q_SLOTS`  
      - the 2 lines beginning with :  
            `#define Q_SIGNALS`  
      - the group of lines (beware at the line continuation character '\' )
        beginning with :  
            `#define Q_OBJECT`  

The 3 following lines may stay unchanged :  
        `#define Q_SLOTS Q_SLOTS`  
        `#define Q_SIGNALS Q_SIGNALS`  
        `#define Q_OBJECT Q_OBJECT`  


1.6 - Now execute the command of §1.3.
      A file named main.E should be created.
      It contains the C preprocessor output including all the Qt headers and
      with the Q_SLOTS et Q_SIGNAL macros unchanged.

1.7 - Remember to restore the qobjectdefs.h file to its initial state.


STEP 2: Extract the definitions of the Qt classes from the C++ headers
----------------------------------------------------------------------


2.1 - Leave the data directory and enter in the src one
    `cd ../src`  

2.2 - Then execute the following command:  
    `raku classExtractor.p6 ../data/main.E`  

Four files should be created:  
    - liste.txt: Liste of extracted classes (with the name of their parents)  
    - arbo.txt: The same list, but adapted to the drawing of a graph with dot  
    - out.txt: The C++ description of the classes  
    - rejected.txt: List of rejected classes (actually, classes whose
                       name are qualified)
        
In addition to these classes, the Qt namespace is also extracted and changed
in a class for ease of getting the enums defined in it.


STEP 3: Filter out needless data
--------------------------------

3.1 - Execute the following command:  
    `raku RaQt_filter.p6 out.txt`
    
It should create sortie_filtre.txt obtained from out.txt by removing:  
    - All which is "private"  
    - All which is related to implementation  
    - All which is related to templates  
    - All definitions of operators  
    - All attributes and other syntactic elements we are not interested in  


STEP 4: Force a few types and size depending of the platform
------------------------------------------------------------

4.1 - To make things simpler, some types and sizes are manually defined in
      the script setSize.raku.

BEWARE: These sizes may depend of the platform and of the Qt configuration.  
Modify the setSizes.raku script if needed.

Execute the following command:  
    `raku setSizes.raku < sortie_filtre.txt > api_description.txt`


STEP 5: Select the classes and methods we want to interface with
----------------------------------------------------------------

5.1 - Write in the WhiteList.input the names of the wanted classes and method.

5.2 - Write the names of the classes and method we BlackList.input file.

STEP 6: Generate the code (Raku and C++)
----------------------------------------

STEP 7: Move the generated code in a place where it can be compiled and used
-----------------------------------------------------------------------------







# TODO




# Issues

# Limitations

Currently, this module is only working with Linux.

# Prerequisite

The Qt5 library

# Installation

The Qt5 developpment package and the gcc compiler are needed.

# Testing

AUTHOR
======

Yves Guillemot

# Contributors

COPYRIGHT AND LICENSE
=====================

Copyright 2021 Yves Guillemot

This software is free; you can redistribute and/or modify it under
the GNU General Public License v3.
