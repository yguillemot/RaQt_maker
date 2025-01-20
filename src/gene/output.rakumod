use gene::common;

###############################################################################
# Dump the whole API $api in the file $output_file
sub dump_api(API $api, Str $output_file, Bool :$very, Bool :$verbose) is export
{
    # Plural form suffix
    sub s($n) { $n > 1 ?? "s" !! "" }
    sub ren($n) { $n > 1 ?? "ren" !! "" }

    my $out = "";

    { print "DUMP_API: "; print "VERY " if $very; say "VERBOSE"; } if $verbose;

    my $nbt = $api.topTypedefs.keys.elems;
    if $nbt {
        $out ~= "$nbt top typedef&s($nbt) :\n";
        for $api.topTypedefs.sort>>.kv -> ($tname, $typedef) {
            $out ~= "\t$tname : " ~ $typedef.type.str ~ "\n";
        }
        $out ~= "\n";
    }

    for $api.qclasses.sort>>.kv -> ($name, $qclass) {
        $out ~= "class $name";
        $out ~= " is QObj" if $qclass.isQObj;
        $out ~= " :\n";

        my $nb = $qclass.parents.elems;
        if $nb {
            $out ~= "\t$nb parent&s($nb) :\n";
            $out ~= [~] "\t\t" <<~>> $qclass.parents.sort <<~>> "\n";
        }

        $nb = $qclass.ancestors.elems;
        if $nb {
            $out ~= "\t$nb ancestor&s($nb) :\n";
            $out ~= [~] "\t\t" <<~>> $qclass.ancestors.sort <<~>> "\n";
        }

        $nb = $qclass.children.elems;
        if $nb {
            $out ~= "\t$nb child&ren($nb) :\n";
            $out ~= [~] "\t\t" <<~>> $qclass.children.sort <<~>> "\n";
        }

        $nb = $qclass.descendants.elems;
        if $nb {
            $out ~= "\t$nb descendant&s($nb) :\n";
            $out ~= [~] "\t\t" <<~>> $qclass.descendants.sort <<~>> "\n";
        }

        $nb = $qclass.enums.elems;
        if $nb {
            $out ~= "\t$nb enum&s($nb) :\n";
            for $qclass.enums.sort>>.kv -> ($ename, $enum) {
                my $nbe = $enum.items.elems;
                $out ~= "\t\t$ename has $nbe element&s($nbe)\n";
            }
        }

        $nb = $qclass.typedefs.keys.elems;
        if $nb {
            $out ~= "\t$nb typedef&s($nb) :\n";
            for $qclass.typedefs.sort>>.kv -> ($tname, $typedef) {
                $out ~= "\t\t$tname : " ~ $typedef.type.str ~ "\n";
            }
        }

        my @prots = ();
        my @ctors = ();
        my @meths = ();
        my @slots = ();
        my @signals = ();
        my @virtuals = ();
        my @statics = ();
        for $qclass.methods.sort({$^a.name cmp $^b.name}) -> $m {
            if $m.isProtected {
                @prots.push($m);
            } elsif $m.name eq "ctor" {
                @ctors.push($m);
            } elsif $m.isSlot {
                @slots.push($m);
            } elsif $m.isSignal {
                @signals.push($m);
            } elsif $m.isVirtual {
                @virtuals.push($m);
            } elsif $m.isStatic {
                @statics.push($m);
            } else {
                @meths.push($m);
            }
        }

        sub show(@methods, $category, Bool :$very, Bool :$verbose --> Str) {
            my $out = "";
            my $n = @methods.elems;
            if $n {
                $out ~= "\t$n $category&s($n) :\n";
                for @methods -> $m {
                    $out ~= "~~~~~~~ ";
                    # $out ~= "\t\t";
                    $out ~= $m.returnType.str ~ " " unless $m.name eq "ctor";
                    $out ~= $m.name ~ "\n";
                    $out ~= "\t\t\t" ~ qSignature($m, showDefault => True) ~ "\n";
                    if $verbose {
  say "METHOD : ", $m;
                        $out ~= show_verbose(0, $m.returnType)
                                                        unless $m.name eq "ctor";
                        { $out ~= dumpArg($m.returnType)
                                    unless $m.name eq "ctor"; } if $very;
                        for (1..*) Z $m.arguments -> ($n, $a) {
                            $out ~= show_verbose($n, $a);
                            $out ~= dumpArg($a) if $very;
                        }
                    }
                }
            }
            return $out;
        }

        $out ~= show(@ctors, "ctor");
        $out ~= show(@slots, "slot");
        $out ~= show(@signals, "signal");
        $out ~= show(@virtuals, "virtual method");
        $out ~= show(@meths, "method") :$very :$verbose;
        $out ~= show(@statics, "static method");
        $out ~= show(@prots, "protected method");

        $out ~= "\n";
    }

    spurt $output_file, $out;
}


###############################################################################
# Count types of types used by methods
sub countTypesOfTypes(API $api) is export
{
    my (@ca, @ea, @na, @ua, @ka, @aa) = ();      # Init accumulators

    for $api.qclasses.kv -> $k, $v {
        for $v.methods -> $m {
            my @types = ();
            if $m.name ne "ctor" {
                @types.push($m.returnType.base);
            }
            for $m.arguments -> $a {
                @types.push($a.base);
            }

            for @types -> $t {

                # What sort of thing is $t ? :
                my @r = finalTypeOf(api => $api,
                                    from => $k,
                                    type => Ltype.new(base => $t, postop => ""));
                my ($tot, $c, $lt, $st) = @r;

                given $tot {
                    when "CLASS" {
                        @ca.push($lt.base);
                    }
                    when "ENUM" {
                        @ea.push($c ~ '::' ~ $lt.base); # There is no toplevel enum
                    }
                    when "NATIVE" {
                        @na.push($lt.base);
                    }
                    when "UNKNOWN" {
                        @ua.push($lt.base);
                    }
                    when "COMPOSITE" {
                        my ($stot, $sc, $slt) = $st;
                        my $where = $sc ?? $sc ~ '::' !! '';
                        @ka.push($lt.base ~ '<' ~ $where ~ $slt.base ~ '>');
                    }
                    default {
                        @aa.push($lt.base);
                    }
                }

                die "Can't get final type of $t" if $tot ~~ "???"; # Still useful ?
            }
        }
    }

    # Show counts ot types
    say "";
    say "How many types of types are used :";
    say "   CLASS :      ", @ca.elems;
    say "   ENUM :       ", @ea.elems;
    say "   NATIVE :     ", @na.elems;
    say "   COMPOSITE :  ", @ka.elems;
    say "   UNKNOWN :    ", @ua.elems;
    say "   ??? :        ", @aa.elems;
    say "";


    # And again, but without doubles;;
    say "";
    say "The same counts, but without doubles :";
    say "   CLASS :      ", set(@ca).elems;
    say "   ENUM :       ", set(@ea).elems;
    say "   NATIVE :     ", set(@na).elems;
    say "   COMPOSITE :  ", set(@ka).elems;
    say "   UNKNOWN :    ", set(@ua).elems;
    say "   ??? :        ", set(@aa).elems;
    say "";


    spurt "List_Class.txt", [~] set(@ca).keys.sort <<~>> "\n";
    spurt "List_Enum.txt", [~] set(@ea).keys.sort <<~>> "\n";
    spurt "List_Native.txt", [~] set(@na).keys.sort <<~>> "\n";
    spurt "List_Composite.txt", [~] set(@ka).keys.sort <<~>> "\n";
    spurt "List_Unknown.txt", [~] set(@ua).keys.sort <<~>> "\n";
}



##############################################################################
# Output a black/white classes synthesis
sub writeSynthesis(API $api, Str $output) is export
{
    my $out = "";
    for $api.qclasses.sort>>.kv -> ($name, $qclass) {
        my $out2 = "";
        my $ok = True;

        my $nb = $qclass.parents.elems;
        my $nbok = 0;
        for $qclass.parents -> $cl {
            $nbok++ if $api.qclasses{$cl}:exists;
        }
        $out2 ~= "p=$nbok/$nb";
        $ok &&= $nbok == $nb;

        $nb = $qclass.ancestors.elems;
        $nbok = 0;
        for $qclass.ancestors -> $cl {
            $nbok++ if $api.qclasses{$cl}:exists;
        }
        $out2 ~= " a=$nbok/$nb ";
        $ok &&= $nbok == $nb;

        $nbok = [+] (!<<$qclass.methods>>.blackListed)>>.Int;
        $out2 ~= "m=$nbok/" ~ $qclass.methods.elems;

        $nbok = [+] (!<<$qclass.enums.values>>.blackListed)>>.Int;
        $out2 ~= " e=$nbok/" ~ $qclass.enums.elems;

        $out ~= $qclass.blackListed ?? "B" !! " ";
        $out ~= $qclass.whiteListed ?? "W" !! " ";
        $out ~= " ";

        $out ~= $ok ?? "   " !! "KO ";
        $out ~= $qclass.isQObj ?? "QObj " !! "     ";
        $out ~= $name;
        $out ~= " " ~ $out2;

        $out ~= "\n";
    }
    spurt $output, $out;
}



##############################################################################
# Output white, black, gray and colorless classes in separate files
sub outputFinal(
    API :$api,
    Str :$oBlackList, Str :$oWhiteList,
    Str :$oGrayList, Str :$oColorlessList
) is export
{
    my $outW = "";
    my $outB = "";
    my $outG = "";
    my $outC = "";

    for $api.qclasses.sort>>.kv -> ($name, $qclass) {
        if $qclass.gray {
            $outG ~= $name ~ "\n";
        } elsif $qclass.blackListed {
            $outB ~= $name ~ "\n";
        } elsif $qclass.whiteListed {
            $outW ~= $name ~ "\n";
        } else {   # Colorless
            $outC ~= $name ~ "\n";
        }
        
        # dump each enum to the right file
        for $qclass.enums.sort>>.kv -> ($en, $ev) {
            my Str $out = "\t\t" ~ $name ~ '::' ~ $en ~ "\n";
            if $ev.gray {
                $outG ~= $out;
            } elsif $ev.blackListed {
                $outB ~= $out;
            } elsif $ev.whiteListed {
                $outW ~= $out;
            } else {   # Colorless
                $outC ~= $out;
            }
        }
        
        # and dump each method to the right file
        for $qclass.methods.sort: *.name -> $qc {
            my Str $out = "\t" ~ $name ~ '::' ~ $qc.name
                ~ qSignature($qc, showNames => False) ~ "\n";
            if $qc.gray {
                $outG ~= $out;
            } elsif $qc.blackListed {
                $outB ~= $out;
            } elsif $qc.whiteListed {
                $outW ~= $out;
            } else {   # Colorless
                $outC ~= $out;
            }
        }
    }

    spurt $oBlackList, $outB;
    spurt $oWhiteList, $outW;
    spurt $oColorlessList, $outC;
    spurt $oGrayList, $outG;
}

###############################################################################
# Dump types used by methods

sub show_types(API $api) is export
{

    my %retTypes;
    my %argTypes;

    QCLASS: for $api.qclasses.kv -> $k, $v {
        next QCLASS if $v.blackListed || !$v.whiteListed;

        METHOD: for $v.methods -> $m {
            next METHOD if $m.blackListed || !$m.whiteListed;

            if $m.name !~~ "ctor" {
               accumulate(%retTypes, $m.returnType);
            }

            for $m.arguments -> $a {
                accumulate(%argTypes, $a);
            }
        }

    }

    sub accumulate(%tps, $t)
    {
        given $t.ftot {
            when "CLASS" {
                if %tps{"CLASS"}{$t.fpostop}:exists {
                    %tps{"CLASS"}{$t.fpostop}++;
                } else {
                    %tps{"CLASS"}{$t.fpostop} = 1;
                }
            }
            when "ENUM" {
                if %tps{"ENUM"}{$t.fpostop}:exists {
                    %tps{"ENUM"}{$t.fpostop}++;
                } else {
                    %tps{"ENUM"}{$t.fpostop} = 1;
                }
            }
            when "NATIVE" {
                if %tps{$t.fbase}{$t.fpostop}:exists {
                    %tps{$t.fbase}{$t.fpostop}++;
                } else {
                    %tps{$t.fbase}{$t.fpostop} = 1;
                }
            }
            when "SPECIAL" {
                if %tps{$t.base}{$t.postop}:exists {
                    %tps{$t.base}{$t.postop}++;
                } else {
                    %tps{$t.base}{$t.postop} = 1;
                }
            }
            when "UNKNOWN" {
                if %tps{"UNKNOWN"}{$t.fpostop}:exists {
                    %tps{"UNKNOWN"}{$t.fpostop}++;
                } else {
                    %tps{"UNKNOWN"}{$t.fpostop} = 1;
                }
            }
            when "COMPOSITE" {
                if %tps{"COMPOSITE"}{$t.fpostop}:exists {
                    %tps{"COMPOSITE"}{$t.fpostop}++;
                } else {
                    %tps{"COMPOSITE"}{$t.fpostop} = 1;
                }
            }
            default {
                die "Unexpected type of type : ", $t.ftot;
            }
        }
    }

    for %retTypes.sort>>.kv -> ($t, $v) {
        for $v.sort>>.kv -> ($p, $w) {
            say "RET  $t $p : $w";
        }
    }

    for %argTypes.sort>>.kv -> ($t, $v) {
        for $v.sort>>.kv -> ($p, $w) {
            say "ARG  $t $p : $w";
        }
    }

}



sub show_types_2(API $api) is export
{

    my %retTypes;
    my %argTypes;

    QCLASS: for $api.qclasses.sort>>.kv -> ($k, $v) {
        next QCLASS if $v.blackListed || !$v.whiteListed;

        METHOD: for $v.methods -> $m {
            next METHOD if $m.blackListed || !$m.whiteListed;

            say $k, "::", $m.name, " :";

            if $m.name !~~ "ctor" {
               show(0, $m.returnType);
            }

            for (1..*) Z $m.arguments -> ($n, $a) {
                show($n, $a);
            }
        }

    }

    sub show($n, $data)
    {
        say "\t$n : ",
            $data.ftot, "\t", $data.base, $data.postop, " : ",
            $data.fclass, ":: ", $data.fbase, $data.fpostop,
            " (", $data.fname, ")";
        say "\t\tQType = ", qType($data), " ", qPostop($data);
        say "\t\tCType = ", cType($data), " ", cPostop($data);
        say "\t\tNType = ", nType($data);
        say "\t\tRType = ", rType($data);

    }

}


    sub show_verbose($n, $data --> Str)
    {
        my $out = "";
        $out ~= "\t$n : " ~
                $data.ftot.gist ~ "\t" ~ $data.base.gist ~ $data.postop ~ " : " ~
                $data.fclass.gist ~ ":: " ~ $data.fbase.gist ~ $data.fpostop ~
                " (" ~ $data.fname.gist ~ ")\n";
        $out ~= "\t\tQType = " ~ qType($data) ~ " " ~ qPostop($data) ~ "\n";
        $out ~= "\t\tCType = " ~ cType($data, :nofail) ~ " "
                               ~ cPostop($data, :nofail) ~ "\n";
        $out ~= "\t\tNType = " ~ nType($data, :nofail) ~ "\n";
        $out ~= "\t\tRType = " ~ rType($data, :nofail) ~ "\n";
        return $out;
    }

    # $x is Argument or is Rtype
    sub dumpArg($x --> Str)
    {
#          "DUMPARG !\n";
        $x.showData("\t\t");
    }
