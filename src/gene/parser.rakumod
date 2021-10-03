
#use Grammar::Debugger;

# use Grammar::Tracer;
# no precompilation;     # Work around 'Internal "Cannot invoke this object"
                         # error #42' when using Grammar::Tracer

use gene::grammar-rules;
use gene::grammar-actions;
use gene::common;



#|( Parse an API description file and return its content
    as an API object.
)
sub parser(Str $fileName --> API) is export
{
    # Read the full file
    my $file = $fileName.IO.slurp;

    # Remove the comments
    $file ~~ s:g/\#.*?$$//;   # '?' means frugal match

    my $actions = qtClassesActions.new;
    my $match = qtClasses.parse($file, :actions($actions));


    say "";

    if !$match {
        say "Can't parse successfuly near line ", $actions.lastSuccessLine, " !";
        exit;
    }
    if $actions.aborted {
        say "Can't parse successfuly near line ", $actions.aborted, " !";
        exit;
    }

    say '';
    say "Parsing done";
    
    my %c = $match.made.qclasses;


    # Add a number to disambiguate methods sharing the same name
    for %c.kv -> $k, $v {
        my Function $prev = (Function);
        for $v.methods.sort: *.name -> $m {
            if $prev {
                if $prev.name ~~ $m.name {
                    if $prev.number {
                        $m.number = $prev.number + 1;
                    } else {
                        $prev.number = 1;
                        $m.number = 2;
                    }
                }
            }
            $prev = $m;
        }
    }
    
    # When an argument of a signal has the type QPrivateSignal
    # remove this argument and mark the signal as private
    for %c.kv -> $k, $v {
        for $v.methods -> $m {
            next if !$m.isSignal;
            
            my Argument  @a1 = ();
            for $m.arguments -> $a {
                if $a.base ~~ "QPrivateSignal" {
                    $m.isPrivateSignal = True;
                } else {
                    @a1.push($a);
                }
            }
            $m.arguments = @a1;
        }
    }

    # Build in each class a list of ancestors
    # (i.e. parents, parents of parents, etc...)
    #
    #   Note : This list should already have been built by grammar_actions.
    #          Nevertheless, when working on partial data while debugging,
    #          this list is sometimes incomplete.
    #          That's why it's build here again.
    #
    for %c.kv -> $k, $v {     # Walk through all the classes
        my @a = ();   # Accumulator
        lookForAncestors($v);
        $v.ancestors = (set @a).keys;   # Remove doubles and store in target

        # Recursive subroutine used hereabove.
        # @a is used to accumulate the ancestors
        sub lookForAncestors($cl) {
            for $cl.parents -> $p {
                @a.push($p);
                if %c{$p}:exists {
                    lookForAncestors(%c{$p});
                }
            }
        }
    }



    # Look for children and descendants

    my List @notFound = ();

    # Populate the children lists
    for %c.kv -> $k, $v {
        for $v.parents -> $p {
            if %c{$p}:exists {
                push %c{$p}.children, $k;
            } else {
                say "Parent $p of class $k is not in the class list";
                push @notFound, ($p, $k);
            }
        }
    }

    if @notFound.elems {
        say "Following classes are undefined :";
        for @notFound -> $x { say "\t$x[0] parent of $x[1]"; }
    }

    # Populate the descendants lists
    for %c.kv -> $k, $v {
        for $v.ancestors -> $p {
            if %c{$p}:exists {
                push %c{$p}.descendants, $k;
            }
        }
    }

    # Remove doubles (if any) in the lists of descendants
    for %c.kv -> $k, $v {
        if $v.descendants.elems {
            my $a = set $v.descendants;
            $v.descendants = $a.keys;
        }
    }




### There is no more "generic classes" in the current RaQt implementation
###
#     # Walk through all the classes looking for the generic ones
#     for %c.kv -> $k, $v {
#
#         if $v.generic {
#             # Generic class found : set its name as the generic one for
#             # all its children until a new generic class is   found
#             $v.genericName = $k;
#             for $v.children -> $ch {
#                 setupGenericName($ch, $k);
#             }
#         }
#
#         # Recursive subroutine used hereabove
#         sub setupGenericName(Str $child, Str $name)
#         {
#             my $cl = %c{$child};
#             return if $cl.generic;
#             $cl.genericName = $name;
#             for $cl.children -> $child2 {
#                 setupGenericName($child2, $name);
#             }
#         }
#
#     }


    # Originally, the $.isQObj bit of each class sould have came from
    # the Q_OBJECT macro still present in the main.E file.
    # For some reason, this had not been done and the $.isQObj bit
    # is set for each class which descents from QObject.

    # Set all $.isQObj bits :

    # Step 1 : reset all the bits
    for %c.kv -> $k, $v { $v.isQObj = False }

    # Step 2 : set up the bits
    if %c{"QObject"}:exists {
        my $qo = %c{"QObject"};
        $qo.isQObj = True;
        for $qo.descendants -> $od {
            if %c{$od}:exists {
                %c{$od}.isQObj = True;
            }
        }
    } else {
        note "WARNING : class \"QObject\" not found";
    }


    # Follow typedefs
    
    # Top level typedefs
    my %t = $match.made.topTypedefs;
    for %t.kv -> $t, $v {
        # say "TYPEDEF1 ", $v.srcClass, "::", $v.name, " : ", $v.type.str;
        $v.lookForFinalType($match.made);    
        # say "          ", $v.fClass, ":: : ", $v.type.str, " is ", $v.typeOfType;
    }
    
    # Other typedefs
    for $match.made.qclasses.kv -> $className, $class {
        for $class.typedefs.kv -> $t, $v {
            # say "TYPEDEF2 ", $v.srcClass, "::", $v.name, " : ", $v.type.str;
            $v.lookForFinalType($match.made);    
            # say "          ", $v.fClass, ":: : ",
            #                     $v.type.str, " is ", $v.typeOfType;
        }
    }


    # Walk through all methods of all classes and look for the final
    # types of each argument
    for %c.kv -> $k, $v {
        for $v.methods -> $m {
            $m.setupFinalTypes($match.made, $k);
        }
    }






    # Sort classes in disconnected groups then levels inside each groups.
    # Groups names are only used to differentiate groups.
    # Similarly, absolute values of levels are insignificant; relative
    # values only matter.

    # Start anywhere then call a recursive sub
    # (sort is called to always process classes in the same order and always
    # get the same groups and levels when running the script several times)
    for %c.sort>>.kv -> ($k, $v) {
        if !$v.group {
            setupGroup($v, $k, 0);
        }
    }

    # The recursive sub
    sub setupGroup(Qclass $v, Str $group, int $level)
    {
        # Do nothing if group is already set
        return if $v.group;

        # say "setupGroup ", $v.name, " ($group, $level)";

        # else setup group and level
        $v.group = $group;
        $v.level = $level;

        # then setup group and level for all parents
        my $newLevel = $level - 1;
        for $v.parents -> $p {
            next if %c{$p}:!exists;
            setupGroup(%c{$p}, $group, $newLevel);
        }
        # then setup group and level for all children
        $newLevel = $level + 1;
        for $v.children -> $ch {
            next if %c{$ch}:!exists;
            setupGroup(%c{$ch}, $group, $newLevel);
        }
    }


    # We need that the group containing the QObject class comes after
    # all the other groups. So we give to it a name coming at the end of
    # the alphabetical order.
    if %c{"QObject"}:exists {
        my $QObjectGroup = %c{"QObject"}.group;
        for %c.values -> $v {
            $v.group = "zzzzz" if $v.group eq $QObjectGroup;
        }
    }


    # The Qt pseudo class is a namespace where enums are defined.
    # It must be defined before all classes to avoid "Invalid typename" errors.
    # For this purpose we give it a group name coming at the beginning of
    # the alphabetical order.
    %c{"Qt"}.group = "A";
        # We are presuming here that :
        #      -1) "Qt" (pseudo)class exists
        #      -2) "Qt" is alone in its group
        #      -3) No "A" group already exists
        # This should always be the case.

    # return API.new(qclasses => %c);    # , types => %t);
    return $match.made;
}


