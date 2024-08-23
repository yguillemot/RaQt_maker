
class Method {
    has Str $.class;
    has Str $.name;
    has Str $.rSig;
    has Str $.qSig;
    has Str $.qualifiers;

    has Str @.qualifiersList;

    has Str @.files;    # Test or example files where the method is used
    has Str @.analogs;  # Keys of already tested methods with the same signaturePr

    submethod TWEAK
    {
        print "K={$!class} N={$!name} Q={$!qSig}";

        @!qualifiersList = $!qualifiers.words;

        say "q=\"", $!qualifiers, "\" QL=", @!qualifiersList;

        my $qs = set @!qualifiersList;
    }

    # Create an easy to compare qualifiers string
    method qualStr( --> Str)
    {
        # Add brackets
        my Str $q = '[ ' ~ $.qualifiers ~ ' ]';

        # Remove multiple spaces
        $q ~~ s:g/\s+/ /;

        return $q;
    }
}

class Counts {
    has Int $.total is rw = 0;
    has Int $.tested is rw = 0;
    has Int $.analog is rw = 0;
    has Int $.untested is rw = 0;
}


# my Str $txt = slurp "JeuEssai.txt";
my Str $txt = slurp "../methodsList.txt";
my %methods = ();
my %signatures = ();
my %counts = ();

# Populate %methods and %signatures hashes from file "methodsList.txt"
for $txt.lines {
    # line : "class § qualifiers § method § Raku signature § C++ signature"
    if $_ ~~ m/^ (\w+) \s* '§' \s* (<-[§]>*) \s* '§' \s* (\w+) \s* '§' (<-[§]>+) '§' (<-[§]>+) $/ {

        my Str $class = trim ~$0;
        my Str $method = trim ~$2;
        my Str $qualifiers = trim ~$1;
        my Str $rSig = trim ~$3;
        my Str $qSig = trim ~$4;

#         say "$class : $method  [$qualifiers]";
#         say "\t$method$rSig";
#         say "\t$qSig";
#         say "";

        my Method $m =  Method.new: class => $class,
                                    name => $method,
                                    rSig => $rSig,
                                    qSig => $qSig,
                                    qualifiers => $qualifiers;

        # Key = "class::name;;signature"
        my Str $methodId = $class ~ "::" ~ $method ~ ";;" ~ $qSig;
        %methods{$methodId} = $m;

        # Key = "qualifiers:signature"
        my Str $sigId = "$qualifiers:$qSig";
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

                    when "[ privateSignal ]" {
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


                    when "[ virtual slot ]" | "[ slot virtual ]" {
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

                    when "[ static ]" {
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




############################################

# Extract methods with given qualifiers from %methods
#     returns a List of %methods keys
#
# Examples :
#   @r = getQualifiedMethods ONLY, <WITH virtual protected>;
#   @r = getQualifiedMethods ONLY, <WITH virtual>, <WITHOUT protected>;   # Error
#   @r = getQualifiedMethods EVERYTHING, <WITHOUT protected>;
#   @r = getQualifiedMethods ONLY, <WITH virtual>, <WITHOUT protected>;

enum GetDataBase <ONLY EVERYTHING>;

sub getQualifiedMethods(GetDataBase $gdb, @options1 = (),
                                          @options2 = () --> List)
{
    my SetHash $with.=new;
    my SetHash $without.=new;

    sub getOptFrom(@opt) {
        return if !@opt;

        my $sh = @opt.SetHash;
        if $sh<WITH> {
            $sh.unset: "WITH";
            $with.set: $sh.keys;
        } elsif $sh<WITHOUT> {
            $sh.unset: "WITHOUT";
            $without.set: $sh.keys;
        } else {
            die "setOpt : nor WITH nor WITHOUT found";
        }
        if $with (.) $without {
            die "Can't have a same element in WITH and WITHOUT";
        }
    }

    getOptFrom @options1;
    getOptFrom @options2;

#     say "";
#     say "getQualifiedMethods :";
#     say "GDB : ", $gdb.Str;
#     say "WITH : ", $with;
#     say "WITHOUT : ", $without;
#     say "";


    my Str @selection;

    METHOD:
    for %methods.keys.sort -> $k {
        my $v = %methods{$k};

        # If gdb is ONLY, $with should have some elements
        next METHOD if $gdb == ONLY && $with.elems == 0;

        # $with should be included in $v.qualifierList
        next METHOD unless $with (<=) $v.qualifiersList;

        # None element from $without should be in $v.qualifierList
        next METHOD if ($v.qualifiersList (&) $without).elems != 0;

        @selection.push: $k;
    }

    return @selection;
}



# Extract methods with given test status from a list of %methods keys
#     returns a List of %methods keys
#
# Valid uses :
#   @r = getTestedMethods @in, ALL;
#   @r = getTestedMethods @in, UNTESTED;
#   @r = getTestedMethods @in, TESTED;
#   @r = getTestedMethods @in, ANALOG;
#   @r = getTestedMethods @in, TESTED, ANALOG;

enum TestMode (IGNORED => 0, ALL => 7, TESTED => 1, ANALOG => 2, UNTESTED => 4);

sub getTestedMethods(@methodIds, TestMode $testMode1,
                                 TestMode $testMode2 = IGNORED --> List)
{
    my Str @selection;

    my Int $mode = $testMode1 +| $testMode2;

    for @methodIds -> $k {
        my $v = %methods{$k};

        @selection.push: $k if    (!$v.files && !$v.analogs && ?($mode +& UNTESTED))
                               || (?$v.files && ?($mode +& TESTED))
                               || (?$v.analogs && ?($mode +& ANALOG));
    }

    return @selection;
}


# Create a printable list of methods from a list of %methods keys
#     returns a Str
#
# Usage :
#   my Str $out = printMethods @in;

sub printMethods(@methodIds --> Str)
{
    my Str $out;

    METHOD:
    for @methodIds -> $k {

        my $v = %methods{$k};

        # Qualifiers string
        my $q = $v.qualStr;

        $out ~= "$k $q\n";

        my Str $out0 = "";

        for $v.files -> $f {
            $out0 ~= "\tTested in " ~ $f ~ "\n";
        }
        for $v.analogs -> $f {
            $out0 ~= "\tAnalog to " ~ $f ~ "\n";
        }
# FOR DEBUG
# $out0 ~= "\tTESTED" if ?$v.files;
# $out0 ~= "\tANALOG" if ?$v.analogs;

        $out0 ~= "\n" if $out0.chars;
        $out ~= $out0;
    }

    return $out;
}


################################################


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


# For testing getQualifiedMethods, getQualifiedMethods and printMethods
# create exactly the same file as Synthesis.tx above
spurt "tmp.txt", printMethods getTestedMethods getQualifiedMethods(EVERYTHING), ALL;




# Show by qualifiers untested and tested methods

sub work(Str $fileName, GetDataBase $g, @opt1 = (), @opt2 = ())
{
    $out = "UNTESTED\n--------\n\n";
    my $r = printMethods getTestedMethods
                            getQualifiedMethods($g, @opt1, @opt2), UNTESTED;
    $out ~= $r if $r.defined;

    $out ~= "\nTESTED\n------\n\n";
    $r = printMethods getTestedMethods
                            getQualifiedMethods($g, @opt1, @opt2), TESTED, ANALOG;
    $out ~= $r if $r.defined;

    spurt $fileName, $out;
}

work "protected_novirtual.txt", EVERYTHING, <WITH protected>, <WITHOUT virtual>;

work "unqualified.txt", EVERYTHING, <WITHOUT override privateSignal
                                               protected signal slot  virtual>;

work "privateSignal.txt", ONLY, <WITH privateSignal>;

work "protected.txt", ONLY, <WITH protected>, <WITHOUT override virtual>;

work "protected_override.txt", ONLY, <WITH protected override>;

work "override.txt", ONLY, <WITH override>, <WITHOUT protected slot>;

work "signal.txt", ONLY, <WITH signal>;

work "slot.txt", ONLY, <WITH slot>, <WITHOUT override virtual static>;

work "slot_override.txt", ONLY, <WITH slot override>;

work "slot_static.txt", ONLY, <WITH slot static>;

work "virtual.txt", ONLY, <WITH virtual>, <WITHOUT protected slot>;

work "virtual_protected.txt", ONLY, <WITH virtual protected>;

work "virtual_slot.txt", ONLY, <WITH virtual slot>;

work "static.txt", ONLY, <WITH static>, <WITHOUT slot>;




# say "=" x 60;
# say "=" x 60;

# say printMethods getTestedMethods
#             getQualifiedMethods(EVERYTHING, <WITH virtual protected>), ALL;

