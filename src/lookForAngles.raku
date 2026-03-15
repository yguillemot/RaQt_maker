
say "ARGS : ", @*ARGS;
say "";

exit if !@*ARGS[0];


my $txt = slurp @*ARGS[0];

my %liste;

for $txt.lines -> $l {

    # Look for something like "xxx<aaa...>"
    if $l ~~ m/ (\w+ '<' <-[\<\>]>+ '>') / {
        my $k = normalize $0.Str;

        # Count each sort of strings found
        if %liste{$k}:exists {
            %liste{$k}++;
        } else {
            %liste{$k} = 1;
        }
    }
}

# Sort and output on stdout
for %liste.sort -> $x {
    say "=A=\t\t", $x.value, "\t ", $x.key;
}

say "";


%liste = ();

for $txt.lines -> $l {

    # Look for something like "<aaa...>"
    if $l ~~ m/ ('<' <-[\<\>]>+ '>') / {
        my $k = normalize $0.Str;

        # Count each sort of strings found
        if %liste{$k}:exists {
            %liste{$k}++;
        } else {
            %liste{$k} = 1;
        }
    }
}

# Sort and output on stdout
for %liste.sort -> $x {
    say "=B=\t\t", $x.value, "\t ", $x.key;
}


sub normalize(Str $s is copy --> Str)
{
    # Remove all spaces
    $s ~~ s :g /' '//;

    # Add a space after each comma
    $s ~~ s :g /','/, /;

    return $s;
}
