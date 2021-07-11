

# Read all the exceptions files and return them in a hash :
#
# Hash %exceptions created :
#
#    All exceptions about QPainter::begin(QPaintDevice*) :
#       %exceptions{"QPainter::begin(QPaintDevice*)"}
#
#       raku module exception text about QPainter::begin(QPaintDevice*) :
#           %exceptions{"QPainter::begin(QPaintDevice*)"}{"rakumod"}
#
#       raku .cpp exception text about QPainter::begin(QPaintDevice*) :
#           %exceptions{"QPainter::begin(QPaintDevice*)"}{"cpp"}
#

# Allowed keywords:
my regex Keyword { 'rakumod' || 'wrappers' || 'cpp' || 'h' || 'hpp' || 'use' };

sub read_exceptions(Str $exceptionsDirName --> Hash) is export
{
    my %exceptions = ();

    my @dir = dir $exceptionsDirName;
    for @dir -> $e {

        my $fname = $e.Str;
        
        # Allowed file extensions:
        next if    $fname !~~ m/\.rakumod$$/
                && $fname !~~ m/\.raku$$/
                && $fname !~~ m/\.hpp$$/
                && $fname !~~ m/\.h$$/
                && $fname !~~ m/\.cpp$$/
                && $fname !~~ m/\.txt$$/;
        
        # Only keep plain files
        next unless $e.f;
       
        # Get keys
        my Str $txt = slurp $e;
        if $txt ~~ m/^^ \s* (<Keyword>) ':' \s* (\S .*?) $$/ {
            my $keyword = ~$0;
            my $method = trim(~$1);
            
            # Remove keys and comments then store text
            $txt ~~ s/^ .*? 'BEGIN' \s* $$//;
            %exceptions{$method}{$keyword} = $txt;

        } else {
            say "File $fname ignored in the exception directory";
        }
        
    }

    return %exceptions;
}

################# UNCOMMENT FOR TEST #######################
#`[

my %ex = read_exceptions "./Exceptions";

for %ex.sort>>.kv -> ($k, $v) {
    for $v.sort>>.kv -> ($k2, $v2) {
        say "";
        say '%' x 70;
        say '*** ', $k, " : ", $k2;
        say $v2;
    }
}

]

