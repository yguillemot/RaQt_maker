
use gene::common;

class Meth {
    has $.class;
    has $.name;
    has $.signature;
}

# Read black or white list
#
# Input : $file is the name of the file to read
# Output : a list of two listes is returned :
#    - The first is the list of class names
#    - The second is the list of methods as objects Meth
sub readList(Str $file --> List) is export
{
    if !$file.IO.e || !$file.IO.f {
        # If there is no input file then empty lists are assumed
        return (), ();
    }

    my $f = slurp $file;

    # Remove comments
    $f ~~ s:g/'#' .*? "\n"/\n/;

    my @c = ();
    my @m = ();

    my @l = $f.lines>>.trim;

    for @l -> $txt {
        next if $txt ~~ "";   # Remove blank lines
        if $txt ~~ m/(\w+) '::' (\w+) ('(' .* ')')/ {
            # Method found
            my $m = Meth.new(class => ~$0, name => ~$1, signature => ~$2);
            @m.push($m);
        } else {
            # Class found
            @c.push($txt);
        }
        # Malformed methods are first identified as class then will
        # be detected as unknown classes
    }

    return (@c, @m);
}


# Remove all the black and white flags from the API
sub resetColors(API $api) is export
{

    for $api.qclasses.kv -> $name, $qclass {
        $qclass.blackListed = False;
        $qclass.whiteListed = False;

        for $qclass.methods -> $m {
            $m.blackListed = False;
            $m.whiteListed = False;
        }

        for $qclass.enums.values -> $enum {
            $enum.blackListed = False;
            $enum.whiteListed = False;
        }
    }
}



sub computeBlackAndWhiteObjects(API :$api, Str :$blackList, Str :$whiteList,
                                Bool :$strict) is export
{


    # Blacklist any class whose at least one parent is unknown
    for $api.qclasses.kv -> $name, $qclass {

        for $qclass.parents -> $cl {
            if $api.qclasses{$cl}:!exists {
 say "YG UNKNOWN 1: '$cl'";
                $qclass.blackListed = True;
                last;
            }
        }
    }


    # Blacklist any method whose at least one argument is of an unknown type.
    for $api.qclasses.kv -> $k, $v {
        MLOOP: for $v.methods -> $m {
            my @types = ();
            if $m.name ne "ctor" {
                if $m.returnType.ftot ~~ "UNKNOWN" {
 say "YG UNKNOWN 2: '", $m.returnType.base, "'";
                    $m.blackListed = True;
                    next MLOOP;
                }
            }
            for $m.arguments -> $a {
                if $a.ftot ~~ "UNKNOWN" {
 say "YG UNKNOWN 3: '", $a.base, "'";
                    $m.blackListed = True;
                    next MLOOP;
                }
            }
        }
    }




    # Read black and white lists files
    say "Reading blacklist and whitelist";

    if !$whiteList.IO.e || !$whiteList.IO.f {
        note "Currently a white list is mandatory";
        die "No white list $whiteList found";
    }
    my (@whiteClasses,  @whiteMethods) := readList($whiteList);

    if !$blackList.IO.e || !$blackList.IO.f {
        note "File $blackList not found: assuming an empty black list";
    }
    my (@blackClasses,  @blackMethods) := readList($blackList);

    
    # Whitelist any uncolored class whose at least one method is whitelisted
    
    # Look for such classes
    my $w = set(@whiteClasses);
    my $b = set(@@blackClasses);
    my @toAdd = ();
    for @whiteMethods -> $m {
        my $c = $m.class;
        if ($c !(elem) $w) && ($c !(elem) $b) {
            @toAdd.push($c);
        }
    }
    
    my $ta = set(@toAdd);                # Remove doubles
    @whiteClasses.append($ta.keys);      # Add classes to the white list 


    # $ok : Flag "unknown class" found in black or white list.
    #    Used to gather all the unknown classes, rather than only the first one,
    #    before dying and reporting to the user.

    # Propagate whitelist to all ancestors of classes
    my $ok = True;
    for @whiteClasses -> $k {
        my $qc;

        # Mark the given class
        if $api.qclasses{$k}:exists {
            $qc = $api.qclasses{$k};
            $qc.whiteListed = True;
        } else {
            note "Unknown class $k in white list";
            $ok = False;
        }

        # Mark its ancestors
        if $ok {    # Unless some unknown class found
            for $qc.ancestors -> $cl {
                if $api.qclasses{$cl}:exists {
                    $api.qclasses{$cl}.whiteListed = True;
                }
            }
        }
    }


    # Propagate blacklist to all descendants of classes
    for @blackClasses -> $k {
        my $qc;

        # Mark the given class
        if $api.qclasses{$k}:exists {
            $qc = $api.qclasses{$k};
            $qc.blackListed = True;
        } else {
            note "Unknown class $k in black list";
            $ok = False;
        }

        # Mark its descendants
        if $ok {    # Unless some unknown class found
            for $qc.descendants -> $cl {
                if $api.qclasses{$cl}:exists {
                    $api.qclasses{$cl}.blackListed = True;
                }
            }
        }
    }


    # Mark the methods specified in the white list
    WMLOOP: for @whiteMethods -> $m {

        # Mark the given method
        my $qc;
        if $api.qclasses{$m.class}:exists {
            $qc = $api.qclasses{$m.class};
        } else {
            note "Unknown class ", $m.class, " in the white list";
            $ok = False;
            next WMLOOP;
        }
        my $mfound = False;
        my $fname = $m.name ~~ $m.class ?? "ctor" !! $m.name;
        WQCMLOOP: for $qc.methods -> $me {
            if $me.name ~~ $fname {
                if $m.signature ~~ qSignature($me, showNames => False) {
                    $me.whiteListed = True;
                    $mfound = True;
                    last WQCMLOOP;
                }
            }
        }
        if !$mfound {
            note "Unknown method ",
                    $m.class, '::', $m.name, $m.signature,
                    " in the white list";
            $ok = False;
            next WMLOOP;
        }
    }


    # Mark the methods specified in the black list
    BMLOOP: for @blackMethods -> $m {

        # Mark the given method
        my $qc;
        if $api.qclasses{$m.class}:exists {
            $qc = $api.qclasses{$m.class};
        } else {
            note "Unknown class ", $m.class, " in the black list";
            $ok = False;
            next BMLOOP;
        }
        my $mfound = False;
        my $fname = $m.name ~~ $m.class ?? "ctor" !! $m.name;
        BQCMLOOP: for $qc.methods -> $me {
            if $me.name ~~ $fname {
                if $m.signature ~~ qSignature($me, showNames => False) {
                    $me.blackListed = True;
                    $mfound = True;
                    last BQCMLOOP;
                }
            }
        }
        if !$mfound {
            note "Unknown method ",
                    $m.class, '::', $m.name, $m.signature,
                    " in the black list";
            $ok = False;
            next BMLOOP;
        }
    }


    if !$ok {
        die "Processing aborted: Unknown name has been found\n"
            ~ "\t\tin the black and/or white list(s)";
    }





    # For all methods :
    #    - Blacklist any method whose at least one argument is blacklisted

    for $api.qclasses.kv -> $k, $v {
        MBCL: for $v.methods -> $m {
            next MBCL if $m.blackListed;
            if $m.name ne "ctor" {
                if $m.returnType.ftot ~~ "CLASS" {
                    # Is class blacklisted ?
                    if $api.qclasses{$m.returnType.fbase}:exists
                            && $api.qclasses{$m.returnType.fbase}.blackListed {
                        $m.blackListed = True;
                        next MBCL;
                    }
                }
            }
            for $m.arguments -> $a {
                if $a.ftot ~~ "CLASS" {
                    # Is class blacklisted ?
                    if $api.qclasses{$a.fbase}:exists
                                && $api.qclasses{$a.fbase}.blackListed {
                        $m.blackListed = True;
                        next MBCL;
                    }
                }
            }

        }
    }


    # For all methods :
    #    - Blacklist all pure virtual method

    for $api.qclasses.kv -> $k, $v {
        for $v.methods -> $m {
            if $m.isPureVirtual {
                $m.blackListed = True;
            }
        }
    }


    # For all classes :
    #    - Blacklist all ctors of an abstract class

    for $api.qclasses.kv -> $k, $v {
        next unless $v.isAbstract;
        for $v.methods -> $m {
            if $v.isAbstract && $m.name ~~ "ctor" {
                $m.blackListed = True;
            }
        }
    }






    # For all whitelisted class :
    #    - if not --strict, mark as white any colorless method
    #    - Look at each whitelisted method which is not blacklisted
    #        - Look at each argument matching a colorless class and set
    #          this class as whitelisted
    #    - Propagate the whiteListed flag to all ancestors of the class
    # Loop on these actions until a cycle occurs without any more class
    # being whitelisted.

    my $cycle = 0;
    LOOP: loop {
        say "Cycle : ", ++$cycle;

        # Look for classes needing to be whitelisted
        my @selected = ();   # Where to remember these classes
        CBCL: for $api.qclasses.kv -> $k, $v {
            next CBCL unless $v.whiteListed;
            MBCL: for $v.methods -> $m {
                next MBCL if $m.blackListed;

                # If not --strict set to white any colorless method of a white class
                $m.whiteListed = True unless $strict;

                next MBCL unless $m.whiteListed;
                my @types = ();
                if $m.name ne "ctor" {
                    @types.push($m.returnType);
                }
                for $m.arguments -> $a {
                    @types.push($a);
                }

                for @types -> $t {
                    # What sort of thing is $t ? :

                    if $t.ftot ~~ "CLASS" {
                        # Is class whitelisted ?
                        if $api.qclasses{$t.fbase}:exists {
                            if !$api.qclasses{$t.fbase}.whiteListed {
                                @selected.push($t.fbase);  # Remember the class
                            }
                        }
                    } elsif $t.ftot ~~ "ENUM" {
                        if !$api.qclasses{$t.fclass}.whiteListed {
                            # Whitelist the enum
                            $api.qclasses{$t.fclass}.enums{$t.fbase}.whiteListed = True;
                            @selected.push($t.fclass);  # Remember the class of the enum
                        }
                    }

                }
            }
        }

        # Whitelist the classes or stop the main loop when nothing more to do
        if @selected.elems {

            # Whitelist the classes
            say "count = ", @selected.elems;
            for @selected -> $cl0 {
                # Whitelist the class
                $api.qclasses{$cl0}.whiteListed = True;

                # Then propagate to ancestors of the class
                for $api.qclasses{$cl0}.ancestors -> $cl {
                    if $api.qclasses{$cl}:exists {
                        $api.qclasses{$cl}.whiteListed = True;
                    }
                }
            }

        } else {

            # Stop the main loop when nothing more to do
            last LOOP;
        }
    }

}

# Whitelist any enum used by a whitelisted method
sub markEnums(API $api) is export
{
    for $api.qclasses.kv -> $k, $v {
        next if $v.blackListed || !$v.whiteListed;
        for $v.methods -> $m {
            next if $m.blackListed || !$m.whiteListed;
            # say "MARKENUMS ", $k, '::', $m.name; 
            process($m.returnType);
            for $m.arguments -> $a {
                process($a);
            }
        }
    }
    
    sub process($arg) {
        if $arg.ftot ~~ "ENUM" {
            my $c = $arg.fclass;
            my $e = $arg.fbase;
            $api.qclasses{$c}.enums{$e}.whiteListed = True;
            $api.qclasses{$c}.whiteListed = True;
            # say "   W : ", $c, "::", $api.qclasses{$c}.enums{$e}.name;
        } elsif $arg.ftot ~~ "COMPOSITE"
                    && $arg.subtype.ftot ~~ "ENUM" {
            my $c = $arg.subtype.fclass;
            my $e = $arg.subtype.fbase;
            $api.qclasses{$c}.enums{$e}.whiteListed = True;
            $api.qclasses{$c}.whiteListed = True;                        
            # say "   W : ", $c, "::", $api.qclasses{$c}.enums{$e}.name;
        }
    }
}



