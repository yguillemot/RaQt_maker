
my $s = slurp "matrix.txt";

my %g;
my $count = 0;
for $s.lines -> $l {
    if $l ~~ m/^ (<-[;]>+) ";;" (<-[\[]>+) ("[" <[\s\w]>+ "]") $/ {
        $count++;
        %g{$2 ~ " " ~ $1}.push: ~$0;
    }
}

say $count;
say %g.elems;

# my $e = Set.new(@r);
# say $e.keys.elems;
#
# say [~] $e.keys.sort <<~>> "\n";


my $out = "";
for %g.keys.sort -> $k {
    $out ~= $k ~ " : " ~ %g{$k}.elems ~ "\n";
}

spurt "GroupsOfMethods.txt", $out;
