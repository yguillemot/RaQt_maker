
# A demonstration of various widgets :
#           QSlider, QDial, QCheckBox and QRadioButton

use Qt::QtWidgets;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QCheckBox;
use Qt::QtWidgets::QDial;
use Qt::QtWidgets::QHBoxLayout;
use Qt::QtWidgets::QRadioButton;
use Qt::QtWidgets::QSlider;
use Qt::QtWidgets::QWidget;
use Qt::QtWidgets::Qt;




class Curseur is QSlider {

    submethod TWEAK {
        # Call the constructor of the parent QMainWindow
        self.QSlider::subClass;

        # Set orientation and size
        self.setOrientation: Qt::Horizontal;
        self.setMinimumWidth: 150;

        self.setSliderPosition: 50;

        connect self, "sliderMoved", self, "refresh";

        # Initialize the display
        self.refresh: 0;
    }

    method refresh(Int $v) is QtSlot {
        say "[", $v, "] Position is ", self.sliderPosition;
    }



    method start {
#         for %!commands.values -> $c {
#             connect $c, "clicked", self, "update";
#         }
#
#         self.update;
    }
}






# Create the application object first
my $qApp = QApplication.new;

# Create curseur
my $c0 = Curseur.new;


# Connect them
# my $cc0 = CondConnect.new: input => $s0, output => $di0, command => $cb0;


# Create layout
my $hl0 = QHBoxLayout.new;
$hl0.addWidget: $c0;



# Create a main window
# then run the application

my $mainWindow = QWidget.new;
$mainWindow.setLayout: $hl0;


# Make visible all the widgets
$mainWindow.show;

# Run the graphical application
$qApp.exec;





