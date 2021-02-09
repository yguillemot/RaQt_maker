
#use Grammar::Debugger;

use gene::grammar-filter-rules;
use gene::grammar-filter-actions;
use gene::common;



#|( Parse an API description file and return its content
    as an API object.
)
sub filter(Str $fileName --> Str) is export
{

    # Read the full file
    my $file = $fileName.IO.slurp;



    # Remove the comments
    $file ~~ s:g/\#.*?$$//;   # '?' means frugal match

    #########################

    my $actions = filterActions.new;
    my $match = letsgo.parse($file, :actions($actions));



    if !$match {
        say "Can't parse successfuly near line ", $actions.lastSuccessLine, " !";
        exit;
    }
    if $actions.aborted {
        say "Can't parse successfuly near line ", $actions.aborted, " !";
        exit;
    }


    return $match.made;

}

