
# Generate the .h file

use config;
use gene::common;
use gene::replace;
use gene::conversions;
use gene::addHeaderText;


# $api : The Qt API description (the output of the parser with the black and
# white info marks added)
# %callbacks : The list of callbacks precomputed by the hpp_generator
# $outFileName : The name of the output file
# $km : The keepMarkers flag (see the replace module)
sub generate_h(Str $k, Qclass $v, %exceptions,
                    Bool $hasCtor, Bool $hasSubclassCtor, Bool $subclassable,
                    $km = False --> Str) is export
                    
     # Arguments ?  Variables locales ?              
     # %callbacks, @hppClasses,
     
{

#     say "Generate the .h file : start";
    # say "\n" x 2;

    # Init the output string
    my Str $out;                    # Code for the class
    
    # $k is the Qt class name
    my Str $wclassname = $prefixWrapper ~ $k;   # Wrapper class name
    my $sclassname = $prefixSubclass ~ $k;      # Wrapper subclass name
    my Str $wsclassname = $prefixSubclassWrapper ~ $k; # Wrapper subclass name

    # $k is an abstract top class
    # TODO: This condition is probably not sufficient to cover all the cases
    #       where an explicit upcasting is needed.
    #       Nevertheless, and until a new issue occurs, the explicit upcasting
    #       will be limited to this case only.
    my Bool $isAbstractTopClass = $v.isAbstract && $v.parents.elems == 0;

    MLOOP: for $v.methods -> $m {
        next MLOOP if !$m.whiteListed || $m.blackListed;
        next MLOOP if $m.isSignal;
        next MLOOP if $m.isProtected;
        
        # Is this method an exception ?
        my $exk = $k ~ '::' ~ $m.name ~ qSignature($m, showNames => False);
        if %exceptions{$exk}{'rakumod'}:exists {
            $out ~= %exceptions{$exk}{'h'};
            next MLOOP;
        }            
        
        # say qProto($m);
        my Str ($retType, $name);
        if $m.name ~~ "ctor" {
            $retType = "void *";
            $name = $suffixCtor;
        } else {
            $retType = cRetType($m);
            $name = $m.name;
        }
        $name ~= ($m.number ?? "_" ~ $m.number !! "");
        $out ~= "EXTERNC ";
        $out ~= $retType ~ " " ~ $wclassname ~ $name ~
                cSignature($m, showObjectPointer => !$m.isStatic,
                                     showCIdx => $isAbstractTopClass) ~ ";\n";

        # if $m.name ~~ "ctor" && $v.isQObj && $subclassable {
        if $m.name ~~ "ctor" && $subclassable {
            # Subclass ctor wrapper
            $out ~= "EXTERNC void * ";
            $out ~= $wsclassname ~ $name ~ cSignature($m) ~ ";\n";
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
        
    return $out;
}


            
sub generate_callbacks_h(%callbacks --> Str) is export
{
    # Callbacks initializers declaration
    
    my Str $outcb = "";
    for %callbacks.sort>>.kv -> ($n, $m) {
        my $name = $n;
        $name ~~ s/^s/S/;
        $name = $prefixWrapper ~ 'Setup' ~ $name;
        my $signature = qSignature($m,
                                  showObjectPointer => False,
                                  showParenth => False);
        
        my $cb = "EXTERNC void $name" ~ '(' ~ "\n";
        $cb ~= IND ~ qRet($m) ~ ' (*f)(int32_t objId, const char *slotName';
        $cb ~= $signature ~ '));' ~ "\n\n";
                    
        $outcb ~= $cb;
    }
    
    return $outcb;
}




