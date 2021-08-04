
use config;
use gene::replace;
use gene::addHeaderText;

# Read the tempate file $source
# Replace version strings if needed
# Replace in it code specified by %modify
# Add the source header and copy it in $destination
#
#   %modify : key = placeholder name
#             value = replacement text
#
#   $commentMark = the chars used to comment out the end of a line
#   $keepMarkers : If True, the placeholders will not be removed
#   $shebang = Some text which will be inserted before the header
#
sub installTemplate(Str :$source!, Str :$destination!,
                    Str :$commentMark = '#',
                    Bool :$keepMarkers = False,
                    Str :$shebang = "",
                    :%modify = {},
                    Bool :$copied)
    is export
{
    my Str $code = slurp $source;
    
    $code ~~ s:g/'MODULE_API'/{MODAPI}/;
    $code ~~ s:g/'MODULE_AUTHOR'/{MODAUTH}/;
    $code ~~ s:g/'MODULE_VERSION'/{MODVERSION}/;

    for %modify.kv -> $k, $v {
        replace $code, $commentMark, $k, $v, $keepMarkers;
    }
    
    $code = addHeaderText(code => $code,
                          commentChar => $commentMark,
                          copied => $copied);
    
    spurt $destination, $shebang ~ $code;
}



