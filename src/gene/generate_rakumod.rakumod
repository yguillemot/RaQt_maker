 
use config;
use gene::common;
use gene::natives;
use gene::replace;
use gene::addHeaderText;
use gene::ToRakuConversions;

sub versionedName(Str $name --> Str)
{
    $name ~ ":ver<{MODVERSION}>" ~ ":auth<{MODAUTH}>" ~ ":api<{MODAPI}>"
}

sub generate_rakumod(Str $k, Qclass $v, %c, %exceptions,
                    Bool $hasCtor, Bool $hasSubclassCtor, Bool $subclassable,
                    %virtuals, :$km = False) is export
{

#     say "Generate the .rakumod file : start";
#     say "Class $k";
    
    my Bool $noCtor = $k (elem) $uninstanciableClasses;
    
    my Str $outqtclasses = "";
    my Str $outSignals = "";
    my Str $outSlots = "";
    my Str $outmain = "### Beginning of the main API part ###";
    my Str $outStubs = "";
    my Str $outNatives = "### Beginning of the main API part ###\n";
    my Str $outcbini = "";    # %callbacks initialisation code
    
    
    $outqtclasses ~= $k ~ "\n";

    my Str $outn = "";          # Native declarations output
    my Str $outm = "";          # Main methods output
    my Str $outu;               # "use" and other declarations
    my Str $outr = "";          # Role definition output

    # $k is the Qt class name
    my Str $wclassname = $prefixWrapper ~ $k;   # Wrapper class name
    my Str $pclassname = $k;                    # Perl module class name
    my Str $wsclassname = $prefixSubclassWrapper ~ $k; # Wrapper subclass name

    
    
    my @rRefs;   # List of Qt roles used in the code
    my @qRefs;   # List of Qt classes used in the code
    
    
    if %exceptions{$k}{'use'}:exists {
        # say "EXCEP USE : $k";
#         say '>>>>>>>'; say %exceptions{$k}{'use'}; say '-------';
        @qRefs.append: qqw{%exceptions{$k}{'use'}};
#         say [~] @qRefs <<~>> ' '; say '<<<<<<<';
    }
    
    
    $outm ~= "\n";
    $outm ~= "class {versionedName($pclassname)}";
    
    if $v.isQObj { 
        # To import QtSigsloty is needed if signals or slots are  defined
        # QtSigsloty is exported from QtWidgets.rakumod
        @qRefs.push: "QtSigsloty";
    }

    my Str $prole = $v.isQObj ?? PREFIXROLE !! "";
    
    my Bool $haveParents = False;
    for $v.parents -> $p {
        $outm ~= "\n{IND}is $p";
        $haveParents = True;
        @qRefs.push: $p;
    }
    
    
    
    if !$haveParents && !$noCtor {
        $outm ~= "\n{IND}is QtBase";
        @qRefs.push: "QtBase";
    }
    
    if !$noCtor && $v.isQObj {
        $outm ~= "\n{IND}does {PREFIXROLE}$k" ;
        @rRefs.push: $k;
        
        $outr ~= '# Work around the "circular module loading" issue' ~ "\n";
        $outr ~= "\n";
        $outr ~= "role {PREFIXROLE}{versionedName($k)} \{\n";
        $outr ~= "}\n";
    }
    
    $outm ~= "\n{IND}is export \{\n";                     # Start of class block
    $outm ~= "\n";

    # Define enums if any
    $outm ~= writeEnumsCode($v);

    
    if $v.isQObj && !$noCtor {
        # Declare handlers for virtual methods if any
        if $v.validVirtuals.elems {    # Have virtual methods ?
            $outcbini ~= IND ~ '%callbacks<' ~ $k ~ '> = <' ~ "\n";
            for $v.validVirtuals -> $m {
                $outcbini ~= IND x 2 ~ $m.name ~ "\n";
            }
            $outcbini ~= IND ~ ">;\n";
        }
    }
    
    
    # Generate ctors if valid ctors exists
    my @ctors = ();
    for $v.methods -> $m {
        if $m.whiteListed && !$m.blackListed && $m.name ~~ "ctor" {
            @ctors.push($m);
        }
    }
    if @ctors.elems {
#         say "CTOR : ";

        my $cbv_already_declared = False;       # cbv: "callbacks validation"
        CTORLOOP: for @ctors -> $ctor {
            my $ctorNum = $ctor.number ?? '_' ~ $ctor.number !! "";

#             say "    ", $wclassname ~ $suffixCtor ~ $ctorNum
#                                                     ~ qSignature($ctor);


            my $exk = $k ~ '::ctor' ~ qSignature($ctor, :!showNames);
            if %exceptions{$exk}{'rakumod'}:exists {
                # say "EXCEP RAKUMOD 1 : $exk";
                if %exceptions{$exk}{'wrappers'}:exists {
                    # say "EXCEP WRAPPERS 1 : $exk";
                    $outn ~= %exceptions{$exk}{'wrappers'};
                }
                $outm ~= %exceptions{$exk}{'rakumod'};
            } else {

                # Declaration of the native wrapper
                $outn ~= "sub " ~ $wclassname ~ $suffixCtor ~ $ctorNum
                                ~ strNativeWrapperArgsDecl($ctor) ~ "\n";
                $outn ~= IND ~ "returns Pointer is native(\&libwrapper)";
                $outn ~= " \{ * }\n";
                $outn ~= "\n";

                # Subroutine(s) ctor calling the native wrapper
                $outm ~= IND ~ "multi sub ctor"
                                ~ strArgsRakuCtorDecl($ctor, %c, :useRole)
                                ~ " \{\n";

                my ($pc, $o) = rakuWrapperCallElems($ctor);
                for classesInSignature($ctor) -> $cl {
                    # say "CL = '$cl'";
                    if %c{$cl}.isQObj {
                        @rRefs.push: $cl;
                    } else {
                        @qRefs.push: $cl;
                    }
                }

                $outm ~= [~] (IND x 2) <<~>> $pc;
                $outm ~= IND x 2 ~ '$this.address = '
                            ~ "$wclassname$suffixCtor$ctorNum$o;" ~ "\n";
                $outm ~= IND x 2 ~ '$this.ownedByRaku = True;' ~ "\n";
                $outm ~= IND ~ "}\n";
                $outm ~= "\n";
                

                # For documentation
                #   Raku method name : new
                #   Raku signature : $o
                #   Qt method name : $k
                #   Qt signature : qSignature($ctor, showDefault => True)

                    
                if $v.isQObj {
                    # Declaration of the native subclass wrapper
                    $outn ~= "sub " ~ $wsclassname ~ $suffixCtor ~ $ctorNum
                                    ~ strNativeWrapperArgsDecl($ctor) ~ "\n";
                    $outn ~= IND ~ "returns Pointer is native(\&libwrapper)";
                    $outn ~= " \{ * }\n";
                    $outn ~= "\n";

                    # Subroutine(s) ctor calling the native subclass wrapper
                    $outm ~= IND ~ "multi sub subClassCtor"
                                    ~ strArgsRakuCtorDecl($ctor, %c, :useRole)
                                    ~ " \{\n";

                    ($pc, $o) = rakuWrapperCallElems($ctor);
                    
                    for classesInSignature($ctor) -> $cl {
                        if %c{$cl}.isQObj {
                            @rRefs.push: $cl;
                        } else {
                            @qRefs.push: $cl;
                        }
                    }

                    $outm ~= [~] (IND x 2) <<~>> $pc;
                    $outm ~= IND x 2 ~ '$this.address = '
                                ~ "$wsclassname$suffixCtor$ctorNum$o;" ~ "\n";
                    $outm ~= IND x 2 ~ '$this.ownedByRaku = True;' ~ "\n";
                    $outm ~= IND ~ "}\n";
                    $outm ~= "\n";

        # TODO???: Move this code after the loop rather than to use "next"
                    # Only defined once the validation method and its wrapper
                    next CTORLOOP if $cbv_already_declared;
                    $cbv_already_declared = True;

                    # Declaration of the callbacks validation method wrapper
                    $outn ~= "sub " ~ $prefixWrapper ~ 'validateCB_' ~ $k
                                        ~ '(Pointer, int32, Str)' ~ "\n";
                    $outn ~= IND ~ "is native(\&libwrapper)" ~ " \{ * }\n";
                    $outn ~= "\n";

                    # Declaration of the callbacks validation method
                    $outm ~= IND ~ 'method validateCB(Str $m) {' ~ "\n";
                    # $outm ~= IND x 2 ~ 'say "validateCB ' ~ $k ~ '";' ~ "\n";
                    $outm ~= IND x 2 ~ $prefixWrapper ~ 'validateCB_' ~ $k
                                ~ '(self.address, self.id, $m);' ~ "\n";
                    $outm ~= IND ~ "}\n";
                    $outm ~= "\n";
                }
                    
                    
            }
        }       # CTORLOOP
    
        # Add the submethod "new" creating a Raku object from an existent
        # Qt one.
        # The $obr named argument is here to allow working in the case
        # the Qt object has been created on the stack and a copy on the
        # heap of this object has been done in the native wrapper,
        # creating an object owned by Raku from an object owned by Qt.
        #
        # Note : Pointer type must be "NativeCall::Types::Pointer".
        # The sub won't be called if type "Pointer" is only specified...
        #
        $outm ~= IND ~ 'multi sub ctor(QtBase $this, '
                            ~ 'NativeCall::Types::Pointer $p, '
                            ~ 'Bool :$obr = False) {' ~ "\n";
        $outm ~= IND x 2 ~ '# Get access to a preexisting Qt object' ~ "\n";
        $outm ~= IND x 2 ~ '$this.address = $p;' ~ "\n";
        $outm ~= IND x 2 ~ '$this.ownedByRaku = $obr;' ~ "\n";
        $outm ~= IND ~ '}' ~ "\n";
        $outm ~= "\n";
        @qRefs.push: "QtBase";

        # Default Subroutine ctor
        $outm ~= IND ~ 'multi sub ctor(|capture) {' ~ "\n";
        $outm ~= IND x 2 ~ 'note "QtWidgets ", ::?CLASS.^name,' ~ "\n";
        $outm ~= IND x 2 ~ '     " ctor called with unsupported args";' ~ "\n";
        $outm ~= IND x 2 ~ 'die "Bad args";' ~ "\n";
        $outm ~= IND ~ "}\n";
        $outm ~= "\n";

        # Submethod new
        $outm ~= IND ~ 'submethod new(|capture) {' ~ "\n";
        $outm ~= IND x 2
                    ~ 'my ' ~ $k ~ ' $rObj = self.bless;' ~ "\n";
        $outm ~= IND x 2 ~ 'ctor($rObj, |capture);' ~ "\n";
        $outm ~= IND x 2 ~ 'return $rObj;' ~ "\n";
        $outm ~= IND ~ "}\n";  
        $outm ~= "\n";
        
        if $v.isQObj {
            # Default Subroutine subclass ctor
            $outm ~= IND ~ 'multi sub subClassCtor(|capture) {' ~ "\n";
            $outm ~= IND x 2 ~ 'note "QtWidgets subclass ", ::?CLASS.^name,' ~ "\n";
            $outm ~= IND x 2 ~ '     " ctor called with unsupported args";' ~ "\n";
            $outm ~= IND x 2 ~ 'die "Bad args";' ~ "\n";
            $outm ~= IND ~ "}\n";
            $outm ~= "\n";

            # Submethod subClass
            $outm ~= IND ~ 'submethod subClass(|capture) {' ~ "\n";
            $outm ~= IND x 2 ~ 'subClassCtor(self, |capture);' ~ "\n";
            $outm ~= IND x 2 ~ 'self.validateCallBacks();' ~ "\n";
            $outm ~= IND ~ "}\n";
            $outm ~= "\n";
        }
        
    } else {
    
        # Not CTOR
    
        if $v.isQObj {
        
            # Class has no valid ctor : new will exit with an error message
            $outm ~= IND ~ 'submethod new(|capture) is hidden-from-backtrace {'
                            ~ "\n";
            $outm ~= IND x 2 ~ 'unimplementedCtor("' ~ $k ~ '");' ~ "\n";
            $outm ~= IND ~ "}\n";
            $outm ~= "\n";
            
        } elsif !$noCtor {
        
            # Add the new submethod creating a Raku object from an existent Qt one
            # Note : Pointer type must be "NativeCall::Types::Pointer".
            # Sub isn't called if type "Pointer" is only specified...
            $outm ~= IND ~ 'multi sub ctor(QtBase $this, '
                                ~ 'NativeCall::Types::Pointer $p) {' ~ "\n";
            $outm ~= IND x 2 ~ '# Get access to a preexisting Qt object' ~ "\n";
            $outm ~= IND x 2 ~ '$this.address = $p;' ~ "\n";
            $outm ~= IND x 2 ~ '$this.ownedByRaku = False;' ~ "\n";
            $outm ~= IND ~ '}' ~ "\n";
            $outm ~= "\n";
            @qRefs.push: "QtBase";

            # Default Subroutine ctor
            $outm ~= IND ~ 'multi sub ctor(|capture) is hidden-from-backtrace {' ~ "\n";
            $outm ~= IND x 2 ~ 'unimplementedCtor("' ~ $k ~ '");' ~ "\n";
            $outm ~= IND ~ "}\n";
            $outm ~= "\n";

            # Submethod new
            $outm ~= IND ~ 'submethod new(|capture) {' ~ "\n";
            $outm ~= IND x 2
                        ~ 'my ' ~ $k ~ ' $rObj = self.bless;' ~ "\n";
            $outm ~= IND x 2 ~ 'ctor($rObj, |capture);' ~ "\n";
            $outm ~= IND x 2 ~ 'return $rObj;' ~ "\n";
            $outm ~= IND ~ "}\n";
            $outm ~= "\n";
            
        } else {
            # uninstanciable class : do nothing
        }
    }

        # DESTROY submethod
#     say "Generate DESTROY ?   ctors.elems = ", @ctors.elems;
    if @ctors.elems {
        $outm ~= IND ~ 'submethod DESTROY {' ~ "\n";
        $outm ~= IND x 2 ~ 'if self.ownedByRaku {' ~ "\n";
        $outm ~= IND x 3
                    ~ $wclassname ~ $suffixDtor ~ '(self.address);' ~ "\n";
        $outm ~= IND x 3 ~ 'self.ownedByRaku = False;' ~ "\n";
        $outm ~= IND x 2 ~ '}' ~ "\n";
        $outm ~= IND ~ '}' ~ "\n";
        $outm ~= "\n";
        
        # Declaration of the native dtor wrapper
        $outn ~= "sub " ~ $wclassname ~ $suffixDtor ~ '(Pointer)' ~ "\n";
        $outn ~= IND ~ "is native(\&libwrapper)" ~ " \{ * }\n";
        $outn ~= "\n";
    }
    
    
    # Generate methods and slots

    for $v.methods -> $m {
        next if $m.blackListed || !$m.whiteListed;
        next if $m.isSignal || $m.name ~~ "ctor";
        next if $m.isVirtual && !$m.isSlot;     # !$m.isSlot since v0.0.5
        
#         say "Generate method ", $m.name;

        my $exk = $k ~ '::' ~ $m.name ~ qSignature($m, :!showNames);
        if %exceptions{$exk}{'rakumod'}:exists {
            # say "EXCEP RAKUMOD 2 : $exk";
            if %exceptions{$exk}{'wrappers'}:exists {
#                 say "EXCEP WRAPPERS 2 : $exk";
                $outn ~= %exceptions{$exk}{'wrappers'};
            }
            $outm ~= %exceptions{$exk}{'rakumod'};
        } else {

            # Declaration of the native wrapper
            my $wrapperName = $wclassname ~ $m.name
                        ~ ($m.number ?? "_" ~ $m.number !! "");
            $outn ~= "sub " ~ $wrapperName
                        ~ strNativeWrapperArgsDecl($m) ~ "\n";
            $outn ~= IND;
            if qRet($m) !~~ "void" && !retBufNeeded($m) {
                $outn ~= "returns " ~ nType($m.returnType) ~ " ";
            }
            $outn ~= "is native(\&libwrapper)";
            $outn ~= " \{ * }\n";
            $outn ~= "\n";
            
            
            if $v.isQObj && $m.isSlot {
                # say "SLOT ", $k, "::", $m.name, qSignature($m);
                # say "SLOT ";

                # say "GENERATING SLOT ", $m.name;

                # my $qualifiedClass = RAQTNAME ~ '::' ~ $k;
                my $qualifiedClass = $k;

                $outSlots ~=
                    IND ~ '%slots<' ~ $qualifiedClass ~ '>.push(SigSlot.new(' ~ "\n"
                    ~ IND x 2 ~ 'name => "' ~ $m.name ~ '",' ~ "\n"
                    ~ IND x 2 ~ 'sig => "' ~ rSignature($m) ~ '",' ~ "\n"
                    ~ IND x 2 ~ 'qSig => "'
                            ~ qSignature($m, showNames => False) ~ '",' ~ "\n"
                    ~ IND x 2 ~ 'signature => :'
                            ~ rSignature($m, :noEnum) ~ ',' ~ "\n"
                    ~ IND x 2 ~ 'sigIsSimple => True,' ~ "\n"
                    ~ IND x 2 ~ 'isPlainQt => True,' ~ "\n"
                    ~ IND x 2 ~ 'isSlot => True,' ~ "\n"
                    ~ IND ~ '));' ~ "\n";
                    
                # Note: Currently, an enum name is replaced with "Int" in
                #       the "signature" field (:noEnum parameter of rSignature).
                #       This avoids problems with enums defined in some Qt class
                #       unknown from QtHelpers module where the %slots global
                #       hash is initialised. 
            }

            
            # Call of the native wrapper
            $outm ~= IND ~ ($m.number ?? "multi method" !! "method") ~ " ";
            $outm ~= $m.name;
            $outm ~= strRakuArgsDecl($m, %c, :useRole)
                            ~ ($m.isSlot ?? " is QtSlot" !! "") ~ "\n";
            $outm ~= IND ~ "\{\n";
            
            # If the method returns a Qt class, to instantiate an
            # associated raku object will be needed and the "use QXxx"
            # instruction have to be added.
            # (Having simultaneously "use QXxx" and "use RQXxx" is
            # not harmful if not useful.)
            my Str $cr = classeReturned($m);
            @qRefs.push: $cr if $cr;
            
            for classesInSignature($m) -> $cl {
                if %c{$cl}.isQObj {
                    @rRefs.push: $cl;
                } else {
                    @qRefs.push: $cl;
                }
            }


            # PROVISIONAL (TODO) !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            # (WAITING FOR A TRUE CORRECT HANDLING)
            if $m.returnType.ftot ~~ "ENUM" {
                if $m.returnType.fpostop !~~ "" {
                    die "Class ", $v.name, " method ", $m.name, "\n",
                        "   returns an enum with ", $m.returnType.fpostop,
                                " postop.\n",
                        "   Such a return is currently unsupported.";
                }
            }


            my ($pc, $o) = rakuWrapperCallElems($m);
            my Bool $returnSomething = qRet($m) !~~ "void";
            $outm ~= [~] (IND x 2) <<~>> $pc;

            # $outm ~= "say \"Before calling $wrapperName\";\n";

            $outm ~= IND x 2
                        ~ ( $returnSomething && !retBufNeeded($m)
                                ?? 'my $result = '
                                !! '' )
                        ~ $wrapperName ~ $o ~ ";\n";

            if $returnSomething {
                if !retBufNeeded($m) {
                    my $rt = $m.returnType;
                    my $poc = postcall_raku('$result', $rt.ftot,
                                                                qPostop($rt),
                                            '$result1', rType($rt));               
                    if $poc {
                        $outm ~= IND x 2 ~ $poc ~ "\n";
                        $outm ~= IND x 2 ~ 'return $result1;' ~ "\n";
                    } else {
                        $outm ~= IND x 2 ~ 'return $result;' ~ "\n";
                    }
                } else {
                    $outm ~= IND x 2 ~ 'my Str $returnedString ='
                                    ~ ' QWStrBufferRead($retBuffer);' ~ "\n";
                    $outm ~= IND x 2 ~ 'QWStrBufferFree($retBuffer);' ~ "\n";
                    $outm ~= IND x 2 ~ 'return $returnedString;' ~ "\n";
                }
            }

            $outm ~= IND ~ "}\n";                       # End of method
            $outm ~= "\n";
        }
    }
                
    if $v.isQObj {
        # Generate signals
        for $v.methods -> $m {
            next if $m.blackListed || !$m.whiteListed;
            next if !$m.isSignal;
            
# say "GENERATING SIGNAL ", $m.name;
# for $m.arguments -> $a {
#     say "\tname ", $a.name, " ", $a.base, " ", $a.ftot, " ", $a.fbase;
#     say "\tfname : ", $a.fname;
#     say "\trType : ", rType($a);
# }
            my $trait = $m.isPrivateSignal ?? "is QtPrivateSignal" !! "is QtSignal";
            # my $qualifiedClass = RAQTNAME ~ '::' ~ $k;
            my $qualifiedClass = $k;

            $outm ~= IND ~ "method " ~ $m.name
                            ~ strRakuArgsDecl($m, %c, :useRole)
                            ~ "\n";
            $outm ~= IND x 2 ~ "$trait \{ ... }\n";
            $outm ~= "\n";

            for classesInSignature($m) -> $cl {
                if %c{$cl}.isQObj {
                    @rRefs.push: $cl;
                } else {
                    @qRefs.push: $cl;
                }
            }

            $outSignals ~=
                IND ~ '%signals<' ~ $qualifiedClass ~ '>.push(SigSlot.new(' ~ "\n"
                ~ IND x 2 ~ 'name => "' ~ $m.name ~ '",' ~ "\n"
                ~ IND x 2 ~ 'sig => "' ~ rSignature($m) ~ '",' ~ "\n"
                ~ IND x 2 ~ 'qSig => "'
                        ~ qSignature($m, showNames => False) ~ '",' ~ "\n"
                ~ IND x 2 ~ 'signature => :' ~ rSignature($m) ~ ',' ~ "\n"
                ~ IND x 2 ~ 'sigIsSimple => True,' ~ "\n"
                ~ IND x 2 ~ 'isPlainQt => True,' ~ "\n"
                ~ IND x 2 ~ 'isSlot => False,' ~ "\n"
                ~ IND x 2 ~ 'isPrivate => '
                                    ~ ($m.isPrivateSignal ?? 'True' !! 'False')
                                    ~ "\n"
                ~ IND ~ '));' ~ "\n";
        }
    } # if $v.isQObj


# say "<<<OUTSIGNALS OUTSIGNALS OUTSIGNALS OUTSIGNALS OUTSIGNALS ";
# say $outSignals;
# say ">>>OUTSIGNALS OUTSIGNALS OUTSIGNALS OUTSIGNALS OUTSIGNALS ";

    
    


    $outm ~= "}\n";                 # End of class
    
    

    # TODO : Write produced strings where they have to go
    
    
    # Insert generate code in template and write it in target file

#     my $code = slurp $mainTemplateFileName;
# 
#     replace $code, "#", "SIGNALS_HASH", $outSignals, $km;
#     replace $code, "#", "SLOTS_HASH", $outSlots, $km;
#     replace $code, "#", "QT_CLASSES_STUBS", $outStubs, $km;
#     replace $code, "#", "SUBAPI_RAKU_CODE", $outsub, $km;
#     replace $code, "#", "MAINAPI_RAKU_CODE", $outmain, $km;
#     replace $code, "#", "CALLBACK_HANDLERS", $outcbh, $km;
#     replace $code, "#", "INIT_CALLBACKS_POINTERS", $outicbp, $km;
#     $code = addHeaderText(code => $code, commentChar => '#');
# 
#     spurt $mainModName, $code;
# 
# 
#     $code = slurp $helpersTemplateFileName;
#     replace $code, "#", "LIST_OF_MAIN_QT_CLASSES", $outqtclasses, $km;
#    # replace $code, "#", "INIT_CALLBACKS_POINTERS", $outicbp, $km;
#     $code = addHeaderText(code => $code, commentChar => '#');
#     spurt $helpersModName, $code;
# 
#     $code = slurp $nativesTemplateFileName;
#     replace $code, "#", "LIST_OF_QT_CLASSES_NATIVE_WRAPPERS", $outNatives, $km;
#     replace $code, "#", "SETUP_CALLBACK_WRAPPERS", $outscbw, $km;
#     $code = addHeaderText(code => $code, commentChar => '#');
#     spurt $nativesModName, $code;
    
    
    my Bool $useQtWidgets = False;
    my $qRefsSet = SetHash.new: @qRefs;
    if "QtObject" (elem) $qRefsSet {
        $qRefsSet (-)= "QtObject";
        $useQtWidgets = True; 
    }
    if "QtSigsloty" (elem) $qRefsSet {
        $qRefsSet (-)= "QtSigsloty";
        $useQtWidgets = True; 
    }
    
    if !$noCtor {
        $outu ~= "use NativeCall" ~ ";\n";
        $outu ~= "use {LIBBASEPREFIX}{versionedName("QtWidgets")};\n" if $useQtWidgets;
        $outu ~= "use {LIBPREFIX}{versionedName("QtHelpers")};\n";
        $outu ~= "use {LIBPREFIX}{versionedName("QtWrappers")};\n";
    
# ??????? TODO
#         # Currently, "use xxx::Qt;" will always be added.
#         # TODO: Only generate the following line when really needed
#         #       (i.e. when some arg. has an enum type defined in Qt)
#         $outu ~= "use " ~ LIBPREFIX ~ "Qt" ~ ";\n";
    }
    
    # Add the needed "use" calls
    for $qRefsSet.keys.sort -> $qcl {
        $outu ~= "use {LIBPREFIX}{versionedName($qcl)};\n" if $qcl !~~ $k;
    }
    for (set @rRefs).keys.sort -> $qcl {
        $outu ~= "use {LIBPREFIX}{PREFIXROLE}{versionedName($qcl)};\n";
    }
    
    # say "\n";
#     say "Generate the .rakumod file : stop";
#     say "";
    
    return $outu, $outm, $outn, $outr, $outSignals, $outSlots, $outcbini;
}

 
 
 
sub generate_callbacks_rakumod(%callbacks) is export
{
    my Str $outscbw = "";    # Setup callback wrappers
    my Str $outcbh = "";     # Callback handlers related to Qt virtual methods
    my Str $outicbp = "";    # Init. of callbacks pointers
    my Str $outcdecl = "";   # Init of classes declaration

    # Generate callback wrappers definition
    for %callbacks.sort>>.kv -> ($n, $m) {
        my $name = $n;
        $name ~~ s/^s/S/;
        $name = $prefixWrapper ~ 'Setup' ~ $name;
        my $signature = strNativeWrapperArgsDecl($m,
                                                 showParenth => False,
                                                 showObjectPointer => False);
        my $return = qRet($m) !~~ "void"
                ?? ' --> ' ~ nType($m.returnType)
                !! "";
        $outscbw ~= "sub $name" ~ '(&f (int32, Str' ~ $signature
                                ~ $return ~ '))' ~ "\n";
        $outscbw ~= IND x 2 ~ 'is native(&libwrapper) is export { * }' ~ "\n\n";
    }

    # Generate callback handlers
    my @allClasses = ();
    for %callbacks.sort>>.kv -> ($n, $m) {

        $outcbh ~= "sub $n" ~ '(int32 $objectId, Str $slotName'
            ~ strNativeWrapperArgsDecl($m,
                                       showObjectPointer => False,
                                       showNames => True,
                                       showParenth => False) ~ ")\n";
        $outcbh ~= "\{\n";
        my ($po, $o, @classes) = rakuCallbackCallElems($m);
        $outcbh ~= [~] IND <<~>> $po.lines <<~>> "\n";
        $outcbh ~= IND ~ '$CM.objs{$objectId}."$slotName"' ~ $o ~ "\n";
        $outcbh ~= "}\n\n";
        @allClasses.append: @classes;
    }
    
#     # Generate the roles declaration code
#     $outrdecl = [~] "use {LIBPREFIX}" <<~>> (set @allClasses).keys <<~>> ";\n";
    # Generate the classes declaration code
    $outcdecl = [~] "use {LIBPREFIX }" <<~>> (set @allClasses).keys <<~>> ";\n";

    # Generate the calls of the callbacks setups
    for %callbacks.sort>>.kv -> ($n, $m) {
        my $name = $n;
        $name ~~ s/^s/S/;
        $name = $prefixWrapper ~ 'Setup' ~ $name;
        $outicbp ~= $name ~ '(&' ~ $n ~ ');' ~ "\n";
    }

    return $outscbw, $outcbh, $outicbp, $outcdecl;
}
