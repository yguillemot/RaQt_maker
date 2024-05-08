


use gene::common;


class qtClassesActions is export {
#         method descr($/) { $/.make: $/; }
#         method rgdata($/) { $/.make: $/; }

    has %.qclasses is rw;

    has @!parents;                  # Parents of the current class
    has %!ancestors;                # Ancestors of all the known classes

    has Int $!unnamedEnumNumber;    # To create unique name when needed
    has Int $!currentEnumValue;     # To increment value inside enum
    has QEnum $!currentEnum;        # Where current parsed enum is reconstructed

    has %!allEnumValues;            # Known enum values of all the known classes
    has %!topLevelTypedefs;         # Typedefs defined outside any class

    has Str $.input;
    has Int $.lastSuccessIndex;
    has Int $.aborted = 0;

    my $self;       # Used to call method abort from a subroutine


    submethod TWEAK
    {
        %!allEnumValues = ();
        %!topLevelTypedefs = ();
        $self = self;
    }


    method success(Match $m)
    {
        $!lastSuccessIndex = $.lastSuccessIndex > $m.to
                                    ?? $.lastSuccessIndex !! $m.to;
    }

    method lastSuccessLine
    {
        $.input.substr(0, $.lastSuccessIndex).split("\n").elems;
    }

    method abort
    {
        # Only remember the first aborting place
        $!aborted = self.lastSuccessLine unless $.aborted;
    }

    method start($/) {
        %!qclasses = ();

        $!lastSuccessIndex = 0;
        $!input = $/.orig;
    }

    method TOP($/)
    {
        make API.new(
            qclasses => %.qclasses,
            topTypedefs => %!topLevelTypedefs
        );
    }


#     method toplevels($/)

    method toplevel($/)
    {
        if $<typedef> {
            my $name = $<typedef>.made.name;
            say "Parsing top typedef: ", $name;
            if %!topLevelTypedefs{$name}:exists {
                say "WARNING: Duplicate definition of toplevel typedef $name";
            } else {
                %!topLevelTypedefs{$name} = $<typedef>.made;
            }
        }
    }

    method class($/)
    {
        my Str $name = $<className>.made;
        say "Parsing class: ", $name;
        my $c = Qclass.new(name => $name);
        $c.parents = $<parents>.made if $<parents>;
        $c.ancestors = %!ancestors{$name}.clone
                                if %!ancestors{$name}:exists;

        my ($m, $e, $t) =  $<class_bloc>.made;
        $c.methods = |$m if $m;
        $c.enums = $e;
        $c.typedefs = $t;

        %!qclasses{$name} = $c;
        self.success($/);

    }

    method className($/) {
        make $<name>.made;
        $!unnamedEnumNumber = 0;
        @!parents = ();
    }

    method parents($/)
    {
        # Build a list of parents
        @!parents = (|($<parent>.made), |($<other_parent>>>.made));

        # Build a list of ancestors (i.e. parents, parents of parents, etc...)
        my @a = @!parents;
        for @!parents -> $p {
            @a.append(|%!ancestors{$p}) if %!ancestors{$p}:exists;
        }
        if @a.elems > 0 {
            # Don't store any ancestor twice
            my $aset = Set.new(@a);
            %!ancestors{$*currentClass} = $aset.keys.cache;
        }

        make @!parents;
        self.success($/);
    }

    method other_parent($/)
    {
        make $<parent>.made;
        self.success($/);
    }

    method parent($/)
    {
        make $<qualifiedName>.made;
        self.success($/);
    }


    method class_bloc($/)
    {
        my @m = ();     # Methods and ctors
        my %e = ();     # Enums
        my %t = ();     # Typedefs

        for $<class_member> {
            if $_.made[1] {
                if $_.made[0] eq 'm' {
                    @m.push($_.made[1]);
                } elsif $_.made[0] eq 'e' {
                    %e{$_.made[1].name} = $_.made[1];
                } elsif $_.made[0] eq 't' {
                    %t{$_.made[1].name} = $_.made[1];
                } else {
                    # Do nothing
                }
            } else {
                # say "CLASS MEMBER : ", $_.made;  # TODO ???
            }
        }

        make (@m, %e, %t);
        self.success($/);
    }

    method class_member($/) {
        if $<access_specifier> {
            make ("a", "TODO");   # Probably unnecessary
        } elsif $<ctor> {
            make ("m", $<ctor>.made); # Ctor is processed as an ordinary method
        } elsif $<method> {
            make ("m", $<method>.made);
        } elsif $<enum> {
            make ("e", $<enum>.made);
        } else {    # $<typedef>
            make ("t", $<typedef>.made);
        }
    }


    method access_specifier($/)
    {
        $*subblocMode = $<access_mode>.made;
        make $*subblocMode ~ ":\n";
    }

    method access_mode($/)
    {
        make $/.Str;
        self.success($/);
    }


    method ctor($/)
    {
        # Protected ctors are ignored
        if $*subblocMode ~~ "public" {
            make Function.new(
                name => "ctor",
                returnType => Rtype.new(base => "", postop => ""),
                arguments => $<params>.made
            );
        }
        self.success($/);
    }


    method method($/)
    {
        my $protected = index($*subblocMode, "protected") !~~ Nil;
        my $slot =  index($*subblocMode, "Q_SLOT") !~~ Nil;
        my $signal =  index($*subblocMode, "Q_SIGNAL") !~~ Nil;
        my $static =  ?$<prespecifier> && $<prespecifier>.made eq 'static';
        my $virtual =  ?$<prespecifier> && $<prespecifier>.made eq 'virtual';
        my $pureVirtual = ?$<eq_something> && $<eq_something>.made eq '0';

        my $const = False;
        my $override = False;
        for $<postspecifier> {
            given $_.made {
                when 'override' { $override = True }
                when 'const' { $const = True }
            }
        }

        # Are this flags consistent ?
        my $pb =    ($signal && $slot)
                 || ($static && $virtual)
                 || ($signal && $protected)
                 || ($signal && $static);
        if $pb {
            note "Inconsistent flags for method ", $<name>.made;
            note "\tslot : ", $slot;
            note "\tsignal : ", $signal;
            note "\t$protected : ", $protected;
            note "\tstatic : ", $static;
            note "\tvirtual : ", $virtual;
            self.abort;
        }

        make Function.new(
                name => $<name>.made,
                isSlot => $slot,
                isSignal => $signal,
                isStatic => $static,
                isVirtual => $virtual,
                isPureVirtual => $pureVirtual,
                isProtected => $protected,
                isConst => $const,
                isOverride => $override,
                returnType => Rtype.new(base => $<typename>.made.base,
                                        postop => $<typename>.made.postop,
                                        const => $<typename>.made.const),
                arguments => $<params>.made
        );
    }

    method prespecifier($/)
    {
        make trim $/.Str;
    }

    method postspecifier($/)
    {
        make trim $/.Str;
    }

    method eq_something($/)
    {
        make "0" if $<zero>;
    }

#     method zero($/)   # YGYGYG
#     {
#         make "0";
#     }

# rule delete_or_default

# # rule postspecifier

#
# rule dtor
# rule ddeclaration
# rule dimplementation
# rule dtor_prespecifier
#
# rule operator
# rule thirdop
# rule otherop
# rule odeclaration
# rule oimplementation
#
    method enum($/) {

        my @items = ();
        my %vals = ();
        if $<enumcore> {
            for $<enumcore>.made -> $t {
                @items.push([$t.name, $t.rawValue]);
                %vals{$t.name} = $t.value;
            }
        }

        my $enum = QEnum.new(name => $<enumstart>.made,
                             items => @items,
                             values => %vals);
        
        if $*currentClass !~~ "" {
            # This enum is defined inside a class
            make $enum;
        } else {
            # This is a toplevel enum : create a toplevel enum class
            my $className = $<enumstart>.made;
            my $c = Qclass.new(name => $className);
            $c.enums = { $className => $enum };
            %!qclasses{$className} = $c;
        }
        
        self.success($/);
    }

    method enumstart($/) {
        my $name = $<name> ?? $<name>.made !! "UNNAMED" ~ ++$!unnamedEnumNumber;
        $!currentEnumValue = -1;
        $!currentEnum = QEnum.new(name => $name);
        make $name;
        self.success($/);
    }

    method enumcore($/) {
        # $<enumelem> = liste [nom, rawValue, value]
        my @e = $<enumelem>>>.made;
        make @e;
    }

    method enumelem($/) {
        my $name = $<name>.made;
        my $rawValue;
        if $<enumvalue> {
            $rawValue = $<enumvalue>.made[0];
            $!currentEnumValue = $<enumvalue>.made[1];
        } else {
            $rawValue = "";
            $!currentEnumValue++;
        }

        $!currentEnum.items.push([$<name>.made, $rawValue]);
    
        # if $*currentClass ~~ "" this is a top level enum class
        my $class = $*currentClass !~~ ""
            ?? $*currentClass
            !! $!currentEnum.name;
        %!allEnumValues{$class ~ "::" ~ $<name>.made} = $!currentEnumValue;

        make Triplet.new(name => $<name>.made,
                         rawValue => $rawValue,
                         value => $!currentEnumValue);
        self.success($/);
    }

    method enumvalue($/) {
        make [$/.Str, $<enum_expression>.made];  # [raw value, computed value]
    }

# rule attribute
# rule normal_attribute
# rule static_attribute
# rule multi_attribute
# rule othername
# rule bits
# rule static_attribute_initializer

    method typedef($/) {
#         say "TYPEDEF : ", $/.Str;
#         say "\tT:", $<typename>.made,
#                         "   N:", $<name>.made, "   S:", $<squareblock>.made;
        make Typedef.new(
            type => $<typename>.made,
            srcClass => $*currentClass,
            name => $<name>.made ~ ($<squareblock> ?? $<squareblock>.made !! "")
        );
        self.success($/);
    }

# rule usualtypedef
# rule functionptrtypedef
# rule friendClass
# rule cspecifier
# rule struct
# rule subclass
# rule subclass_def
# rule class_ref
# rule union
# rule var
# rule template
# rule timplementation
# rule tdeclaration
# rule using

    method params($/)
    {
        my @f = ();
        @f.push($<first_param>.made) if $<first_param>;

        my @n = ();
        for $<next_param> { @n.push($_.made) };

        my @d = ();
#         @d.push($<dots_param>.made) if $<dots_param>;

        make (|@f, |@n, |@d);
        self.success($/);
    }


    method first_param($/)
    {
        make $<param>.made;
    }

    method next_param($/)
    {
        make $<param>.made;
    }

# rule dots_params      # TODO



    method param($/)
    {
        if $<defaultedParameter> {
            make $<defaultedParameter>.made;
        } elsif $<namedParam> {
            make $<namedParam>.made;
        } elsif $<defaultedUnnamedParameter> {
            make $<defaultedUnnamedParameter>.made;
        } elsif $<functionPointer> {
            make $<functionPointer>.made;
        } elsif $<unnamedParam> {
            make $<unnamedParam>.made;
        }

        self.success($/);
    }

    method namedParam($/)
    {
        make Argument.new(
            base => $<typename>.made.base,
            postop => $<typename>.made.postop,
            name => $<name>.made,
            const => $<typename>.made.const
        );
        self.success($/);
    }

    method unnamedParam($/)
    {
        make Argument.new(
            base => $<typename>.made.base,
            postop => $<typename>.made.postop,
            name => "???",
            const => $<typename>.made.const
        );
        self.success($/);
    }

    method functionPointer($/)   # TODO TODO TODO
    {
#     say "\t\tFUNCTIONPTRPARAM " ~ $/ ~ "<";
        my $tname = "FPTR";
        my $tpo = "";
        make Argument.new(base => $tname, postop => $tpo, name => "");
        self.success($/);
    }

    method defaultedParameter($/)   # TODO TODO TODO
    {
#     say "\t\tDEFAULTEDPARAM " ~ $/ ~ "<";
        make Argument.new(
            base => $<typename>.made.base,
            postop => $<typename>.made.postop,
            name => $<name>.made,
            value => $<value>.made,
            const => $<typename>.made.const
        );
        self.success($/);
    }

    method defaultedUnnamedParameter($/)   # TODO TODO TODO
    {
#     say "\t\tDEFAULTEDUNNAMEDPARAM " ~ $/ ~ "<";
        make Argument.new(
            base => $<typename>.made.base,
            postop => $<typename>.made.postop,
            name => "???",
            value => $<value>.made,
            const => $<typename>.made.const
        );
        self.success($/);
    }

    method typename($/)
    {
        # say "\t\t\tTYPENAME >", ~$/, "<";
        my $postop = $<typePostop> ?? [~] $<typePostop>>>.made !! "";
        my $type = $<completetypename>.made ?? $<completetypename>.made !! "";
        my $tspec = $<tspecifier>.made ?? $<tspecifier>.made !! "";
        # say "\t\t\t\tBASE >", $type, "<  tspecifier >", $tspec, "<";

        make Ltype.new(base => $type,
                       postop => $postop,
                       const => $tspec
        );
        self.success($/);
    }

    method completetypename($/)
    {
        make ($<simpletypename>
                    ?? $<simpletypename>.made !! $<complextypename>.made);
    }


    method qualifiedname($/)
    {
        make $/.Str.trim;
    }

    method complextypename($/)
    {
        make $/.Str.trim;
    }

    method simpletypename($/)
    {
        make $/.Str.trim;
    }

    method tspecifier($/)
    {
        make trim $/.Str;
    }

    method tpostspecifier($/)
    {
        make trim $/.Str;
    }



    method typePostop($/)
    {
        make $/.Str;
    }



    method value($/)
    {
        make $/.Str;                         ### PROVISIONAL !!!
        # say "VALUE : >", $/.Str, "<";
    }

# rule value_elem
# token quotedchar
# token numericalvalue
# rule functioncall
# rule expression
# token extended_value
# token empty_list

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Arithmetic associated with the values of enums

    method enum_expression($/) {
        if $<group15>.elems != 1 {
            make ?$<group15>[0].made ?? $<group15>[1].made !! $<group15>[2].made;
        } else {
            make $<group15>[0].made;
        }
    }

    method group15($/) {
        if $<op12> {
            make compute($<op12>, $<group12>);
        } else {
            make $<group12>[0].made;
        }
    }

    method op12($/) {
        make ~$/;
    }

    method group12($/) {
        if $<op10> {
            make compute($<op10>, $<group10>);
        } else {
            make $<group10>[0].made;
        }
    }

    method op10($/) {
        make ~$/;
    }

    method group10($/) {
        given $<op9>.made {
            when '==' { make($<group9>[0].made == $<group9>[1].made); }
            when '!=' { make($<group9>[0].made != $<group9>[1].made); }
            default { make $<group9>[0].made; }
        }
    }

    method op9($/) {
        make ~$/;
    }

    method group9($/) {    
        given $<op7>.made {
            when '<<' { make($<group7>[0].made +< $<group7>[1].made); }
            when '>>' { make($<group7>[0].made +> $<group7>[1].made); }
            default { make $<group7>[0].made; }
        }
    }

    method op7($/) {
        make ~$/;
    }

    method group7($/) {
        if $<op6> {
            make compute($<op6>, $<group6>);
        } else {
            make $<group6>[0].made;
        }
    }

    method op6($/) {
        make ~$/;
    }

    method group6($/) {
        if $<op5> {
            make compute($<op5>, $<group5>);
        } else {
            make $<group5>[0].made;
        }
    }

    sub compute(@op, @data) {
        my $v = @data.shift.made;
        for @op -> $x {
            $v = operation($x.made, $v, @data.shift.made);
        }
        return $v;
    }

    sub operation($op, $a, $b) {
        given $op {
            when '+' { return $a + $b; }
            when '-' { return $a - $b; }
            when '*' { return $a * $b; }
            when '/' { return $a / $b; }

            when '&' { return $a +& $b; }
            when '|' { return $a +| $b; }

            default {
                note "Unknown operation \"$op\"";
                die "Can't parse successfuly near line ", $self.abort;
                note "Aborting in $?FILE:$?LINE";
            }
        }
    }

    method op5($/) {
        make ~$/;
    }

    method group5($/) {
        given $<op3>.made {
            when '+' { make $<group3>.made; }
            when '-' { make - $<group3>.made; }
            when '!' { make +(!$<group3>.made); }
            when '~' { make +^$<group3>.made; }
            default  { make $<group3>.made; }
        }
    }

    method op3($/) {
        make ~$/;
    }

    method group3($/) {
        if $<qualifiedName> {

            # The value associated with this name should be looked for not
            # only in the current class, but in all its ancestors equally

            my $enumref = $<qualifiedName>.made;
            my @targets = ();
            if index($enumref, "::") !~~ Nil {
                # Name is really qualified, look for it in the enums
                @targets.push($enumref);
            } else {
                # Despite its original name, $enumref is not qualified
                # Qualify it with current class and its ancestors
                @targets.push($*currentClass ~ "::" ~ $enumref);

                if %!ancestors{$*currentClass}:exists {
                    @targets.append(|%!ancestors{$*currentClass}
                                                <<~>> ("::" ~ $enumref));
                }
            }
    
            my $ok = False;
            TLOOP: for @targets -> $t {
                if %!allEnumValues{$t}:exists {
                    make %!allEnumValues{$t};
                    $ok = True;
                    last TLOOP;
                }
            }

            if !$ok {
                note "";
                note "ERROR : $enumref not found !";
                note " C = ", $*currentClass;
                note " P = ", @!parents;
                if %!ancestors{$*currentClass}:exists {
                    note " A = ", %!ancestors{$*currentClass};
                } else {
                    note " A = \"\"";
                }
                note "Targets = ", @targets;
                note "";
                note "An enum references an unknown enum !";
                note "Can't parse successfuly near line ", self.abort;
                
                note "Aborting in $?FILE:$?LINE";
                exit;
            }


        } elsif $<numericalValue> {
            make $<numericalValue>.made;
        } else {   # $<enum_expression>
            make $<enum_expression>.made;
        }
    }

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# token bracedblock
# token bracedblockcore
# token b_bblock
# token a_bblock

# Idem braced : parenth

    method angleblock($/) {
        make trim $/.Str;
    }

# token angleblockcore
# token b_ablock
# token a_ablock

    method squareblock($/) {
        make trim $/.Str;
    }

# token squareblockcore
# token b_sblock
# token a_sblock

#     token noangle
#     token nobrace
#     token noparenth
#     token nosquare

# token op
# token leftop


    method name($/)
    {
        make trim $/.Str;
    }

    method qualifiedName($/)
    {
        make trim $/.Str;
    }


   method numericalValue($/) {
        if $<integerValue> {
            make $<integerValue>.made;
        } else {
            make $<floatingValue>.made;
        }
    }
    
    method floatingValue($/) {
        make $<simpleFloatingValue>.made;
    }
    
    method simpleFloatingValue($/) { 
        make +$/;
    }
    
    method integerValue($/) {
        make $<simpleIntegerValue>.made;
    }

   method simpleIntegerValue($/) {
        make +$/;
    }

# token decnumber
# token hexnumber

}

