
use lib <.>;

use gene::config;
use gene::common;
use gene::parser;
use gene::natives;
use gene::blackAndWhite;
use gene::output;
use gene::exceptions;

use gene::cpp_generator;
use gene::hpp_generator;
use gene::h_generator;
use gene::rakumod_generator;
use gene::doc_generator;

# Choice of classes, methods and enums is driven by black and white lists.
# The black list always has precedence over the white list.

sub MAIN ( #| C++ filtered header to read
           Str $fileName,
           #| Only whitelisted methods will be generated
           Bool :$strict,
           #| Validate the generation process
           Bool :$generate,
           #| Keep the placeholder marks from templates to generated files
           Bool :$keepMarks,
           #| Validate the output of a list of types
           Bool :$show-types,
           #| Loop interactively to find out what classes/methods to implement
           Bool :$interactive,
           #| Create QtObjs.lst and QtOthers.lst lists of classes (info only)
           Bool :$list-classes,
           #| Display the list of classes with groups and levels
           Bool :$show-groups,
           #| Count and display how many types are defined in the Qt source.
           #| Print out this types in List_xxx.txt files.
           Bool :$count-types
         )
{
    my $okToGenerate = $generate;

    my API $api = parser($fileName);


    # Create two lists of Qt classes :
    #   - one of classes which are QObject
    #   - one of classes which are not
    if $list-classes {
        my @qtobjs = ();
        my @qtothers = ();

        for $api.qclasses.kv -> $k, $v {
            # say $k, " :", [~] (" " <<~>> $v.parents);

            if $v.isQObj {
                @qtobjs.push($k);
            } else {
                @qtothers.push($k);
            }
        }

        my Str $out = [~] @qtobjs.sort <<~>> "\n";
        spurt "QtObjs.lst", $out;

        $out = [~] @qtothers.sort <<~>> "\n";
        spurt "QtOthers.lst", $out;
    }

    if $show-groups {
    # Print out classes and groups
        say "\n\n===   CLASSES AND GROUPS   ===";
        for $api.qclasses.keys.sort:
            { ($api.qclasses{$^a}.group => $api.qclasses{$^a}.level)
                cmp  ($api.qclasses{$^b}.group => $api.qclasses{$^b}.level)
            } -> $k, {
                say $k, " : ", $api.qclasses{$k}.group,
                                    " ", $api.qclasses{$k}.level;
        }
        say "=== END OF CLASSES AND GROUPS ===\n\n";
    }


    ##########################################################################
    # Walk through all used types and sort them in types of types
    say "count-types : ", ?$count-types;
    if $count-types {
        say "";
        say "";
        say "Count types used by methods";
        countTypesOfTypes($api);
    }


    ##########################################################################
    # Creation of the api.lst file
    say "Creation of the api.lst file";
    dump_api($api, "api.lst");
    say "";
    say "";


    ##########################################################################
    # (Interactive) loop for extracting what to generate from black/white lists
    BWLOOP: loop {
        say "Reset colors";
        resetColors($api);

        say "Propagate black and white list in the whole API";
        computeBlackAndWhiteObjects(
            api => $api, strict => $strict,
            blackList => $iBlackList, whiteList => $iWhiteList,
        );

        markEnums($api);
        
        say "Output white, black, gray, colorless and KO classes in separate files";
        outputFinal(
            api => $api,
            oBlackList => $oBlackList, oWhiteList => $oWhiteList,
            oGrayList => $oGrayList, oColorlessList => $oColorlessList
        );

        say 'Output results in "synthese.txt"';
        writeSynthesis($api, "synthese.txt");

        last unless $interactive;

        loop {
            say "";
            say "Look at BlackList.output, WhiteList.output, GrayList.output";
            say "and ColorlessList.output";
            say "If needed, modify BlackList.input and/or WhiteList.input";
            say "Then enter :";
            say '    A : to compute again the black and white flags in the API';
            say '    Q : to give up and exit immediately';
            say '    G : to start generating the code';
            say "";

            my $cmd = prompt("? : ").trim.uc;

            given $cmd {
                when "A" { next BWLOOP }
                when "G" { $okToGenerate = True; last BWLOOP }
                when "Q" { exit }
            }
        }
    }

    say "";
    say "show-types : ", ?$show-types;
    say "";

    if $show-types {
        show_types($api);

        say "";
        say "---------------------------";
        show_types_2($api);
        say "";
    }


    if !$okToGenerate {
        say "";
        say "--generate not specified on the command line => No code generation";
    } else {
        # Process generation

        # Read the exceptions
        say "Reading exceptions...";
        my %excpt = read_exceptions("gene/Exceptions");

#         # Only for test
#         for %excpt.sort>>.kv -> ($k, $v) {
#             for $v.sort>>.kv -> ($k2, $v2) {
# #                 say "";
# #                 say '%' x 70;
#                 say '*** EXCEPT ', $k, " : ", $k2;
# #                 say $v2;
#             }
#         }

        say "Generating...";
        say "";

        # Prepare places where raku modules will go
        mkdir $LibDirectory;
        mkdir $LibSubDirectory;

        # hpp_generator must called first because it creates
        # the list of callbacks %cb the other generators use

        my %cb = hpp_generator($api, %excpt, $keepMarks);

        h_generator($api, %excpt, %cb, $keepMarks);

        raku_generator(:$api, exceptions => %excpt, callbacks => %cb,
                       mainModName => "$LibDirectory/$mainRakuFile",
                       nativesModName => "$LibSubDirectory/$wrappersRakuFile",
                       helpersModName => "$LibSubDirectory/$helpersRakuFile",
                       km => $keepMarks);

        cpp_generator($api, %excpt, %cb, $keepMarks);

        doc_generator(:$api, exceptions => %excpt);
        
        # TEST ONLY
        use gene::test_str;
        say '###';
        test_str(api => $api, exceptions => %excpt);
    }
    
    
#     # Only for test
#     say "";
#     say "---";
#     for $api.qclasses.sort>>.kv -> ($k, $v) {
#         say "class $k ",
#             ($v.blackListed ?? "B" !! ""),
#             ($v.whiteListed ?? "W" !! "");
#         for $v.enums.sort>>.kv -> ($n, $e) {
#             say "enum $n ",
#                 ($e.blackListed ?? "B" !! ""),
#                 ($e.whiteListed ?? "W" !! "");
#         }
#     }


#     # Only for test : printout all the Qt virtual methods from all the classes
#     my @out = ();
#     for $api.qclasses.sort>>.kv -> ($k, $v) {
#         for $v.methods -> $m {
#             if $m.isVirtual {
#                 my Str $out = $m.name ~ qSignature($m) ~ ' --> ' ~ qRet($m);
#                 $out ~= "\t\t" ~ $k;
#                 @out.push($out);
#             }
#         }
#     }
#     my Str $virtuals = [~] @out.sort <<~>> "\n";
#     spurt "virtuals.txt", $virtuals;


} # End of sub MAIN
