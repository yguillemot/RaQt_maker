 
use config;
use gene::common;
use gene::natives;
use gene::replace;
use gene::addHeaderText;
use gene::ToRakuConversions;

sub versionedName(Str $name --> Str) is export
{
    $name ~ ":ver<{MODVERSION}>" ~ ":auth<{MODAUTH}>" ~ ":api<{MODAPI}>"
}

# Look for the set of classes required by a QXxx.rakumod module
# Input
#    $k : class name ("QXxx")
#    $v : $api.qclasses{$k}
# Output
#    %dep where
#        %dep.keys : list of "QXxx" classes whose $k depends
#        %dep{"QXxx"} = "FULL" or "ROLE"
#             "FULL" means "use Qt::QtWidgets::QXxx" is mandatory
#             "ROLE" means "use Qt::QtWidgets::RQXxx" is sufficient
sub lookForDependencies(Str $k, Qclass $v --> Hash)
{
    my %dep;

    # Populate with parents classes
    for $v.parents -> $p {
        %dep{$p} = "FULL";
    }


    # Add classes used in the arguments of the methods

    # Loop on methods
    for $v.methods -> $m {
        next if $m.blackListed || !$m.whiteListed;

        # Process returned type
        if $m.name ne "ctor" {
            if $m.returnType.ftot ~~ "CLASS" {
                my Str $class = $m.returnType.fbase;
                # Set as "FULL"
                %dep{$class} = "FULL";
            }
        }

        # Process arguments types
        for $m.arguments -> $a {
            if $a.ftot ~~ "CLASS" {
                my Str $class = $a.fbase;
                if ($class ne $k) {
                    # Does a default value exist ?
                    if $a.value {
                        %dep{$class} = "FULL";
                    } else {
                        # Set as "ROLE" unless already "FULL"
                        %dep{$class} = "ROLE" if %dep{$class}:!exists;
                    }
                } else {
                    %dep{$class} = "FULL";
                }
            }
        }

    }

    return %dep;
}


# Replace the mark class names in $text with the correct name (class name
# or role name) given data in %dep
sub fixClassNames(Str $text is rw, %dep)
{
    $text ~~ s:global/"{CNOM}" (\w+) "{CNCM}"
                     /{ %dep{$0} ~~ "FULL" ?? "" !! PREFIXROLE }$0/;
}

sub generate_rakumod(Str $k, Qclass $v, %c, %exceptions,
                     Bool $hasCtor, Bool $hasSubclassCtor, Bool $subclassable,
                     %virtuals, $classesInHelper, :$km = False) is export
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
    my Str $pclassname = $k;                    # Raku module class name
    my Str $wsclassname = $prefixSubclassWrapper ~ $k; # Wrapper subclass name


    # $k is an abstract top class
    # TODO: This condition is probably not sufficient to cover all the cases
    #       where an explicit upcasting is needed.
    #       Nevertheless, and until a new issue occurs, the explicit upcasting
    #       will be limited to this case only.
    my Bool $isAbstractTopClass = $v.isAbstract && $v.parents.elems == 0;


    my @rRefs;   # List of Qt roles used in the code
    my @qRefs;   # List of Qt classes used in the code
    my @qRefsHelper; # List of Qt classes used in signals for QtHelper.rakumod
    
    my %dependencies = lookForDependencies $k, $v;

    for %dependencies.kv -> $k, $v {
        if $v eq "FULL" {
            @qRefs.push: $k;
        } else {
            @rRefs.push: $k;
        }
    }
    
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
    
    my Bool $haveParents = False;
    for $v.parents -> $p {
        $outm ~= "\n{IND}is $p";
        $haveParents = True;
    }
    
    if $subclassable {
        $outm ~= "\n{IND}is QtObject";
        @qRefs.push: "QtObject";
    } elsif !$haveParents && !$noCtor {
        $outm ~= "\n{IND}is QtBase";
        @qRefs.push: "QtBase";
    }
    
#     if !$noCtor && $v.isQObj {
    if !$noCtor {
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

    # Define a callers hash if needed
    if $isAbstractTopClass {
        $outm ~= IND ~ 'my constant %callers = {' ~ "\n";
        my $i = 0;
        for $v.descendants.sort -> $d {
            $outm ~= IND x 2 ~ '"' ~ $d ~ '" => ' ~ $i++ ~ ",\n";
        }
        $outm ~= IND ~ '}' ~ "\n";
        $outm ~= "\n";
    }

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
                                ~ strArgsRakuCtorDecl($ctor, %c, :markers)
                                ~ " \{\n";

                my ($pc, $o) = rakuWrapperCallElems($ctor);
                my ($cl-type, $cl-enum) = classesInSignature($ctor);
                @qRefs.append: @$cl-enum;
                # $cl-type : already processed in %dep

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

                    
                if $v.isQObj || $subclassable {
                    # Declaration of the native subclass wrapper
                    $outn ~= "sub " ~ $wsclassname ~ $suffixCtor ~ $ctorNum
                                    ~ strNativeWrapperArgsDecl($ctor) ~ "\n";
                    $outn ~= IND ~ "returns Pointer is native(\&libwrapper)";
                    $outn ~= " \{ * }\n";
                    $outn ~= "\n";

                    # Subroutine(s) ctor calling the native subclass wrapper
                    $outm ~= IND ~ "multi sub subClassCtor"
                                    ~ strArgsRakuCtorDecl($ctor, %c, :markers)
                                    ~ " \{\n";

                    ($pc, $o) = rakuWrapperCallElems($ctor);
                    
                    my ($cl-type, $cl-enum) = classesInSignature($ctor);
                    @qRefs.append: @$cl-enum;
                    # $cl-type : already processed in %dep

                    $outm ~= [~] (IND x 2) <<~>> $pc;
                    $outm ~= IND x 2 ~ '$this.address = '
                                ~ "$wsclassname$suffixCtor$ctorNum$o;" ~ "\n";
                    $outm ~= IND x 2 ~ '$this.ownedByRaku = True;' ~ "\n";
                    $outm ~= IND ~ "}\n";
                    $outm ~= "\n";

        # TODO???: Move this code after the loop rather than to use "next"
                    # Defined the validation method and its wrapper only once
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
        # The $obr (Owned By Raku) named argument is here to allow working
        # in the case the Qt object has been created on the stack and a copy
        # on the heap of this object has been done in the native wrapper,
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
        
        if $v.isQObj || $subclassable {
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

        next if $m.isVirtual && qRet($m) eq "void" && !$m.isSlot;
                                            # !$m.isSlot since v0.0.5
                                            # qRet($m) eq "void" since v0.0.7
        say "Generate method ", $m.name;

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
                      ~ strNativeWrapperArgsDecl($m,
                                       showCIdx => $isAbstractTopClass)
                      ~ "\n";
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

                # YGYGYG <<<
                my ($cl-type, $cl-enum) = classesInSignature($m);
                @qRefs.append: @$cl-enum;
                # $cl-type already processed in %dep
                $classesInHelper.append: @$cl-type;
                # >>> YGYGYG

                $outSlots ~=
                    IND ~ '%slots<' ~ $qualifiedClass ~ '>.push(SigSlot.new(' ~ "\n"
                    ~ IND x 2 ~ 'name => "' ~ $m.name ~ '",' ~ "\n"
                    ~ IND x 2 ~ 'sig => "' ~ rSignature($m) ~ '",' ~ "\n"
                    ~ IND x 2 ~ 'qSig => "'
                            ~ qSignature($m, showNames => False) ~ '",' ~ "\n"
                    ~ IND x 2 ~ 'signature => :'
                            ~ rSignature($m, :forceRole, :noEnum) ~ ',' ~ "\n"
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
            my @valQClasses;
            my @valRClasses;
            my $q = @valQClasses;
            my $r = @valRClasses;
            $outm ~= strRakuArgsDecl($m, %c, $q, $r,
                                invocant => $isAbstractTopClass, :markers)
                            ~ ($m.isSlot ?? " is QtSlot" !! "") ~ "\n";
            $outm ~= IND ~ "\{\n";

            # Already processed from %dep
            # @qRefs.append: @valQClasses;
            # @rRefs.append: @valRClasses;
            
            my ($cl-type, $cl-enum) = classesInSignature($m);
            @qRefs.append: @$cl-enum;
            # $cl-type already processed from %dep


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


            my ($pc, $o) = rakuWrapperCallElems($m,
                                         showCIdx => $isAbstractTopClass);
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
                    # If a QXxx object was created, surround it with class
                    # name markers
                    $poc ~~
                        s/ 'my $' (\w+) ' = Q' (\w+) '.new'
                                        /my \$$0 = {CNOM}Q{$1}{CNCM}.new/;
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
            my @valQClasses;
            my @valRClasses;
            $outm ~= IND ~ "method " ~ $m.name
                            ~ strRakuArgsDecl($m, %c,
                                    @valQClasses, @valRClasses, :markers)
                            ~ "\n";
            $outm ~= IND x 2 ~ "$trait \{ ... }\n";
            $outm ~= "\n";

#             Already processed from %dep
#             @qRefs.append: @valQClasses;
#             @rRefs.append: @valRClasses;


            my ($cl-type, $cl-enum) = classesInSignature($m);
            @qRefs.append: @$cl-enum;
            # $cl-type already processed from %dep
            $classesInHelper.append: @$cl-type;

            $outSignals ~=
                IND ~ '%signals<' ~ $qualifiedClass ~ '>.push(SigSlot.new(' ~ "\n"
                ~ IND x 2 ~ 'name => "' ~ $m.name ~ '",' ~ "\n"
                ~ IND x 2 ~ 'sig => "' ~ rSignature($m) ~ '",' ~ "\n"
                ~ IND x 2 ~ 'qSig => "'
                        ~ qSignature($m, showNames => False) ~ '",' ~ "\n"
                ~ IND x 2 ~ 'signature => :' ~ rSignature($m, :forceRole) ~ ',' ~ "\n"
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

    spurt "/tmp/BEFORE.txt", $outm if $k ~~ "QWidget";
#     fixClassNames $outu, %dependencies;
    fixClassNames $outm, %dependencies;
    fixClassNames $outn, %dependencies;
    fixClassNames $outr, %dependencies;
#     fixClassNames $outSignals, %dependencies;
#     fixClassNames $outSlots, %dependencies;
#     fixClassNames $outcbini, %dependencies;
    spurt "/tmp/AFTER.txt", $outm if $k ~~ "QWidget";

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
