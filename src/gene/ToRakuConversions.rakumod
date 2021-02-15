
use gene::config;
use gene::common;
use gene::natives;

# Return the list of enums defined in the given class
sub showEnums(Qclass $cl --> Str) is export
{
    my $o = "";
    for $cl.enums.sort>>.kv -> ($en, $ev) {
        next if !$ev.whiteListed || $ev.blackListed;

        $o ~= "    enum $en \n";

    }
    return $o;
}


# Return code defining the enums of a class
sub writeEnumsCode(Qclass $cl --> Str) is export
{
    my $o = "";
    for $cl.enums.sort>>.kv -> ($en, $ev) {
        next if !$ev.whiteListed || $ev.blackListed;

        # say "\tEnum : $en";

        $o ~= IND ~ "enum $en (\n";
        for $ev.items -> ($name, $rawValue) {
            $o ~= IND x 2 ~ $name ~ " => " ~ $ev.values{$name} ~ ",\n";
        }
        $o ~= IND ~ ");\n";

        # If a QFlags typedef is defined for this enum defined a related sub
        LOOPSUB: for $cl.typedefs.kv -> $k, $v {
            if $v.typeOfType ~~ "COMPOSITE"
                        && $v.fType.base ~~ "QFlags"
                        && $v.subType.base ~~ $en {
                $o ~= IND ~ "our sub $k" ~ '($e? = ';
                $o ~= $ev.items[0][0];  # The first item of the enum
                $o ~= ' --> Int ) is export { $e };' ~ "\n";
                last LOOPSUB;
            }
        }
    }
    return $o;
}



# Return arguments string of the raku method declaration
sub strRakuArgsDecl(Function $f, %qClasses --> Str) is export
{
    my $o = "(";
    my $sep = "";
    for $f.arguments -> $a {
        $o ~= $sep ~ rType($a) ~ " " ~ '$' ~ $a.fname;
        if $a.value { $o ~= " = " ~ toRaku($a.value, %qClasses) }
        $sep = ", ";
    }
    if qRet($f) !~~ "void" {
        $o ~= " --> " ~ rType($f.returnType);
    }
    $o ~= ")";
    return $o;
}


# Return arguments string of the ctor method declaration
sub strArgsRakuCtorDecl(Function $f, %qClasses --> Str) is export
{
    my $o = '(RaQtBase $this';
    my $sep = ", ";
    for $f.arguments -> $a {
        $o ~= $sep ~ rType($a) ~ ' $' ~ $a.fname;
        if $a.value {
            $o ~= " = " ~ ($a.value ~~ "nullptr"
                            ?? "(" ~ rType($a) ~ ")"
                            !! toRaku($a.value, %qClasses));
        }
    }
    $o ~= ")";
    return $o;
}



# Return arguments string of the raku method declaration
sub strRakuArgsCtorDecl(Function $f, Str $class, %qClasses --> Str) is export
{
    my $o = "(";
    my $sep = "";
    for $f.arguments -> $a {
        $o ~= $sep ~ rType($a) ~ " " ~ '$' ~ $a.fname;
        if $a.value { $o ~= " = " ~ toRaku($a.value, %qClasses) }
        $sep = ", ";
    }
    if qRet($f) !~~ "void" {
        $o ~= " --> $class)";
    }
    $o ~= ")";
    return $o;
}





#| Return the Raku arguments of the method (without its invocant) in a list
# coded inside a string.
# Each element of the list is either the type of the argument when it has no
# default value, either a list of three elements: the type, name and default
# value of this argument.
# This list is intended to be used as an argument of the createSignature sub
# called at RaQt compile time.
sub StrRakuParamsLst(Function $f, %qClasses --> Str) is export
{
    my Str $o = "(";
    my Str $sep = "";
    for $f.arguments -> $a {
        $o ~= $sep;
        $sep = ", ";
        if $a.value {
            $o ~= '("' ~ rType($a) ~ '" ,"'
                        ~ $a.fname ~ '", ' ~ toRaku($a.value, %qClasses) ~ ')';
        } else {
            $o ~= '"' ~ rType($a) ~ '"';
        }
    }
    return $o ~ $sep ~ ')';
}







# Conversion from C++ to Raku for some constants and expressions
sub toRaku($val is copy, %qClasses) is export
{
    given $val {
        when /'false'/      { $val ~~ s:g/'false'/False/; proceed }
        when /'true'/       { $val ~~ s:g/'true'/True/; proceed }
        when /'|'/          { $val ~~ s:g/'|'/+|/; proceed }
        when /'&'/          { $val ~~ s:g/'&'/+&/; proceed }
        when /'()'/         {
            if $val ~~ /^ (\w+) '(' .*? ')' $/ {
                if %qClasses{$0.Str}:exists {
                    # C++ "QXxx(val)" --> Raku "QXxx.new(val)"
                    $val ~~ s/^ (\w+) ('(' .*? ')') $/$0.new$1/;
                }
            }
        }
    }
    return $val;
}


#| Return arguments string of the native wrapper declaration
# $showObjectPointer : if true the signature starts with the object pointer
#                      when needed (i.e. when the method is not a ctor)
# $showParenth : if true, add parentheses around the signature
# $startWithSep : if true and $showParenth is false, output a comma first
# $showNames : if true, args names are added to the string
sub strNativeWrapperArgsDecl(Function $f,
                             Bool :$showObjectPointer = True,
                             Bool :$showParenth = True,
                             Bool :$startWithSep = True,
                             Bool :$showNames = False --> Str) is export
{
    my $o = "";
    my $sep = "";

    # Add the object pointer if needed
    if $f.name !~~ "ctor" && $showObjectPointer {
        $o ~= "Pointer";
        $o ~= ' $obj' if $showNames;
        $sep = ", ";
    }

    # Add the arguments
    for $f.arguments -> $a {
        $o ~= $sep ~ nType($a);
        $o ~= ' $' ~ $a.name if $showNames;
        $sep = ", ";
    }

    # Add parentheses and comma if needed
    if $showParenth {
        $o = "($o)";
    } elsif $startWithSep {
        $o = ", $o" if $o !~~ "";
    }

    return $o;
}



# Return code to precompute arguments in a callback handler
# then the list of arguments passed to the callback
sub strArgsRakuCallbackCall(Function $f --> List) is export
{
    my $o = "(";
    my $po = "";
    my $sep = "";
    my $c = 0;
    for $f.arguments -> $a {
        $c++;

        # If the arg type is a class, a ctor from a pointer have to be provided
        if $a.ftot ~~ "CLASS" {
            $po ~= 'my ' ~ $a.fbase ~ ' $a' ~ $c ~ ' = '
                        ~ $a.fbase ~ '.new($' ~ $a.name ~ ');' ~ "\n";
            $o ~= $sep ~ '$a' ~ $c;
        } else {
            $o ~= $sep ~ '$' ~ $a.name;
        }
        $sep = ", ";
    }
    $o ~= ")";
    return ($po, $o);
}




# Return arguments string of the new method declaration
sub strArgsRakuBlessCall(Function $f --> Str) is export
{
    my $o = "(";
    my $sep = "";
    for $f.arguments -> $a {
        $o ~= $sep ~ ':$' ~ $a.name;
        $sep = ", ";
    }
    $o ~= ")";
    return $o;
}



# Return code to precompute arguments then the arguments string
# of the native wrapper call
sub strArgsRakuCallDecl(Function $f --> List) is export
{
    my $o = "(self.address";
    my @po = ();
    my $sep = ", ";
    my $c = 0;
    for $f.arguments -> $a {
        $c++;
        my Str $convLine = precall_raku($c, $a.ftot, $a.fname,
                                            rType($a), $a.const, $a.postop);
        if $convLine {
            @po.push($convLine ~ "\n");
            $o ~= $sep ~ '$a' ~ $c;
        } else {
            $o ~= $sep ~ '$' ~ $a.fname;
        }
        $sep = ", ";
    }
    $o ~= ")";
    return (@po, $o);
}



# Return a list of lines of code to precompute arguments then the
#  arguments string of the ctor method wrapper call
sub strArgsRakuCtorWrapperCall(Function $f --> List) is export
{
    my $o = "(";
    my @po = ();
    my $sep = "";
    my $c = 0;
    for $f.arguments -> $a {
        $c++;

        my Str $convLine = precall_raku($c, $a.ftot, $a.fname,
                                            rType($a), $a.const, $a.postop);
        if $convLine {
            @po.push($convLine ~ "\n");
            $o ~= $sep ~ '$a' ~ $c;
        } else {
            $o ~= $sep ~ '$' ~ $a.fname;
        }

        $sep = ", ";
    }
    $o ~= ")";
    return (@po, $o);
}


###############################################################################

# Create Raku instruction to convert an argument before calling a native sub

# Parameters :
#  1 - argIndex = Order of the argument in the signature
#  2 - typeOfType ("CLASS", "NATIVE", "ENUM", etc...)
#  3 - argName = Name of the source variable in the conversion code
#  4 - rakuTypeName = Type name of the source argument
#  5 - $const = "const" or "" according to const keyword of the C++ argument
#  6 - $postop = "*", "&" or "" according to postoperator of the C++ argument
#
# All parameters except the first one are Str


#   precall_raku( Int argIndex, Str typeOfType, Str argName, Str rakuTypeName)
#     returns conversion code line or "" if no conversion needed

# C++ argument is "Class * name" :
# If the arg type is a Qt object, the wrapper needs its address
# or 0 if the object is undefined (i.e. nullptr)
multi sub precall_raku(Int $c, "CLASS", Str $argName,
                        Str $rakuTypeName, Str $const, "*" --> Str)
{ 'my $a' ~ $c ~ ' = ?$' ~ $argName ~ ' ?? $' ~ $argName ~ '.address !! QWInt2Pointer(0);' }

# C++ argument is "Class & name" :
# If the arg type is a Qt object, the wrapper needs its address
# A nullptr is not allowed
multi sub precall_raku(Int $c, "CLASS", Str $argName,
                        Str $rakuTypeName, Str $const, "&" --> Str)
{ 'my $a' ~ $c ~ ' = $' ~ $argName ~ '.address;' }

# Conversion from Real to Num needed before native call
multi sub precall_raku(Int $c, "NATIVE", Str $argName,
                        "Real", Str $const, Str $postop --> Str)
    { 'my Num $a' ~ $c ~ ' = $' ~ $argName ~ '.Num;' }

# Conversion from Bool to Num
multi sub precall_raku(Int $c, "NATIVE", Str $argName,
                        "Bool", Str $const, Str $postop --> Str)
    { 'my int8 $a' ~ $c ~ ' = $' ~ $argName ~ '.Int;' }

# Default
multi sub precall_raku(Int $c, Str $tot, Str $argName,
                        Str $rakuTypeName, Str $const, Str $postop --> Str)
    { '' }



#   postcall_raku(Str $src, Str typeOfType, Str, qPostop,
#                 Str $dst, Str rakuTypeName)
#     returns conversion code line or "" if no conversion needed

# Conversion from Num to Real needed after native call
multi sub postcall_raku($src, "NATIVE", $qPostop, $dst, "Real")
 is export
    { "my $dst = $src" ~ '.Real;' }

# Conversion to Bool
multi sub postcall_raku($src, "NATIVE", $qPostop, $dst, "Bool")
 is export
    { "my $dst = ?$src;" }

# Conversion to Enum
multi sub postcall_raku($src, "ENUM", $qPostop, $dst, $enumName)
 is export
    { "my $dst = $enumName\($src);" }

# Conversion to class. Qt returns an object on the stack.
# The native wrapper should have done a copy on the heap of the object.
# The copy is owned by Raku.
multi sub postcall_raku($src, "CLASS", "", $dst, $className)
 is export
    { "my $dst = $className.new\($src, obr => True);" }

# Conversion to class. Qt returns a reference or a ptr.
# The object is owned by Qt.
multi sub postcall_raku($src, "CLASS", $qPostop, $dst, $className)
 is export
    { "my $dst = $className.new\($src, obr => False);" }


# Default
multi sub postcall_raku($src, $tot, $qPostop, $dst, $typeName)
  is export
   { "" }




