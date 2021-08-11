
use config;
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
                # $o ~= $ev.items[0][0];    # The first item of the enum
                $o ~= "0";                # Always 0 (see QFileDialog::Option)
                $o ~= ' --> Int ) is export { $e };' ~ "\n";
                last LOOPSUB;
            }
        }
        
        $o ~= "\n";
    }
    return $o;
}



# Return arguments string of the raku method declaration
sub strRakuArgsDecl(Function $f, %qClasses,
                    Bool :$useRole = False --> Str) is export
{
    my $o = "(";
    my $sep = "";
    for $f.arguments -> $a {
        my $qtc = isQtClass $a;
        my Bool $ur = $useRole && (?$qtc && %qClasses{$qtc}.isQObj); 
        my $rtp = rType($a, useRole => $ur);
        $o ~= $sep ~ $rtp ~ " " ~ '$' ~ $a.fname;
        if $a.value { 
            $o ~= " = " ~ toRaku($a.value, $rtp, %qClasses, useRole => $ur)
        }
        $sep = ", ";
    }
    if qRet($f) !~~ "void" {
        my $qtc = isQtClass $f.returnType;
        my Bool $ur = $useRole && (?$qtc && %qClasses{$qtc}.isQObj); 
        $o ~= " --> " ~ rType($f.returnType, useRole => $ur);
    }
    $o ~= ")";
    return $o;
}


# Return arguments string of the ctor method declaration
sub strArgsRakuCtorDecl(Function $f, %qClasses,
                        Bool :$useRole = False --> Str) is export
{
    my $o = '(QtBase $this';
    my $sep = ", ";
    for $f.arguments -> $a {

        my Bool $useRole2 = False;
        if $useRole {
            my $argClass = isQtClass($a);
            if $argClass {
                $useRole2 = %qClasses{$argClass}.isQObj;
            }
        }

        $o ~= $sep ~ rType($a, useRole => $useRole2) ~ ' $' ~ $a.fname;
        if $a.value {
            $o ~= " = " ~ ($a.value ~~ "nullptr"
                            ?? "(" ~ rType($a, useRole => $useRole2) ~ ")"
                            !! toRaku($a.value, rType($a), %qClasses, 
                                                    useRole => $useRole2));
        }
    }
    $o ~= ")";
    return $o;
}


# Return arguments string of the raku method declaration
# (Used by the doc generator)
sub strRakuArgsCtorDecl(Function $f, Str $class, %qClasses --> Str) is export
{
    my $o = "(";
    my $sep = "";
    for $f.arguments -> $a {
        $o ~= $sep ~ rType($a) ~ " " ~ '$' ~ $a.fname;
        if $a.value { $o ~= " = " ~ toRaku($a.value, rType($a), %qClasses) }
        $sep = ", ";
    }
    if qRet($f) !~~ "void" {
        $o ~= " --> $class)";
    }
    $o ~= ")";
    return $o;
}


# Return the list of Qt classes used in the signature of the function
sub classesInSignature(Function $f --> List) is export
{
    my @o;
    for $f.arguments -> $a {
        my $t = isQtClass($a);
        if $t {
            @o.push: $t;
        } else {
            my $t = isQtEnum($a);
            if $t {
                @o.push: $t;
            }
        }
    }
    if qRet($f) !~~ "void" {
        my $t = isQtClass($f.returnType);
        if $t {
            @o.push: $t;
        } else {
            my $t = isQtEnum($f.returnType);
            if $t {
                @o.push: $t;
            }
        }
    }
    return @o;
}

# Return the name of the name of the Qt classe returned by the function
# or Nil if the function doesn't return a Qt class
sub classeReturned(Function $f --> Str) is export
{
    if qRet($f) !~~ "void" {
        my $t = isQtClass($f.returnType);
        if $t {
            return $t;
        }
    }
    return (Str);
}


# #| Return the Raku arguments of the method (without its invocant) in a list
# # coded inside a string.
# # Each element of the list is either the type of the argument when it has no
# # default value, either a list of three elements: the type, name and default
# # value of this argument.
# # This list was intended to be used as an argument of the createSignature sub
# # called at compile time.
# sub StrRakuParamsLst(Function $f, %qClasses --> Str) is export
# {
#     my Str $o = "(";
#     my Str $sep = "";
#     for $f.arguments -> $a {
#         $o ~= $sep;
#         my Str $rtp = rType($a);
#         $sep = ", ";
#         if $a.value {
#             $o ~= '("' ~ $rtp ~ '" ,"' ~ $a.fname ~ '",
#                             ' ~ toRaku($a.value, $rtp, %qClasses) ~ ')';
#         } else {
#             $o ~= '"' ~ $rtp ~ '"';
#         }
#     }
#     return $o ~ $sep ~ ')';
# }







# Conversion from C++ to Raku for some constants and expressions
# $val : the string to convert
# $cls : The target class of this string
# %qClasses : The hash of known classes
# $useRole : True if role should be use in declaration rather than class
sub toRaku(Str $val is copy, Str $cls, %qClasses,
            Bool :$useRole = False --> Str) is export
{
    given $val {
        when /'false'/      { $val ~~ s:g/'false'/False/; proceed }
        when /'true'/       { $val ~~ s:g/'true'/True/; proceed }
        when /'|'/          { $val ~~ s:g/'|'/+|/; proceed }
        when /'&'/          { $val ~~ s:g/'&'/+&/; proceed }
        when /'(' .*? ')'/         {
            if $val ~~ /^ (\w+) '(' .*? ')' $/ {
                if %qClasses{$0.Str}:exists {
                    if $useRole {
                        # C++ "QXxx(val)" --> Raku "RQXxx.new(val)"
                        $val ~~ s/^ (\w+) ('(' .*? ')') $/R$0.NEW1$1/;
                    } else {
                        # C++ "QXxx(val)" --> Raku "QXxx.new(val)"
                        $val ~~ s/^ (\w+) ('(' .*? ')') $/$0.new$1/;
                        
                        # Process special classes :
                        #       QString.new()      --> ""
                        #       QString.new("xxx") --> "xxx"
                        if $val ~~ m/^ 'QString.new(' ( .*? ) ')' $/ {
                            $val = $0 ~~ "" ?? '""' !! $0;
                        }
                    }
                }
            }
        }
    }
                            
    # Replace nullptr with some Raku equivalent
    $val ~~ s/nullptr/($cls)/;

    return $val;
}


#| Return arguments string of the native wrapper declaration
# $showObjectPointer : if true the signature starts with the object pointer
#                      when needed (i.e. when the method is neither static
#                                   nor a ctor)
# $showParenth : if true, add parentheses around the signature
# $startWithSep : if true and $showParenth is false, output a comma first
# $showNames : if true, args names are added to the string
sub strNativeWrapperArgsDecl(Function $f,
                             Bool :$showObjectPointer = True,
                             Bool :$showParenth = True,
                             Bool :$startWithSep = True,
                             Bool :$showNames) is export
{
    my $o = "";
    my $sep = "";

    # Add the object pointer if needed
    if $f.name !~~ "ctor" && !$f.isStatic && $showObjectPointer {
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



# Return in a three elements list :
#  * A Str of the code needed to precompute arguments in a callback handler
#  * A Str containing the arguments list passed to the callback
#  * The list of classes used as argument if $multiFiles is True
sub rakuCallbackCallElems(Function $f, 
                          Bool :$multiFiles = False --> List) is export
{
    my $o = "(";
    my $po = "";
    my $sep = "";
    my $c = 0;
    my @classes = ();    # Accumulate here classes which have to be declared
    for $f.arguments -> $a {
        $c++;

        # If the arg type is a class, a ctor from a pointer have to be provided
        if $a.ftot ~~ "CLASS" {
        
            my $tname = $a.fbase;
            @classes.push: $tname if $multiFiles;
        
            $po ~= 'my ' ~ $tname ~ ' $a' ~ $c ~ ' = '
                        ~ $tname ~ '.new($' ~ $a.name ~ ');' ~ "\n";
            $o ~= $sep ~ '$a' ~ $c;
        } else {
            $o ~= $sep ~ '$' ~ $a.name;
        }
        $sep = ", ";
    }
    $o ~= ")";
    return ($po, $o, @classes);
}


# Return in a two elements list :
#  * A list of Str, one for each line of code needed to precompute arguments
#    before calling a native wrapper
#  * A Str containing the arguments list passed to the wrapper
sub rakuWrapperCallElems(Function $f --> List) is export
{
    my $o;
    my @po = ();
    my $sep;
    if $f.isStatic || $f.name ~~ "ctor" {
        $o = "(";
        $sep = "";
    } else {
        $o = "(self.address";
        $sep = ", ";
    }
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




