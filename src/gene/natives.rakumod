
# Memorize the connections between Qt, C, native and Raku types
class  DictElem {
    has $.qtype;     # Type used in Qt API
    has $.ctype;     # Type used in C I/F wih Raku
    has $.cpostop;   # Post operator used in C I/F wih Raku
    has $.ntype;     # Native type used by Raku
    has $.rtype;     # Raku type used in Raku API calling the Qt API
}


# Create a dictElem from :
#       $a : Qt type
#       $b : C type
#       $c : C postop
#       $d : native type
#       $e : Raku type
sub nde($a, $b, $c, $d, $e --> DictElem)
{
    DictElem.new(qtype => $a, ctype => $b, cpostop => $c,
                                            ntype => $d, rtype => $e)
}

my %type_dict = (
    "void" => nde("void", "void", "", "void", "void"),   # ???????
    "bool" => nde("bool", "int8_t", "", "int8", "Bool"),
    "int8" =>nde("char", "int8_t", "", "int8", "Byte"),
    "int16" =>nde("short", "int16_t", "", "int16", "Int"),
    "int32" => nde("int", "int32_t", "", "int32", "Int"),
    "int64" => nde("long long", "int64_t", "", "int64", "Int"),
    "uint8" => nde("unsigned char", "uint8_t", "", "uint8", "Int"),
    "uint16" => nde("unsigned short", "uint16_t", "", "uint16", "Int"),
    "uint32" => nde("unsigned int", "uint32_t", "", "uint32", "Int"),
    "uint64" => nde("unsigned long long", "uint64_t", "", "uint64", "Int"),
    "num32" => nde("float", "float", "", "num32", "Real"),
    "num64" => nde("double", "double", "", "num64", "Real"),
    "Str" => nde("QString", "char", "*", "Str", "Str")
);






# Return the native type of a native type or False
sub nativeType_n(Str $typeName --> Str) is export
{
    my $t = trim $typeName;
    return %type_dict{$t}:exists ?? %type_dict{$t}.ntype !! Str;
}

# Return the C type of a native type or False
sub nativeType_c(Str $typeName --> Str) is export
{
    my $t = trim $typeName;
    return %type_dict{$t}:exists ?? %type_dict{$t}.ctype !! Str;
}

# Return the C type of a native type or False
sub nativeType_cp(Str $typeName --> Str) is export
{
    my $t = trim $typeName;
    return %type_dict{$t}:exists ?? %type_dict{$t}.cpostop !! Str;
}

# Return the Raku type of a native type or False
sub nativeType_r(Str $typeName --> Str) is export
{
    my $t = trim $typeName;
    return %type_dict{$t}:exists ?? %type_dict{$t}.rtype !! Str;
}






sub normalize(Str $t is copy --> Str)
{
    $t ~~ s:g/\s+/ /;
    return $t;
}




my %native = (
    "void" => "void",
    "bool" => "bool",
    "char" => "int8",
    "short" => "int16",
    "int" => "int32",
    "long" => "int32",
    "long int" => "int32",
    "long long" => "int64",
    "short int" => "int16",
    "unsigned short" => "uint16",
    "unsigned short int" => "uint16",
    "unsigned int" => "uint32",
    "unsigned long" => "uint32",
    "unsigned long int" => "uint32",
    "long unsigned int" => "uint32",
    "unsigned long long" => "uint64",
    "signed char" => "int8",
    "unsigned char" => "uint8",
    "unsigned" => "uint32",
    "float" => "num32",
    "double" => "num64",
    "char16_t" => "int16",
    "char32_t" => "int32",
    "wchar_t" => "int32"        # should be int16 on Windows ???
);

sub nativeType(Str $typeName --> Str) is export
{
    my $t = normalize trim $typeName;
    return %native{$t}:exists ?? %native{$t} !! Str;
}

my %special = (
    "QString" => "Str"
);

sub specialType(Str $typeName --> Str) is export
{
    my $t = trim $typeName;
    return %special{$t}:exists ?? %special{$t} !! Str;
}


