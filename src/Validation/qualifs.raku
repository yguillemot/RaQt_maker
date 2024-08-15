
my $s = slurp "matrix.txt";

my @r;
for $s.lines -> $l {
    if $l ~~ m/ ("[" <[\s\w]>+ "]") $/ {
        @r.push: ~$0;
    }
}

say @r.elems;
my $e = Set.new(@r);
say $e.keys.elems;

say [~] $e.keys.sort <<~>> "\n";


my $out = "";
for $e.keys.sort -> $k {
    next if $k ~~ "[ ]";
    for $s.lines -> $l {
        if $l ~~ m/ (<-[\[]>+)  "$k" $/ {
            $out ~= "$k $0\n";
        }
    }
}

spurt "QualifiedMethods.txt", $out;
