
use config;

#
# Add a comment header to the $code string to say how it was generated.
#
# $commentChar is the string beginning each line of comment.
# Returns the concatenation of the header and $code.
#
sub addHeaderText(Str :$code,
                  Str :$commentChar = '#',
                  Bool :$copied) is export
{

    # text of the header
    my $text = q:to/END/;

        This file has been automatically _VERB_ by RaQt_maker V_VERSION_.
        To modify and regenerate it, see the source code available here: 
                _REPOSITORY_

        END
        
    my Str $verb = $copied ?? "copied" !! "generated";

    # Replace the keywords
    $text ~~ s/_VERSION_/$geneVersion/;
    $text ~~ s/_REPOSITORY_/$repository/;
    $text ~~ s/_VERB_/$verb/;

    # Set text as a comment
    my $comment = [~] ($commentChar ~ " ") <<~>> $text.lines <<~>> "\n";

    # Output code with header
    return "\n" ~ $comment ~ "\n" ~ $code;
}


