
use Test;
use Qt::QtWidgets::QRect;
use Qt::QtWidgets::QPoint;


my ($x, $y, $w, $h) = 10, 22, 33, 55;
my $a = QRect.new($x, $y, $w, $h);

ok $a.x == $x,             "x from ctor 1";
ok $a.y == $y,             "y from ctor 1";
ok $a.width == $w,         "width from ctor 1";
ok $a.height == $h,        "height from ctor 1";


my ($x1, $y1, $x2, $y2) = 109, 108, 207, 206;
my $p1 = QPoint.new($x1, $y1);
my $p2 = QPoint.new($x2, $y2);
my $b = QRect.new($p1, $p2);

ok $b.x == $x1,                 "x from ctor 2";
ok $b.y == $y1,                 "x from ctor 2";
ok $b.width == $x2 - $x1 + 1,   "width from ctor 2";
ok $b.height == $y2 - $y1 + 1,  "height from ctor 2";
# Width and height: "+1" for "historical reasons" (cf. Qt documentation)


done-testing;
