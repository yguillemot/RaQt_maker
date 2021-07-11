
# Generate the basic tests file

use config;

# @files_rakumod : List of the .rakumod files
sub generate_basicTest(Str @qtClasses, Str @otherQtClasses --> Str) is export
{
    say "";
    say "Generate the basic tests file : start";
    # say "\n" x 2;

    # Init the lib string with QtWidgets.rakumod
    my Str $out = q:to/END/;
         
        # Basic tests
         
        use v6;
        use Test;
         
        if ?%*ENV<AUTHOR_TESTING> {
            require Test::META <&meta-ok>;
            meta-ok;
        }     
         
        use-ok "Qt::QtWidgets";
         
        END
    
    my @classes = @qtClasses;
    @classes.append: @otherQtClasses;
    
    # Generate one test for each class
    $out ~= [~] "use-ok \"Qt::QtWidgets::" <<~>> @classes.sort <<~>> "\";\n";
    
    $out ~= "\n";
    $out ~= "done-testing;\n";
    $out ~= "\n";

    return $out;
}



