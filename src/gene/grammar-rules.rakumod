
#use Grammar::Debugger;

# use Grammar::Tracer;
# no precompilation;     # Work around 'Internal "Cannot invoke this object"
                         # error #42' when using Grammar::Tracer



grammar qtClasses is export {

    rule TOP {
        <start> <toplevels>
                # Rules include tailing spaces but not heading spaces
    }

    token start { <?> }

    rule toplevels { <toplevel>* }

    rule toplevel { 
    
        :my Str $*currentClass = "";       # Used to detect ctor and dtor
        
        <class> || <typedef> || <enum> }

    rule class {

        'class' <className> <parents>? '{' <class_bloc> '}' ';'
        
        {   
            # Exiting class
            $*currentClass = "";
        }
    }

    rule className {
        <name>
        {
            # Entering class
            $*currentClass = $<name>.made;
        }
    }

    rule parents { ':' <parent> <other_parent>*  }
    rule other_parent { ',' <parent> }
    rule parent { 'public' <qualifiedName> }


    rule class_bloc {

        :my Str $*subblocMode = 'private';

        <class_member>+
    }

    rule class_member {
            <access_specifier> | <ctor> | <method> | <enum> | <typedef>
    }


    ########################################################################
    # Access specifier : "public:", "private:", "slots:", "signals:", etc...

    rule access_specifier { <access_mode> ':' }

    token access_mode {
        'public' | 'protected' | 'public Q_SLOTS'
                | 'protected Q_SLOTS' | 'private Q_SLOTS' | 'Q_SIGNALS'
    }


    ########################################################################
    # Constructors :

    rule ctor {
         "$*currentClass" '(' <params> ')' ';'
    }


    ########################################################################
    # Methods :

    rule method {
        <prespecifier>? <typename>
        <name> '(' <params> ')' <postspecifier>* ';'
    }

    # A C++ method can't be simultaneously virtual and static
    rule prespecifier {
            'virtual' | 'static'
    }

    rule postspecifier { 'override' | 'const' }



    ########################################################################
    # Enums :

    rule enum { <enumstart> '{' <enumcore>? '}' ';' }

    rule enumstart { 'enum' <name>? }

    rule enumcore { <enumelem>+ %% ',' }

    rule enumelem { <name> ['=' <enumvalue>]? }

    rule enumvalue { <enum_expression> }


    ########################################################################
    # Typedefs :

    rule typedef { 'typedef' <typename> <name> <squareblock>? ';' }

    ########################################################################
    # Method parameters

    rule params { <first_param>? <next_param>* <dots_param>? }

    rule first_param { <param> }

    rule next_param { ',' <param> }

    rule dots_param { ',' '...' }


    rule param {
           <defaultedParameter>
        || <namedParam>
        || <defaultedUnnamedParameter>
        || <functionPointer>
        || <unnamedParam>
    }

    rule namedParam {
        <typename> <name>  <squareblock>*
    }

    rule unnamedParam { <typename> }

    rule functionPointer { <typename> '(' '*' <name> ')' <parenthblock> }

    rule defaultedParameter { <typename> <name> '=' <value> }

    rule defaultedUnnamedParameter { <typename> '=' <value> }


    token typename {
        <tspecifier>? <.ws> <completetypename>
                    <.ws> <typePostop>* <.ws>
                            <tpostspecifier>? <.ws> <typePostop>* <.ws>
    }



    rule completetypename { <simpletypename> || <complextypename> }
    token qualifiedname { [<name> ['::' <name>]*] || [<name>? ['::' <name>]+] }
    rule complextypename {
        || [<name> <angleblock> '::' <name>]
        || [<qualifiedname> <angleblock>?]
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
        || [ 'QPrivateSignal' ]
    }

    rule tspecifier { 'const' }
    rule tpostspecifier { 'const' }

    token typePostop { '&'+ | '*'+ }


    rule value {
            <expression> || <empty_list>
    }
    rule value_elem {
           <quotedchar>
        || <numericalvalue>
        || <functioncall>
        || <qualifiedname>
    }
    token quotedchar { '\'' . '\'' }
    token numericalvalue {    # TODO :  numericalvalue vs numericalValue !!!
        || <hexnumber> 
        || [ '-'? <floatingValue> ] 
        || [ '-'? <decnumber> ]
    }
    rule functioncall { <completetypename>? <parenthblock> }

    rule expression { <leftop>? <value_elem> [ <op> <expression> ]? }

    token extended_value { <[a..zA..Z_0..9\.\(\)|\<\>\&\:\=\+\-\?\*\\\'\ \~]>+ }

    token empty_list { '{' '}' }
    
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Arithmetic associated with the enum value

    rule enum_expression {
       <group15> [ '?' <group15> ':' <group15> ]?
    }

    rule group15 {
       <group12> [ <op12> <group12> ]*
    }

    token op12 { '|' }

    rule group12 {
       <group10> [ <op10> <group10> ]*
    }

    token op10 { '&' }

    rule group10 {
       <group9> [ <op9> <group9> ]?
    }

    token op9 { '==' || '!=' }

    rule group9 {
       <group7> [ <op7> <group7> ]?
    }

    token op7 { '<<' || '>>' }

    rule group7 {
       <group6> [ <op6> <group6> ]*
    }

    token op6 { '+' || '-' }

    rule group6 {
       <group5> [ <op5> <group5> ]*
    }

    token op5 { '*' || '/' }

    rule group5 {
        <op3>?  <group3>
    }

    token op3 { '+' || '-' || '!' || '~' }

    rule group3 {
        || 'int'? '(' <enum_expression> ')'
        || <numericalValue>
        || <qualifiedName> 
    }

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


    # Braced block with possible nested braced blocks
    token bracedblock { '{' <bracedblockcore> '}' }

    token bracedblockcore { || <b_bblock> || <nobrace> }

    token b_bblock { <a_bblock>+ <nobrace>? }

    token a_bblock {  <nobrace>? <bracedblock>  }

    ###############################

    # Parenthesized block with possible nested parenthesized blocks
    token parenthblock { '(' <parenthblockcore> ')' }

    token parenthblockcore { || <b_pblock> || <noparenth> }

    token b_pblock { <a_pblock>+ <noparenth>? }

    token a_pblock {  <noparenth>? <parenthblock>  }

    ###############################

    # Angle brackets block with possible other nested blocks
    token angleblock { '<' <angleblockcore> '>' }

    token angleblockcore { <b_ablock> || <noangle> }

    token b_ablock { <a_ablock>+ <noangle>? }

    token a_ablock {  <noangle>? <angleblock>  }

    ###############################

    # Square brackets block with possible other nested blocks
    token squareblock { '[' <squareblockcore> ']' }

    token squareblockcore { || <b_sblock> || <nosquare> }

    token b_sblock { <a_sblock>+ <nosquare>? }

    token a_sblock {  <nosquare>? <squareblock>  }


######################################################################


    token noangle { <-[<\>]>* }

    token nobrace { <-[{}]>* }

    token noparenth { <-[()]>* }

    token nosquare { <-[\[\]]>* }

    token op {
          '++' | '--' | '+=' | '-=' | '!=' | '==' | '<=' | '>=' | '[]'
        | '*=' | '/=' | '<<' | '>>' | '&=' | '^=' | '|=' | '()'
        | '~' | '>' | '<' | '+' | '-' | '*' | '/' | '=' | '!'
        | '|' | '&' | '^' | '?' | ':'
    }

    token leftop { '~' }

    token name {
        <[a..zA..Z_]> <[a..zA..Z_0..9]>*
      #  [<:alpha> | '_'] \w*
    }

    token qualifiedName { <name> ["::" <name>]* }

    token numericalValue { <floatingValue> || <integerValue> }
    
    token floatingValue { <simpleFloatingValue> 'f'? }
    
    token simpleFloatingValue { <decnumber> '.' <decnumber>? }
    
    token integerValue { <simpleIntegerValue> 'u'? }

    token simpleIntegerValue {
        <hexnumber> || <decnumber> 
    }

    token decnumber { \d+ }

    token hexnumber { '0' <[xX]> <xdigit>+ }

    token ws { <!ww> \s* 'Q_OBJECT'? \s* }

}

