
class Method {
    has Str $.class;
    has Str $.name;
    has Str @.files;
}

my Str $txt = slurp "../WhiteList.output";
my %methods = ();

for $txt.lines {
    if $_ ~~ m/(\w+) '::' (\w+) '(' (<-[)]>*) ')'/ {
        say "$0 : $1  -- $2";
        %methods{"$0::$1"} = Method.new: class => ~$0, name => ~$1;
    }
}


say "=" x 12;

my Str $base = "../../module";
my Str @paths = <examples t>;
for @paths -> $p {
    my Str $path = "$base/$p";
    for dir($path, test => { "$path/$_".IO ~~ :f & :r }) -> $f {
        say "$f";
        my Str $txt = slurp $f;
        for %methods.kv -> $k, $v {
            if $v.name ~~ "ctor" {
                if $txt ~~ m/\W "{$v.class}.new" \W/ {
                    $v.files.push: ~$f;
                }
            } else {
                if    $txt ~~ m/\W "$k" \W/
                || $txt ~~ m/'.' "{$v.name}" \W/ {
                        $v.files.push: ~$f;
                }
            }
        }
    }
}

say "+" x 12;


my Int $mcount = 0;
my Int $vcount = 0;

my Str $out = "";
for %methods.keys.sort -> $k {
    say $k;
    $mcount++;
    $out ~= "$k\n";
    my $v = %methods{$k};
    $vcount++ if $v.files.elems;
    for $v.files {
        say "\t$_";
        $_ ~~ s/ "$base" '/' //;
        $out ~= "\t$_\n";
    }
    $out ~= "\n";
}
spurt "matrix.txt", $out;

say "";
say "$mcount methods";
say "$vcount validated methods";
say $mcount - $vcount, " unvalidated methods";



