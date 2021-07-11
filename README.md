RaQt_maker
==========

Generate the code (Raku and C++) of the Raku Qt::QtWidgets module (a Raku
native interface to Qt GUI)

DESCRIPTION
-----------

RaQt_maker is a set of scripts which can:  
- extract the Qt classes and methods from Qt headers  
- generate the code of a Raku module which works as a Qt API  
- generate the native wrapper this module needs  
- generate a minimum documentation of the generated API  

Two files, a white and a black list are used to select which Qt classes and
methods should be integrated into the API.

PREREQUISITES
-------------

- A Linux operating system  
- The Qt5 developpment package  
- A gcc compiler  
- Optionally hoedown for creating some HTML documentation  

INSTALLATION
------------

Just clone the repository somewhere on your system.

```
mkdir RaQt_maker
cd RaQt_maker
git clone git://github.com/yguillemot/RaQt_maker.git
```

The scripts will be run from this place.

USAGE
-----

The object of the scripts gathered here is to build a module interfacing
Raku with the Qt GUI.  
Currently this module is far to be complete and these scripts need many
enhancements before reaching their goal.

That's why this chapter has two parts:

- I\. How to build a limited, but "known as working" version of Qt::QtWidgets  
- II\. How to add new Qt classes/methods to Qt::QtWidgets

###  Part I: How to build a limited, but "known as working" version of RaQt 
 
The whole process needs 7 steps:

- 1\. Extract the C++ headers from a Qt distribution  
- 2\. Extract the definitions of the Qt classes from the C++ headers  
- 3\. Filter out needless data  
- 4\. Force a few types and sizes depending of the platform  
- 5\. Select the classes and methods we want to interface with  
- 6\. Generate the code (Raku and C++)  
- 7\. Test and use the generated code  

#### STEP 1: Extract the C++ headers from a Qt distribution

1.1 - cd in the data directory then execute the following commands :

```
qmake
make
```
    
1.2 - Note the compilation command written on the terminal window when make runs.

You should see something like:

`g++ -c -pipe -std=gnu++0x -O2 -g -pipe -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fstack-protector --param=ssp-buffer-size=4 -fno-strict-aliasing -DPIC -fPIC -std=gnu++11 -Wall -W -D_REENTRANT -fPIC -DQT_NO_DEBUG -DQT_WIDGETS_LIB -DQT_GUI_LIB -DQT_CORE_LIB -I. -I/usr/lib64/qt5/include -I/usr/lib64/qt5/include/QtWidgets -I/usr/lib64/qt5/include/QtGui -I/usr/lib64/qt5/include/QtCore -I. -isystem /usr/include/libdrm -I/usr/lib64/qt5/mkspecs/linux-g++ -o main.o main.cpp`

1.3 - Modify it by:  
- replacing the "-c" flag with "-E" near the beginning of the command  
- replacing "-o main.o" with "-o main.E" near the end of the command

   You should now have something like this:

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


#### STEP 2: Extract the definitions of the Qt classes from the C++ headers

2.1 - Leave the data directory and enter in the src one
    `cd ../src`  

2.2 - Then execute the following command:  
    `raku classExtractor.raku ../data/main.E`  

Four files should be created:  
- liste.txt: List of extracted classes (with the name of their parents)  
- arbo.txt: The same list, but adapted to the drawing of a graph with dot  
- out.txt: The C++ description of the classes  
- rejected.txt: List of rejected classes (actually, classes whose
                    name is qualified)
        
In addition to these classes, the Qt namespace is also extracted and changed
in a class for ease of getting the enums defined in it.


#### STEP 3: Filter out needless data

3.1 - Execute the following command:  
    `raku RaQt_filter.raku out.txt`
    
It should create sortie_filtre.txt obtained from out.txt by removing:  
- All which is "private"  
- All which is related to implementation  
- All which is related to templates  
- All definitions of operators  
- All attributes and other syntactic elements we are not interested in  


#### STEP 4: Force a few types and sizes depending of the platform

4.1 - To make things simpler, some types and sizes are manually defined in
      the script setSize.raku.

BEWARE: These sizes may depend of the platform and of the Qt configuration.  
Modify the setSizes.raku script if needed.

Execute the following command:  
    `raku setSizes.raku < sortie_filtre.txt > api_description.txt`


#### STEP 5: Select the classes and methods we want to interface with

In this part I, this step has already been done: the WhiteList.input file
is a list of these classes and methods.  
This list is only a small subset of the large number of Qt elements,
but RaQt_maker will generate a working code from it.


#### STEP 6: Generate the code (Raku and C++)

6.1 - Execute this command:  
`raku RaQt_maker.raku --strict --generate api_description.txt`

A repertory **module** should be generated in the top RaQt_maker directory.

It should contain six already populated subdirectories:  
- bin  
- doc  
- examples  
- lib  
- src  
- t  

and four files:  
- Build.rakumod  
- LICENSE  
- META6.json  
- README.md  

This module directory should be ready to be installed with **zef**.

```
cd module
zef install .
```

#### STEP 7: Test and use the generated code

Before trying zef, it may be useful to make some tests manually from the
module directory.

7.1 - Compile the C++ code:

```
cd module/src
qmake
make
```

With multiple CPU cores, to speed up the compilation is possible by
issuing "make -j N", where N in the number of cores, rather than only
"make".

The file libRaQtWrapper.so should be created.

7.2 - Setup the environment:

```
cd ..
export RAKULIB=lib
export LD_LIBRARY_PATH=src
```

7.3 - Run tests:  
These tests will pass only if the needed classes and methods have been
generated in the previous steps.

`for t in t/*; do raku $t; done`

Using **prove6** is possible if this one is installed:

`prove6 t`

7.4 - Run some examples:  
These examples will work only if the needed classes and methods have been
generated in the previous steps.

`raku examples/clock.raku`

`raku examples/2deg_eqn_solver.raku`

`raku examples/sketch_board.raku`



###  Part II: How to add new Qt classes/methods to RaQt 
 
Again, the whole process needs the same 7 steps:

- 1\. Extract the C++ headers from a Qt distribution  
- 2\. Extract the definitions of the Qt classes from the C++ headers  
- 3\. Filter out needless data  
- 4\. Force a few types and sizes depending of the platform  
- 5\. Select the classes and methods we want to interface with  
- 6\. Generate the code (Raku and C++)  
- 7\. Test and use the generated code  

Nevertheless, steps 1 to 4 and step 7 are strictly identical to those
of the part I.

Only steps 5 and 6 are detailed here.


#### STEP 5: Select the classes and methods we want to interface with

The wanted classes and methods have to be listed in the WhiteList.input file
and the absolutly unwanted ones in the BlackList.input file.

The BlackList.input file is optional.

Each time RaQt_maker runs, WhiteList.input and BlackList.input are read
while WhiteList.output, BlackList.output, GrayList.output and
ColorlessList.output are written.

* BlackList.output lists the methods which can't be generated (usually because
they need currently unsupported types)  
* WhiteList.output lists the methods which will be generated.  
* GrayList.output lists the methods which are in the WhiteList.input but can't
be implemented.  
* ColorlessList.output lists all the other classes and methods.  

5.1 - Initialize ColorlessList.output

Execute the following command:  
`raku RaQt_maker.raku --strict api_description.txt`

5.2 - Select the methods which should be generated

To select a set of methods to be generated, the following cycle should be run:

- 1 - Copy classes and/or methods names from ColorlessList.output
    to WhiteList.input (and, optionally to BlackList.input).
    
- 2 - Run RaQt_maker.raku

- 3 - Return to step 1 until satisfied

Nevertheless, this process is time-consuming because api_description.txt
is parsed again each time RaQt_maker.raku is run.

An alternative way is to use the following command:  
`raku RaQt_maker.raku --strict --interactive api_description.txt`  

This command runs an interactive loop inside RaQt_maker.raku.
api_description.txt is only run once before the first cycle. 
At the end of each cycle, the user is asked to run a cycle again,
generate the API or abort the whole process.
Before answering this question, the user has the opportunity to 
read the .output files and modify the .input files.

#### STEP 6: Generate the code (Raku and C++)

Executing the following command is always possible, but not needed
if this step has already been done at the end of the interactive
loop in the previous step.  
`raku RaQt_maker.raku --strict --generate api_description.txt`

The top level **module** directory should have been generated or regenerated.

#### STEP 7: Test and use the generated code

This step is identical to the **STEP 7** in the **PART I** above.

Nevertheless, if new classes and methods have been generated, new tests
needs very likely to be added to the existing ones.

Tests and examples are copied to **module** directory from the
**Files/Module** directory.

Other data, like version number, module and directories names are found
in the **GenAuto/config.rakumod** file.

If new types have been introduced in the white list, there is a good chance
that some modifications are needed in the scripts, templates and bits of code
residing in **GenAuto/gene**, **GenAuto/gene/template** and
**GenAuto/gene/Exceptions**.


Issues
------

Currently, the parser looks for Qt classes flagged with
**__attribute__((visibility("default")))** in the Qt header code.

Nevertheless, lot of Qt classes don't have this attribute, are not seen by
the scripts and therefore cant'be generated.

Limitations
-----------

Currently, the generated module is only working with Linux.


AUTHOR
------

Yves Guillemot \<<yc.guillemot@wanadoo.fr>\>


COPYRIGHT AND LICENSE
---------------------

Copyright (C) 2021 Yves Guillemot

This software is free: you can redistribute and/or modify it under
the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any
later version.

This software is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

