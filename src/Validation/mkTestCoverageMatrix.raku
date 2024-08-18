
class Method {
    has Str $.class;
    has Str $.name;
    has Str $.rSig;
    has Str $.qSig;
    has Str $.qualifiers;

    has Bool $.signal = False;
    has Bool $.privateSignal = False;
    has Bool $.slot = False;
    has Bool $.virtual = False;
    has Bool $.static = False;
    has Bool $.protected = False;
    has Bool $.override = False;

    has Str @.files;    # Test or example files where the method is used
    has Str @.analogs;  # Keys of already tested methods with the same signaturePr

    submethod TWEAK
    {
        say "K={$!class} N={$!name} Q={$!qSig}";

        $!signal = ?($!qualifiers ~~ m/"Si"/);
        $!privateSignal = ?($!qualifiers ~~ m/"Ps"/);
        $!slot = ?($!qualifiers ~~ m/"Sl"/);
        $!virtual = ?($!qualifiers ~~ m/"Vi"/);
        $!static = ?($!qualifiers ~~ m/"St"/);
        $!protected = ?($!qualifiers ~~ m/"Pr"/);
        $!override = ?($!qualifiers ~~ m/"Ov"/);
    }

    # Create an understandable qualifiers string
    method qualStr( --> Str)
    {
        my $q = "[";
        $q ~= " virtual" if $.virtual;
        $q ~= " protected" if $.protected;
        $q ~= " slot" if $.slot;
        $q ~= " signal" if $.signal;
        $q ~= " private signal" if $.privateSignal;
        $q ~= " override" if $.override;
        $q ~= " ]";
        return $q;
    }


}

class Counts {
    has Int $.total is rw = 0;
    has Int $.tested is rw = 0;
    has Int $.analog is rw = 0;
    has Int $.untested is rw = 0;
}


my Str $txt = slurp "JeuEssai.txt";
# my Str $txt = slurp "../methodsList.txt";
my %methods = ();
my %signatures = ();
my %counts = ();

# Populate %methods and %signatures hashes from file "methodsList.txt"
for $txt.lines {
    # line : "class § qualifiers § method § Raku signature § C++ signature"
    if $_ ~~ m/^ (\w+) '§' (\w*) '§' (\w+)'§' (<-[§]>+) '§' (<-[§]>+) $/ {
        say "$0 : $2  [$1]";
        say "\t$2$3";
        say "\t$4";
        say "";

        my Method $m =  Method.new: class => ~$0,
                                    name => ~$2,
                                    rsig => ~$3,
                                    qSig => ~$4,
                                    qualifiers => ~$1;

        # Key = "class::name;;signature"
        my Str $methodId = "$0::$2;;$4";
        %methods{$methodId} = $m;

        # Key = "qualifiers:signature"
        my Str $sigId = "$1:$4";
        %signatures{$sigId}.push: $methodId;
    }
}



# For debug
spurt "keys_methods.txt", [~] %methods.keys.sort <<~>> "\n";
spurt "keys_signatures.txt", [~] %signatures.keys.sort <<~>> "\n";


say "=" x 12;

# Look for test or example scripts where methods are used
# (set up the field @.files in the elements of %methods)
my Str $base = "../../module";
my Str @paths = <examples t>;
for @paths -> $p {
    my Str $path = "$base/$p";
    for dir($path, test => { "$path/$_".IO ~~ :f & :r }) -> $f {
        say "$f";
        my Str $txt = slurp $f;

        # Look for all used Qt::Widgets packages
        $txt ~~ m:g/"use Qt::QtWidgets::" (\w+) ";"/;
        my $packages = set $/>>.list>>[0]>>.Str;

        METHOD: for %methods.kv -> $k, $v {

            # Class of the method must be in the packages list
            next METHOD if !$packages{$v.class};

            if $v.name ~~ "ctor" {
                if $txt ~~ m/\W "{$v.class}.new" \W/ {
                    $v.files.push: ~$f;
                }
            } else {
                given $v.qualStr {
                    when "[ signal ]" {
                        # Look for
                        #  'connect something , "method" ,'
                        # or for
                        #   connect <something> , <something> ,
                        #                  <something> , <method> ;
                        if    $txt ~~ m/\W "connect" <-[,]>+ ","
                                        \s* '"' "{$v.name}" '"' \s* ","/
                        || $txt ~~ m/\W "connect" <-[,]>+ ","
                                    <-[,]>+ "," <-[,]>+ ","
                                    \s* '"' "{$v.name}" '"' \s* ";"/
                        {
                            $v.files.push: ~$f;
                        }
                    }

                    when "[ private signal ]" {
                        # Look for
                        #   connect <something> , <method> ,
                        if $txt ~~ m/\W "connect" <-[,]>+ ","
                                    \s* '"' "{$v.name}" '"' \s* ","/
                        {
                            $v.files.push: ~$f;
                        }
                    }

                    when "[ slot ]" {
                        # Look for
                        #   connect <something> , <something> ,
                        #                   <something> , <method> ;
                        if $txt ~~ m/\W "connect" <-[,]>+ ","
                                    <-[,]>+ "," <-[,]>+ ","
                                    \s* '"' "{$v.name}" '"' \s* ";"/
                        {
                            $v.files.push: ~$f;
                        }
                    }


                    when "[ virtual slot ]" {
                    }

                    when "[ virtual ]" {
                        # Look for
                        #   class <something> is <class>
                        # and for
                        #   self.<class>::subClass
                        # and for
                        #   method <method>
#                         print "VIRTUAL : ", $v.class, " :: ", $v.name;
#                         if $txt ~~ m/\W "{$v.name}" \W/ { say " FOUND"; }
                        if    $txt ~~ m/\W "class" \s+ \w+ \s+
                                                "is" \s+ "{$v.class}" \W/
                           && $txt ~~ m/\W "self.{$v.class}::subClass" \W/
                           && $txt ~~ m/\W "method" \s+ "{$v.name}" \W/
                        {
                            $v.files.push: ~$f;
#                             say " OK";
                        }
#                         else { say ""; }
                    }

                    when "[ protected ]" {
                    }

                    when "[ override ]" {
                    }

                    when "[ protected override ]" {
                    }


                    when "[ slot override ]" {   # On passe vraiment ici ???
                    }


                    when "[ virtual protected ]" {
                        # No difference between "virtual" and
                        # "virtual protected" : OK ?
                        #
                        # Look for
                        #   class <something> is <class>
                        # and for
                        #   self.<class>::subClass
                        # and for
                        #   method <method>
#                         print "VIRTUAL PROTECTED : ", $v.class, " :: ", $v.name;
#                         if $txt ~~ m/\W "{$v.name}" \W/ { say " FOUND"; }
                        if    $txt ~~ m/\W "class" \s+ \w+ \s+
                                                "is" \s+ "{$v.class}" \W/
                           && $txt ~~ m/\W "self.{$v.class}::subClass" \W/
                           && $txt ~~ m/\W "method" \s+ "{$v.name}" \W/
                        {
                            $v.files.push: ~$f;
#                             say " OK";
                        }
#                         else { say ""; }
                    }


                    when "[ ]" {
                        if    $txt ~~ m/\W "$k" \W/
                        || $txt ~~ m/'.' "{$v.name}" \W/ {
                                $v.files.push: ~$f;
                        }
                    }

                    default {
                        die "Unexpected qualifier string \"$_\" found";
                    }
                }
            }
        }
    }
}

say "+" x 12;


# Provisional
# Write the list of methods and where they are used
my Int $mcount = 0;
my Int $vcount = 0;

my Str $out = "";
for %methods.keys.sort -> $k {
    # say $k;
    my $v = %methods{$k};
    $mcount++;

    $out ~= $k ~ " " ~ $v.qualStr ~ "\n";

    $vcount++ if $v.files.elems;
    for $v.files {
        # say "\t$_";
        $_ ~~ s/ "$base" '/' //;
        $out ~= "\t$_\n";
    }
    $out ~= "\n";
}
spurt "matrix.txt", $out;


# Provisional
# Write the list of methods and where they are used, but try to group methods
# sharing the same signatures

$out = "";
for %signatures.keys.sort -> $k {
    my $v = %signatures{$k};
    $out ~= $k ~ "\n";
    for @$v -> $m {
        $out ~= "\t$m\n";
        for %methods{$m} -> $w {
            for $w.files {
                $_ ~~ s/ "$base" '/' //;
                $out ~= "\t\t$_\n";
            }
        }
    }
}
spurt "Signatures.txt", $out;

say "";
say "$mcount methods";
say "$vcount validated methods";
say $mcount - $vcount, " unvalidated methods";


# Set up the fields @.analogs in the elements of %methods
for %methods.keys.sort -> $k {
    # say $k;
    my $v = %methods{$k};
    if !$v.files {
        my $sigId = $v.qualifiers ~ ":" ~ $v.qSig;
        for @(%signatures{$sigId}) -> $k {
            if %methods{$k}.files {
                $v.analogs.push: $k;
            }
        }
    }
}




############################################"""""

# Output results in a printable string
#   There is two arguments groups.
#       The test group:
#            tested and analog
#       The qualifier group:
#            signal, privateSignal, slot, virtual, override, protected and static
#   In each group, the arguments are ANDed by default and the unspecified
#   arguments are ignored (no filter is applied).
#
#   In each group, a special argument may be used to initialize the others:
#   :untested
#       - Forces :!tested and :!analog
#       - ANDed the specified arguments.
#   :!untested
#       - Forces :tested and :analog. ORed the specified arguments.
#       - ORed the specified arguments.
#   :unqualified
#       - Forces :!signal, :!privateSignal, :!slot, etc...
#       - ANDed the specified arguments.
#   :!unqualified
#       - Forces :signal, :privateSignal, :slot, etc...
#       - ORed the specified arguments.
#
# Examples:
#
#   - no argument
#       Prints all methods (no filter)
#
#    - :virtual
#       Prints methods "virtual", "virtual protected", "virtual slot"
#
#     - :virtual :!slot
#       Prints methods "virtual", "virtual protected"
#
#     - :virtual :slot
#       Prints methods "virtual slot"
#
#    - :unqualified
#       Prints methods without any qualifier
#
#    - :unqualified :!virtual
#       Prints methods without any qualifier
#
#    - :unqualified :virtual
#       Prints methods "virtual"
#
#    - :!unqualified
#       Prints nothing
#
sub getData(Bool :$untested,
            Bool :$tested is copy, Bool :$analog is copy,
            Bool :$unqualified,
            Bool :$signal is copy; Bool :$privateSignal is copy, Bool :$slot is copy,
            Bool :$virtual is copy, Bool :$override is copy, Bool :$protected is copy,
            Bool :$static is copy
            --> Str)
{

    sub ok(Method $v --> Bool)
    {
say "OK {$v.class}::{$v.name} <{$v.qualifiers}>";
say "   signal  p=", $signal, " v=", $v.signal, " => ", ($signal.defined && (?$signal == $v.signal));
say "   privateSignal  p=", $privateSignal, " v=", $v.privateSignal, " => ", ($privateSignal.defined && (?$privateSignal == $v.privateSignal));
say "   slot  p=", $slot, " v=", $v.slot, " => ", ($slot.defined && (?$slot == $v.slot));
say "   virtual  p=", $virtual, " v=", $v.virtual, " => ", ($virtual.defined && (?$virtual == $v.virtual));
say "   override  p=", $override, " v=", $v.override, " => ", ($override.defined && (?$override == $v.override));
say "   protected  p=", $protected, " v=", $v.protected, " => ", ($protected.defined && (?$protected == $v.protected));
say "   static  p=", $static, " v=", $v.static, " => ", ($static.defined && (?$static == $v.static));
say "   unqualified  p=", $unqualified;


#         my Bool $qualifOK =     ?$allQualifiers
#                             ||  ($signal.defined && (?$signal == $v.signal))
#                             ||  ($privateSignal.defined && (?$privateSignal == $v.privateSignal))
#                             ||  ($slot.defined && (?$slot == $v.slot))
#                             ||  ($virtual.defined && (?$virtual == $v.virtual))
#                             ||  ($override.defined && (?$override == $v.override))
#                             ||  ($protected.defined && (?$protected == $v.protected))
#                             ||  ($static.defined && (?$static == $v.static))
#                             ||  (    ?$unqualified && !$v.slot && !$v.signal && !$v.privateSignal
#                                   && !$v.virtual && !$v.override && !$v.protected
#                                   && !$v.static);

        my Bool $qualifOK = True;
        my Bool $op = False;        # False ==> &&
        if $unqualified.defined {
            if $unqualified {
                $signal = False unless $signal.defined;
                $privateSignal = False unless $privateSignal.defined;
                $slot = False unless $slot.defined;
                $virtual = False unless $virtual.defined;
                $override = False unless $override.defined;
                $protected = False unless $protected.defined;
                $static = False unless $static.defined;
            } else {
                $qualifOK = False;
                $op = True,             # True ==> ||
                $signal = True unless $signal.defined;
                $privateSignal = True unless $privateSignal.defined;
                $slot = True unless $slot.defined;
                $virtual = True unless $virtual.defined;
                $override = True unless $override.defined;
                $protected = True unless $protected.defined;
                $static = True unless $static.defined;
            }
        }

        sub boolSet(Bool $in1, Bool $in2, Bool :$or = False --> Bool)
        {
            if $or {
                return $in1 || $in2;
            } else {
                return $in1 && $in2;
            }
        }

        if $signal.defined { $qualifOK = boolSet $qualifOK,  ?$signal == $v.signal, or => $op; }
        if $privateSignal.defined { $qualifOK = boolSet $qualifOK,  ?$privateSignal == $v.privateSignal, or => $op; }
        if $slot.defined { $qualifOK = boolSet $qualifOK,  ?$slot == $v.slot, or => $op; }
        if $virtual.defined { $qualifOK = boolSet $qualifOK,  ?$virtual == $v.virtual, or => $op; }
        if $override.defined { $qualifOK = boolSet $qualifOK,  ?$override == $v.override, or => $op; }
        if $protected.defined { $qualifOK = boolSet $qualifOK,  ?$protected == $v.protected, or => $op; }
        if $static.defined { $qualifOK = boolSet $qualifOK,  ?$static == $v.static, or => $op; }


        my Bool $statusOK = True;
        $op = False;        # False ==> &&
        if $untested.defined {
            if $untested {
                $tested = False unless $tested.defined;
                $analog = False unless $analog.defined;
            } else {
                $statusOK = False;
                $op = True;        # True ==> ||
                $tested = True unless $tested.defined;
                $analog = True unless $analog.defined;
            }
        }
        if $tested.defined { $statusOK = boolSet $statusOK,  ?$v.files == ?$tested, or => $op; }
        if $analog.defined { $statusOK = boolSet $statusOK,  ?$v.analogs == ?$analog, or => $op; }

say " qOK=$qualifOK sOK=$statusOK";
        return $statusOK && $qualifOK;
    }

    my Str $out = "";

    for %methods.keys.sort -> $k {
        my $v = %methods{$k};

        # Qualifiers string
        my $q = $v.qualStr;

        my Str $out0 = "";

        my $currentMethod = "$k $q\n";
        $out0 ~= $currentMethod if ok $v;

        for $v.files -> $f {
            $out0 ~= "\tTested in " ~ $f ~ "\n" if ok $v;
        }
        for $v.analogs -> $f {
            $out0 ~= "\tAnalog to " ~ $f ~ "\n" if ok $v;
        }

        $out0 ~= "\n" if $out0.chars;
        $out ~= $out0;
    }

    return $out;
}

################################################""""

# # class Method {
# #     has Str $.class;
# #     has Str $.name;
# #     has Str $.rSig;
# #     has Str $.qSig;
# #     has Str $.qualifiers;
# #
# #     has Bool $.signal = False;
# #     has Bool $.privateSignal = False;
# #     has Bool $.slot = False;
# #     has Bool $.virtual = False;
# #     has Bool $.static = False;
# #     has Bool $.protected = False;
# #     has Bool $.override = False;
# #
# #     has Str @.files;    # Test or example files where the method is used
# #     has Str @.analogs;  # Keys of already tested methods with the same signaturePr
# #
# # }


# my Method $m = Method.new: class => "MaClasse", name => "maMethode",
#                            rSig => "raku signature", qSig => "Qt signature",
#                            qualifiers => "ViOv";
#
# say "getData :";
# say getData $m,


#######################################################""""""


# Output the results in a file "Synthesis.txt"
$out = "";
my Str $outu = "";
for %methods.keys.sort -> $k {
    my $v = %methods{$k};

    # Qualifiers string
    my $q = $v.qualStr;

    if %counts{$q}:!exists {
        %counts{$q} = Counts.new;
    }

    my $currentMethod = "$k $q\n";
    $out ~= $currentMethod;

    my $status = "untested";
    for $v.files -> $f {
        $out ~= "\tTested in " ~ $f ~ "\n";
        $status = "tested";
    }
    for $v.analogs -> $f {
        $out ~= "\tAnalog to " ~ $f ~ "\n";
        $status = "analog";
    }

    %counts{$q}.total++;
    given $status {
        when "tested" { %counts{$q}.tested++; }
        when "analog" { %counts{$q}.analog++; }
        default       { %counts{$q}.untested++;  $outu ~= $currentMethod; }
    }

    $out ~= "\n";
}
spurt "Synthesis.txt", $out;
spurt "Untested.txt", $outu;

my $gTotal = 0;
my $gTested = 0;
my $gAnalog = 0;
my $gUntested = 0;

say "";
say "Qualifiers                   Total   Tested   Analog Untested";
say "------------------------- -------- -------- -------- --------";
for %counts.keys.sort -> $k {
    my Counts $c = %counts{$k};
    say sprintf "%-25s %8d %8d %8d %8d",
                $k, $c.total, $c.tested, $c.analog, $c.untested;
    $gTotal += $c.total;
    $gTested += $c.tested;
    $gAnalog += $c.analog;
    $gUntested += $c.untested;
}
say "                          -------- -------- -------- --------";
say sprintf "%25s %8d %8d %8d %8d",
            "Grand total :", $gTotal, $gTested, $gAnalog, $gUntested;
say "";



# # For testing getData :$out =
# # Create exactly the same file as Synthesis.tx above
# spurt "tmp.txt", getData;


# Show by qualifiers untested and tested methods

# $out = "UNTESTED\n--------\n\n";
# $out ~= getData :override, :untested;
# $out ~= "\nTESTED\n------\n\n";
# $out ~= getData :override, :tested, :analog;
# spurt "override.txt", $out;

# $out = "UNTESTED\n--------\n\n";
# $out ~= getData :protected, :!virtual, :untested;
# $out ~= "\nTESTED\n------\n\n";
# $out ~= getData :protected, :!virtual, :tested, :analog;
# spurt "protected_novirtual.txt", $out;

sub work(Str $fileName, *%_)
{
    $out = "UNTESTED\n--------\n\n";
    $out ~= getData :untested, |%_;
    $out ~= "\nTESTED\n------\n\n";
    $out ~= getData :tested, :analog, |%_;
    spurt $fileName, $out;
}

# work "protected_novirtual.txt", :protected, :noqualifier;

# work "unqualified.txt", :unqualified;
# work "override.txt", :override;
# work "privateSignal.txt", :privateSignal;
# work "protected.txt", :protected;
# work "protected_override.txt", :protected, :override;
# work "signal.txt", :signal;
# work "slot.txt", :slot;
# work "slot_override.txt", :slot, :override;
# work "virtual.txt", :virtual;
# work "virtual_protected.txt", :virtual, :protected;
# work "virtual_slot.txt", :virtual, :slot;

say getData :!unqualified :virtual;


