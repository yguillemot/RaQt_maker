
use Test;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QLabel;

my $app = QApplication.new;

my $a = QLabel.new; 


$a.setText("Foo");
ok $a.text ~~ "Foo", "Text set to a first value";

$a.setText("Bar");
ok $a.text ~~ "Bar", "Text set to another value";

done-testing;
