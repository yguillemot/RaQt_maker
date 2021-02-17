

# Generate the .hpp file
# The name of the created file is defined in config.rakumod

use gene::config;
use gene::common;
use gene::replace;
use gene::natives;
use gene::addHeader;

my %callbacks = ();         # Should be defined in RaQt_maker.pm6
                            # for sharing with the other generators

# $api : The Qt API description (the output of the parser with the black and
# white info marks added)
# $km : The keepMarkers flag (see the replace module)
# Returns a hash where the descriptions of all callbacks are gathered
sub hpp_generator(API $api, %exceptions, $km = False --> Hash) is export
{

    my Str $templateFileName = "gene/templates/QtWidgetsWrapper.hpp.template";
    my %c = $api.qclasses;

    say "Generate the .hpp file : start";
    # say "\n" x 2;

    my Str $out = "";
    my %allVirtuals = ();

    for %c.sort>>.kv -> ($k, $v) {
        next if !$v.whiteListed || $v.blackListed;

       # Count ctors
        my Int $nb = 0;
        for $v.methods -> $m {
            $nb++ if $m.whiteListed && !$v.blackListed && $m.name ~~ "ctor";
        }

        # Nothing to do if no ctor
        next if $nb == 0;

        # Debug
        # say "Class $k";

        # $k is the Qt class name
        my $wclassname = $prefixWrapper ~ $k;   # Wrapper class name
        my $sclassname = $prefixSubclass ~ $k;  # Wrapper subclass name

        # Get all the virtual methods usable from the current class.
        my %virtuals = vmethods($api, $k);
        %allVirtuals ,= %virtuals;

        # Debug
        # for %virtuals.kv -> $k, $v { say "\t\tvirts : ", $k, " : ", $v[0]; }

        # Nothing to do if no virtual
        next unless %virtuals.elems;

        # Start of the class definition
        $out ~= "class $sclassname : public $k, public CallbackValidator\n";
#         $out ~= "class $sclassname : public $k\n";
        $out ~= "\{\npublic:\n";

        # Ctor(s)
        for $v.methods -> $vm {
            next if $vm.blackListed || !$vm.whiteListed || $vm.name !~~ "ctor";
            $out ~= IND ~ $sclassname ~ qSignature($vm) ~ ":\n";
            $out ~= IND x 2 ~ $k ~ qCallUse($vm) ~ "\n";
            $out ~= IND ~ "\{ }\n\n";
        }

        # Dtor
        $out ~= IND ~ "~$sclassname\() \{ }\n\n";

        # Overriding methods
        for %virtuals.keys.sort -> $vn {
            my ($vk, $vm) = %virtuals{$vn};

            $out ~= IND ~ qRet($vm) ~ ' ' ~ $vm.name ~ qSignature($vm) ~ "\n";
            $out ~= IND ~ "\{\n";
            $out ~= IND x 2 ~ "if (m_" ~ $vn ~ ") \{\n";

            $out ~= IND x 2 ~ '//   CONVERSION NEEDED HERE !!!' ~ "\n";

            my $callbackName = 'slotCallback' ~ callbackSuffix($vm);
            %callbacks{$callbackName} = $vm;

            $out ~= IND x 3 ~ '(*slotCallback'
                                     ~ callbackSuffix($vm) ~")(\n";
            $out ~= IND x 4 ~ 'm_objId, "' ~ $vn ~ '"';
            for $vm.arguments -> $a {
                $out ~= ",\n" ~ IND x 4 ~ $a.fname;
            }
            $out ~= "\n";
            $out ~= IND x 3 ~ ");\n";
            $out ~= IND x 2 ~ "}\n";
            $out ~= IND x 2 ~ $k ~ '::' ~ $vm.name ~ qCallUse($vm) ~ ";\n";
            $out ~= IND ~ "}\n\n";
        }

        # End of the class definition
        $out ~= "};\n\n";

    }



    # Declaration of the pointers to the callbacks
    my Str $outx = "";
    for %callbacks.sort>>.kv -> ($n, $m) {
        $outx ~= 'extern void (*' ~ $n ~ ')(int objId, const char *slotName';
        $outx ~= qSignature($m, showParenth => False) ~ ');' ~ "\n";
    }



    # Validation switch and related code
    my $outs = "";                          # Code of the switch
    my $outd = "";                          # Declaration of the flags
    my $outi = IND x 2 ~ "m_objId(0)";      # Initialisation of the flags
    for %allVirtuals.sort>>.kv -> ($vn, $vm) {

        $outs ~= IND ~ 'if (meth == QString("' ~ $vn ~ '")) {' ~ "\n";
        $outs ~= IND x 2 ~ "m_$vn = true;\n";
        $outs ~= IND ~ "}\n";

        $outd ~= IND ~ "bool m_$vn;\n";

        $outi ~= IND x 2 ~ ",\nm_$vn\(false)";
    }



    my $code = slurp $templateFileName;

    replace $code, "//", "VIRTUAL_METHODS_CALLBACKS_PROTOTYPES", $outx, $km;

    replace $code, "//", "SUBCLASSES_WITH_VIRTUAL_METHODS", $out, $km;
    replace $code, "//", "VALIDATOR_DECLARATION", $outd, $km;
    replace $code, "//", "VALIDATOR_SWITCH", $outs, $km;
    replace $code, "//", "VALIDATOR_INIT", $outi, $km;

    $code = addHeaderText(code => $code, commentChar => '//');

    spurt $hppFile, $code;

    say "Generate the .hpp file : stop";
    say "";

    return %callbacks;
}

#############################################

sub callbackSuffix(Function $vm --> Str)
{
    # TODO : Look at postop ???

    my Str $out = "";

    my Str $preout = "";
    my Int $count = 0;
    for $vm.arguments -> $a {
        my $t = typeSymbol($a);
        if $t ~~ $preout {
            $count++;
        } else {
            if ?$count {
                $out ~= $preout;
                if $count > 1 { $out ~= $count; }
            }
            $preout = $t;
            $count = 1;
        }
    }
    $out ~= $preout;
    if $count > 1 { $out ~= $count; }

    return $out;

    sub typeSymbol(Argument $a --> Str)
    {
        given $a.ftot {
            when "CLASS"    { return $a.fbase }
            when "ENUM"     { return "Int" }
            when "NATIVE"   { return nativeType_r($a.fbase) }
            default         { return "???" }
        }
    }
}

