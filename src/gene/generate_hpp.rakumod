 
use config;
use gene::common;
use gene::natives;

sub generate_hpp(Str $k, Qclass $v, %exceptions, %virtuals --> List) is export
{
        # Subclass name
        my Str $sclassname = $prefixSubclass ~ $k; 
        # my Str $sclasswname = $prefixSubclassWrapper ~ $k; 
        
        my %callbacks = ();
        
        my Str $out
            = "class $sclassname : public $k, public CallbackValidator\n";

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
        
        return $out, %callbacks;
}



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



sub generate_callbacks_hpp(%callbacks, %allVirtuals --> List) is export
{

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

    return $outx, $outs, $outd, $outi;
}  

