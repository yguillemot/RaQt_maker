
use Test;
use Qt::QtWidgets::QRectF;
use Qt::QtWidgets::QPointF;

constant ε = 1e-10;

my ($x, $y, $w, $h) = 10.1, 22.3, 33.3, 55.4;
my $a = QRectF.new($x, $y, $w, $h);

ok $a.x == $x,             "x from ctor 1";
ok $a.y == $y,             "y from ctor 1";
ok $a.width == $w,         "width from ctor 1";
ok $a.height == $h,        "height from ctor 1";


my ($x1, $y1, $x2, $y2) = 109.9, 108.8, 207.7, 206.6;
my $p1 = QPointF.new($x1, $y1);
my $p2 = QPointF.new($x2, $y2);
my $b = QRectF.new($p1, $p2);

ok $b.x == $x1,                 "x from ctor 2";
ok $b.y == $y1,                 "x from ctor 2";

ok $x2 - $x1 - ε < $b.width < $x2 - $x1 + ε,   "width from ctor 2";
ok $y2 - $y1 - ε < $b.height < $y2 - $y1 + ε,  "height from ctor 2";

ok $b.bottomLeft.x == $x1,      "x from bottomLeft";
ok $b.bottomLeft.y == $y2,      "y from bottomLeft";

done-testing;
