# use Grammar::Tracer;
# no precompilation;

if @*ARGS.elems == 0 {
    say "Syntaxe : ", $*PROGRAM-NAME, " description_API.txt [options]\n";
    say "(No option is currently defined)";
    exit;
}

my ($fileName, @options) = @*ARGS;

# Read the full file
my $file = $fileName.IO.slurp;




# Remove the comments
$file ~~ s:g/\#.*?$$//;   # '?' means frugal match
#say $file;



#########################
#exit;


grammar onyva {

     # Rules include tailing spaces but not heading spaces ???
     
    token TOP {
        <?> <space>* <basetop>+ <space>*
    }
    
    rule basetop { <typedeftop> || <groupetop> || <nobracetop> }

    rule typedeftop { 'typedef' <nobracesc> ';' }
    
    rule groupetop {  <classe> || <namespace> || <groupetopa> }

    rule groupetopa { <nobracesc> <groupe> ';'? }
    
    rule nobracetop { <nobracesc> ';' }
    
    rule classe { <space>* 'class __attribute__((visibility("default")))'
                                             <name> <parents>? <groupe> ';' }

    rule parents { ':' <parent> <other_parent>*  }
    rule other_parent { ',' <parent> }
    rule parent { 'public' <name> }
    
    
    rule namespace { 'namespace' <basename> <groupe> }

    token base { <groupea>+ <nobrace>? }
    
    token nobrace { <-[{}]>* }
    
    token nobracesc { <-[{};]>* }   # no brace and no semicolon

    token groupea {  <nobrace>? <groupe>  }
    
    token groupe { '{' <groupecore> '}' }

    token groupecore { <nobrace> | <base> }

    token name { <basename> [ '::' <basename> ]* }

    token basename { <[a..zA..Z_]> <[a..zA..Z_0..9]>* }
}

my $out = "";
my $liste = "";
my $arbo = "";
my $rejected = "";

class onyvaActions { 


    method typedeftop($/)
    {
#         say "TYPEDEF \"", $<nobracesc>.Str, '"';
        $out ~=  "typedef " ~ $<nobracesc>.Str ~ ";\n"
    }

#     method groupetopa($/) {
#         say "============================================";
#         say "--- Groupetopa -----------------------------";
#         say $/.Str;
#         say "============================================";
#     }

    method classe($/)
	{
        # We don't want to automatically include to the API such classes
        if ?index($<name>.made, "::") {
            $rejected ~= $<name>.made ~ "\n";
            return;
        }

        $out ~= $/ ~ "\n";
        $liste ~= $<name>.made;
        
        if $<parents> {
            $liste ~= " :";
            for $<parents>.made {
                $liste ~= " " ~ $_;
            }
        }
        $liste ~= "\n";
           
        if $<parents> {
            for $<parents>.made {
                $arbo ~= $<name>.made ~ " -> " ~ $_ ~ "\n";
            }
        } else {
            $arbo ~= $<name>.made ~ "\n";
        }
	}
	
    method parent($/)
	{
        make $<name>.made;
	}
	
    method parents($/)
	{
        my @p = ();
        @p.push($<parent>.made);
        for $<other_parent> -> $x {
            @p.push($x.made);
        }
        make @p;
	}
	
    method other_parent($/)
	{
        make $<parent>.made;
	}

	method namespace ($/)
	{
        # Only Qt namespace is kept
        if $<basename>.made ~~ "Qt" {
            $out ~= $/ ~ "\n";
        }
	}

    method name($/)
    {
        make $/.Str;
    }

    method basename($/)
    {
        make $/.Str;
    }
}

my $match = onyva.parse($file, :actions(onyvaActions.new));



if $match !~~ Nil {
    say "Parse succeeded";
} else {
    say "Parse failed !";
}


spurt "out.txt", $out;
spurt "liste.txt", $liste;
spurt "arbo.txt", $arbo;
spurt "rejected.txt", $rejected;


