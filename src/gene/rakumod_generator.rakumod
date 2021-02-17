
# Generate the Raku module file

use gene::config;
use gene::common;
use gene::natives;
use gene::replace;
use gene::addHeader;
use gene::ToRakuConversions;

# $api : The Qt API description (the output of the parser with the black and
# white info marks added)
# %callbacks : The list of callbacks precomputed by the hpp_generator
# $outFileName : The name of the output file
# $km : The keepMarkers flag (see the replace module)
sub raku_generator(API :$api, :%callbacks, :%exceptions,
                    Str :$mainModName,
                    Str :$nativesModName,
                    Str :$helpersModName,
                    Bool:$km = False) is export
{

    my Str $mainTemplateFileName = "gene/templates/QtWidgets.rakumod.template";
    my Str $helpersTemplateFileName = "gene/templates/QtHelpers.rakumod.template";
    my Str $nativesTemplateFileName = "gene/templates/QtWrappers.rakumod.template";
    my %c = $api.qclasses;

    ###############################################################################
    # Generate the .rakumod files

    say "Generate the .rakumod file : start";
    # say "\n" x 2;

    my Str $outqtclasses = "";
    my Str $outSignals = "";
    my Str $outSlots = "";
    my Str $outmain = "### Beginning of the main API part ###";
    my Str $outStubs = "";
    my Str $outscbw = "";    # Setup callback wrappers
    my Str $outcbh = "";     # Callback handlers related to Qt virtual methods
    my Str $outicbp = "";    # Init. of callbacks pointers
    my Str $outNatives = "### Beginning of the main API part ###\n";

#     for %c.sort>>.kv -> ($k, $v) {
#         say ">>> ", $k, " ", 
#                 $v.whiteListed ?? "W" !! " ",
#                 $v.blackListed ?? "B" !! " ";
#     }

    # Create a stub for all accepted classes to avoid problems with
    # potential cross reference
    for %c.sort>>.kv -> ($k, $v) {
        if $v.whiteListed && !$v.blackListed && !specialType($k) {
            $outStubs ~= "class $k \{ ... }\n";
        }
    }




    # Generation of the "main API" :


    # Sort classes by group then by level then by name to avoid "unknown class"
    # when declaring the parents of a class and to always get the same order
    for %c.keys.sort: { (%c{$^a}.group, %c{$^a}.level, $^a)
                        cmp  (%c{$^b}.group, %c{$^b}.level, $^b)} -> $k {
        my $v = %c{$k};

#         say "*** ", $v.name, " ", ($v.isQObj ?? "QObj" !! "    "),
#                             " ", ($v.whiteListed ?? "W" !! " "),
#                             " ", ($v.blackListed ?? "B" !! " ");

        next if !$v.whiteListed || $v.blackListed;
        next if !$v.isQObj;
        next if $v.name (elem) $specialClasses;

       # $v.name is QObj and $k is class name : should be the same

        # print "Class $k";
        $outqtclasses ~= $k ~ "\n";

        my Str $outn = "";
        my Str $outm = "";

        # $k is the Qt class name
        my $wclassname = $prefixWrapper ~ $k;   # Wrapper class name
        my $pclassname = $k;                    # Perl module class name
        my $wsclassname = $prefixSubclassWrapper ~ $k; # Wrapper subclass name

        # say " ==> $pclassname";

        $outm ~= "\n";
        $outm ~= "class $pclassname";
        for $v.parents -> $p {
            $outm ~= " is $p";
        }
        $outm ~= " is export \{\n";                     # Start of class block

        # Define enums if any
        $outm ~= writeEnumsCode($v);
        
### QOBJS ONLY : START
        # Declare handlers for virtual methods if any
        #     - BEGIN was replaced by CHECK because ::?CLASS was sometimes
        #       still not known when the block was executed.
        #     - Maybe ::?CLASS.raku should not be used at all as we already
        #       know its value $k when generating the code.
        if $v.validVirtuals.elems {    # Have virtual methods ?
            $outm ~= IND ~ "CHECK \{\n";
            $outm ~= IND x 2 ~ '%callbacks{::?CLASS.raku} = <' ~ "\n";
            for $v.validVirtuals -> $m {
                $outm ~= IND x 3 ~ $m.name ~ "\n";
            }
            $outm ~= IND x 2 ~ ">;\n";
            $outm ~= IND ~ "}\n";
        }
### QOBJS ONLY : END

        # Generate ctors if valid ctors exists
        my @ctors = ();
        for $v.methods -> $m {
            if $m.whiteListed && !$m.blackListed && $m.name ~~ "ctor" {
                @ctors.push($m);
            }
        }
        if @ctors.elems {
            # say "CTOR : ";

            my $cbv_already_declared = False;
            CTORLOOP: for @ctors -> $ctor {
                my $ctorNum = $ctor.number ?? '_' ~ $ctor.number !! "";

                # say "    ", $wclassname ~ $suffixCtor ~ $ctorNum
                #                                         ~ qSignature($ctor);


                my $exk = $k ~ '::ctor' ~ qSignature($ctor, showNames => False);
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
                    $outn ~= IND ~ "returns Pointer is native(\&libwrapper) is export \{ * }\n";
                    $outn ~= "\n";

                    # Subroutine(s) ctor calling the native wrapper
                    $outm ~= IND ~ "multi sub ctor"
                                    ~ strArgsRakuCtorDecl($ctor, %c) ~ " \{\n";

                    my ($pc, $o) = strArgsRakuCtorWrapperCall($ctor);

                    $outm ~= [~] (IND x 2) <<~>> $pc;
                    $outm ~= IND x 2 ~ '$this.address = '
                                ~ "$wclassname$suffixCtor$ctorNum$o;" ~ "\n";
                    $outm ~= IND x 2 ~ '$this.ownedByRaku = True;' ~ "\n";
                    $outm ~= IND ~ "}\n";

                    # For documentation
                    #   Raku method name : new
                    #   Raku signature : $o
                    #   Qt method name : $k
                    #   Qt signature : qSignature($ctor, showDefault => True)

### QOBJS ONLY : START
                    # Declaration of the native subclass wrapper
                    $outn ~= "sub " ~ $wsclassname ~ $suffixCtor ~ $ctorNum
                                    ~ strNativeWrapperArgsDecl($ctor) ~ "\n";
                    $outn ~= IND ~ "returns Pointer is native(\&libwrapper) is export \{ * }\n";
                    $outn ~= "\n";

                    # Subroutine(s) ctor calling the native subclass wrapper
                    $outm ~= IND ~ "multi sub subClassCtor"
                                    ~ strArgsRakuCtorDecl($ctor, %c) ~ " \{\n";

                    ($pc, $o) = strArgsRakuCtorWrapperCall($ctor);

                    $outm ~= [~] (IND x 2) <<~>> $pc;
                    $outm ~= IND x 2 ~ '$this.address = '
                                ~ "$wsclassname$suffixCtor$ctorNum$o;" ~ "\n";
                    $outm ~= IND x 2 ~ '$this.ownedByRaku = True;' ~ "\n";
                    $outm ~= IND ~ "}\n";

        # TODO???: Move this code after the loop rather than to use "next"
                    # Only defined once the validation method and its wrapper
                    next CTORLOOP if $cbv_already_declared;
                    $cbv_already_declared = True;

                    # Declaration of the callbacks validation method wrapper
                    $outn ~= "sub " ~ $prefixWrapper ~ 'validateCB_' ~ $k
                                        ~ '(Pointer, int32, Str)' ~ "\n";
                    $outn ~= IND ~ "is native(\&libwrapper) is export \{ * }\n";
                    $outn ~= "\n";

                    # Declaration of the callbacks validation method
                    $outm ~= IND ~ 'method validateCB(Str $m) {' ~ "\n";
                    # $outm ~= IND x 2 ~ 'say "validateCB ' ~ $k ~ '";' ~ "\n";
                    $outm ~= IND x 2 ~ $prefixWrapper ~ 'validateCB_' ~ $k
                                ~ '(self.address, self.id, $m);' ~ "\n";
                    $outm ~= IND ~ "}\n";
### QOBJS ONLY : END

                }

            }

            # Add the new submethod creating a Raku object from an existent
            # Qt one.
            # The $obr named argument is here to allow working in the case
            # the Qt object has been created on the stack and a copy on the
            # heap of this object has been done in the native wrapper,
            # creating an object owned by Raku from an object owned by Qt.
            #
            # Note : Pointer type must be "NativeCall::Types::Pointer".
            # Sub isn't called if type "Pointer" is only specified...
            #
            $outm ~= IND ~ 'multi sub ctor(QtBase $this, '
                                ~ 'NativeCall::Types::Pointer $p, '
                                ~ 'Bool :$obr = False) {' ~ "\n";
            $outm ~= IND x 2 ~ '# Get access to a preexisting Qt object' ~ "\n";
            $outm ~= IND x 2 ~ '$this.address = $p;' ~ "\n";
            $outm ~= IND x 2 ~ '$this.ownedByRaku = $obr;' ~ "\n";
            $outm ~= IND ~ '}' ~ "\n";

            # Default Subroutine ctor
            $outm ~= IND ~ 'multi sub ctor(|capture) {' ~ "\n";
            $outm ~= IND x 2 ~ 'note "QtWidgets ", ::?CLASS.^name,' ~ "\n";
            $outm ~= IND x 2 ~ '     " ctor called with unsupported args";' ~ "\n";
            $outm ~= IND x 2 ~ 'die "Bad args";' ~ "\n";
            $outm ~= IND ~ "}\n";

            # Submethod new
            $outm ~= IND ~ 'submethod new(|capture) {' ~ "\n";
            $outm ~= IND x 2
                        ~ 'my ' ~ $k ~ ' $rObj = self.bless;' ~ "\n";
            $outm ~= IND x 2 ~ 'ctor($rObj, |capture);' ~ "\n";
            $outm ~= IND x 2 ~ 'return $rObj;' ~ "\n";
            $outm ~= IND ~ "}\n";

### QOBJS ONLY : START
            # Default Subroutine subclass ctor
            $outm ~= IND ~ 'multi sub subClassCtor(|capture) {' ~ "\n";
            $outm ~= IND x 2 ~ 'note "QtWidgets subclass ", ::?CLASS.^name,' ~ "\n";
            $outm ~= IND x 2 ~ '     " ctor called with unsupported args";' ~ "\n";
            $outm ~= IND x 2 ~ 'die "Bad args";' ~ "\n";
            $outm ~= IND ~ "}\n";

            # Submethod subClass
            $outm ~= IND ~ 'submethod subClass(|capture) {' ~ "\n";
            $outm ~= IND x 2 ~ 'subClassCtor(self, |capture);' ~ "\n";
            $outm ~= IND x 2 ~ 'self.validateCallBacks();' ~ "\n";
            $outm ~= IND ~ "}\n";
### QOBJS ONLY : END

        } else {
### QOBJS ONLY : START
            # Class has no valid ctor : new will exit with an error message
            $outm ~= IND ~ 'submethod new(|capture) is hidden-from-backtrace {'
                            ~ "\n";
            $outm ~= IND x 2 ~ 'unimplementedCtor("' ~ $k ~ '");' ~ "\n";
            $outm ~= IND ~ "}\n";
### QOBJS ONLY : END
        }
        
        # DESTROY submethod
        if @ctors.elems {
            $outm ~= IND ~ 'submethod DESTROY {' ~ "\n";
            $outm ~= IND x 2 ~ 'if self.ownedByRaku {' ~ "\n";
            $outm ~= IND x 3
                        ~ $wclassname ~ $suffixDtor ~ '(self.address);' ~ "\n";
            $outm ~= IND x 3 ~ 'self.ownedByRaku = False;' ~ "\n";
            $outm ~= IND x 2 ~ '}' ~ "\n";
            $outm ~= IND ~ '}' ~ "\n";
            
            # Declaration of the native dtor wrapper
            $outn ~= "sub " ~ $wclassname ~ $suffixDtor ~ '(Pointer)' ~ "\n";
            $outn ~= IND ~ "is native(\&libwrapper) is export \{ * }\n";
            $outn ~= "\n";
        }

        # Generate methods and slots
        for $v.methods -> $m {
            next if $m.blackListed || !$m.whiteListed;
            next if $m.isSignal || $m.name ~~ "ctor";
            next if $m.isVirtual;

            my $exk = $k ~ '::' ~ $m.name ~ qSignature($m, showNames => False);
            if %exceptions{$exk}{'rakumod'}:exists {
                # say "EXCEP RAKUMOD 2 : $exk";
                if %exceptions{$exk}{'wrappers'}:exists {
                    say "EXCEP WRAPPERS 2 : $exk";
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
                if qRet($m) !~~ "void" {
                    $outn ~= "returns " ~ nType($m.returnType) ~ " ";
                }
                $outn ~= "is native(\&libwrapper) is export \{ * }\n";
                $outn ~= "\n";



### QOBJS ONLY : START
                if $m.isSlot {
                    # say "SLOT ", $k, "::", $m.name, qSignature($m);
                    # say "SLOT ";


                    # say "GENERATING SLOT ", $m.name;

                    my $qualifiedClass = RAQTNAME ~ '::' ~ $k;

                    $outSlots ~=
                        IND ~ '%slots<' ~ $qualifiedClass ~ '>.push(SigSlot.new(' ~ "\n"
                        ~ IND x 2 ~ 'name => "' ~ $m.name ~ '",' ~ "\n"
                        ~ IND x 2 ~ 'sig => "' ~ rSignature($m) ~ '",' ~ "\n"
                        ~ IND x 2 ~ 'qSig => "'
                                ~ qSignature($m, showNames => False) ~ '",' ~ "\n"
                        ~ IND x 2 ~ 'sigIsSimple => True,' ~ "\n"
                        ~ IND x 2 ~ 'isPlainQt => True,' ~ "\n"
                        ~ IND x 2 ~ 'isSlot => True,' ~ "\n"
                        ~ IND x 2 ~ 'sSignature => createSignature('
                                            ~ StrRakuParamsLst($m, %c) ~ ")\n"
                        ~ IND ~ '));' ~ "\n";
                }
### QOBJS ONLY : END




                # Call of the native wrapper
                $outm ~= IND ~ ($m.number ?? "multi method" !! "method") ~ " ";
                $outm ~= $m.name;
                $outm ~= strRakuArgsDecl($m, %c)
                                ~ ($m.isSlot ?? " is QtSlot" !! "") ~ "\n";
                $outm ~= IND ~ "\{\n";



                # PROVISIONAL (TODO) !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                if $m.returnType.ftot ~~ "ENUM" {
                    if $m.returnType.fpostop !~~ "" {
                        die "Class ", $v.name, " method ", $m.name, "\n",
                            "   returns an enum with ", $m.returnType.fpostop,
                                    " postop.\n",
                            "   Such a return is currently unsupported.";
                    }
                }


                my ($pc, $o) = strArgsRakuCallDecl($m);
                my Bool $returnSomething = qRet($m) !~~ "void";
                $outm ~= [~] (IND x 2) <<~>> $pc;

                # $outm ~= "say \"Before calling $wrapperName\";\n";

                $outm ~= IND x 2
                            ~ ($returnSomething ?? 'my $result = ' !! '')
                            ~ $wrapperName ~ $o ~ ";\n";

                if $returnSomething {
                    my $rt = $m.returnType;
                    say "POSTCALL_RAKU $k: (", '$result', ", {$rt.ftot}, ",
                                        "{qType($rt)}, {qPostop($rt)}, ",
                                        '$result1', ", {rType($rt)})";
                    ### POSTCALL_RAKU(Str $src, Str $tot, Str $qPostop,
                    ###                 Str $dst, Str $rakuTypeName --> Str)
                    my $poc = postcall_raku('$result', $rt.ftot,
                                                                qPostop($rt),
                                            '$result1', rType($rt));                    if $poc {
                        $outm ~= IND x 2 ~ $poc ~ "\n";
                        $outm ~= IND x 2 ~ 'return $result1;' ~ "\n";
                    } else {
                        $outm ~= IND x 2 ~ 'return $result;' ~ "\n";
                    }
                }

                $outm ~= IND ~ "}\n";                       # End of method
            }
        }








### QOBJS ONLY : START
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
            my $qualifiedClass = RAQTNAME ~ '::' ~ $k;

            $outm ~= IND ~ "method " ~ $m.name ~ strRakuArgsDecl($m, %c) ~ "\n";
            $outm ~= IND x 2 ~ "$trait \{ ... }\n";

            $outSignals ~=
                  IND ~ '%signals<' ~ $qualifiedClass ~ '>.push(SigSlot.new(' ~ "\n"
                ~ IND x 2 ~ 'name => "' ~ $m.name ~ '",' ~ "\n"
                ~ IND x 2 ~ 'sig => "' ~ rSignature($m) ~ '",' ~ "\n"
                ~ IND x 2 ~ 'qSig => "'
                        ~ qSignature($m, showNames => False) ~ '",' ~ "\n"
                ~ IND x 2 ~ 'sigIsSimple => True,' ~ "\n"
                ~ IND x 2 ~ 'isPlainQt => True,' ~ "\n"
                ~ IND x 2 ~ 'isSlot => False,' ~ "\n"
                ~ IND x 2 ~ 'isPrivate => '
                                    ~ ($m.isPrivateSignal ?? 'True' !! 'False')
                                    ~ ',' ~ "\n"
                ~ IND x 2 ~ 'sSignature => createSignature('
                                            ~ StrRakuParamsLst($m, %c) ~ ")\n"
                ~ IND ~ '));' ~ "\n";
        }
### QOBJS ONLY : END


# say "<<<OUTSIGNALS OUTSIGNALS OUTSIGNALS OUTSIGNALS OUTSIGNALS ";
# say $outSignals;
# say ">>>OUTSIGNALS OUTSIGNALS OUTSIGNALS OUTSIGNALS OUTSIGNALS ";

        $outm ~= "}\n";                                 # End of class

        $outmain ~= $outm;
        if $outn !~~ "" {
            $outn ~= "\n" ~ "#" x 80 ~ "\n\n";
            $outNatives ~= $outn;
        }
    }
    $outmain ~= "### End of the main API part ###\n";
    $outNatives ~= "### End of the main API part ###\n";






    # Generation of the "subAPI" (i.e. Qt classes which are not QObject):

    my Str $outsub = "### Beginning of the sub API part ###";
    $outNatives ~= "### Beginning of the sub API part ###\n";

    # Sort classes by group then level then name to avoid "unknown class" when
    # declaring the parents of a class and to always get the same order
    for %c.keys.sort: { (%c{$^a}.group, %c{$^a}.level, $^a)
                        cmp  (%c{$^b}.group, %c{$^b}.level, $^b)} -> $k {
        my $v = %c{$k};

#         say "*** ", $v.name, " ", ($v.isQObj ?? "QObj" !! "    "),
#                             " ", ($v.whiteListed ?? "W" !! " "),
#                             " ", ($v.blackListed ?? "B" !! " ");

        next if !$v.whiteListed || $v.blackListed;
        next if $v.isQObj;
        next if $v.name (elem) $specialClasses;

        # say "*** SApi : ", $v.name;

        # print "Class $k";

        my Str $outn = "";
        my Str $outm = "";

        # $k is the Qt class name
        my $wclassname = $prefixWrapper ~ $k;   # Wrapper class name
        my $pclassname = $k;                    # Perl module class name

        # say " ==> $pclassname";

        $outm ~= "\n";
        $outm ~= "class $pclassname";
        my Bool $haveParents = False;
        for $v.parents -> $p {
            $outm ~= " is $p";
            $haveParents = True;
        }
        if !$haveParents {
            $outm ~= " is QtBase";
        }

        $outm ~= " is export \{\n";                     # Start of class block

        # Define enums if any
        $outm ~= writeEnumsCode($v);

        # Generate ctors if valid ctors exists
        my @ctors = ();
        for $v.methods -> $m {
            if $m.whiteListed && !$m.blackListed && $m.name ~~ "ctor" {
                @ctors.push($m);
            }
        }
        if @ctors.elems {
            # say "CTOR : ";

            for @ctors -> $ctor {

                my $ctorNum = $ctor.number ?? '_' ~ $ctor.number !! "";

                # say "    ", $wclassname ~ $suffixCtor ~ $ctorNum
                #                                         ~ qSignature($ctor);

                my $exk = $k ~ '::ctor' ~ qSignature($ctor, showNames => False);
                if %exceptions{$exk}{'rakumod'}:exists {
                    # say "EXCEP RAKUMOD 3 : $exk";
                    if %exceptions{$exk}{'wrappers'}:exists {
                        # say "EXCEP WRAPPERS 3 : $exk";
                        $outn ~= %exceptions{$exk}{'wrappers'};
                    }
                    $outm ~= %exceptions{$exk}{'rakumod'};
               } else {

                    # Declaration of the native wrapper
                    $outn ~= "sub " ~ $wclassname ~ $suffixCtor ~ $ctorNum
                                    ~ strNativeWrapperArgsDecl($ctor) ~ "\n";
                    $outn ~= IND ~ "returns Pointer is native(\&libwrapper) is export \{ * }\n";
                    $outn ~= "\n";

                    # Subroutine(s) ctor calling the native wrapper
                    $outm ~= IND ~ "multi sub ctor"
                                    ~ strArgsRakuCtorDecl($ctor, %c) ~ " \{\n";

                    my ($pc, $o) = strArgsRakuCtorWrapperCall($ctor);
                    $outm ~= [~] (IND x 2) <<~>> $pc;
                    $outm ~= IND x 2 ~ '$this.address = '
                                    ~ "$wclassname$suffixCtor$ctorNum$o;" ~ "\n";
                    $outm ~= IND x 2 ~ '$this.ownedByRaku = True;' ~ "\n";
                    $outm ~= IND ~ "}\n";
                }
            }


            
            # Add the new submethod creating a Raku object from an existent
            # Qt one.
            # The $obr named argument is here to allow working in the case
            # the Qt object has been created on the stack and a copy on the
            # heap of this object has been done in the native wrapper,
            # creating an object owned by Raku from an object owned by Qt.
            #
            # Note : Pointer type must be "NativeCall::Types::Pointer".
            # Sub isn't called if type "Pointer" is only specified...
            #
            $outm ~= IND ~ 'multi sub ctor(QtBase $this, '
                                ~ 'NativeCall::Types::Pointer $p, '
                                ~ 'Bool :$obr = False) {' ~ "\n";
            $outm ~= IND x 2 ~ '# Get access to a preexisting Qt object' ~ "\n";
            $outm ~= IND x 2 ~ '$this.address = $p;' ~ "\n";
            $outm ~= IND x 2 ~ '$this.ownedByRaku = $obr;' ~ "\n";
            $outm ~= IND ~ '}' ~ "\n";

            # Default subroutine ctor
            $outm ~= IND ~ 'multi sub ctor(|capture) {' ~ "\n";
            $outm ~= IND x 2 ~ 'note "QtWidgets ", ::?CLASS.^name,' ~ "\n";
            $outm ~= IND x 2 ~ '     " ctor called with unsupported args";' ~ "\n";
            $outm ~= IND x 2 ~ 'die "Bad args";' ~ "\n";
            $outm ~= IND ~ "}\n";

            # Submethod new
            $outm ~= IND ~ 'submethod new(|capture) {' ~ "\n";
            $outm ~= IND x 2
                        ~ 'my ' ~ $k ~ ' $rObj = self.bless;' ~ "\n";
            $outm ~= IND x 2 ~ 'ctor($rObj, |capture);' ~ "\n";
            $outm ~= IND x 2 ~ 'return $rObj;' ~ "\n";
            $outm ~= IND ~ "}\n";
        } else {
### SUBAPI ONLY : START
            # Add the new submethod creating a Raku object from an existent Qt one
            # Note : Pointer type must be "NativeCall::Types::Pointer".
            # Sub isn't called if type "Pointer" is only specified...
            $outm ~= IND ~ 'multi sub ctor(QtBase $this, '
                                ~ 'NativeCall::Types::Pointer $p) {' ~ "\n";
            $outm ~= IND x 2 ~ '# Get access to a preexisting Qt object' ~ "\n";
            $outm ~= IND x 2 ~ '$this.address = $p;' ~ "\n";
            $outm ~= IND x 2 ~ '$this.ownedByRaku = False;' ~ "\n";
            $outm ~= IND ~ '}' ~ "\n";

            # Default Subroutine ctor
            $outm ~= IND ~ 'multi sub ctor(|capture) is hidden-from-backtrace {' ~ "\n";
            $outm ~= IND x 2 ~ 'unimplementedCtor("' ~ $k ~ '");' ~ "\n";
            $outm ~= IND ~ "}\n";

            # Submethod new
            $outm ~= IND ~ 'submethod new(|capture) {' ~ "\n";
            $outm ~= IND x 2
                        ~ 'my ' ~ $k ~ ' $rObj = self.bless;' ~ "\n";
            $outm ~= IND x 2 ~ 'ctor($rObj, |capture);' ~ "\n";
            $outm ~= IND x 2 ~ 'return $rObj;' ~ "\n";
            $outm ~= IND ~ "}\n";
### SUBAPI ONLY : END
        }

        # DESTROY submethod
        if @ctors.elems {
            $outm ~= IND ~ 'submethod DESTROY {' ~ "\n";
            $outm ~= IND x 2 ~ 'if self.ownedByRaku {' ~ "\n";
            $outm ~= IND x 3
                        ~ $wclassname ~ $suffixDtor ~ '(self.address);' ~ "\n";
            $outm ~= IND x 3 ~ 'self.ownedByRaku = False;' ~ "\n";
            $outm ~= IND x 2 ~ '}' ~ "\n";
            $outm ~= IND ~ '}' ~ "\n";
            
            # Declaration of the native dtor wrapper
            $outn ~= "sub " ~ $wclassname ~ $suffixDtor ~ '(Pointer)' ~ "\n";
            $outn ~= IND ~ "is native(\&libwrapper) is export \{ * }\n";
            $outn ~= "\n";
        }

        
        # Generate methods
        for $v.methods -> $m {
            next if $m.blackListed || !$m.whiteListed;
            next if $m.isSignal || $m.name ~~ "ctor";

            my $exk = $k ~ '::' ~ $m.name ~ qSignature($m, showNames => False);
            if %exceptions{$exk}{'rakumod'}:exists {
                # say "EXCEP RAKUMOD 4 : $exk";
                if %exceptions{$exk}{'wrappers'}:exists {
                    # say "EXCEP WRAPPERS 4 : $exk";
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
                if qRet($m) !~~ "void" {
                    $outn ~= "returns " ~ nType($m.returnType) ~ " ";
                }
                $outn ~= "is native(\&libwrapper) is export \{ * }\n";
                $outn ~= "\n";

                # Call of the native wrapper
                $outm ~= IND ~ ($m.number ?? "multi method" !! "method") ~ " ";
                $outm ~= $m.name;
                $outm ~= strRakuArgsDecl($m, %c)
                                ~ ($m.isSlot ?? " is QtSlot" !! "") ~ "\n";
                $outm ~= IND ~ "\{\n";



                # WAITING FOR A TRUE CORRECT HANDLING
                if $m.returnType.ftot ~~ "ENUM" {
                    if $m.returnType.fpostop !~~ "" {
                        die "Class ", $v.name, " method ", $m.name, "\n",
                            "   returns an enum with ", $m.returnType.fpostop,
                                    " postop.\n",
                            "   Such a return is currently unsupported.";
                    }
                }


                my ($pc, $o) = strArgsRakuCallDecl($m);
                my Bool $returnSomething = qRet($m) !~~ "void";
                $outm ~= [~] (IND x 2) <<~>> $pc;
                $outm ~= IND x 2
                            ~ ($returnSomething ?? 'my $result = ' !! '')
                            ~ $wrapperName ~ $o ~ ";\n";

                if $returnSomething {
                    my $rt = $m.returnType;
                    say "POSTCALL_RAKU $k: (", '$result', ", {$rt.ftot}, ",
                                        "{qType($rt)}, {qPostop($rt)}, ",
                                        '$result1', ", {rType($rt)})";
                    ### POSTCALL_RAKU(Str $src, Str $tot, Str $qPostop,
                    ###                 Str $dst, Str $rakuTypeName --> Str)
                    my $poc = postcall_raku('$result', $rt.ftot,
                                                                qPostop($rt),
                                            '$result1', rType($rt));
                    if $poc {
                        $outm ~= IND x 2 ~ $poc ~ "\n";
                        $outm ~= IND x 2 ~ 'return $result1;' ~ "\n";
                    } else {
                        $outm ~= IND x 2 ~ 'return $result;' ~ "\n";
                    }
                }

                $outm ~= IND ~ "}\n";                       # End of method
            }
        }

        $outm ~= "}\n";                                 # End of class

        $outsub ~= $outm;
        if $outn !~~ "" {
            $outn ~= "\n" ~ "#" x 80 ~ "\n\n";
            $outNatives ~= $outn;
        }
    }
    $outsub ~= "### End of the sub API part ###\n";
    $outNatives ~= "### End of the sub API part ###\n";


    # Generate callback wrappers definition
    for %callbacks.sort>>.kv -> ($n, $m) {
        my $name = $n;
        $name ~~ s/^s/S/;
        $name = $prefixWrapper ~ 'Setup' ~ $name;
        my $signature = strNativeWrapperArgsDecl($m,
                                                 showParenth => False,
                                                 showObjectPointer => False);
        $outscbw ~= "sub $name" ~ '(&f (int32, Str' ~ $signature ~ '))' ~ "\n";
        $outscbw ~= IND x 2 ~ 'is native(&libwrapper) is export { * }' ~ "\n\n";
    }

    # Generate callback handlers
    for %callbacks.sort>>.kv -> ($n, $m) {

        $outcbh ~= "sub $n" ~ '(int32 $objectId, Str $slotName'
            ~ strNativeWrapperArgsDecl($m,
                                       showObjectPointer => False,
                                       showNames => True,
                                       showParenth => False) ~ ")\n";
        $outcbh ~= "\{\n";
        my ($po, $o) = strArgsRakuCallbackCall($m);
        $outcbh ~= [~] IND <<~>> $po.lines <<~>> "\n";
        $outcbh ~= IND ~ '$CM.objs{$objectId}."$slotName"' ~ $o ~ "\n";
        $outcbh ~= "}\n\n";
    }

    # Generate the calls of the callbacks setups
    for %callbacks.sort>>.kv -> ($n, $m) {
        my $name = $n;
        $name ~~ s/^s/S/;
        $name = $prefixWrapper ~ 'Setup' ~ $name;
        $outicbp ~= $name ~ '(&' ~ $n ~ ');' ~ "\n";
    }



    # Insert generate code in template and write it in target file

    my $code = slurp $mainTemplateFileName;

    replace $code, "#", "SIGNALS_HASH", $outSignals, $km;
    replace $code, "#", "SLOTS_HASH", $outSlots, $km;
    replace $code, "#", "QT_CLASSES_STUBS", $outStubs, $km;
    replace $code, "#", "SUBAPI_RAKU_CODE", $outsub, $km;
    replace $code, "#", "MAINAPI_RAKU_CODE", $outmain, $km;
    replace $code, "#", "CALLBACK_HANDLERS", $outcbh, $km;
    replace $code, "#", "INIT_CALLBACKS_POINTERS", $outicbp, $km;
    $code = addHeaderText(code => $code, commentChar => '#');

    spurt $mainModName, $code;


    $code = slurp $helpersTemplateFileName;
    replace $code, "#", "LIST_OF_MAIN_QT_CLASSES", $outqtclasses, $km;
   # replace $code, "#", "INIT_CALLBACKS_POINTERS", $outicbp, $km;
    $code = addHeaderText(code => $code, commentChar => '#');
    spurt $helpersModName, $code;

    $code = slurp $nativesTemplateFileName;
    replace $code, "#", "LIST_OF_QT_CLASSES_NATIVE_WRAPPERS", $outNatives, $km;
    replace $code, "#", "SETUP_CALLBACK_WRAPPERS", $outscbw, $km;
    $code = addHeaderText(code => $code, commentChar => '#');
    spurt $nativesModName, $code;

    # say "\n";
    say "Generate the .rakumod file : stop";
    say "";
}

