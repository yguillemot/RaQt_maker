#!/usr/bin/env raku


use gene::common;

# Various subroutines useful to examine the module dependencies and
# to find out possible loops in modules loading

sub populateTree(API $api) is export {


    # Add special classes (for test and debug only) :
    $api.qclasses<QtHelpers> = Qclass.new:
                                 name => "QtHelpers",
                                 parents => < QAction QSize QRectF QWidget  >,
                                 children =>
                                 < QAction QLayout QWidget QtWrappers QSize QRectF QtBase >,
                                 whiteListed => False,
                                 blackListed => True,
                                 visible => True;

     $api.qclasses<QtWrappers> = Qclass.new:
                                 name => "QtWrappers",
                                 parents => < QtHelpers  >,
                                 children =>
                                 < QAction QLayout QWidget QSize QRectF >,
                                 whiteListed => False,
                                 blackListed => True,
                                 visible => True;

     $api.qclasses<QtBase> = Qclass.new:
                                 name => "QtBase",
                                 parents => < QtHelpers  >,
                                 children =>
                                 < QAction QWidget QSize QRectF >,
                                 whiteListed => False,
                                 blackListed => True,
                                 visible => True;

# Each QObj needs QtWidgets. So it's not added here because the resulting
# graph would too large to be useful.
#
#      $api.qclasses<QtWidgets> = Qclass.new:
#                                  name => "QtBase",
#                                  parents => < QtBase QtHelpers QtWrappers >,
#                                  children => < a lot ... >,
#                                  whiteListed => False,
#                                  blackListed => True,
#                                  visible => True;



    # Populate with parents classes
    for $api.qclasses.kv -> $k, $v {
        next if  !$v.visible && (!$v.whiteListed || $v.blackListed);
        for $v.parents -> $p {
            $v.needed{$p} = "UNDEFINED";
        }

        # All Qt classes depend on QtHelpers
        $v.needed<QtHelpers> = "UNDEFINED" unless $k eq "QtHelpers";
    }

    # For test and debug only:
    # QtBase and QtWrappers also depend on QtHelpers
#     say "XXXXXXX:";
#     say "Base: ", $api.qclasses<QtBase>;
#     say "Wrappers: ", $api.qclasses<QtWrappers>;
    $api.qclasses<QtBase>.needed<QtHelpers> = "UNDEFINED";
    $api.qclasses<QtWrappers>.needed<QtHelpers> = "UNDEFINED";
    $api.qclasses<QtHelpers>.needed<QRectF> = "UNDEFINED";
    $api.qclasses<QtHelpers>.needed<QSize> = "UNDEFINED";
    $api.qclasses<QtHelpers>.needed<QAction> = "UNDEFINED";


    # Add classes used in the arguments of the methods

    # Loop on classes
    CLOOP: for $api.qclasses.kv -> $k, $v {
        next CLOOP if !$v.visible && (!$v.whiteListed || $v.blackListed);

        # Loop on methods
        MLOOP: for $v.methods -> $m {
#             next MLOOP if $m.blackListed;
            next MLOOP if !$m.whiteListed || $m.blackListed;

            # Process returned type
            if $m.name ne "ctor" {
                if $m.returnType.ftot ~~ "CLASS" {
                    my Str $dep = $m.returnType.fbase;
                    # Does class exist ?   TODO : TEST VRAIMENT NECESSAIRE ???
                    if ($dep ne $k) and $api.qclasses{$dep}:exists {
                        $v.needed{$dep} = "UNDEFINED";
                    }
                }
            }

            # Process arguments types
            for $m.arguments -> $a {
                if $a.ftot ~~ "CLASS" {
                    my Str $dep = $a.fbase;
                    # Does class exist ?   TODO : TEST VRAIMENT NECESSAIRE ???
                    if ($dep ne $k) and $api.qclasses{$dep}:exists {
                        $v.needed{$dep} = "UNDEFINED";
                          # TODO : Not always "UNDEFINED" HERE !!!!!
                          # Look at possible default value
                    }
                }
            }
        }
    }

}

sub dumpRawTree(API $api, Str $f) is export {
    my Str $out = "";
    for $api.qclasses.keys.sort -> $k {
        my $obj = $api.qclasses{$k};
        next if !$obj.visible && (!$obj.whiteListed || $obj.blackListed);
        $out ~= $k ~ " : " ~ "\n";
        for $obj.needed.keys.sort -> $p {
            $out ~= "\t" ~ $p ~ "\n";
        }
    }
    spurt $f, $out;
}

sub clearFlags(API $api) is export {
    for $api.qclasses.keys -> $k {
        $api.qclasses{$k}.flag = False;
    }
}

sub lookForLoops(API $api) is export {
    say "LOOKFORLOOPS";
    my Bool $loop;
    my Str $objName;
    for $api.qclasses.kv -> $k, $v {
#     for "QGraphicsLayout", $api.qclasses<QGraphicsLayout> -> $k, $v {
        say "=== $k ===";
        say "visible=", $v.visible, " white=", $v.whiteListed, " black=", $v.blackListed;
        next if !$v.visible && (!$v.whiteListed || $v.blackListed);

        next if $v.inLoop;  # Already done

#         # Don't need to do more in such a case
#         if $v.parents.elems == 0 || $v.children.elems == 0 {
#             $v.inLoop = "NO";
#             say "--", "*" x 78;
#             say $k, " in loop : ", "NO";
#             next;
#         }

        $loop = False;
        $objName = $k;
        clearFlags($api);
        goSearch($k);
        $v.inLoop = "YES" if $loop;

        say "++", "*" x 78;
        say $k, " loop : ", $loop;
    }


    # Any class whose position is still undefined is not in a loop
    for $api.qclasses.kv -> $k, $v {
        $v.inLoop = "NO" unless $v.inLoop;
    }

    sub goSearch($k1) {
        # say "--- $k1 ---";
        my $obj := $api.qclasses{$k1};
        # say "needed : ", $obj.needed;
        my $oldFlag = $obj.flag;
        $obj.flag = True;
        return if $oldFlag;
        for $obj.needed.keys -> $k2 {
            # say "* $objName : $k1 : $k2";
            if $k2 ~~ $objName {
                $loop = True;
                return;
            }
            goSearch($k2);
        }
    }
}

sub makeDot(API $api, Str $f) is export {
    my Str $out = "";
    $out ~= 'digraph modules_tree {' ~ "\n";
    for $api.qclasses.keys.sort -> $k {
        my $obj = $api.qclasses{$k};
        next if !$obj.visible && (!$obj.whiteListed || $obj.blackListed);
        # say "$k : ", $obj.needed;
        for $obj.needed.keys.sort -> $k1 {
            # my $obj1 = $api.qclasses{$k1};
            # next if !$obj1.whiteListed || $obj1.blackListed;
            $out ~= "\t" ~ $k ~ " -> " ~ $k1 ~ ";" ~ "\n";
        }
    }
    $out ~= '}' ~ "\n";
    spurt $f, $out;
}

sub makeDot_OutOfLoops(API $api, Str $f) is export {
    my Str $out = "";
    $out ~= 'digraph modules_out_of_loops {' ~ "\n";
    for $api.qclasses.keys.sort -> $k {
        my $obj := $api.qclasses{$k};
        next if !$obj.visible && (!$obj.whiteListed || $obj.blackListed);
        next unless $obj.inLoop eq "NO";
        for $obj.needed.keys.sort -> $k1 {
            my $obj1 = $api.qclasses{$k1};
            # next if !$obj1.whiteListed || $obj1.blackListed;
            next unless $obj1.inLoop eq "NO";
            $out ~= "\t" ~ $k ~ " -> " ~ $k1 ~ ";" ~ "\n";
        }
    }
    $out ~= '}' ~ "\n";
    spurt $f, $out;
}

sub makeDot_InLoop(API $api, Str $f) is export {
    my Str $out = "";
    $out ~= 'digraph modules_in_loop {' ~ "\n";
    for $api.qclasses.keys.sort -> $k {
        my $obj := $api.qclasses{$k};
        next if !$obj.visible && (!$obj.whiteListed || $obj.blackListed);
        next if $obj.inLoop eq "NO";
        for $obj.needed.keys.sort -> $k1 {
            next if $api.qclasses{$k1}:!exists;
            my $obj1 = $api.qclasses{$k1};
            # next if !$obj1.whiteListed || $obj1.blackListed;
            next if $obj1.inLoop eq "NO";
            $out ~= "\t" ~ $k ~ " -> " ~ $k1 ~ ";" ~ "\n";
        }
    }
    $out ~= '}' ~ "\n";
    spurt $f, $out;
}



sub montrerEtat($api, Str $f) is export {
    my Str $out = "";

    for $api.qclasses.keys.sort -> $k {
        $out ~= "$k: ";
        my $obj := $api.qclasses{$k};
        $out ~= "v:" ~ ($obj.visible ?? 1 !! 0);
        $out ~= " w:" ~ ($obj.whiteListed ?? 1 !! 0);
        $out ~= " b:" ~ ($obj.blackListed ?? 1 !! 0);

        $out ~= " l:";
        if $obj.inLoop eq "NO" {
            $out ~= "0"
        } elsif $obj.inLoop eq "YES" {
            $out ~= "1"
        } else {
            $out ~= "?";
        }

        $out ~= ' [ ';
        $out ~= [~] $obj.needed.keys.sort <<~>> " ";
        $out ~= ' ]';

        $out ~= "\n";

#         for $obj.needed.keys.sort -> $k1 {
#             next if $api.qclasses{$k1}:!exists;
#             my $obj1 = $api.qclasses{$k1};
#             # next if !$obj1.whiteListed || $obj1.blackListed;
#             next if $obj1.notInLoop;
#             $out ~= "\t" ~ $k ~ " -> " ~ $k1 ~ ";" ~ "\n";
#         }

    }

    spurt $f, $out;
}



#     lookInDir $dirPath;
#     simplify;
#
#     lookForLoops;

#     makeDot($outName ~ "-all.dot");
#     makeDot_OutOfLoops($outName ~ "-outLoops.dot");
#     makeDot_InLoops($outName ~ "-inLoops.dot");
#     dump($outName ~ "-dump.txt");



# class Obj {
#     has Str $.name;
#     has SetHash $.links;
#     has Bool $.flag is rw;
#     has Bool $.notInLoop is rw;
#
#     submethod TWEAK {
#         $!links = SetHash.new;
#     }
# }
#
# my %ig;     # Input graph
# my %graph;
#
#
# sub lookInDir(Str $dir) {
#     for $dir.IO.dir: test => / '.rakumod' $/ -> $u {
#         lookInFile $u.Str;
#     }
# }
#
# sub lookInFile(Str $f) {
#     if $f ~~ m/ ('R'? 'Q') (\w+) '.rakumod' $ / {
#         # say $f, " : ", $0 ~ $1, " : ", 'Q' ~ $1;
#         my Str $object = 'Q' ~ $1;
#
#         my $text = slurp $f;
#         for $text.lines -> $l {
#             if $l ~~ m/ 'use' \s+ 'Qt::QtWidgets::' ('R'? 'Q') (\w+) ':ver' / {
#                 # say "\t", $0 ~ $1;
#                 # say "\t", $object, " -> ", 'Q' ~ $1, ';';
#                 %ig{$object}.push: 'Q' ~ $1;
#             }
#         }
#
#     } else {
#         # say "/* PROBLEME AVEC \"", $f, "\" */";
#     }
# }
#
# sub show {
#     for %ig.keys.sort -> $k {
#         say $k, " : ", %ig{$k};
#     }
# }
#
# sub simplify {
#     for %ig.keys -> $k {
#         %graph{$k} = Obj.new(name => $k) unless %graph{$k}:exists;
#         for  @(%ig{$k}) -> $k1 {
#             %graph{$k}.links.set: $k1 unless $k1 ~~ $k;   # no link to itself
#             %graph{$k1} = Obj.new(name => $k1.Str) unless %graph{$k1}:exists;
#         }
#     }
# }
#

#

#
#

#


# All whiteListed classes and methods should already be defined
sub lookForDependencies(API $api) is export {

    # Reset
    for $api.qclasses.kv -> $k, $v {
        next if  !$v.visible && (!$v.whiteListed || $v.blackListed);
        for $v.parents -> $p {
            $v.needed = ();
        }
    }


    # Populate with parents classes
    for $api.qclasses.kv -> $k, $v {
        next if  !$v.visible && (!$v.whiteListed || $v.blackListed);
        for $v.parents -> $p {
            $v.needed{$p} = "DIRECT";
        }
    }

    # Add classes used in the arguments of the methods

    # Loop on classes
    CLOOP: for $api.qclasses.kv -> $k, $v {
        next CLOOP if !$v.visible && (!$v.whiteListed || $v.blackListed);

        # Loop on methods
        MLOOP: for $v.methods -> $m {
#             next MLOOP if $m.blackListed;
            next MLOOP if !$m.whiteListed || $m.blackListed;

            # Process returned type
            if $m.name ne "ctor" {
                if $m.returnType.ftot ~~ "CLASS" {
                    my Str $dep = $m.returnType.fbase;
                    # Does class exist ?   TODO : TEST VRAIMENT NECESSAIRE ???
                    if ($dep ne $k) and $api.qclasses{$dep}:exists {
                        # Set as "ROLE" unless already "DIRECT"
                        $v.needed{$dep} = "ROLE" if $v.needed{$dep}:!exists;
                    }
                }
            }

            # Process arguments types
            for $m.arguments -> $a {
                if $a.ftot ~~ "CLASS" {
                    my Str $dep = $a.fbase;
                    # Does class exist ?   TODO : TEST VRAIMENT NECESSAIRE ???
                    if ($dep ne $k) and $api.qclasses{$dep}:exists {
                        # Does a default value exist ?
                        if $a.value {
                            $v.needed{$dep} = "DIRECT";
                        } else {
                            # Set as "ROLE" unless already "DIRECT"
                            $v.needed{$dep} = "ROLE" if $v.needed{$dep}:!exists;
                        }
                    }
                }
            }
        }
    }



}

