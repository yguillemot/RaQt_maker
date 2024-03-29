
# This script replaces sizeof with numerical values
# in the Qt grouped header file

# Please, edit it and set appropriate values

my $txt = slurp;

# If system is 64 bits
$txt ~~ s/'sizeof(void *)'/8/;

# and int is kept to 32 bits (gcc/linux)
$txt ~~ s/'(std::numeric_limits<int>::min)()'/-2147483648/;

# Is this always true ?
$txt ~~ s/'sizeof(double)'/8/;

# If Qt compiled with qreal = double
$txt ~~ s/'sizeof(qreal)'/8/;

print $txt;

