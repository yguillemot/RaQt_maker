
use Test;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QSize;

my $app = QApplication.new;

my $a = QSize.new(19, 34); 
ok $a.width == 19, "Initial width";
ok $a.height == 34, "Initial height";

$a.setWidth(254);
$a.setHeight(98);
ok $a.width == 254, "Set width";
ok $a.height == 98, "Set height";

my $b = QSize.new;
ok $b.isEmpty, "Is empty";

$b.setWidth(0);
ok !$b.isValid, "Is not valid";

$b.setHeight(0);
ok $b.isValid, "Is valid";
ok $b.isNull, "Is null";

$b.setWidth(24);
$b.setHeight(42);
ok $b.isValid, "Is still valid";
ok !$b.isNull, "Is no more null";
ok $b.width == 24, "Set another width";
ok $b.height == 42, "Set another height";


my $c = $b.boundedTo($a);
ok      $c.width == 24
    &&  $c.height == 42,
                    "Bounded to";

my $d = $b.expandedTo($a);
ok      $d.width == 254
    &&  $d.height == 98,
                    "Expanded to";

                    
done-testing;
 