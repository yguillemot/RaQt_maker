
# Test some functions returning strings

# THIS FILE IS ONLY FOR DEBUG AND UNDERSTANDING
# IT SHOULD NOT BE PUBLICLY EXPORTED

use gene::config;
use gene::common;
use gene::natives;
use gene::replace;
use gene::ToRakuConversions;

# $api : The Qt API description (the output of the parser with the black and
# white info marks added)
# %exceptions : Exceptions if any
sub test_str(API :$api, :%exceptions) is export
{
    my %c = $api.qclasses;


    my $classe = "QLabel";
    my $methode = "ctor";
    my Function $fonction;
    for %c{$classe}.methods -> $m {
        # say "\tname : ", $m.name;
        if $m.name ~~ $methode {
            $fonction = $m;
            last;
        }
    }
    die $classe ~ "::" ~ $methode ~ " not found" if !$fonction;

    say "-------";

    # Doesn't work with ctor : can't found return value;
    # say "strRakuArgsDecl : ", strRakuArgsDecl($fonction);

    say "strArgsRakuCtorDecl : ", strArgsRakuCtorDecl($fonction);
    say "strRakuArgsCtorDecl : ", strRakuArgsCtorDecl($fonction, $classe);
    say "strNativeWrapperArgsDecl[def] : ", strNativeWrapperArgsDecl($fonction );
    say "strArgsRakuCallbackCall : ", strArgsRakuCallbackCall($fonction);
    say "strArgsRakuBlessCall : ", strArgsRakuBlessCall($fonction);
    say "strArgsRakuCallDecl : ", strArgsRakuCallDecl($fonction);
    say "strArgsRakuCtorWrapperCall : ", strArgsRakuCtorWrapperCall($fonction);
    say "";
    say "qArgs (*) [def] : ", qSignature($fonction);
    say "qSigBase (*) : ", qSignature($fonction, showNames => False);
    say "rSignature [def] : ", rSignature($fonction);
    say "qSignature [def] : ", qSignature($fonction);
    say "qProto : ", qProto($fonction);

}










