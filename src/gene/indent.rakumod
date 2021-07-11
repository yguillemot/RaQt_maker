
# Add an indentation to a multi-line text string
#   $text : the multi-line text
#   $ind : the indentation
sub indent(Str $text is copy, Str $ind --> Str) is export
{
    $text ~~ s:g/ \n /\n$ind/;
    return $ind ~ $text;
}
