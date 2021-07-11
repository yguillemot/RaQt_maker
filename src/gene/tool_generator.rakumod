
# Generate the "guessuse" script distributed with the Qt::QtWidgets mpodule

use config;
use gene::common;
use gene::installTemplate;


# $api : The Qt API description (the output of the parser with the black and
# white info marks added)
# %exceptions : Exceptions if any
# $km : The keepMarkers flag (see the replace module)
sub tool_generator(API :$api, :%exceptions, Bool :$km) is export
{
    my %c = $api.qclasses;

    say "";
    say "Generate the tool script : start";
    # say "\n" x 2;


    # Generate the list of classes of the API

    my Str $out = "";

    for %c.keys.sort -> $k {
        my $v = %c{$k};
        next if !$v.whiteListed || $v.blackListed;
        next if $v.name (elem) $specialClasses;

        # $k (eq $v.name) is the Qt class name
        $out ~= IND x 2 ~ '"' ~ $k ~ '",' ~ "\n";
    }
    
    my Str $ver = 'my $ver = ' ~ "\"{MODNAME} version {MODVERSION}\";\n";

    installTemplate commentMark => '#', keepMarkers => $km,
        shebang => "#!/usr/bin/env raku\n",
        source => "gene/templates/guessuse.raku.template",
        destination => "{BINDIR}guessuse",
        modify => {
            VERSION_NUMBER => $ver,
            LIST_OF_CLASSES => $out
        };
        
    # Change permission of the file to executable
    "{BINDIR}guessuse".IO.chmod: 0o755;

    say "Generate the tool script : end";
}

