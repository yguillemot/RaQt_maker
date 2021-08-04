
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

# Inputs :
#   $k : Class name
#   $v : Class description
#   %exceptions : Where all the exceptions are stored
#   $hasCtor : True if class has a constructor
#   $hasSubclassCtor : True if the class has a subclass constructor
#   $subclassable : True if the class may be subclassed
#   $km : If true, keep the insertion marks in the generated file
#
# Outputs :
#   Returns a list of 4 strings:
#       - $includes : The "#include" lines of code
#       - $out : The main code
#       - $outSignals : Code for the signals dictionnary
#       - $outSlots : Code for the slots dictionnary
#
sub generate_cpp(Str $k, Qclass $v, %exceptions,
                    Bool $hasCtor, Bool $hasSubclassCtor, Bool $subclassable,
                    $km = False) is export
{

#     my Str $templateFileName = "gene/templates/QtWidgetsWrapper.cpp.template";
#     my Str $classCppTemplate = 
#                         slurp "gene/templates/QClassWrapper.cpp.template";

#     say "Generate the .cpp file : start";
    # say "\n" x 2;

    # Init strings which will be inserted in the template
    my Str $includes = "";          # List "#include" lines
    my Str $out;                    # Code of the classes
    my Str $outSignals = "";        # Signals dictionary
    my Str $outSlots = "";          # Slots dictionary
#     my Str $outSctors = "";
#     my Str $outSubapi = "";
    
    
    # $k is the Qt class name
    my Str $wclassname = $prefixWrapper ~ $k;   # Wrapper class name
    my $sclassname = $prefixSubclass ~ $k;      # Wrapper subclass name
    my Str $wsclassname = $prefixSubclassWrapper ~ $k; # Wrapper subclass name
    
    
    # Look for a "#include" exception related to the class
    if %exceptions{$k}{'cpp-include'}:exists {
        # say "EXCEPTION cpp-include : $k";
        $includes ~= %exceptions{$k}{'cpp-include'};
    }
    
    # if $v.isQObj {    ### NO MORE NEEDED
    if True {

        # Main Qt class (QWidget, QPushButton, QVBoxlayout, etc...)
    
        MLOOP: for $v.methods -> $m {
            next MLOOP if !$m.whiteListed || $m.blackListed;
            
            next if $m.isVirtual;  ###  Always ???
    
            # Look for an exception related to the method
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
                    my $pc = precall($k, $tot,
                                    cType($a), cPostop($a), $a.fname,
                                    qType($a), qPostop($a), 'x' ~ $a.fname);
                    $txt1 ~= indent($pc, IND);
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
                $out ~= $retType ~ " " ~ $wclassname ~ $m.name ~ $number
                    ~ cSignature($m, showObjectPointer => !$m.isStatic) ~ "\n";
                $out ~= "\{\n";
                
                # A static method doesn't need an object pointer
                if !$m.isStatic {
                    $out ~= IND ~ "$k * ptr = reinterpret_cast<$k *>(obj);\n";
                }

                for $m.arguments -> $a {
                    my $tot = $a.ftot ~~ "COMPOSITE"
                                ?? $a.subtype.ftot
                                !! $a.ftot;
                    my $pc = precall($k, $tot,
                                     cType($a), cPostop($a), $a.fname,
                                     qType($a), qPostop($a), 'x' ~ $a.fname);
                    $out ~= indent($pc, IND);
                    $out ~= "\n";
                }

                $out ~= IND;
                if $retType ne "void" {
                    my Str $qualif = enumQualifier($k, $rt);
                    $out ~= $rt.const ~ " " ~ $qualif ~ qType($rt)
                            ~ " " ~ qPostop($rt) ~ " retVal = ";
                }
                
                if $m.isStatic {
                    $out ~= $k ~ "::" ~ $m.name;
                } else {
                    $out ~= "ptr->" ~ $m.name
                }
                $out ~= qCallUse($m, "x") ~ ";\n";

                for $m.arguments -> $a {
                    my $tot = $a.ftot ~~ "COMPOSITE"
                                ?? $a.subtype.ftot
                                !! $a.ftot;
                    my $pc = postcall($m.name, $k, $tot, "arg",
                            qType($a), qPostop($a), $a.const, 'x' ~ $a.fname,
                            cType($a), cPostop($a), $a.fname);
                    $out ~= indent($pc, IND) ~ "\n" if $pc ne "";
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
    
    if $subclassable {
        $includes ~= "#include \"$k.hpp\"" ~ "\n";
    } else {
        $includes ~= "#include \"$k.h\"" ~ "\n";
    }
    $includes ~= "\n";

    return $includes, $out, $outSignals, $outSlots;
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

