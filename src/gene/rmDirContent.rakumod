
# Recursively delete the content of the specified directory

sub rmDirContent($dirName) is hidden-from-backtrace is export {
    my @d = dir($dirName);
    for @d -> $f {
        if $f.IO.d {
            rmDirContent $f;
            failed $f unless rmdir $f;
        } else {
            failed $f unless unlink $f;
        }
    }
    
    sub failed($f) is hidden-from-backtrace {
        die "Can't delete $f";
    }
}

