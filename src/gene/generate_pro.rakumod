
# Generate the .pro file

# use config;
use gene::addHeaderText;


# @files_hpp : List of the .hpp source files
# @files_cpp : List of the .cpp source files
# @files_h : List of the .h source files
sub generate_pro(Str @files_hpp, Str @files_cpp, Str @files_h --> Str) is export
{
    say "";
    say "Generate the .pro file : start";
    # say "\n" x 2;

    # Init the output string
    my Str $out; 

    $out ~= "TEMPLATE = lib" ~ "\n";
    $out ~= "QT += widgets" ~ "\n";
    
    $out ~= [~] 'SOURCES += ' <<~>> @files_cpp <<~>> "\n";
    $out ~= [~] 'HEADERS += ' <<~>> @files_hpp <<~>> "\n";
    $out ~= [~] 'HEADERS += ' <<~>> @files_h <<~>> "\n";
    
    say "Generate the .pro file : end";

    return $out;
}


