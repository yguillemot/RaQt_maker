
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
#   %virtuals : Where all the virtual methods are stored
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
#       - $upcaster : Code of an up_cast function if needed
#
sub generate_cpp(Str $k, Qclass $v, %exceptions, %virtuals,
                    Bool $hasCtor, Bool $hasSubclassCtor, Bool $subclassable,
                    $km = False) is export
{


#     say "Generate the .cpp file : start";
    # say "\n" x 2;

    # Init strings which will be inserted in the template
    my Str $includes = "";          # "#include" lines
    my Str $out;                    # Code of the classes
    my Str $outSignals = "";        # Signals dictionary
    my Str $outSlots = "";          # Slots dictionary
    my Str $upc = "";               # up_cast function code

    my @incl-files;     # List of file names which have to be included 
    
    # $k is the Qt class name
    my Str $wclassname = $prefixWrapper ~ $k;   # Wrapper class name
    my $sclassname = $prefixSubclass ~ $k;      # Wrapper subclass name
    my Str $wsclassname = $prefixSubclassWrapper ~ $k; # Wrapper subclass name
    
    # $k is an abstract top class
    # TODO: This condition is probably not sufficient to cover all the cases
    #       where an explicit upcasting is needed.
    #       Nevertheless, and until a new issue occurs, the explicit upcasting
    #       will be limited to this case only.
    my Bool $isAbstractTopClass = $v.isAbstract && $v.parents.elems == 0;

    # Look for a "#include" exception related to the class
    if %exceptions{$k}{'cpp-include'}:exists {
        # say "EXCEPTION cpp-include : $k";
        @incl-files.append: %exceptions{$k}{'cpp-include'}.trim.lines;
    }

    # Insert an explicit upcasting function if needed
    if $isAbstractTopClass {

        $upc ~= "static $k * up_cast(void * obj, int callerIndex,"
                                              ~ " const char * methodName)\n";
        $upc ~= '{' ~ "\n";
        $upc ~= IND ~ "// methodName parameter is only used to help debugging\n";
        $upc ~= IND ~ "// if an erroneous callerIndex is used.\n";
        $upc ~= IND ~ "// This should never occur and this parameter\n";
        $upc ~= IND ~ "// is going to be removed after some time.\n";
        $upc ~= IND ~ "\n";
        $upc ~= IND ~ 'switch (callerIndex) {' ~ "\n";
        my $i = 0;
        for $v.descendants.sort -> $d {
            $upc ~= IND x 2 ~ 'case ' ~ $i++ ~ " :\n";
            $upc ~= IND x 3 ~ "return dynamic_cast<$k *>(\n";
            $upc ~= IND x 5 ~ "reinterpret_cast<$d *>(obj));\n";
        }
        $upc ~= IND x 2 ~ "default :\n";
        $upc ~= IND x 3 ~ "std::cerr << \"up_cast(\\\"$k\\\") : \"\n";
        $upc ~= IND x 3 ~ "          << \"Unsupported caller index \"\n";
        $upc ~= IND x 3 ~ "          << callerIndex << \" from method \"\n";
        $upc ~= IND x 3 ~ "          << methodName << \"\\n\";\n";
        $upc ~= IND x 3 ~ "return nullptr;        // Force a crash\n";
        $upc ~= IND ~ '}' ~ "\n";
        $upc ~= "}\n";
        $upc ~= "\n";
    }


    MLOOP: for $v.methods -> $m {
        next MLOOP if !$m.whiteListed || $m.blackListed;

#         my Bool $overriding = %virtuals{$m.name}:exists
#                                             && %virtuals{$m.name}[0] ~~ $k;
        my Bool $overriding = %virtuals{$m.name}:exists;
        # TODO : Maybe the signature of the method should be tested

        next MLOOP if $overriding && !$m.isSlot;
                                            # v0.0.5: added exception for slots

        next MLOOP if $m.isProtected;
        # Probably an overriding method whose virtual parent is not in the
        # white list.

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
                ~ cSignature($m, showObjectPointer => !$m.isStatic,
                                      showCIdx => $isAbstractTopClass) ~ "\n";
            $out ~= "\{\n";
            
            # A static method doesn't need an object pointer
            if !$m.isStatic {
                $out ~= IND ~ "$k * ptr = ";
                if $isAbstractTopClass {
                    $out ~= "up_cast(obj, callerIdx, \"" ~ $m.name ~ "\");\n";
                } else {
                    $out ~= "reinterpret_cast<$k *>(obj);\n";
                }
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
            if $retType ne "void" || retBufNeeded($m) {
                my Str $qualif = enumQualifier($k, $rt);
                $out ~= trim($rt.const ~ " " ~ $qualif
                                       ~ qType($rt) ~ " " ~ qPostop($rt))
                        ~ " retVal = ";
            }
            
            if $m.isStatic {
                $out ~= $k ~ "::" ~ $m.name;
            } else {
                $out ~= "ptr->" ~ $m.name
            }
            $out ~= qCallUse($m, "x") ~ ";\n";
            
            # If a return buffer is used, copy the returned string to it 
            if retBufNeeded($m) {
                $out ~= IND ~ 'if (!retVal.isNull()) {' ~ "\n";
                $out ~= IND x 2 ~ 'QWStrBufferWrite(retBuffer, retVal.toUtf8().data());' ~ "\n";
                $out ~= IND ~ '}' ~ "\n";
                
                # A specific file have to be included
                @incl-files.push: '"StrBuffer.h"';
            }

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
    
    if $subclassable {
        @incl-files.push: "\"$k.hpp\"";
    } else {
        @incl-files.push: "\"$k.h\"";
    }
    
    # Generate the #include statements
    $includes = [~] "#include " <<~>> @incl-files.Seq.values.sort <<~>> "\n"; 
    $includes ~= "\n";
    
    return $includes, $out, $outSignals, $outSlots, $upc;
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
        $outCbi ~= qRet($m) ~ " (*" ~ $n ~ ')' ~ "\n";
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
        $outCbs ~= IND ~ qRet($m)
                            ~ ' (*f)(int32_t objId, const char *slotName'
                                                    ~ $signature ~ '))' ~ "\n";
        $outCbs ~= '{' ~ "\n";
        $outCbs ~= IND ~ "$n = f;\n";
        $outCbs ~= '}' ~ "\n\n";
    }

    return $outCbi, $outCbs;
}  

