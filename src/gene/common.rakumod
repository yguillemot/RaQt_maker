
use config;
use gene::natives;

# Following Qt classes need a special processing and must not be
# automatically implemented in a standard way.
# If needed, their code may be directly defined in the template files.
our constant $specialClasses = <
    QObject QString
>.Set;
our constant $uninstanciableClasses = <
    Qt
>.Set;


# Markers identifying class names in a future raku module before replacing
# them either with a class name or role name
our constant CNOM = '[)';    # Class Name Open Marker
our constant CNCM = '(]';    # Class Name Close Marker


=begin pod
=head2 Class API

This class gathers two hashes where the whole description
of an API text file is stored.

=item %.qclasses

All the "Qt class" objects (Qclass), key = Qt class name (Str)

=item %.topTypedefs

The typedefs defined outside classes, key = typedef name

=end pod

class API {
    has %.qclasses;
    has %.topTypedefs;
}

class SubType {...}

=begin pod

=head2 role FinalType

Store the final nature (type of type) of an argument

The following attributes can only be filled after the parsing process
itself has been achieved :

=head3 Str $.ftot

 Final type of the type : QTCLASS, ENUM, NATIVE, COMPOSITE or UNKNOWN

=head3 Str $.fclass

 The class name where the final type is defined (if any)

=head3 Str $.fbase

 The name of the final type (if this final type is known)

=head3 Str $.fpostop

 The postop of the final type (if this final type is known)

=head3 Str $.fname

 The name of the argument (in the case it was unnamed)

=head3 Str $.subtype

 The subtype involved if $.ftot is "COMPOSITE"

=end pod


role FinalType {

    has Str $.ftot is rw;
    has Str $.fclass is rw;
    has Str $.fbase is rw;
    has Str $.fpostop is rw;
    has Str $.fname is rw;
    has SubType $.subtype is rw = (SubType);

    method sayFinalType
    {   say "\t", $.ftot, " ", $.fclass, " : ", $.fbase, " ", $.fpostop, " ", $.fname;
    }
}

class SubType does FinalType { }

#| Store one of the elements of a signature
class Argument does FinalType {
    has Str $.base;
    has Str $.postop;
    has Str $.name;
    has Str $.value;
    has Str $.const = "";      # "const" C++ keyword

    method say
    { say $.const, " ", $.base, " ", $.postop, " ", $.name;
      self.sayFinalType;
    }
}


##############################################################################

# Used to easily add blacklist management to some already existing class
role Validation {
    has Bool $.blackListed is default(False) is rw;
    has Bool $.whiteListed is default(False) is rw;

    method colorless (--> Bool) { !$.blackListed && !$.whiteListed }
    method gray (--> Bool) { $.blackListed && $.whiteListed }
}

##############################################################################

# Used to find out possible module load loops and to determine if a module
# have to be seen directly or through a role
# (There is one module for each Qt class)
role LoadTreeElement {
    has Str %.needed;    # List of modules needed by the current one
                         # %.needed{$moduleName} = How_string
                         #      How_string is "UNDEFINED"
                         #                 or "DIRECT"
                         #                 or "ROLE"

    has Str $.inLoop is rw;   # Is part of a module load loop
    has Bool $.flag is rw;  # Used while computing $.notInLoop to avoid
                            # infinite recursion if a loop is found
}

##############################################################################


#| Local type (ie Raku, Native, C or Qt type)
class Ltype {
    has Str $.base is rw;           # Base type name
    has Str $.postop is rw = "";    # Possible post operator (or "")
    has Str $.const is rw = "";     # "const" C++ keyword

    method str returns Str
    {
        my Str $out = $.base;
        $out ~= " " ~ $.postop if $.postop;
        return $out;
    }
}

# #| Global type (Gather in the same object Raku, Native, C and Qt type)
# class type {
#     has %.types;            # k = N, P, Q       v = ($type, $postop)
#     has %.fconv;            # k = N2Q, Q2N      v = Function
#
#     method say {
#         say "type N=", %.types<N>.str, " P=", %.types<P>.str, " Q=", %.types<Q>.str;
#         say "   N2Q : " ~ (%.fconv<N2Q>:exists ?? qProto(%.fconv<N2Q>) !! "");
#         say "   Q2N : " ~ (%.fconv<Q2N>:exists ?? qProto(%.fconv<Q2N>) !! "");
#         say "   P2N : " ~ (%.fconv<P2N>:exists ?? qProto(%.fconv<P2N>) !! "");
#         say "   N2P : " ~ (%.fconv<N2P>:exists ?? qProto(%.fconv<N2P>) !! "");
#         say "";
#     }
#
#     method rakuType returns Str
#     {
#         return %.types<P>.str;
#     }
# }


#| Enum defined in Qt classes
class QEnum does Validation {
    has Str $.name;
    has List @.items = ();   # Ordered list of pairs ("item name", "raw value")
    has %.values = ();       # "item name" => computed value (when possible)
}

class Triplet {
    has $.name;
    has $.rawValue;
    has $.value;
}

class Typedef {
    has Str $.name;
    has Ltype $.type;                  # First type where the typedef points
    has Str $.srcClass is default(""); # Where the typedef is defined
    has Ltype $.fType is rw;           # Final type where typedef points
    has Str $.fClass is rw is default("");   # Where $.ftype is defined
    
    # "CLASS", "ENUM", "NATIVE", "COMPOSITE" or "UNKNOWN"
    has Str $.typeOfType is rw is default("???");
    
    # SubType is only defined when typeOfType is "COMPOSITE"
    has Ltype $.subType is rw is default(Ltype);
    has Str $.subType-tot is rw is default(Str);
    has Str $.subType-class is rw is default(Str);

    method lookForFinalType(API $api)
    {
        my @r = finalTypeOf(api => $api, from => $.srcClass, type => $.type);
        my $subtype;
        ($.typeOfType, $.fClass, $.fType, $subtype) = @r;
        if $subtype {
            ($.subType-tot, $.subType-class, $.subType) = $subtype;
        }
    }
}


##############################################################################

class Rtype is Ltype does FinalType { }


=begin pod
=header1 qType qPostop qConst

Following subs work on Argument of type Rtype :
They return the various types used through the conversion between Qt/C++
and Raku

=end pod

#| Return Qt type in a string
sub qType($arg --> Str) is export { $arg.base }

#| Return Qt type post operator ('*' or '&'=) in a string
sub qPostop($arg --> Str) is export { $arg.postop }

#| Return Qt type "const" attribute in a string
sub qConst($arg --> Str) is export { $arg.const }

sub cType($arg --> Str) is export
{
    given $arg.ftot {
        when "CLASS" { "void" }
        when "ENUM" { "int" }
        when "NATIVE" {
            #   TODO : This case should be dealed in natives.rakumod and not here
            if $arg.fbase ~~ "char" && $arg.fpostop ~~ "*" { "char" }
            else { nativeType_c($arg.fbase) }
        }
        when "SPECIAL" { nativeType_c($arg.fbase) }
        when "COMPOSITE" {
            given $arg.fbase {
                when "QFlags" {
                    given $arg.subtype.ftot {
                        when "ENUM" { "int" }
                        default { die "Subtype ", $arg.subtype.ftot, 
                                                            " unsupported" }
                    }
                }
                default { die "Composite ", $arg.fbase, " unsupported" }
            }
        }
        when "UNKNOWN" {
            die "Looking for the C type of the unknown type ", $arg.base;
        }
    }
}

sub cPostop($arg --> Str) is export
{
    given $arg.ftot {
        when "CLASS" { "*" }
        when "ENUM" { "" }
        when "NATIVE" {
            #   TODO : This case should be dealed in natives.rakumod and not here
            if $arg.fbase ~~ "char" && $arg.fpostop ~~ "*" { "*" }
            else { "" }
        }
        when "SPECIAL" { nativeType_cp($arg.fbase) }
        when "COMPOSITE" {
            given $arg.fbase {
                when "QFlags" {
                    given $arg.subtype.ftot {
                        when "ENUM" { "" }
                        default { die "Subtype ", $arg.subtype.ftot,
                                                        " unsupported]" }
                    }
                }
                default { die "Composite ", $arg.fbase, " unsupported]" }
            }
        }
        when "UNKNOWN" {
            die "Looking for the C postop of the unknown type ", $arg.base;
        }
    }
}

sub nType($arg --> Str) is export
{
    given $arg.ftot {
        when "CLASS" { "Pointer" }
        when "ENUM" { "int32" }
        when "NATIVE" {                 # ???????
            #   TODO : This case should be dealed in natives.rakumod and not here
            if $arg.fbase ~~ "char" && $arg.fpostop ~~ "*" { "char" }
            else { nativeType_n($arg.fbase) }
        }
        when "SPECIAL" { nativeType_n($arg.fbase) }
        when "COMPOSITE" {
            given $arg.fbase {
                when "QFlags" {
                    given $arg.subtype.ftot {
                        when "ENUM" { "int32" }
                        default { die "Subtype ", $arg.subtype.ftot,
                                                        " unsupported]" }
                    }
                }
                default { "[Composite " ~ $arg.fbase ~ " unsupported]" }
            }
        }
        when "UNKNOWN" {
            die "Looking for the native type of the unknown type ", $arg.base;
        }
    }
}

# When $useRole is True, the role prefix is added to the name of classes
# When $noEnum is True, the rnum types are replaced with "Int" 
sub rType($arg,
          Bool :$markers = False,
          Bool :$forceRole = False,
          Bool :$noEnum = False
          --> Str) is export
{
    my Str ($prefix, $postfix) = $forceRole ?? ("R", "")
                                            !! $markers ?? (CNOM, CNCM)
                                                        !! ("","");
    given $arg.ftot {
        when "CLASS" { $prefix ~ $arg.base ~ $postfix }
        when "ENUM" {
            $noEnum
                ?? "Int"
                !! ($arg.fclass ~ '::' ~ $arg.fbase)
        }
        when "NATIVE" {
            #   TODO : This case should be dealed in natives.rakumod and not here
            if $arg.fbase ~~ "char" && $arg.fpostop ~~ "*" { "Str" }
            else { nativeType_r($arg.fbase) }
        }
        when "SPECIAL" { nativeType_r($arg.fbase) }
        when "COMPOSITE" {
            given $arg.fbase {
                when "QFlags" {
                    given $arg.subtype.ftot {
                        when "ENUM" { # $arg.subtype.fclass ~ '::'
                                      #                  ~ $arg.subtype.fbase
                                      "Int"    # Avoid conversion problems
                                    }
                        default { die "Subtype ", $arg.subtype.ftot,
                                                        " unsupported]" }
                    }
                }
                default { "[Composite " ~ $arg.fbase ~ " unsupported]" }
            }
        }
        when "UNKNOWN" {
            die "Looking for the Raku type of the unknown type ", $arg.base;
        }
    }
}

# If the given Argument type is a Qt class, returns its name
# else, return Nil
sub isQtClass($arg --> Str) is export
{
    given $arg.ftot {
        when "CLASS" { $arg.base }
        when "ENUM" { (Str) }
        when "NATIVE" { (Str) }
        when "SPECIAL" { (Str) }
        when "COMPOSITE" {
            given $arg.fbase {
                when "QFlags" {
                    given $arg.subtype.ftot {
                        when "ENUM" { (Str) }
                        default { die "Subtype ", $arg.subtype.ftot,
                                                        " unsupported]" }
                    }
                }
                default { (Str) }
            }
        }
        when "UNKNOWN" {
            die "Looking for the Raku type of the unknown type ", $arg.base;
        }
        default { (Str) }
    }
}

# If the given Argument type is a Qt enum
# then return the name of the Qt class where this enum is defined
# else return Nil
sub isQtEnum($arg --> Str) is export
{
    given $arg.ftot {
        when "CLASS" { (Str) }
        when "ENUM" { $arg.fclass }
        when "NATIVE" { (Str) }
        when "SPECIAL" { (Str) }
        when "COMPOSITE" {
            given $arg.fbase {
                when "QFlags" {
                    given $arg.subtype.ftot {
                        when "ENUM" { $arg.fclass }
                        default { die "Subtype ", $arg.subtype.ftot,
                                                        " unsupported]" }
                    }
                }
                default { (Str) }
            }
        }
        when "UNKNOWN" {
            die "Looking for the Raku type of the unknown type ", $arg.base;
        }
        default { (Str) }
    }
}

#| Store the prototype of a function (or a signal)
class Function does Validation {
    has Str $.name;

    has Bool $.isSlot is default(False);
    has Bool $.isSignal is default(False);
        # isSlot and isSignal are mutually exclusive
        
    has Bool $.isPrivateSignal is rw is default(False);
        # Only significant if $.isSignal is True

    has Bool $.isStatic is default(False);
    has Bool $.isVirtual is default(False);
        # isStatic and isVirtual are mutually exclusive

    has Bool $.isPureVirtual is default(False);
    has Bool $.isProtected is default(False);
    has Bool $.isConst is default(False);
    has Bool $.isOverride is default(False);
    has Rtype $.returnType;
    has Argument @.arguments is rw;

    has Int $.number is rw is default((Int)); # Disambiguate C code of multi

    method say
    {
        my $t = $.returnType.base;
        my $pop = $.returnType.postop;
        say $t, " ", $pop, " ", $.name, qSignature(self);
#         for @.arguments -> $x { $x.say; }
#         say ")";
    }

    method setupFinalTypes(API $api, Str $class)
    {
        if $.returnType.base {
            my ($tot, $cl, $ltype, $subtype)
                = finalTypeOf(api => $api,
                              from => $class,
                              type => Ltype.new(base => $.returnType.base,
                                                postop => $.returnType.postop));
            $.returnType.ftot = $tot;
            $.returnType.fclass = $cl;
            $.returnType.fbase = $ltype.base;
            $.returnType.fpostop = $ltype.postop;
            $.returnType.fname = "retVal";        # Should never be used
            
            if $tot ~~ "COMPOSITE" {
            
                if !$subtype {
                    note "While processing method ", $.name; 
                    note "Return type : class : $cl, type : ", $ltype.str;
                    die "Type is COMPOSITE but subtype is undefined";
                }
                
                my ($stot, $scl, $sltype) = $subtype;
                
                if $stot ~~ "COMPOSITE" {
                    note "While processing method ", $.name; 
                    note "Return type : class : $cl, type : ", $ltype.str;
                    die "More than one level of COMPOSITE type is not allowed";
                }
                
                $.returnType.subtype = SubType.new;
                $.returnType.subtype.ftot = $stot;
                $.returnType.subtype.fclass = $scl;
                $.returnType.subtype.fbase = $sltype.base;
                $.returnType.subtype.fpostop = $sltype.postop;
                $.returnType.subtype.fname = "subType";  # Should never be used
            }
        }
        for @.arguments Z (1..*) -> ($a, $count) {
            my ($tot, $cl, $ltype, $subtype)
                = finalTypeOf(api => $api,
                              from => $class,
                              type => Ltype.new(base => $a.base,
                                                postop => $a.postop));
            $a.ftot = $tot;
            $a.fclass = $cl;
            $a.fbase = $ltype.base;
            $a.fpostop = $ltype.postop;
            # TODO: We should know if it is "" or "???" and simplify next line
            $a.fname = ($a.name ne "" && $a.name ne "???") ??
                                                $a.name !! "arg$count";
                                                
            if $tot ~~ "COMPOSITE" {
            
                if !$subtype {
                    note "While processing method ", $.name, ", arg ", $a.name; 
                    note "class : $cl, type : ", $ltype.str;
                    die "Type is COMPOSITE but subtype is undefined";
                }
                
                my ($stot, $scl, $sltype) = $subtype;
                
                if $stot ~~ "COMPOSITE" {
                    note "While processing method ", $.name, ", arg ", $a.name; 
                    note "Return type : class : $cl, type : ", $ltype.str;
                    die "More than one level of COMPOSITE type is not allowed";
                }
                
                $a.subtype = SubType.new;
                $a.subtype.ftot = $stot;
                $a.subtype.fclass = $scl;
                $a.subtype.fbase = $sltype.base;
                $a.subtype.fpostop = $sltype.postop;
                $a.subtype.fname = "subType";        # Should never be used
            }
        }
    }
}





# Return all the available signatures that a function may have
# when its arguments having default values are removed.
# Signatures are returned through a list of minimalist Function
# where only arguments are defines.
sub availableSignatures(Function $f --> List) is export
{
    my @a = $f.arguments;
    my @fs = ();
    loop {
        @fs.push(Function.new(name => $f.name, arguments => @a));
        last if @a.elems == 0;
        my $u = @a.pop;
        last if !$u.value;
    }
    return @fs;
}


#| Store the prototypes of the methods of a QObject C++ class
class Qclass does Validation does LoadTreeElement {
    has Str $.name;
    has Bool $.generic is rw = False;
    has Bool $.visible is rw = False;
    has Bool $.isAbstract is rw = False;
    has Str @.parents is rw;     # Names of parents classes
    has Str @.ancestors is rw;   # Parents plus parents of parents, etc...
    has Function @.methods is rw;
    has QEnum %.enums is rw;
    has Typedef %.typedefs is rw;

    has Str @.children is rw = ();    # Names of children classes
    has Str @.descendants is rw = (); # Children, children of children, etc...

    has Str $.genericName is rw = "";

    has Bool $.isQObj is rw = False;
    has Str $.group is rw;
    has Int $.level is rw;

    method validVirtuals ( --> List )
    {
        my @out = ();
        for @.methods -> $m {
            if $m.isVirtual && $m.whiteListed && !$m.blackListed {
                @out.push($m);
            }
        }
        return @out;
    }

#     method validSlots ( --> List )
#     {
#         my @out = ();
#         for @.methods -> $m {
#             if $m.isSlot && $m.whiteListed && !$m.blackListed {
#                 @out.push($m);
#             }
#         }
#         return @out;
#     }

    method say
    {
        print " visible" if $.visible;
        print " generic" if $.generic;
        say " class $.name", $.genericName ?? "   is $.genericName" !! "";
        if @.parents.elems {
            print "   Parents :";
            for @.parents -> $p { print " ", $p; }
            say "";
        }
        if @.children.elems {
            print "   Children :";
            for @.children -> $p { print " ", $p; }
            say "";
        }

        say "\nCTOR : ";
        $.ctor.say if $.ctor;

        say "\nmethods : ";
        for @.methods -> $m { $m.say; }

        say "\nvirtuals : ";
        for @.virtuals -> $v { $v.say; }

        say "\nslots : ";
        for @.slots -> $s { $s.say; }

        say "\nsignals : ";
        for @.signals -> $s { $s.say; }

    }
}

##############################################################################

#| Return the C++ signature of $f with types and names
# $showObjectPointer : if true the signature starts with the object pointer
# $showNames : if true, show the name of the parameter
# $showDefault : if true, the possible default values are added
# $showParenth : if true, add parentheses around the signature
# $startWithSep : if true and $showParenth is false, output a comma first
sub qSignature(Function $f,
        Bool :$showObjectPointer = False,
        Bool :$showNames = True,
        Bool :$showDefault = False,
        Bool :$showParenth = True,
        Bool :$startWithSep = True       --> Str) is export
{
    my Str $out = "";
    my $sep = "";
    for $f.arguments -> $a {
        $out ~= $sep;
        $out ~= $a.const ~ " " if $a.const !~~ "";
        $out ~= $a.base ~ $a.postop;
        $out ~= " " ~ $a.fname if $showNames;
        $out ~= " = " ~ $a.value if $showDefault && $a.value;
        $sep = ", ";
    }

    # Add the object pointer
    if $showObjectPointer {
        if $out eq "" {
            $out = "void * obj";
        } else {
            $out = "void * obj, " ~ $out;
        }
    }

    # Add parentheses and comma if needed
    if $showParenth {
        $out = "($out)";
    } elsif $startWithSep {
        $out = ", $out" if $out !~~ "";
    }

    return $out;
}

#| Return the arguments names only (wihout types)
multi qCallUse(Function $f --> Str) is export
{
    my Str $out = "(";
    my $virgule = "";
    for $f.arguments -> $a {
        my $argName = $a.fname;
        $out ~= $virgule ~ $argName;
        $virgule = ", ";
    }
    return $out ~ ")";
}

#| Return the arguments names only (wihout types), each one prefixed with $pr
multi qCallUse(Function $f, Str $pr --> Str) is export
{
    my Str $out = "(";
    my $virgule = "";
    for $f.arguments -> $a {
        my $argName = $pr ~ $a.fname;
        $out ~= $virgule ~ $argName;
        $virgule = ", ";
    }
    return $out ~ ")";
}

#| Return the returned type as defined in the API.txt
sub qRet(Function $f --> Str) is export
{
    my $data = $f.returnType.str;
    return $data.trim;
}

#| Return the method prototype as defined in the API specification text file
sub qProto(Function $f --> Str) is export
{
    return qRet($f) ~ " " ~ $f.name ~ qSignature($f);
}


#| Return true if the returned value needs a buffer on the heap
sub retBufNeeded(Function $f --> Bool) is export
{
    # TODO : Move this sub elsewhere ?
    #        In natives.rakumod ?

    qRet($f) ~~ "QString"
}


#| Return the C return type of a method
sub cRetType(Function $f --> Str) is export
{
    retBufNeeded($f)
        ?? "void"
        !! cRawRetType $f
}


#| Return the C return type a method would have without bufferisation 
sub cRawRetType(Function $f --> Str) is export
{
    trim(cType($f.returnType) ~ " " ~ cPostop($f.returnType))
}


#| Return the arguments of $f with C types and names
# $showObjectPointer : if true the signature starts with the object pointer
#                      when needed (i.e. when the method is not a ctor)
#             Note: If the function needs a return buffer, the buffer address
#                   is the first parameter and the object pointer is the 
#                   second one.
# $showCIdx : if true AND IF $showObjectPointer is true, add the caller
#             index parameter immediately after the object pointer.
# $showParenth : if true, add parentheses around the arguments
# $startWithSep : if true and $showParenth is false, output a comma first
sub cSignature(Function $f,
              Bool :$showObjectPointer = True,
              Bool :$showParenth = True,
              Bool :$startWithSep = True,
              Bool :$showCIdx = False           --> Str) is export
{
    my Str $out = "";
    my Str $sep = "";
    for $f.arguments -> $a {
        $out ~= $sep ~ cType($a) ~ " " ~ cPostop($a) ~ " " ~ $a.fname;
        $sep = ", ";
    }

    # Add the object pointer if needed
    if $f.name !~~ "ctor" && $showObjectPointer {
        my $txt = "void * obj";
        $txt ~= ", int callerIdx" if $showCIdx;
        if $out eq "" {
            $out = $txt;
        } else {
            $out = "$txt, $out";
        }
    }

    # Add the return buffer address if needed
    if retBufNeeded($f) {
        if $out eq "" {
            $out = "void * retBuffer";
        } else {
            $out = "void * retBuffer, $out";
        }
    }

    # Add parentheses and comma if needed
    if $showParenth {
        $out = "($out)";
    } elsif $startWithSep {
        $out = ", $out" if $out !~~ "";
    }

    return $out;
}


#| Return the Raku signature (Raku types without arg names) of $f
# $showParenth : if true, add parentheses around the signature
# $startWithSep : if true and $showParenth is false, output a comma first
# $noEnum : if true, enum types are replaced with "Int"
sub rSignature(Function $f,
               Bool :$showParenth = True,
               Bool :$startWithSep = True,
               Bool :$markers = False,
               Bool :$forceRole = False,
               Bool :$noEnum = False --> Str) is export
{
    my Str $out = "";
    my $sep = "";
    for $f.arguments -> $a {
        $out ~= $sep ~ rType($a, :$markers, :$forceRole, :$noEnum);
        $sep = ", ";
    }

    # Add parentheses and comma if needed
    if $showParenth {
        $out = "($out)";
    } elsif $startWithSep {
        $out = ", $out" if $out !~~ "";
    }

    return $out;
}




################################################################################

# Look for what real type an identifier is pointing to
# Inputs :
#     $api : the parsed API
#     $from : the name of the class where is used the type we are looking for
#     $type : the type we are looking for
# Output :
#     A list with 3 or 4 elems :
#       [0] : Str : Nature of the type CLASS, ENUM, NATIVE, COMPOSITE or UNKNOWN
#       [1] : Str : The class name where type is defined (if type is known)
#       [2] : Ltype : The final type (if type has been found)

#   //    [3] : Str : The template method name if the type is COMPOSITE

#       [3] : List : Idem [0] to [3] but related to the subtype
#                    when type is COMPOSITE

sub finalTypeOf(API :$api, Str :$from, Ltype :$type --> List) is export
{
    # Always look for special first to correctly discovered special Qt class
    # which should not be processed like classes (i.e. QString)
   
    # Is type special ?
    my $nt = specialType($type.base);
    if $nt {
        return ("SPECIAL", "", Ltype.new(base => $nt,
                                        postop => $type.postop));
    }

    # Is type native ?

    # Special case : "char *" is a C string and not a int8 array
    #   TODO : This case should be dealed in natives.rakumod and not here
    if $type.base ~~ "char" && $type.postop ~~ "*" {
            return ("NATIVE", "", Ltype.new(base => "char",
                                            postop => $type.postop));
    } else {
        $nt = nativeType($type.base);
        if $nt {
            return ("NATIVE", "", Ltype.new(base => $nt,
                                            postop => $type.postop));
        }
    }

    # Is type a Qt class ?
    if $api.qclasses{$type.base}:exists {
        return ("CLASS", "", $type);
    }

    # Is type qualified ?
    if $type.base ~~ m/(\w*) '::' (\w+)/ {
        # Remove the qualifier and look again from the specified class
        return finalTypeOf(api => $api,
                           from => ~$0,
                           type => Ltype.new(base => ~$1,
                                             postop => $type.postop));
    }

    # Is type a typedef ?
    # Look first in the top level typedefs
    if $api.topTypedefs{$type.base}:exists {
        my $td = $api.topTypedefs{$type.base};
        my $nt = Ltype.new(base => $td.type.base,
                           postop => $type.postop ~ $td.type.postop);
        return finalTypeOf(api => $api,
                           from => $td.srcClass,
                           type => $nt);

    # Not found in the top level typedefs : look in the class typedefs
    } elsif $api.qclasses{$from}:exists {
        # First in the class itself
        if $api.qclasses{$from}.typedefs{$type.base}:exists {
            my $td = $api.qclasses{$from}.typedefs{$type.base};
            my $nt = Ltype.new(base => $td.type.base,
                               postop => $type.postop ~ $td.type.postop);
            return finalTypeOf(api => $api,
                               from => $td.srcClass,
                               type => $nt);

        } else {
            # Then in the ancestors of the class

                for $api.qclasses{$from}.ancestors -> $a {
                    if $api.qclasses{$a}:exists {
                        if $api.qclasses{$a}.typedefs{$type.base}:exists {
                            my $td = $api.qclasses{$a}.typedefs{$type.base};
                            my $nt = Ltype.new(base => $td.type.base,
                                            postop => $type.postop ~ $td.type.postop);
                            return finalTypeOf(api => $api,
                                            from => $td.srcClass,
                                            type => $nt);
                        }
                    }
                }
        }
    } else {
        # Class $from not found : shoud not occur ???
    }

    # Is type an enum ?
    if $api.qclasses{$from}:exists {
        # First look in the class
        if $api.qclasses{$from}.enums{$type.base}:exists {
            return ("ENUM", $from, $type);
        } else {
            # Then look in the ancestors of the class
            for $api.qclasses{$from}.ancestors -> $a {
                if $api.qclasses{$a}:exists {
                    if $api.qclasses{$a}.enums{$type.base}:exists {
                        return ("ENUM", $a, $type);
                    }
                }
            }
        }
    } else {
        # Class $from not found : shoud not occur ???
    }

    # Is type a composite (i.e. "QXXX<YYY>") ?
    if $type.base ~~ /^ (\w+) '<' (\w+) '>' $/ {
        my $template = ~$0;
        my $arg = ~$1;
        
        # say " COMPOSITE : ", $type.base, " template=$template, arg=$arg";
        # say "   from=$from";
        
        my @argft = finalTypeOf(:$api, :$from, 
                              type => Ltype.new(base => $arg, postop => ''));
                              
        # say @argft[0], " ", @argft[1], '::', @argft[2];
        
        return ("COMPOSITE", $from, Ltype.new(base => $template), @argft);
    }
     
    # Found nothing
    return ("UNKNOWN", $from, $type);
}


################################################################################

# Get all the virtual methods usable from the class named $k in the API.
# A hash is used to deal with possible overriding and to keep only the
# first method found with a given name while ascending the parents list.
#
# Returns { "method_name" => ("class_name", $method), ... }
# where class_name is the name of the class where the method is defined
# and $method is the Function object which describes the method.
#
sub vmethods(API $api, Str $k --> Hash) is export
{
    my %c = $api.qclasses;
    my %virtuals = ();
    gatherVirtuals($k);
    return %virtuals;

    # Recursive subroutine used hereabove
    sub gatherVirtuals(Str $className)
    {
        my $cl = %c{$className};
        GVLOOP:
        for $cl.methods.sort -> $m {
            # say "try ", $m.name, " in class ", $className;

            # V0.0.5: There is a problem with QDialog::exec which is
            #         a "virtual slot". So, currently, the generation
            #         of code related to virtual methods is disabled
            #         with the slots.
            next if $m.isSlot;

            # QObject class is a special case implemented in an exception
            # template and whose methods should never be defined in the
            # white list, but knowing its virtual methods is needed.
            next if $className !~~ "QObject"
                            && ($m.blackListed || !$m.whiteListed);
            ####################################################################
            # Note: Currently, the overriding of a virtual method will only be
            #       implemented if its parent virtual method is whitelisted
            ####################################################################

            next if !$m.isVirtual;

            # Don't look for an already found method
            next if %virtuals{$m.name}:exists;

            # The arguments of the method should only have whitelisted types
            for $m.arguments -> $a {
                my $qc = isQtClass($a);
                if ($qc) {
                    my $cc = %c{$qc};
                    next GVLOOP if !$cc.whiteListed || $cc.blackListed;
                }
            }
            # say "FOUND ", $m.name, " in class ", $className;

            # Method found: store it in the hash
            %virtuals{$m.name} = $className, $m;
        }

        # Try again with the parents of the current class
        for $cl.parents {
            gatherVirtuals($_);
        }
    }
}


