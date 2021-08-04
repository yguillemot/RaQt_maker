

use config;
use gene::common;


# Create C++ instructions converting a variable from a C Raku native type
# to a C++ Qt compatible type

# Parameters (all are Str, except subType which is SubType)
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

multi precall(  $where, "SPECIAL",
                "char", "*", $src,
                "QString", "*", $dst 
    --> Str) is export
{
    "QString {$dst}_tmp;\n" ~
    "QString * $dst = nullptr;\n" ~
    "if ($src) \{\n" ~
    IND ~ "{$dst}_tmp = QString($src);\n" ~
    IND ~ "$dst = \&{$dst}_tmp;\n" ~
    "};"
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
                $dtype is copy, "", $dst
    --> Str) is export
{
    die "Can't find any precall conversion for COMPOSITE\n"
            ~ "from $where, $stype, $src to $dtype, $dst";
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
#  1 - $name = Name of method (only used in possible error message)
#  2 - $where = Name of class which contains the method where the precall
#               conversion line is inserted
#  3 - $tot = Type of type of the argument ("CLASS", "NATIVE", "ENUM", etc...)
#  4 - $ret = "ret" if the data to be converted is the value returned by
#      the function. "arg" if it is one of its argument.
#  5 - $stype = Type name of the source argument
#  6 - $spostop = Post operator of the type of the source argument
#  7 - $sconst = "const" keyword or ""
#  8 - $src = Name of the source variable in the conversion code
#  9 - $dtype = Type name of the destination argument
# 10 - $dpostop = Post operator of the type of the destination argument
# 11 - $dst = Name of the destination variable in the conversion code
#
# All parameters are Str


multi postcall( $name, $where, "CLASS", "ret",
                $class, '*', $sconst, $src, 
                "void", "*", $dst 
    --> Str) is export
{
    ""
}

multi postcall( $name, $where, "CLASS", "ret",
                $class, '&', "", $src,
                "void", "*", $dst 
    --> Str) is export
{
    "void * $dst = reinterpret_cast<void *>(& $src);"
}

multi postcall( $name, $where, "CLASS", "ret",
                $class, '&', "const", $src,
                "void", "*", $dst 
    --> Str) is export
{
    "void * $dst = const_cast<void *>(reinterpret_cast<const void *>(& $src));"
}

multi postcall( $name, $where, "CLASS", "ret",
                $class, '', $const, $src,
                "void", "*", $dst 
    --> Str) is export
{
    # This should be an object build on the stack
    # Assuming the existence of a copy constructor, the original
    # object is copied on the heap.
    "$class * x$dst = new $class\($src\);\n" ~
    "void * $dst = reinterpret_cast<void *>(x$dst);"
    # WARNING: "$ownedByRaku=True" must be set to True using parameter "obr"
    # of &ctor when the Raku associated object is created.

    # QColor.new in the related Raku method.
    # (see &postcall_raku in ToRakuConversions.rakumod)
}

multi postcall( $name, $where, "NATIVE", "ret",
                $stype, "", $sconst, $src,
                $dtype, "", $dst
    --> Str) is export
{
    ""
}

multi postcall( $name, $where, "SPECIAL", "ret",
                "QString", "&", $sconst, $src, 
                "char", "*", $dst
    --> Str) is export
{
    ""
    # "char * $src = $dst\.toLocal8Bit().data();"
}

multi postcall( $name, $where, "SPECIAL", "ret",
                "QString", "", $sconst, $src, 
                "char", "*",            $dst
    --> Str) is export
{
    "char * $dst = $src\.toLocal8Bit().data();"
}

multi postcall( $name, $where, "ENUM", "ret",
                $stype, "", $sconst, $src,
                $dtype, "",          $dst 
    --> Str) is export
{
    ""
    # "int $dst = $src;"
}

multi postcall( $name, $where, $tot, "arg",
                $stype, $spostop, $sconst, $src,
                $dtype, "",          $dst 
    --> Str) is export
{
    # Conversion for argument is not needed if argument is passed by value
    ""
}

multi postcall( $name, $where, $tot, "arg",
                $stype, $spostop, "const", $src,
                $dtype, $dpostop,          $dst 
    --> Str) is export
{
    # Conversion for argument is not needed if argument is const
    ""
}

multi postcall( $name, $where, "CLASS", "arg",
                $stype, $spostop, "", $src,
                $dtype, "*",          $dst 
    --> Str) is export
{
    # A class is never supposed to be returned via an argument (TBC)
    ""
}


multi postcall( $name, $where, $tot, $ret,
                $stype, $spostop, $sconst, $src,
                $dtype, $dpostop,          $dst
    --> Str) is export
{
    my $msg = "Can't find any postcall conversion for $tot [$ret]" ~ "\n"
                ~ "from $where\::$name $sconst $stype $spostop $src"
                ~ " to $dtype $dpostop $dst" ~ " " ~ $sconst ~ "\n";
    note $msg;
#      die $msg;
    return '/* WARNING:' ~ "\n" ~ $msg ~ ' */';
}
