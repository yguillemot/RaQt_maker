
# Generate the meta6 file

use config;

# @files_rakumod : List of the .rakumod files
sub generate_meta6(Str $template, Str @files_rakumod is copy --> Str) is export
{
    say "";
    say "Generate the meta6 file : start";
    # say "\n" x 2;

    # Init the lib string with QtWidgets.rakumod
    my Str $out = "\n";
    $out ~= IND x 2 ~ '"Qt::QtWidgets" : "lib/Qt/QtWidgets.rakumod"';
    
    # Generate the lib string
    $out ~= [~] ",\n" <<~>> @files_rakumod.sort>>.&createLine;
    $out ~= "\n" ~ IND;
    
    # Create the file from the template
    my $data = slurp $template;
    $data ~~ s/'MODULE_NAME'/{MODNAME}/;
    $data ~~ s/'MODULE_API'/{MODAPI}/;
    $data ~~ s/'MODULE_AUTHOR'/{MODAUTH}/;
    $data ~~ s/'MODULE_VERSION'/{MODVERSION}/;
    $data ~~ s/'"provides" : {' .*? '},'/"provides" : \{$out\},/;
    
    say "Generate the meta6 file : end";

    return $data;
}

sub createLine(Str $fileName) {
    my Str $moduleName = $fileName;
    $moduleName ~~ s/'.rakumod'//;
    
    my Str $completeFileName = '"lib/Qt/QtWidgets/' ~ $fileName ~ '"';
    my Str $completeModuleName = '"Qt::QtWidgets::' ~ $moduleName ~ '"';
    return IND x 2 ~ $completeModuleName ~ ' : ' ~ $completeFileName;
}

