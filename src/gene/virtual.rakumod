use gene::common;

# For all whitelisted class :
#    For each method, look if it overrides some of its ancestors' method
#    If yes: Set the current method's virtual flag if the overrided
#    method is virtual.
#
###############################################################################
# WARNING/TODO : Currently, the case of an overriding method with modified
#                default arguments values is not processed.
###############################################################################
#
# Loop on these actions until a cycle occurs without any more modification.
sub propagateVirtual(API $api) is export
{
    my $cycle2 = 0;
    OVRLOOP: loop {
        say "Cycle2 : ", ++$cycle2;
        my $modified = 0;

        # For each method, look if it overrides some
        # of its ancestors' virtual methods
        CLOOP: for $api.qclasses.kv -> $k, $v {
            next CLOOP unless $v.whiteListed;
            MLOOP: for $v.methods -> $m {
                next MLOOP if $m.blackListed || $m.isVirtual;

                for $v.ancestors -> $a {
                    for $api.qclasses{$a}.methods -> $am {

                        # If $am is whitelisted and virtual,
                        # does $m & $am have the same name and signature ?
                        if  $am.whiteListed && $am.isVirtual
                            && $am.name eq $m.name
                            && rSignature($am) eq rSignature($m) {

                            # If yes, $m have also to be virtual
                            $m.isVirtual = True;
                            # say "Virtual keyword propagated ",
                            #     "from ", $a, '::', $am.name,
                            #     " to ", $k, '::', $m.name;
                            $modified++;
                        }

                    }
                }

            }
        }
        last OVRLOOP if !$modified;
        say "Modified: ", $modified;
    }
}
