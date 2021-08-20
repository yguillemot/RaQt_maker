
# A demonstartion of various widgets

use Qt::QtWidgets;
use Qt::QtWidgets::QAbstractSlider;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QLabel;
use Qt::QtWidgets::QDial;
use Qt::QtWidgets::QSlider;
use Qt::QtWidgets::QVBoxLayout;
use Qt::QtWidgets::QWidget;
use Qt::QtWidgets::Qt;




# Objects creation

# Create the application object first
my $qApp = QApplication.new;

my $mainWindow = QWidget.new;
my $mainLayout = QVBoxLayout.new;
$mainWindow.setLayout: $mainLayout;

class Converter is QtObject
{
    has QLabel $.out;
    has QAbstractSlider $.in;
    
    submethod TWEAK
    {
        connect $!in, "valueChanged", self, "input"; 
        connect self, "output", $!out, "setText";
        self.input: $!in.value;  # Display an initial value
    }
    
    method input(Int $i) is QtSlot
    {
        self.output(~$i);
    }
    
    method output(Str $o) is QtSignal { ... }
}


my $s1 = QSlider.new;
my $l1 = QLabel.new;

my $font = $l1.font;
$font.setPointSize(20);
$l1.setFont($font);

$s1.setOrientation: Qt::Horizontal;

# Connect slider1 to label1 via a converter
my $c1 = Converter.new: in => $s1, out => $l1;

my $d2 = QDial.new;
my $l2 = QLabel.new;
$l2.setFont($font);

# Connect dial2 to label2 via a converter
my $c2 = Converter.new: in => $d2, out => $l2;

$mainLayout.addWidget($l1);
$mainLayout.addWidget($s1);
$mainLayout.addWidget($l2);
$mainLayout.addWidget($d2);

$mainWindow.show;


# Run the graphical application
$qApp.exec;





