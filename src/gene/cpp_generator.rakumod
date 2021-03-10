
# Generate the .cpp file

use gene::config;
use gene::common;
use gene::replace;
use gene::conversions;
use gene::exceptions;
use gene::addHeader;

# $api : The Qt API description (the output of the parser with the black and
# white info marks added)
# %callbacks : The list of callbacks precomputed by the hpp_generator
# $outFileName : The name of the output file
# $km : The keepMarkers flag (see the replace module)
sub cpp_generator(API $api, %exceptions, %callbacks, $km = False) is export
{

    my Str $templateFileName = "gene/templates/QtWidgetsWrapper.cpp.template";
    my %c = $api.qclasses;

    say "Generate the .cpp file : start";
    # say "\n" x 2;

    # Init strings which will be inserted in the template
    my Str $out = "";               # Code of the main classes (Qobjects)
    my Str $outSignals = "";        # Signals dictionary
    my Str $outSlots = "";          # Slots dictionary
    my Str $outCbi = "";
    my Str $outCbs = "";
    my Str $outSctors = "";
    my Str $outSubapi = "";


    # Main classes code generation
    
    CLOOP: for %c.sort>>.kv -> ($k, $v) {
        next CLOOP if !$v.whiteListed || $v.blackListed;
        next CLOOP if !$v.isQObj;

        # say "Class : ", $k;

        # $k is the Qt class name
        my Str $wclassname = $prefixWrapper ~ $k;   # Wrapper class name
        my $sclassname = $prefixSubclass ~ $k;      # Wrapper subclass name
        my Str $wsclassname = $prefixSubclassWrapper ~ $k; # Wrapper subclass name
        my Bool $hasCtor = False;
        my Bool $hasSubclassCtor = False;
        my Bool $subclassable = ?vmethods($api, $k).elems; # $k is subclassable

        MLOOP: for $v.methods -> $m {
            next MLOOP if !$m.whiteListed || $m.blackListed;
            next if $m.isVirtual;

            # Look for exception
            my $exk = $k ~ '::' ~ $m.name ~ qSignature($m, showNames => False);
            # say "?EXCEPTION $exk";
            if %exceptions{$exk}{'cpp'}:exists {
                # say "EXCEPTION cpp 1 : $exk";
                $out ~= %exceptions{$exk}{'cpp'};
                next MLOOP;
            }


            my $number = $m.number ?? '_' ~ $m.number !! "";

            if $m.name ~~ "ctor" {
                # say "ctor$number : ", qSignature($m);
                $hasCtor = True;

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
                    $hasSubclassCtor = True;
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
                        $out ~= IND ~ $pc ~ "\n";
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

    #--------------------------------------------

    # SubAPI classes code generation
    
    SLOOP: for %c.sort>>.kv -> ($k, $v) {
        next SLOOP if !$v.whiteListed || $v.blackListed;
        next SLOOP if $v.isQObj;

        # say "Class : ", $k;

        # $k is the Qt class name
        my Str $wclassname = $prefixWrapper ~ $k;   # Wrapper class name
        my Bool $hasCtor = False;

        MLOOP: for $v.methods -> $m {
            next MLOOP if !$m.whiteListed || $m.blackListed;

            # Look for exception
            my $exk = $k ~ '::' ~ $m.name ~ qSignature($m, showNames => False);
            # say "?EXCEPTION $exk";
            if %exceptions{$exk}{'cpp'}:exists {
                # say "EXCEPTION cpp 2 : $exk";
                $outSubapi ~= %exceptions{$exk}{'cpp'};
                next MLOOP;
            }

            my $number = $m.number ?? '_' ~ $m.number !! "";

            if $m.name ~~ "ctor" {
                # say "ctor$number : ", qSignature($m);
                $hasCtor = True;

                $outSctors ~= "void * " ~ $wclassname ~ $suffixCtor
                                            ~ $number ~ cSignature($m) ~ "\n";
                $outSctors ~= '{' ~ "\n";


                for $m.arguments -> $a {
                    my $tot = $a.ftot ~~ "COMPOSITE"
                                ?? $a.subtype.ftot
                                !! $a.ftot;
                    $outSctors ~= IND;
                    $outSctors ~= precall($k, $tot,
                                    cType($a), cPostop($a), $a.fname,
                                    qType($a), qPostop($a), 'x' ~ $a.fname);
                    $outSctors ~= "\n";
                }


                $outSctors ~= IND ~ $k ~ " * ptr = new "
                                            ~ $k ~ qCallUse($m, "x") ~ ";\n";
                $outSctors ~= IND ~ "return reinterpret_cast<void *>(ptr);\n";
                $outSctors ~= "}\n\n";

            } else {

                # say qProto($m);
                my $rt = $m.returnType;
                my $retType = trim cRetType $m;
                # say "CRETTYPE : $retType";
                $outSubapi ~= $retType ~ " " ~ $wclassname
                                ~ $m.name ~ $number ~ cSignature($m) ~ "\n";
                $outSubapi ~= "\{\n";
                $outSubapi ~= IND ~ "$k * ptr = reinterpret_cast<$k *>(obj);\n";

                for $m.arguments -> $a {
                    my $tot = $a.ftot ~~ "COMPOSITE"
                                ?? $a.subtype.ftot
                                !! $a.ftot;
                    $outSubapi ~= IND;
                    $outSubapi ~= precall($k, $tot,
                                        cType($a), cPostop($a), $a.fname,
                                        qType($a), qPostop($a), 'x' ~ $a.fname);
                    $outSubapi ~= "\n";
                }

                $outSubapi ~= IND;
                if $retType ne "void" {
                    my Str $qualif = enumQualifier($k, $rt);
                    $outSubapi ~= $rt.const ~ " " ~ $qualif ~ qType($rt)
                                        ~ " " ~ qPostop($rt) ~ " retVal = ";
                }
                $outSubapi ~= "ptr->" ~ $m.name ~ qCallUse($m, "x") ~ ";\n";

                for $m.arguments -> $a {
                    my $tot = $a.ftot ~~ "COMPOSITE"
                                ?? $a.subtype.ftot
                                !! $a.ftot;
                    my $pc = postcall($m.name, $k, $tot, "arg",
                                qType($a), qPostop($a), $a.const, 'x' ~ $a.fname,
                                cType($a), cPostop($a), $a.fname);
                    $outSubapi ~= IND ~ $pc ~ "\n" if $pc ne "";
                }
                if $retType ne "void" { 
                    my $pc = postcall($m.name, $k, $rt.ftot, "ret",
                                      qType($rt), qPostop($rt), $rt.const, "retVal",
                                      cType($rt), cPostop($rt), "xretVal");
                    if $pc ~~ "" {
                        $outSubapi ~= IND ~ "return retVal;\n";
                    } else {
                        $outSubapi ~= IND ~ $pc ~ "\n";
                        $outSubapi ~= IND ~ "return xretVal;\n";
                    }
                }
                $outSubapi ~= "}\n";
                $outSubapi ~= "\n";
            }
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
        
    }

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

    #--------------------------------------------
    


    my $code = slurp $templateFileName;

    replace $code, "//", "MAIN_CLASSES_CPP_CODE", $out, $km;
    replace $code, "//", "SIGNALS_DICTIONARY", $outSignals, $km;
    replace $code, "//", "SLOTS_DICTIONARY", $outSlots, $km;
    replace $code, "//", "CALLBACKS_SETUP", $outCbs, $km;
    replace $code, "//", "SUBCLASSES_CTORS", $outSctors, $km;
    replace $code, "//", "SUBAPI_CLASSES_CPP_CODE", $outSubapi, $km;
    replace $code, "//", "CALLBACKS_POINTERS_DECLARATION", $outCbi, $km;
    $code = addHeaderText(code => $code, commentChar => '//');

    spurt $cppFile, $code;

    say "Generate the .cpp file : stop";
    say "";

}


# Return "xxx::" if a C++ method from class $class and returning an Rtype $ret
# needs it in its declaration.
sub enumQualifier(Str $class, Rtype $ret --> Str)
{
    return "" if $ret.ftot !~~ "ENUM";       # Not an enum
    return "" if qType($ret) ~~ m/ '::' /;   # Already qualified
    return $class ~ "::";                    # Qualifier needed
}

