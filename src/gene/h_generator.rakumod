
# Generate the .h file
# The name of the created file is defined in config.rakumod

use gene::config;
use gene::common;
use gene::replace;
use gene::addHeader;

# $api : The Qt API description (the output of the parser with the black and
# white info marks added)
# %callbacks : The list of callbacks precomputed by the hpp_generator
# $outFileName : The name of the output file
# $km : The keepMarkers flag (see the replace module)
sub h_generator(API $api, %exceptions, %callbacks, $km = False) is export
{
    my Str $templateFileName = "gene/templates/RaQtWrapper.h.template";
    my %c = $api.qclasses;

    say "Generate the .h file : start";
    # say "\n" x 2;

    my Str $out = "";

    for %c.sort>>.kv -> ($k, $v) {
        next if !$v.whiteListed || $v.blackListed;

        # say "Class : ", $k;

        # $k is the Qt class name
        my Str $wclassname = $prefixWrapper ~ $k;      # Wrapper class name
        my Str $wsclassname = $prefixSubclassWrapper ~ $k; # Wrapper subclass name
        my Bool $hasCtor = False;
        my Bool $hasSubclassCtor = False;
        my Bool $subclassable = ?vmethods($api, $k).elems; # $k is subclassable

        # say "METHODS : ";
        METH: for $v.methods -> $m {
            next if !$m.whiteListed || $m.blackListed;
            next if $m.isSignal;

            my $exk = $k ~ '::' ~ $m.name ~ qSignature($m, showNames => False);
            if %exceptions{$exk}{'rakumod'}:exists {
                $out ~= %exceptions{$exk}{'h'};
                next METH;
            }

            # say qProto($m);
            my Str ($retType, $name);
            if $m.name ~~ "ctor" {
                $retType = "void *";
                $name = $suffixCtor;
                $hasCtor = True;
            } else {
                $retType = cRetType($m);
                $name = $m.name;
            }
            $name ~= ($m.number ?? "_" ~ $m.number !! "");
            $out ~= "EXTERNC ";
            $out ~= $retType ~ " " ~ $wclassname ~ $name ~ cSignature($m) ~ ";\n";

            if $m.name ~~ "ctor" && $v.isQObj && $subclassable {
                # Subclass ctor wrapper
                $out ~= "EXTERNC void * ";
                $out ~= $wsclassname ~ $name ~ cSignature($m) ~ ";\n";
                $hasSubclassCtor = True;
            }
        }

        # If subclass ctor exists, add code for the validation method
        if $hasSubclassCtor {
            $out ~= "EXTERNC ";
            $out ~= 'void ' ~ $prefixWrapper ~ 'validateCB_' ~ $k
                    ~ '(void *obj, int32_t objId, char *methodName);' ~ "\n";
        }

        # If ctor exists, add code for the related dtor
        if $hasCtor {
            $out ~= "EXTERNC ";
            $out ~= 'void ' ~ $wclassname ~ $suffixDtor ~ '(void *)' ~ ";\n";
        }

        # If subclass ctor exists, add code for the related dtor
        if $hasSubclassCtor {
            $out ~= "EXTERNC ";
            $out ~= 'void ' ~ $wsclassname ~ $suffixDtor ~ '(void *)' ~ ";\n";
        }


#         for $v.virtuals -> $v {
#             @virtuals.push($v);
#         }
#         for $v.slots -> $s {
#             @slots.push($s);
#         }
#         for $v.signals -> $s {
#             @signals.push($s);
#         }
#
#         for $v.parents -> $p {
#             say "    $p";
#
#             my $pc = %c{$p};
#
#             next if $pc.generic;   # Generic class only has name
#
#             for $pc.methods -> $m {
#                 @methods.push($m);
#             }
#             for $pc.virtuals -> $v {
#                 @virtuals.push($v);
#             }
#             for $pc.slots -> $s {
#                 @slots.push($s);
#             }
#             for $pc.signals -> $s {
#                 @signals.push($s);
#             }
#         }
    }


    # Callbacks initializers declaration
    my Str $outcb = "";
    for %callbacks.sort>>.kv -> ($n, $m) {
        my $name = $n;
        $name ~~ s/^s/S/;
        $name = $prefixWrapper ~ 'Setup' ~ $name;
        my $signature = qSignature($m,
                                  showObjectPointer => False,
                                  showParenth => False);
        $outcb ~= "EXTERNC void $name" ~ '(' ~ "\n";
        $outcb ~= IND ~ 'void (*f)(int32_t objId, const char *slotName';
        $outcb ~= $signature ~ '));' ~ "\n\n";
    }


    my $code = slurp $templateFileName;

    replace $code, "//", "WRAPPER_H_CODE", $out, $km;
    replace $code, "//", "CALLBACKS_INITIALIZERS", $outcb, $km;
    $code = addHeaderText(code => $code, commentChar => '//');

    spurt $hFile, $code ~ "\n";

    say "Generate the .h file : stop";
    say "";
}





