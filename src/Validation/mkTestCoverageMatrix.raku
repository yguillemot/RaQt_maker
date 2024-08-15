
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

    has Str @.files;    # Test or example files where the method is used
    has Str @.analogs;  # Keys of already tested methods with the same signature

    submethod TWEAK
    {
        say "K={$!class} N={$!name} Q={$!qSig}";

        $!signal = ?($!qualifiers ~~ m/"Si"/);
        $!privateSignal = ?($!qualifiers ~~ m/"Ps"/);
        $!slot = ?($!qualifiers ~~ m/"Sl"/);
        $!virtual = ?($!qualifiers ~~ m/"Vi"/);
        $!static = ?($!qualifiers ~~ m/"St"/);
        $!protected = ?($!qualifiers ~~ m/"Pr"/);
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


my Str $txt = slurp "../methodsList.txt";
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
say "Qualifiers               Total   Tested   Analog Untested";
say "--------------------- -------- -------- -------- --------";
for %counts.keys.sort -> $k {
    my Counts $c = %counts{$k};
    say sprintf "%-21s %8d %8d %8d %8d",
                $k, $c.total, $c.tested, $c.analog, $c.untested;
    $gTotal += $c.total;
    $gTested += $c.tested;
    $gAnalog += $c.analog;
    $gUntested += $c.untested;
}
say "                      -------- -------- -------- --------";
say sprintf "%21s %8d %8d %8d %8d",
            "Grand total :", $gTotal, $gTested, $gAnalog, $gUntested;
say "";


# Show untested methods


