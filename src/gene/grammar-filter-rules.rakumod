
#use Grammar::Debugger;

# use Grammar::Tracer;
# no precompilation;     # Work around 'Internal "Cannot invoke this object"
                         # error #42' when using Grammar::Tracer



grammar letsgo is export {

    rule TOP {
        <start> <groups>
                # Rules include tailing spaces but not heading spaces
    }

    token start { <?> }

    rule groups { <group>* }

    rule group { <typedef> || <class> || <namespace> }




    rule namespace { 'namespace' <namespace_name> '{' <namespace_block> '}' }

    rule namespace_name { <name> }

    rule namespace_block { <namespace_member>* }

    rule namespace_member {
             <method> || <attribute> || <enum> ||
             <typedef> || <namespace_operator>
    }



    rule class {
        :my Str $*currentClass;

        'class' '__attribute__((visibility("default")))'
                        <className> <parents>? '{' <class_block> '}' ';'
    }
    

    rule className {
        (<qualifiedName>)
        {
            $*currentClass = ~$0;   # Remember to detect ctor and dtor
            make $*currentClass;    # Make here because name is captured
        }
    }

    rule parents { ':' <parent> <other_parent>*  }
    rule other_parent { ',' <parent> }
    rule parent { 'public' <qualifiedName> }


    rule class_block {

        :my Str $*subblocMode = 'private';

        {  say 'Processing class "' ~ $*currentClass ~ '"';
        }

        <class_member>+
    }

    rule class_member {
        || <access_specifier> 
        || <ctor> 
        || <dtor> 
        || <method> 
        || <attribute>
        || <enum> 
        || <friendClass> 
        || <class_operator> 
        || <typedef>
        || <struct> 
        || <union> 
        || <subclass> 
        || <template> 
        || <using>
        || <static_assert>
    }


    ########################################################################
    # Access specifier : "public:", "private:", "slots:", "signals:", etc...

    rule access_specifier { <access_mode> ':' }

    token access_mode { 
        || 'public Q_SLOTS' 
        || 'public' 
        || 'protected Q_SLOTS'
        || 'protected' 
        || 'private Q_SLOTS' 
        || 'private'
        || 'Q_SIGNALS'
    }


    ########################################################################
    # Constructors :

    rule ctor {
        <ctor_prespecifier>* "$*currentClass"
            <param_block> <ctor_postspecifier>?  <ctor_end>
        # { say " CTOR DECL $*currentClass"; }
    }


    # !!! Potential issue hacked by "<bracedblock>?" :
    #       cf. "constexpr QUuid()" in precompiled Qt input file
    rule ctor_end {
        [ <eq_something>? ';' ]
        || [ <init>? <bracedblock>? <bracedblock> ]
        # { say " CTOR IMPL $*currentClass"; }
    }

    rule ctor_prespecifier {
        'explicit' | 'constexpr' | 'inline' | <__attribute__>
    }

    rule ctor_postspecifier { <noexcept> }

    token init { ':' <nobrace> }

    ########################################################################
    # Methods :

    rule method {
        <mprespecifiers>? <typename> <__attribute__>?
        <name> <param_block>
        <postspecifier>* <refmark>? <__attribute__>? <method_end>
    }


    rule mprespecifiers { <prespecifier>* }

    rule method_end {
        [ <eq_something>? ';' ] || [ <bracedblock> ]
    }

    ########################################################################
    # Destructors :

    rule dtor {
        <dtor_prespecifier>*  "~$*currentClass" '(' ')' <postspecifier>?
        <dtor_end>

        # { say " DTOR D $*currentClass"; }
    }

    rule dtor_end {
        [ <eq_something>? ';' ] || <bracedblock>
        # { say " DTOR I $*currentClass"; }
    }

    rule dtor_prespecifier { 'inline' | 'virtual' }


    ########################################################################
    # Operators :

    rule class_operator { <eqop> | <otherop> | <thirdop> }
    
    rule namespace_operator { <otherop> | <thirdop> }

    rule eqop {
        "$*currentClass" '&' 'operator' '='
                    <parenthblock> <eq_something>? ';'
        # { say " EQ OP $*currentClass"; }
    }

    rule thirdop {
        'inline'? 'operator' 'const'? <name> <typePostop> '(' ')' 'const'? ';'
    }

    rule otherop { <odeclaration> | <oimplementation> }

    rule odeclaration {
            <prespecifier>* <typename>
            <__attribute__>? 'operator' <op>
            <parenthblock> <postspecifier>* <__attribute__>? ';'
    }

    rule oimplementation {
            <prespecifier>* <typename>
            <__attribute__>? 'operator' <op>
            <parenthblock> <postspecifier>*  <__attribute__>? <bracedblock>
    }


    ########################################################################
    # Enums :

    rule enum {
        'enum' <deprecated>? 'class'? <name>? <enum_type>? <bracedblock> ';'
    }
    
    rule enum_type { ':' <enum_used_type> }
    
    token enum_used_type { 'int' || 'quint8' || 'qint32' }


    ########################################################################
    # Various elements not needed but which have to be parsed

    rule attribute {
        || <normal_attribute>
        || <static_attribute>
        || <multi_attribute> 
        || <other_attribute>
    }

    rule normal_attribute {
        <typename> 'const'? <name> <squareblock>* <bits>? ';'
    }

    rule static_attribute {
        <deprecated>? <cspecifier>? <typename>
                <name>  <squareblock>* <bits>?
                            <static_attribute_initializer>? ';'
    }

    rule multi_attribute {
        <typename> <name> <othername>+ ';'
    }
    rule othername { ',' <ptrmark>? <name> }

    rule other_attribute {
        'static' 'constexpr' <__attribute__> <name> <name>
                                    <static_attribute_initializer>? ';'
    }

    rule bits { ':' <[0..9]>+ }

    rule static_attribute_initializer { '=' <init_value> }
    
    rule init_value { <extended_value> || <empty_block> }

    rule typedef { 
        || <usualtypedef> 
        || <functionptrtypedef> 
        || <specialtypedef>
    }
    
    rule usualtypedef { 'typedef' <deprecated>? <typename>
                                        <name> <squareblock>? ';' }
    rule functionptrtypedef {
        'typedef' <deprecated>? <typename>
            '(' [<name> '::']? '*' <name> ')' <parenthblock> ';'
    }
    
    rule specialtypedef {
        'typedef' <typename> <name> <__attribute__> ';'
    }

    rule friendClass {
            [ 'friend' 'class' (<qualifiedname>) ';' ]
        | [ 'friend' 'struct' (<name>) ';' ]
        | [ 'friend' (<completetypename>) ';' ]
        # { say " FRIEND : $0 : $1 :"; }
    }

    rule cspecifier { 'static' || 'const' }

    rule struct { <cspecifier>* 'struct'
                    <__attribute__>? <name> <bracedblock>? <var>? ';'
    }

    rule subclass { <subclass_def> | <class_ref> }

    rule subclass_def {
        <cspecifier>* 'class'
            <__attribute__>? <name>
                <parents>? <bracedblock> <var>? ';'
    }

    rule class_ref { 'class' <name>  <var> ';' }


    rule union {
        <cspecifier>* 'union'
            <__attribute__>? <name>? <bracedblock> <var>? ';'
    }

    rule var { <typePostop>? <name> }

    rule template { <tdeclaration> | <timplementation> }
    rule timplementation { 'template' '<' <-[{]>+ <bracedblock> ';'? }
    rule tdeclaration { 'template' <angleblock> <-[{}]>+ ';' }

    rule using { 'using' <qualifiedname> ';' }
    
    rule static_assert { 'static_assert' <parenthblock> ';' }


    ########################################################################
    # Method parameters

    rule param_block { <parenthblock> }

    token refmark { '&'+ }
    token ptrmark { '*'+ }

    rule eq_something { '=' [ 'delete' | 'default' | '0' ] }

    token typename {
        <tspecifiers> <ws> <completetypename>
                    <ws> <typePostopB>? <ws>
                            <tpostspecifier>? <ws> <typePostopA>? <ws>
        # { say "TYPE_NAME >", ~$/, '<'; }
    }

    rule tspecifiers { <tspecifier>* }

    rule completetypename { <simpletypename> || <complextypename> }
    token qualifiedname { [<name> ['::' <name>]*] || [<name>? ['::' <name>]+] }
    rule complextypename {
        || [<name> <angleblock> '::' <name>]
        || [<qualifiedname> <angleblock>?]
        || [<qualifiedname> <squareblock>?]
    }
    rule simpletypename {
        || [ 'long' 'unsigned' 'int' ]
        || [ 'unsigned' 'int' ]
        || [ 'unsigned' 'char' ]
        || [ 'unsigned' 'short' 'int' ]
        || [ 'unsigned' 'short' ]
        || [ 'unsigned' 'long' 'int' ]
        || [ 'unsigned' 'long' 'long' ]
        || [ 'unsigned' 'long' ]
        || [ 'signed' 'char' ]
        || [ 'long' 'int' ]
        || [ 'long' 'long' ]
        || [ 'int' ]
        || [ 'char' ]
        || [ 'short' 'int' ]
        || [ 'short' ]
        || [ 'long' ]
        || [ 'unsigned' ]
        || [ 'struct' <name> ]
        || [ 'decltype' '(' <name> ')' ]
    }

    rule tspecifier { 'const' | 'mutable' }
    rule tpostspecifier { 'const' }

    rule typePostopB { <typePostops> }

    rule typePostopA { <typePostops> }

    rule typePostops { <typePostop>* }

    token typePostop { '&'+ | '*'+ }

    rule prespecifier { <prespecifiercore> }

    token prespecifiercore {
        || 'virtual' 
        || 'static' 
        || 'inline' 
        || '[[nodiscard]]' 
        || 'constexpr' 
        || 'friend' 
        || <deprecated> 
        || <__attribute__>
    }

    rule postspecifier { 'override' | 'const' | <noexcept> }

    rule noexcept { [ 'noexcept' <parenthblock> ] | 'noexcept' }


    rule value {
            <expression>
    }
    rule value_elem {
            <quotedchar>
        || <numericalvalue>
        || <functioncall>
        || <qualifiedname>
    }
    token quotedchar { '\'' . '\'' }
    token numericalvalue {
            <hexnumber> || [ '-'? <number> [ '.' <number> ]? ]
    }
    rule functioncall { <completetypename>? <parenthblock> }

    rule expression { <value_elem> [ <op> <expression> ]? }

    token extended_value { <[a..zA..Z_0..9\.\(\)|\<\>\&\:\=\+\-\?\*\\\'\ \~]>+ }

    rule empty_block { '{' '}' }

    token __attribute__ {
        '__attribute__' <.ws> '(' <parenthblock> ')'
        # { say "__ATTRIB >", ~$/, "<"; }
    }

    rule deprecated {
        '__attribute__' '((' '__deprecated__' <deprecation_text>? '))'
    }


    rule deprecation_text { '(' <text_block> ')' }

    ##############################

    # Any text between double quotes 
    token text_block { '"' <-["]>* '"' }

    ###############################

    # Braced block with possible nested braced blocks
    token bracedblock { '{' <bracedblockcore> '}' }

    token bracedblockcore { <nobrace> | <b_bblock> }

    token b_bblock { <a_bblock>+ <nobrace>? }

    token a_bblock {  <nobrace>? <bracedblock>  }

    ###############################

    # Parenthesized block with possible nested parenthesized blocks
    token parenthblock { '(' <parenthblockcore> ')' }

    token parenthblockcore { <noparenth> | <b_pblock> }

    token b_pblock { <a_pblock>+ <noparenth>? }

    token a_pblock {  <noparenth>? <parenthblock>  }

    ###############################

    # Angle brackets block with possible other nested blocks
    token angleblock { '<' <angleblockcore> '>' }

    token angleblockcore { <noangle> | <b_ablock> }

    token b_ablock { <a_ablock>+ <noangle>? }

    token a_ablock {  <noangle>? <angleblock>  }

    ###############################

    # Square brackets block with possible other nested blocks
    token squareblock { '[' <squareblockcore> ']' }

    token squareblockcore { <nosquare> | <b_sblock> }

    token b_sblock { <a_sblock>+ <nosquare>? }

    token a_sblock {  <nosquare>? <squareblock>  }


######################################################################


    token noangle { <-[<>]>* }

    token nobrace { <-[{}]>* }

    token noparenth { <-[()]>* }

    token nosquare { <-[\[\]]>* }

    token op {
          '++' | '--' | '+=' | '-=' | '!=' | '==' | '<=' | '>=' | '[]'
        | '*=' | '/=' | '<<' | '>>' | '&=' | '^=' | '|=' | '()'
        | '~' | '>' | '<' | '+' | '-' | '*' | '/' | '=' | '!'
        | '|' | '&' | '^'
    }

    token name {
        <[a..zA..Z_]> <[a..zA..Z_0..9]>*
    }

    token qualifiedName { <name> ["::" <name>]* }

    token number { <[0..9]>+ }

    token hexnumber { '0' <[xX]> <[0..9a..fA..F]>+ }

    token ws { <!ww> \s* 'Q_OBJECT'? \s* }

}

