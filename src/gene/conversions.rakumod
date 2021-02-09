

use gene::common;


# Create C++ instructions converting a variable from a C Raku native type
# to a C++ Qt compatible type

# Parameters :
#  1 - $where = Name of class which contains the method where the precall
#               conversion line is inserted
#  2 - $tot = Type of type of the argument ("CLASS", "NATIVE", "ENUM", etc...)
#  3 - $stype = Type name of the source argument
#  4 - $spostop = Post operator of the type of the source argument
#  5 - $src = Name of the source variable in the conversion code
#  6 - $dtype = Type name of the destination argument
#  7 - $dpostop = Post operator of the type of the destination argument
#  8 - $dst = Name of the destination variable in the conversion code
#
# All parameters are Str

multi precall(  $where, "CLASS",
                "void", "*", $src,
                $class, "*", $dst
    --> Str) is export
{
    "$class * $dst = reinterpret_cast<$class *>($src);"
}

multi precall(  $where, "CLASS",
                "void", "*", $src, 
                $class, "&", $dst 
    --> Str) is export
{
    "$class & $dst = * reinterpret_cast<$class *>($src);"
}

multi precall(  $where, "NATIVE",
                $stype, "", $src,
                $dtype, "", $dst
    --> Str) is export
{
    "$dtype $dst = $src;"
}

multi precall(  $where, "NATIVE",
                "char", "*", $src,
                "char", "*", $dst
    --> Str) is export
{
    "char * $dst = $src;"
}

multi precall(  $where, "SPECIAL",
                "char", "*", $src,
                "QString", "&", $dst 
    --> Str) is export
{
    "QString $dst = QString($src);"
}

multi precall(  $where, "ENUM",
                "int", "", $src,
                Str $enum_type is copy, "", $dst
    --> Str) is export
{
    if $enum_type !~~ m/'::'/ {
        $enum_type = $where ~ '::' ~ $enum_type; 
    }
    
    "$enum_type $dst = static_cast<$enum_type>($src);"
}

multi precall(  $where, "COMPOSITE",
                $stype, "", $src,
                $dtype, "", $dst
    --> Str) is export
{
    # Conversion from integer to QFlags<enum> using the QFlags ctor
    "$dtype $dst = $dtype\($src\);"
}

multi precall(  $where, $tot,
                $stype, $spostop, $src,
                $dtype, $dpostop, $dst
    --> Str) is export
{
    my $msg = "Can't find any precall conversion for $tot\n"
                ~ "from $where, $stype, $spostop, $src to $dtype, $dpostop, $dst";
    # note $msg;
    die $msg;
    # return $msg;
}



# Create C++ instructions converting a variable from C++ Qt compatible type
# to a C Raku native type

# Parameters :
#  1 - $where = Name of class which contains the method where the precall
#               conversion line is inserted
#  2 - $tot = Type of type of the argument ("CLASS", "NATIVE", "ENUM", etc...)
#  3 - $stype = Type name of the source argument
#  4 - $spostop = Post operator of the type of the source argument
#  5 - $sconst = "const" keyword or ""
#  6 - $src = Name of the source variable in the conversion code
#  7 - $dtype = Type name of the destination argument
#  8 - $dpostop = Post operator of the type of the destination argument
#  9 - $dst = Name of the destination variable in the conversion code
#
# All parameters are Str


multi postcall( $where, "CLASS",
                $class, '*', $sconst, $src, 
                "void", "*", $dst 
    --> Str) is export
{
    ""
}

multi postcall( $where, "CLASS",
                $class, '&', "", $src,
                "void", "*", $dst 
    --> Str) is export
{
    "void * $dst = reinterpret_cast<void *>(& $src);"
}

multi postcall( $where, "CLASS",
                $class, '&', "const", $src,
                "void", "*", $dst 
    --> Str) is export
{
    "void * $dst = const_cast<void *>(reinterpret_cast<const void *>(& $src));"
}

multi postcall( $where, "NATIVE",
                $stype, "", $sconst, $src,
                $dtype, "", $dst
    --> Str) is export
{
    ""
}

multi postcall( $where, "SPECIAL",
                "QString", "&", $sconst, $src, 
                "char", "*", $dst
    --> Str) is export
{
    ""
    # "char * $src = $dst\.toLocal8Bit().data();"
}

multi postcall( $where, "SPECIAL", 
                "QString", "", $sconst, $src, 
                "char", "*",            $dst
    --> Str) is export
{
    "char * $dst = $src\.toLocal8Bit().data();"
}

multi postcall( $where, "ENUM",
                $stype, "", $sconst, $src,
                $dtype, "",          $dst 
    --> Str) is export
{
    ""
    # "int $dst = $src;"
}


multi postcall( $where, $tot,
                $stype, $spostop, $sconst, $src,
                $dtype, $dpostop,          $dst
    --> Str) is export
{
    my $msg = "Can't find any postcall conversion for $tot\n"
                ~ "from $where:: $sconst $stype $spostop $src"
                ~ " to $dtype $dpostop $dst" ~ "\n>" ~ $sconst ~ "< ";
    note $msg;
#      die $msg;
    return '/* WARNING:' ~ "\n" ~ $msg ~ ' */';
}
