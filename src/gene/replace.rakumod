


# In the string $workPlace, replace the placeholder containing $key
# with the string $value.
# The placeholder starts with "??BEGIN_INSERTION_HERE" immediately followed
# by "??"~$key and ends with "??END_INSERTION_HERE" where "??" is the comment
# marker $cMarker.
# $value is modified to keep the indentation of the first marker.
# The markers are kept in the final text when $keepMarkers is True.
#
sub replace(Str $workPlace is rw, Str $cMarker,
        Str $key, Str $value is copy, Bool $keepMarkers = False) is export
{
    my constant $START = 'BEGIN_INSERTION_HERE';
    my constant $STOP = 'END_INSERTION_HERE';
    my Str $Start = $cMarker ~ $START;
    my Str $Stop = $cMarker ~ $STOP;
    my Str $Key = $cMarker ~ $key;
    my regex start { $Start };
    my regex stop { $Stop };
    my regex key { $Key };

    # Step 1 : Look for the place holder and get the indentation
    $workPlace ~~ m/^^ (<[\ \t]>*) <start> <[\ \t\n]>* <key> .*? <stop>/;
    
    # $0 is the indentation. If it doesn't exist, use an empty string.
    my $indent = $0 ?? $0 !! "";

    # Step2 : Add the markers to $value if we want them kept
    if $keepMarkers {
        $value = $Start ~ "\n" ~ $Key ~ "\n" ~ $value ~ $Stop ~ "\n";
    }

    # Step3 : Add the indentation to each line of $value
    my $indentedValue = [~] $indent <<~>> $value.lines <<~>> "\n";

    # Step4 : Do the replacement
    $workPlace
        ~~ s/(<[\ \t]>*) <start> <[\ \t\n]>* <key> .*? <stop>/$indentedValue/;
}


