


use gene::common;


class filterActions is export {
#         method descr($/) { $/.make: $/; }
#         method rgdata($/) { $/.make: $/; }

    has Str $.input;
    has Int $.lastSuccessIndex;
    has Int $.aborted;
    has Str $.output;

    has Str $!currentNamespace;


    method success(Match $m)
    {
        $!lastSuccessIndex = $.lastSuccessIndex > $m.to
                                    ?? $.lastSuccessIndex !! $m.to;
    }

    method lastSuccessLine
    {
        $.input.substr(0, $.lastSuccessIndex).split("\n").elems;
    }

    method abort
    {
        # Only remember the first aborting place
        $!aborted = self.lastSuccessLine unless $.aborted;
    }

    method start($/)
    {
        $!aborted = 0;
        $!output = "";

        $!lastSuccessIndex = 0;
        $!input = $/.orig;
    }

    method TOP($/)
    {
            make $<groups>.made;
    }

    method groups($/)
    {
        make [~] $<group>>>.made;
    }

    method group($/)
    {
        if $<class> {
            make $<class>.made;
        } elsif $<namespace> {
            make $<namespace>.made;
        } else {
            make $<typedef>.made;
        }
    }






    method namespace($/)
    {

        if $<namespace_name>.made !~~ "Qt" {
            die "Only Qt namespace is allowed";
        }

        my $txt = "";

        # Empty namespaces are ignored
        if $<namespace_block>.made ne "" {

            # Replace namespace with a class
            $txt = 'class ' ~ $<namespace_name>.made ~ "\n";
            $txt ~= "\{\n";
            $txt ~= "public:\n";
            $txt ~= $<namespace_block>.made;
            $txt ~= "};\n\n";
        }

        make $txt;
        self.success($/);
    }

    method namespace_name($/)
    {
        $!currentNamespace = $<name>.made;
        make $<name>.made;
        self.success($/);
    }

    method namespace_block($/)
    {
        say 'Processing namespace "' ~ $!currentNamespace ~ '"';
        if $<namespace_member> {
            make [~] $<namespace_member>>>.made;
        } else {
            make "";
        }
        self.success($/);
    }

    method namespace_member($/)
    {
        my Str $out = "";

        if $<enum> {
            $out = $<enum>.made;
        } elsif $<typedef> {
            $out = $<typedef>.made;
        } else {

            # do nothing when :
            #    <method>
            #    <attribute>

        }

        make $out;
        self.success($/);
    }








    method class($/)
    {
        my $txt = 'class ' ~ $<className>.made ~ "\n";
        $txt ~= $<parents>.made if $<parents>;
        $txt ~= "\{\n";
        $txt ~= $<class_block>.made;
        $txt ~= "};\n\n";

        make $txt;
        self.success($/);
    }

    method className($/) {
    #     WARNING : This action method is directly implemented inside the
    #               className rule because the <name> token is captured in
    #               this rule and is no more usable here.

    #   say "METHOD CLASSNAME ", $*currentClass;
    }



    method parents($/)
    {
        make $/.Str;
        self.success($/);
    }

#     method other_parent($/)
#     {
#         self.success($/);
#     }
#
#     method parent($/)
#     {
#         self.success($/);
#     }



    method class_block($/)
    {
        make [~] $<class_member>>>.made;
        self.success($/);
    }


    method class_member($/)
    {
        my Str $out = "";

        if index($*subblocMode, "private") ~~ Nil {
            if $<access_specifier> {
                $out = $<access_specifier>.made;
            } elsif $<ctor> {
                $out = $<ctor>.made;
            } elsif $<method> {
                $out = $<method>.made;
            } elsif $<enum> {
                $out = $<enum>.made;
            } elsif $<typedef> {
                $out = $<typedef>.made;
            } else {

                # do nothing when :
                #    <dtor>
                #    <attribute>
                #    <friendClass>
                #    <operator>
                #    <struct>
                #    <union>
                #    <subclass>
                #    <template>
                #    <using>

            }
        }

        make $out;
        self.success($/);
    }


    method access_specifier($/)
    {
        $*subblocMode = $<access_mode>.made;
        make $*subblocMode ~ ":\n";
    }

    method access_mode($/)
    {
        make "\n" ~ $/.Str;
        self.success($/);
    }



    method ctor($/)
    {
        # say "\tCTOR ", $*currentClass, " : ", $*subblocMode;
        make $*currentClass ~ $<param_block>.made ~ ";\n";
    }

    method ctor_end($/)             # TODO
    {
        self.success($/);
    }

# rule ctor_prespecifier
# rule ctor_postspecifier
# token init


    method method($/)
    {
        # say "\tMETH ", $<name>.made, " : ", $*subblocMode;
        my $txt = $<mprespecifiers> ?? $<mprespecifiers>.made !! "";
        $txt ~= $<typename>.made ~ " " ~ $<name>.made
                                    ~ $<param_block>.made;
        $txt ~= " " ~ $<mpostspecifiers>.made if $<mpostspecifiers>;
        make $txt  ~ ";\n"; 
    }

    method mprespecifiers($/) {
        if $<prespecifier> {
            make [~] $<prespecifier>>>.made <<~>> " ";
        } else {
            make "";
        }
    }

    method mpostspecifiers($/) {
        make [~] $<postspecifier>>>.made <<~>> " ";
    }

    method method_end($/)
    {
        self.success($/);
    }


#
# rule dtor

    method dtor_end($/)
    {
        self.success($/);
    }

#
# rule operator
# rule equop
# rule thirdop
# rule otherop
# rule odeclaration
# rule oimplementation
#
    method enum($/) {
        my $name = $<name> ?? $<name>.made !! "";
        make "enum " ~ $name ~ " " ~ $<bracedblock>.made ~ ";\n\n";
        self.success($/);
    }

#
# rule attribute
# rule normal_attribute
# rule static_attribute
# rule multi_attribute
# rule othername
# rule bits
# rule static_attribute_initializer
#

method typedef($/) {
    if $<usualtypedef> {
        make $<usualtypedef>.made;
    } else {
        make "";        # Function ptr typedef are currently ignored
    }
}

method usualtypedef($/) {
    # typedefs marked as deprecated are currently ignored
    make $<deprecated> ?? "" !! $/.Str;
}

# rule functionptrtypedef


# rule friendClass
# rule cspecifier
# rule struct
# rule subclass
# rule subclass_def
# rule class_ref
# rule union
# rule var
# rule template
# rule timplementation
# rule tdeclaration
# rule using

    method param_block($/)
    {
        make $<parenthblock>.made;
        self.success($/);
    }




# token refmark
# token ptrmark
# rule eq_something



    method typename($/)
    {
        my $txt = $<tspecifiers>.made ~ " " if $<tspecifiers>;
        $txt ~= $<completetypename>.made;
        $txt ~= " " ~ $<typePostopB>.made if $<typePostopB>;
        $txt ~= " " ~ $<tpostspecifier>.made if $<tpostspecifier>;
        $txt ~= " " ~ $<typePostopA>.made if $<typePostopA>;
        make $txt;
        self.success($/);
    }

    method tspecifiers($/)
    {
        make $/.Str;
    }

    method completetypename($/)
    {
        make $/.Str;
    }


    method qualifiedname($/)
    {
        make $/.Str;
    }

#     rule complextypename
#     rule simpletypename

#    method tspecifier($/)

    method tpostspecifier($/)
    {
        make $/.Str;
    }

    method typePostopB($/)
    {
        make $/.Str;
    }

    method typePostopA($/)
    {
        make $/.Str;
    }

#    method typePostops($/)


# method typePostop($/)


    method prespecifier($/)
    {
        make $<prespecifiercore>.made;
    }

    method prespecifiercore($/)
    {
        given $/.Str {
            when 'virtual' { make $/.Str }
            when 'static' { make $/.Str }
            default { make "" }
        }
    }

    method postspecifier($/) {
        my $specifier = $/.Str.trim;
        given $specifier {
            when 'override' { make $specifier }
            when 'const' { make $specifier }
            # "noexcept" is ignored here
            default { make "" }
        }
    }

    method noexcept($/) {
        # Currently, "noexcept" is always ignored
        make "";
    }

    method value($/)
    {
        # say "VALUE : >", $/.Str, "<";
    }

# rule value_elem
# token quotedchar
# token numericalvalue
# rule functioncall
# rule expression
# token extended_value
# token __attribute__



    method bracedblock($/)
    {
        make $/.Str;
    }

# token bracedblockcore
# token b_bblock
# token a_bblock

method parenthblock($/)
{
    make $/.Str;
}

# token parenthblockcore
# token b_pblock
# token a_pblock

# Idem braced : angle

# Idem braced : square

#     token noangle
#     token nobrace
#     token noparenth
#     token nosquare

# token op


    method name($/)
    {
        make $/.Str;
    }

    method qualifiedName($/)
    {
        make $/.Str;
    }


# token number
# token hexnumber

}


