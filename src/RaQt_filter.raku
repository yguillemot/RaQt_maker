
use lib <.>;
use gene::common;
use gene::filter;

if @*ARGS.elems == 0 {
    say "Syntaxe : ", $*PROGRAM-NAME, " description_API.txt [options]\n";
    say "(No option is currently defined)";
    exit;
}

my ($fileName, @options) = @*ARGS;

my Str $text = filter($fileName);
spurt "sortie_filtre.txt", $text;






