#!/usr/bin/env raku


use gene::common;

# Various subroutines useful to examine the module load tree and
# to find out possible loops inside this tree

sub populateTree(API $api) is export {
    for $api.qclasses.keys.sort -> $k {
        my $obj = $api.qclasses{$k};
        next if !$obj.whiteListed || $obj.blackListed;
        for $obj.parents -> $p {
            $obj.needed{$p} = "UNDEFINED";
        }
    }
}

sub dumpRawTree(API $api, Str $f) is export {
    my Str $out = "";
    for $api.qclasses.keys.sort -> $k {
        my $obj = $api.qclasses{$k};
        next if !$obj.whiteListed || $obj.blackListed;
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
    my Bool $loop;
    my Str $objName;
    for $api.qclasses.keys -> $k {
        my $obj = $api.qclasses{$k};
        next if !$obj.whiteListed || $obj.blackListed;
        $loop = False;
        $objName = $k;
        clearFlags($api);
        goSearch($k);
        $api.qclasses{$k}.notInLoop = !$loop;
        # say $k, " <- ", !$loop;
    }

    sub goSearch($k1) {
        my $obj := $api.qclasses{$k1};
        return if $obj.flag;
        $obj.flag = True;
        for $obj.needed.keys -> $k2 {
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
        next if !$obj.whiteListed || $obj.blackListed;
        say "$k : ", $obj.needed;
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
        next if !$obj.whiteListed || $obj.blackListed;
        next unless $obj.notInLoop;
        for $obj.needed.keys.sort -> $k1 {
            # my $obj1 = $api.qclasses{$k1};
            # next if !$obj1.whiteListed || $obj1.blackListed;
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
        next if !$obj.whiteListed || $obj.blackListed;
        next if $obj.notInLoop;
        for $obj.needed.keys.sort -> $k1 {
            # my $obj1 = $api.qclasses{$k1};
            # next if !$obj1.whiteListed || $obj1.blackListed;
            $out ~= "\t" ~ $k ~ " -> " ~ $k1 ~ ";" ~ "\n";
        }
    }
    $out ~= '}' ~ "\n";
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

