
# Generate the all the files of whichever type they are

use config;
use gene::common;
use gene::addHeaderText;
use gene::exceptions;
use gene::installTemplate;

use gene::generate_hpp;
use gene::generate_h;
use gene::generate_cpp;
use gene::generate_rakumod;
use gene::generate_pro;
use gene::generate_meta6;
use gene::generate_basicTest;

# $api : The Qt API description (the output of the parser with the black and
# white info marks added)
# %callbacks : The list of callbacks precomputed by the hpp_generator
# $outFileName : The name of the output file
# $km : The keepMarkers flag (see the replace module)
sub whole_generator(API $api, %exceptions, $km = False) is export
{

    say "\n";
    say "Generate code : start";

    my %c = $api.qclasses;

    my Str $outSignals = "";
    my Str $outSlots = "";
    
    my Str $outSignalsHash = "";
    my Str $outSlotsHash = "";
    my Str $outCallbacksHash = "";
    
    
     my %allVirtuals = ();
     my %callbacks = ();
     
     # Remember here the created files
     my Str @files_hpp;
     my Str @files_cpp;
     my Str @files_h;
     my Str @files_rakumod;
   
    my Str @qtClasses;      # List of the main Qt classes (QWidget, etc...)
    my Str @otherQtClasses; # List of the subsidiary Qt classes (QPoint, etc...)

    my Str @classsesInHelper; # List of classes used in QtHelper.rakumod module
    
    # Walk through all the Qt classes
    CLASS: for %c.sort>>.kv -> ($k, $v) {
    
        # Ignore classes we don't want to implement
        next CLASS: if !$v.whiteListed || $v.blackListed;
        next CLASS: if $v.name (elem) $specialClasses;
        
        ### 1 - Gather data about current class
        
        print "   $k:";        # Begin the info line on stdout
        
        # $k is the Qt class name
        my Str $wclassname = $prefixWrapper ~ $k;      # Wrapper class name
        # my Str $wsclassname = $prefixSubclassWrapper ~ $k; # Wrapper subclass name
        my Bool $hasCtor = False;
        my Bool $hasSubclassCtor = False;
        my Bool $subclassable = ?vmethods($api, $k).elems; # $k is subclassable

        # Relation between $hasSubclassCtor and $subclassable ???????
        
        # Populate a list of the main Qt classes
        if $v.isQObj {
            @qtClasses.push: $k;
        } else { 
            @otherQtClasses.push: $k;
        }

        # Walk through the methods of the current class
        METH: for $v.methods -> $m {
        
            # Ignore methods we don't want to implement
            next METH if !$m.whiteListed || $m.blackListed;
            
            my $exk = $k ~ '::' ~ $m.name ~ qSignature($m, showNames => False);

            my Str ($retType, $name);
            if $m.name ~~ "ctor" {
                $name = $suffixCtor;
                $hasCtor = True;
            } else {
                $name = $m.name;
            }
            $name ~= ($m.number ?? "_" ~ $m.number !! "");

            if $m.name ~~ "ctor" && $v.isQObj && $subclassable {
                $hasSubclassCtor = True;
            }
        }

        

        # Get all the virtual methods usable from the current class.
        my %virtuals = vmethods($api, $k);
        %allVirtuals ,= %virtuals;

        ### 2 - Generate hpp file (if any)
        
        if $subclassable {
            my Str $include = "\n"
                            ~ "#include \"$k.h\"" ~ "\n"
                            ~ "#include \"QtWidgetsWrapper.hpp\"" ~ "\n"
                            ~ "\n";
            my (Str $hpp, %cb) = generate_hpp($k, $v, %exceptions, %virtuals);

            my Str $fileName = $k ~ ".hpp";
            spurt CPPDIR ~ $fileName, 
                        addHeaderText(code => $include ~ $hpp,
                                      commentChar => '//');
            @files_hpp.push: $fileName;
            %callbacks ,= %cb;

            print " class.hpp";
        }
       
       
        ### 3 - Generate cpp file
        
        my Str ($incl, $cpp, $outSignals1, $outSlots1)
                = generate_cpp($k, $v, %exceptions,
                               $hasCtor, $hasSubclassCtor, $subclassable
                              );
        
        if $cpp {
            my Str $fileName = $k ~ ".cpp";
            spurt CPPDIR ~ $fileName,
                    addHeaderText(code => $incl ~ $cpp, commentChar => '//');
            @files_cpp.push: $fileName;
            
            $outSignals ~= $outSignals1;
            $outSlots ~= $outSlots1;
            
            print " class.cpp";
        }

            
        ### 4 - Generate h file
        
        my Str $hstart = q:to/END/;
                            #include <stdint.h>
                            #include <QtWidgets>
                            #include "externc.h"
                            
                            END
                    
        my $htext = generate_h($k, $v, %exceptions,
                                    $hasCtor, $hasSubclassCtor, $subclassable
                              );

        if $htext && $cpp {   # Don't create empty .h file
                              # Don't create .h file if no .cpp file to use it
            my Str $fileName = $k ~ ".h";
            spurt CPPDIR ~ $fileName,
                    addHeaderText(code => $hstart ~ $htext, commentChar => '//');
            @files_h.push: $fileName;
            
            print " class.h";
        }

        
        ### 5 - Generate rakumod file
        my Str ($use, $class, $nsubs, $role,
                    $signalslHash, $slotsHash, $callbacksHash) =
                generate_rakumod($k, $v, %c, %exceptions,
                                 $hasCtor, $hasSubclassCtor, $subclassable,
                                 %virtuals, @classsesInHelper);

say "******************************************************************";
say "USE";
say $use;
say "------------------------------------------------------------------";
say "CLASS";
say $class;
say "------------------------------------------------------------------";
say "USE";
say $nsubs;
say "------------------------------------------------------------------";
say "ROLE";
say $role;
say "------------------------------------------------------------------";
say "******************************************************************";
        
        $outSignalsHash ~= $signalslHash;
        $outSlotsHash ~= $slotsHash;
        $outCallbacksHash ~= $callbacksHash;
        
        
        $use ~= "\n\n" ~ $class ~ "\n\n" ~ $nsubs;  # Join the pieces of code
        if $class {
            my Str $fileName = $k ~ ".rakumod";
            @files_rakumod.push: $fileName;
            spurt LIBDIR ~ $fileName, addHeaderText(
                    code => $use, commentChar => '#');
                    
            print " class.rakumod";
            
            if $role {
                $fileName = PREFIXROLE ~ $fileName;
                @files_rakumod.push: $fileName;
                spurt LIBDIR ~ $fileName,
                        addHeaderText(code => $role, commentChar => '#');
                        
                print " role.rakumod";
            }
            # say $use;
        }

        say "";         # Terminate the info line on stdout
    }               # End of the CLASS loop

    say "YGYGYGYGYGYG : ", @classsesInHelper;
    
    
    say "Generate code : end";
    
    
    ### 6 - Create other files  
    
    say "";
    say "Generate other files : start";
    
    my Str ($outscbw, $outcbh, $outicbp, $outcdecl)
                = generate_callbacks_rakumod(%callbacks);


    say "    QtWidgets.rakumod";
    installTemplate commentMark => '#', keepMarkers => $km,
        source => "gene/templates/QtWidgets.rakumod.template",
        destination => "{LIBBASEDIR}QtWidgets.rakumod",
        modify => {
            
            # CALLBACK_HANDLERS => $outcbh,
            # INIT_CALLBACKS_POINTERS => $outicbp,
        };
        
        
    say "    Callbacks.rakumod";
    installTemplate commentMark => '#', keepMarkers => $km,
        source => "gene/templates/Callbacks.rakumod.template",
        destination => "{LIBDIR}Callbacks.rakumod",
        modify => {
            ROLES_DECLARATION => $outcdecl,
            CALLBACK_HANDLERS => $outcbh,
            INIT_CALLBACKS_POINTERS => $outicbp,
        };
    @files_rakumod.push: "Callbacks.rakumod";
        

    say "    QApplication.rakumod";
    installTemplate 
        source => "gene/templates/QApplication.rakumod.template",
        destination => "{LIBDIR}QApplication.rakumod";
    @files_rakumod.push: "QApplication.rakumod";
                        
    say "    QObject.rakumod";
    installTemplate 
        source => "gene/templates/QObject.rakumod.template",
        destination => "{LIBDIR}QObject.rakumod";
    @files_rakumod.push: "QObject.rakumod";
                                        
    say "    RQObject.rakumod";
    installTemplate 
        source => "gene/templates/RQObject.rakumod.template",
        destination => "{LIBDIR}RQObject.rakumod";
    @files_rakumod.push: "RQObject.rakumod";
                                        
                                        

    say "    QtHelpers.rakumod";
    # Add the needed "use" calls
    my Str $useStr = "";
    my $roles = SetHash.new: @classsesInHelper;
    for 'R' <<~>> $roles.keys.sort -> $rname {
        $useStr ~= "use {LIBPREFIX}{versionedName($rname)};\n";
    }
    installTemplate  commentMark => '#', keepMarkers => $km,
        source => "gene/templates/QtHelpers.rakumod.template",
        destination => "{LIBDIR}QtHelpers.rakumod",
        modify => {
            ROLES_DECLARATION => $useStr,
            SIGNALS_HASH => $outSignalsHash,
            SLOTS_HASH => $outSlotsHash,
            CALLBACKS_HASH => $outCallbacksHash,
            # QT_CLASSES_STUBS => $outStubs,
            LIST_OF_MAIN_QT_CLASSES => [~] "'" <<~>> @qtClasses <<~>> "',\n",
        };
    @files_rakumod.push: "QtHelpers.rakumod";
    
    
    say "    QtWrappers.rakumod";
    installTemplate commentMark => '#', keepMarkers => $km,
        source => "gene/templates/QtWrappers.rakumod.template",
        destination => "{LIBDIR}QtWrappers.rakumod",
        modify => {
            SETUP_CALLBACK_WRAPPERS => $outscbw,
            
            # No more needed in multiple files mode
            # LIST_OF_QT_CLASSES_NATIVE_WRAPPERS => $outNatives,
        };
    @files_rakumod.push: "QtWrappers.rakumod";

# TODO : $outscbw should be inserted in the callbacks wrappers file
# TODO       (... is native(...) { * }

            
    say "    ConnectionManager.rakumod";
    installTemplate
        source => "gene/templates/ConnectionManager.rakumod.template",
        destination => "{LIBDIR}ConnectionManager.rakumod";
    @files_rakumod.push: "ConnectionManager.rakumod";
        
        
    say "    QtBase.rakumod";
    installTemplate
        source => "gene/templates/QtBase.rakumod.template",
        destination => "{LIBDIR}QtBase.rakumod";
    @files_rakumod.push: "QtBase.rakumod";

    
    say "    externc.h";
    my Str $externc = q:to/END/;

                        #ifdef __cplusplus
                        #define EXTERNC extern "C"
                        #else
                        #define EXTERNC
                        #endif
                        
                        END
                        
    spurt CPPDIR ~ "externc.h",
            addHeaderText(code => $externc, commentChar => '//');
    @files_h.push: "externc.h";
                        
                        
    say "    QtWidgetsWrapper.cpp";
    my Str ($outCbi, $outCbs) = generate_callbacks_cpp(%callbacks);

    installTemplate commentMark => '//', keepMarkers => $km,
        source => "gene/templates/QtWidgetsWrapper.cpp.template",
        destination => "{CPPDIR}QtWidgetsWrapper.cpp",
        modify => {
            SIGNALS_DICTIONARY => $outSignals,
            SLOTS_DICTIONARY => $outSlots,
            CALLBACKS_SETUP => $outCbs,
            CALLBACKS_POINTERS_DECLARATION => $outCbi,
            
            # MAIN_CLASSES_CPP_CODE => $out,
            # SUBCLASSES_CTORS => $outSctors,
            # SUBAPI_CLASSES_CPP_CODE => $outSubapi,
        };
    
    
    say "    QtWidgetsWrapper.h";
    my Str ($outcb) = generate_callbacks_h(%callbacks);

    installTemplate commentMark => '//', keepMarkers => $km,
        source => "gene/templates/QtWidgetsWrapper.h.template",
        destination => "{CPPDIR}QtWidgetsWrapper.h",
        modify => {
            CALLBACKS_INITIALIZERS => $outcb,
            
            # WRAPPER_H_CODE => $out,
        };
                            
                                        
        

    say "    QtWidgetsWrapper.hpp";
    my Str ($outx, $outs, $outd, $outi)
                = generate_callbacks_hpp(%callbacks, %allVirtuals);
                
    installTemplate commentMark => '//', keepMarkers => $km,
        source => "gene/templates/QtWidgetsWrapper.hpp.template",
        destination => "{CPPDIR}QtWidgetsWrapper.hpp",
        modify => {
            VIRTUAL_METHODS_CALLBACKS_PROTOTYPES => $outx,
            VALIDATOR_DECLARATION => $outd,
            VALIDATOR_SWITCH => $outs,
            VALIDATOR_INIT => $outi,
            
            # SUBCLASSES_WITH_VIRTUAL_METHODS => $out,
        };
        
        
    say "    StrBuffer.c";
                
    installTemplate commentMark => '//',
        source => "gene/templates/StrBuffer.c",
        destination => "{CPPDIR}StrBuffer.c",
        :copied;
        
    say "    StrBuffer.h";
                
    installTemplate commentMark => '//',
        source => "gene/templates/StrBuffer.h",
        destination => "{CPPDIR}StrBuffer.h",
        :copied;

                
    say "Generate other files : end";

    # Generate the Qt project file
    @files_hpp.push: "QtWidgetsWrapper.hpp";
    @files_cpp.push: "QtWidgetsWrapper.cpp";
    @files_cpp.push: "StrBuffer.c";
    @files_h.push: "QtWidgetsWrapper.h";
    @files_h.push: "StrBuffer.h";

    my Str $pro = generate_pro(@files_hpp, @files_cpp, @files_h);
    spurt CPPDIR ~ WRAPPERLIBNAME ~ ".pro", $pro;
    
    # Generate the meta6.json file
    my Str $template = "gene/templates/META6.json.template";
    my Str $meta = generate_meta6($template, @files_rakumod);
    spurt TARGETDIR ~ "META6.json", $meta; 
    
    # Generate the basic tests file
    my Str $basicTest = generate_basicTest(@qtClasses, @otherQtClasses);
    spurt TARGETDIR ~ "t/000-Basic.t", $basicTest; 
}





