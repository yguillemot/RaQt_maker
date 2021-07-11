
# Generate the .cpp file

use config;
use gene::common;
use gene::replace;
use gene::conversions;
use gene::indent;
use gene::addHeaderText;


# $api : The Qt API description (the output of the parser with the black and
# white info marks added)
# %callbacks : The list of callbacks precomputed by the hpp_generator
# $outFileName : The name of the output file
# $km : The keepMarkers flag (see the replace module)
sub generate_cpp(Str $k, Qclass $v, %exceptions,
                    Bool $hasCtor, Bool $hasSubclassCtor, Bool $subclassable,
                    $km = False) is export
                    
     # Arguments ?  Variables locales ?              
     # %callbacks, @hppClasses,
     
{

#     my Str $templateFileName = "gene/templates/QtWidgetsWrapper.cpp.template";
#     my Str $classCppTemplate = 
#                         slurp "gene/templates/QClassWrapper.cpp.template";

#     say "Generate the .cpp file : start";
    # say "\n" x 2;

    # Init strings which will be inserted in the template
    my Str $out;                    # Code of the classes
    my Str $outSignals = "";        # Signals dictionary
    my Str $outSlots = "";          # Slots dictionary
#     my Str $outSctors = "";
#     my Str $outSubapi = "";
    
    
    # $k is the Qt class name
    my Str $wclassname = $prefixWrapper ~ $k;   # Wrapper class name
    my $sclassname = $prefixSubclass ~ $k;      # Wrapper subclass name
    my Str $wsclassname = $prefixSubclassWrapper ~ $k; # Wrapper subclass name
    
    
    # if $v.isQObj {    ### NO MORE NEEDED
    if True {
    
        # Main Qt class (QWidget, QPushButton, QVBoxlayout, etc...)
    
        MLOOP: for $v.methods -> $m {
            next MLOOP if !$m.whiteListed || $m.blackListed;
            
            next if $m.isVirtual;  ###  Always ???
    
            # Look for exception
            my $exk = $k ~ '::' ~ $m.name ~ qSignature($m, showNames => False);
            # say "?EXCEPTION $exk";
            if %exceptions{$exk}{'cpp'}:exists {
                # say "EXCEPTION cpp : $exk";
                $out ~= %exceptions{$exk}{'cpp'};
                next MLOOP;
            }
    

            my $number = $m.number ?? '_' ~ $m.number !! "";


            if $m.name ~~ "ctor" {
                # say "ctor$number : ", qSignature($m);
                
                $out ~= "void * " ~ $wclassname ~ $suffixCtor
                                            ~ $number ~ cSignature($m) ~ "\n";

                my Str $txt1 = '{' ~ "\n";


                for $m.arguments -> $a {
                    my $tot = $a.ftot ~~ "COMPOSITE"
                                ?? $a.subtype.ftot
                                !! $a.ftot;
                    $txt1 ~= IND;
                    $txt1 ~= precall($k, $tot,
                                    cType($a), cPostop($a), $a.fname,
                                    qType($a), qPostop($a), 'x' ~ $a.fname);
                    $txt1 ~= "\n";
                }



                my Str $txt2 = IND ~ "return reinterpret_cast<void *>(ptr);\n";
                $txt2 ~= "}\n\n";

                $out ~= $txt1;
                $out ~= IND ~ $k ~ " * ptr = new "
                                ~ $k ~ qCallUse($m, "x") ~ ";\n";
                $out ~= $txt2;
                
                

                if $subclassable {
                    # Subclass ctor wrapper

                    $out ~= "void * " ~ $wsclassname ~ $suffixCtor
                                            ~ $number ~ cSignature($m) ~ "\n";
                    $out ~= $txt1;
                    $out ~= IND ~ $sclassname ~ " * ptr = new "
                                    ~ $sclassname ~ qCallUse($m, "x") ~ ";\n";
                    $out ~= $txt2;
                }
                
                

            } elsif $m.isSignal { 
                # Write an elements to the signals dictionary.
                # We need an element for each obtained signature
                # when arguments with default values are successively
                # eleminated.
                my @sigs = availableSignatures($m);
                for @sigs -> $ig {
                    # say "SIGNAL : ", qProto($ig);
                
                    my $s = $ig.name ~ qSignature($ig, showNames => False);
                    $outSignals ~= "signalDict->insert(\"$s\",\n";
                    $outSignals ~= "    new QtSignal(SIGNAL($s), nullptr));\n";
                }
                
            } else {
            
                if $m.isSlot {
                    # Write elements to the slots dictionary.
                    # We need an element for each obtained signature
                    # when arguments with default values are successively
                    # eleminated.
                    my @slots = availableSignatures($m);
                    for @slots -> $slot {
                        #say "SLOT : ", qProto($slot);
                        
                        $outSlots ~= "slotDict->insert(\""
                            ~ $slot.name
                            ~ qSignature($slot, showNames => False)
                            ~ "\", SLOT("
                            ~ $slot.name
                            ~ qSignature($slot, showNames => False) 
                            ~ "));\n";
                    }
                }            
            
                # say qProto($m);
                my $rt = $m.returnType;
                my $retType = trim cRetType $m;
                $out ~= $retType ~ " " ~ $wclassname
                            ~ $m.name ~ $number ~ cSignature($m) ~ "\n";
                $out ~= "\{\n";
                $out ~= IND ~ "$k * ptr = reinterpret_cast<$k *>(obj);\n";

                for $m.arguments -> $a {
                    my $tot = $a.ftot ~~ "COMPOSITE"
                                ?? $a.subtype.ftot
                                !! $a.ftot;
                    $out ~= IND;
                    $out ~= precall($k, $tot,
                                    cType($a), cPostop($a), $a.fname,
                                    qType($a), qPostop($a), 'x' ~ $a.fname);
                    $out ~= "\n";
                }

                $out ~= IND;
                if $retType ne "void" {
                    my Str $qualif = enumQualifier($k, $rt);
                    $out ~= $rt.const ~ " " ~ $qualif ~ qType($rt)
                            ~ " " ~ qPostop($rt) ~ " retVal = ";
                }
                $out ~= "ptr->" ~ $m.name ~ qCallUse($m, "x") ~ ";\n";

                for $m.arguments -> $a {
                    my $tot = $a.ftot ~~ "COMPOSITE"
                                ?? $a.subtype.ftot
                                !! $a.ftot;
                    my $pc = postcall($m.name, $k, $tot, "arg",
                            qType($a), qPostop($a), $a.const, 'x' ~ $a.fname,
                            cType($a), cPostop($a), $a.fname);
                    $out ~= IND ~ $pc ~ "\n" if $pc ne "";
                }
                if $retType ne "void" { 
                    my $pc = postcall($m.name, $k, $rt.ftot, "ret",
                                      qType($rt), qPostop($rt), $rt.const, "retVal",
                                      cType($rt), cPostop($rt), "xretVal");
                    if $pc ~~ "" {
                        $out ~= IND ~ "return retVal;\n";
                    } else {
                        $out ~= indent($pc, IND) ~ "\n";
                        $out ~= IND ~ "return xretVal;\n";
                    }
                }
                $out ~= "}\n";
                $out ~= "\n";            
            }
    
        }

        # If subclass ctor exist, add code for callbacks validation
        if $hasSubclassCtor {
            $out ~= "void $prefixWrapper" ~ "validateCB_$k"
                        ~ '(void *obj, int32_t objId, char *methodName)' ~ "\n";
            $out ~= '{' ~ "\n";
            $out ~= IND ~ $sclassname ~ ' * ptr = reinterpret_cast<'
                    ~ $sclassname ~ ' *>(obj);' ~ "\n";
            $out ~= "\n";
            $out ~= IND ~ 'ptr->validateEvent(objId, methodName);' ~ "\n";
            $out ~= "\n";
            $out ~= '}' ~ "\n";
        }


        # If ctor exist, add code for the related dtor
        if $hasCtor {
            $out ~= 'void ' ~ $wclassname ~ $suffixDtor ~ '(void * obj)'~ "\n";
            $out ~= '{' ~  "\n";
            $out ~= IND ~ "$k * ptr = reinterpret_cast<$k *>(obj);\n";
            $out ~= IND ~ 'delete ptr;' ~ "\n";
            $out ~= '}' ~  "\n";
            $out ~= "\n";
        }

        # If subclass ctor exist, add code for the related dtor
        if $hasSubclassCtor {
            $out ~= 'void ' ~ $wsclassname ~ $suffixDtor ~ '(void * obj)'~ "\n";
            $out ~= '{' ~  "\n";
            $out ~= IND ~ "$k * ptr = reinterpret_cast<$k *>(obj);\n";
            $out ~= IND ~ 'delete ptr;' ~ "\n";
            $out ~= '}' ~  "\n";
            $out ~= "\n";
        }

    } 
    
#        ### NO MORE NEEDED
#       else {
#         # Subsidiary class (QColor, QEvent, QRect, etc...
#         
# 
#         
#     }
    
    
    
    return $out, $outSignals, $outSlots;
    


#     # Main classes code generation
#     
# #     CLOOP: for %c.sort>>.kv -> ($k, $v) {
# #         next CLOOP if !$v.whiteListed || $v.blackListed;
# #         next CLOOP if !$v.isQObj;
# #         
# #         my $strs = cpp_main_class_gen($api, %exceptions, %callbacks, $k, $v);
# #         $out = "";
# #         $outSignals ~= $strs[1];
# #         $outSlots ~= $strs[2];
# # 
# #         # If subclasses can be defined, include the .hpp file
# #         # before the code
# #         if $k (elem) $hppClassesSet {
# #             $out ~= '#include "' ~ $prefixSubclass ~ $k ~ '.hpp"';
# #             $out ~= "\n\n";
# #         }
# #         $out ~= $strs[0];
# #         
# #         # Create the class wrapper Cpp file
# #         my Str $fileName =  $k ~ 'Wrapper.cpp';
# #         my $code = $classCppTemplate;
# #         replace $code, "//", "CPP_CLASS_DATA", $out, $km;
# #         spurt CPPDIR ~ $fileName, $code;
# #         
# #         @cppFiles.push($fileName);
# #     }
# 
#     #--------------------------------------------
# 
#     # SubAPI classes code generation
#     
# #     SLOOP: for %c.sort>>.kv -> ($k, $v) {
# #         next SLOOP if !$v.whiteListed || $v.blackListed;
# #         next SLOOP if $v.isQObj;
# # 
# #         my $strs = cpp_subapi_class_gen($api, %exceptions, $k, $v);
# #         $out = $strs[0];
# #         $outSctors ~= $strs[1];
# #         $outSubapi ~= $strs[2];
# #         
# #         # Create the class wrapper Cpp file
# #         my Str $fileName =  $k ~ 'Wrapper.cpp';
# #         my $code = $classCppTemplate;
# #         replace $code, "//", "CPP_CLASS_DATA", $out, $km;
# #         spurt CPPDIR ~ $fileName, $code;
# #         
# #         @cppFiles.push($fileName);
# #     }
# 
#     # Declaration of callbacks pointers
#     for %callbacks.sort>>.kv -> ($n, $m) {
#         my $signature = qSignature($m, showParenth => False);
#         $outCbi ~= "void (*" ~ $n ~ ')' ~ "\n";
#         $outCbi ~= IND ~ '(int32_t objId, const char *slotName'
#                                     ~ $signature ~ ') = 0;' ~ "\n\n";
#     }
# 
#     # Callbacks setup
#     for %callbacks.sort>>.kv -> ($n, $m) {
#         my $name = $n;
#         $name ~~ s/^s/S/;
#         $name = $prefixWrapper ~ 'Setup' ~ $name;
#         my $signature = qSignature($m, showParenth => False);
#         $outCbs ~= "void $name" ~ '(' ~ "\n";
#         $outCbs ~= IND ~ 'void (*f)(int32_t objId, const char *slotName'
#                                                 ~ $signature ~ '))' ~ "\n";
#         $outCbs ~= '{' ~ "\n";
#         $outCbs ~= IND ~ "$n = f;\n";
#         $outCbs ~= '}' ~ "\n\n";
#     }
# 
#     #--------------------------------------------
#     
# 
# 
#     my $code = slurp $templateFileName;
# 
#     # replace $code, "//", "MAIN_CLASSES_CPP_CODE", $out, $km;
#     replace $code, "//", "MAIN_CLASSES_CPP_CODE", "", $km;
# 
# 
#     replace $code, "//", "SIGNALS_DICTIONARY", $outSignals, $km;
#     replace $code, "//", "SLOTS_DICTIONARY", $outSlots, $km;
#     replace $code, "//", "CALLBACKS_SETUP", $outCbs, $km;
#     replace $code, "//", "SUBCLASSES_CTORS", $outSctors, $km;
#     replace $code, "//", "SUBAPI_CLASSES_CPP_CODE", $outSubapi, $km;
#     replace $code, "//", "CALLBACKS_POINTERS_DECLARATION", $outCbi, $km;
#     $code = addHeaderText(code => $code, commentChar => '//');
# 
#     spurt CPPDIR ~ $cppFile, $code;
#     
#     my Str $proFile = slurp "gene/templates/RakuQtWidgets.pro.template";
#     my Str $data = [~] 'SOURCES += ' <<~>> @cppFiles <<~>> "\n";
#     replace $proFile, "#", "LIST_OF_CPP_SOURCES", $data, $km;
#     $data = [~] 'HEADERS += ' <<~>> @hppFiles <<~>> "\n";
#     replace $proFile, "#", "LIST_OF_HPP_SOURCES", $data, $km;
#     spurt CPPDIR ~ PROFILE, $proFile;
#     
#     say "Generate the .cpp file : stop";
#     say "";

}



# Return "xxx::" if a C++ method from class $class and returning an Rtype $ret
# needs it in its declaration.
sub enumQualifier(Str $class, Rtype $ret --> Str)
{
    return "" if $ret.ftot !~~ "ENUM";       # Not an enum
    return "" if qType($ret) ~~ m/ '::' /;   # Already qualified
    return $class ~ "::";                    # Qualifier needed
}


sub generate_callbacks_cpp(%callbacks --> List) is export
{
    my Str $outCbi = "";            # Callbacks init
    my Str $outCbs = "";            # Callbacks setup

    # Declaration of callbacks pointers
    for %callbacks.sort>>.kv -> ($n, $m) {
        my $signature = qSignature($m, showParenth => False);
        $outCbi ~= "void (*" ~ $n ~ ')' ~ "\n";
        $outCbi ~= IND ~ '(int32_t objId, const char *slotName'
                                    ~ $signature ~ ') = 0;' ~ "\n\n";
    }

    # Callbacks setup
    for %callbacks.sort>>.kv -> ($n, $m) {
        my $name = $n;
        $name ~~ s/^s/S/;
        $name = $prefixWrapper ~ 'Setup' ~ $name;
        my $signature = qSignature($m, showParenth => False);
        $outCbs ~= "void $name" ~ '(' ~ "\n";
        $outCbs ~= IND ~ 'void (*f)(int32_t objId, const char *slotName'
                                                ~ $signature ~ '))' ~ "\n";
        $outCbs ~= '{' ~ "\n";
        $outCbs ~= IND ~ "$n = f;\n";
        $outCbs ~= '}' ~ "\n\n";
    }

    return $outCbi, $outCbs;
}  

