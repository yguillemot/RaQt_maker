RaQt_maker
==========

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
 7. Test and use the generated code

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
    `raku classExtractor.raku ../data/main.E`  

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
    `raku RaQt_filter.raku out.txt`
    
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

The wanted classes and methods have to be listed in the WhiteList.input file
and the absolutly unwanted ones in the BlackList.input file.

If a correct WhiteList.input file is already existing, you can jump to the STEP 6.
The BlackList.input file is optional.

5.1 - Create data to fill in the black/white lists :

Execute the following commands:  
`touch WhiteList.input`  
`raku RaQt_maker.raku --strict api_description.txt`  

This step should create 4 files : BlackList.output, ColorlessList.output,
GrayList.output and WhiteList.output.

* BlackList.output lists the methods which can't be generated (usually because
they need currently unsupported types)  
* WhiteList.output lists the methods which wille be generated. It should
be empty if WhiteList.input was empty.  
* GrayList.output lists the methods which are in the WhiteList.input but can't
be implemented. It should be empty.  
* ColorlessList.output lists all the other classes and methods.  

5.2 - Select the methods which should be generated:

Just copy the lines with the name of these methods from ColorlessList.output
to WhiteList.input (and, optionally to BlackList.input).

In the input files, blank lines are ignored and the '#' character may be used 
for beginning a comment.

5.3 - Run again RaQt_maker:  
`raku RaQt_maker.raku --strict api_description.txt`  

Then jump to 5.2 until the WhiteList.output contains all the wanted methods.

Note : This loop on steps 5.2 and 5.3 is long because api_description.txt
is always parsed in step 5.3.

An alternative way is to use the following command:  
`raku RaQt_maker.raku --strict --interactive api_description.txt`  

STEP 6: Generate the code (Raku and C++)
----------------------------------------

6.1 - When you are OK with the WhiteList.input and BlackList.input, issue
this command:  
`raku RaQt_maker.raku --strict --generate api_description.txt`

The following files should be generated:  
- RaQtWrapper.hpp  
- RaQtWrapper.h  
- RaQtWrapper.cpp  
- Qt/RaQt.rakumod  
- Qt/RaQt/RaQtHelpers.rakumod
- Qt/RaQt/RaQtWrappers.rakumod

STEP 7: Test and use the generated code
---------------------------------------

7.1: Compile the C++ code:  
`qmake`  
`make`

The file libRaQtWrapper.so should be created.

7.2: Setup the environment:  
`export LD_LIBRARY_PATH=.`  
`export RAKULIB=.,$RAKULIB`  

7.3: Run some tests:__
These tests will pass only if the needed classes and methods have been
generated in the previous steps.

`raku tests/test1.t`  
`raku tests/QEvent.t`  
`raku tests/QPoint.t`  
`raku tests/QPointF.t`  

7.4: Run some examples:__
These examples will work only if the needed classes and methods have been
generated in the previous steps.

`raku example/clock.raku`  
`raku example/2deg_eqn_solver.raku`  
`raku example/sketch_board.raku`  

7.5: Copy the .rakumod and .so files produced to their target places.



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
