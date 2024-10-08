
use Qt::QtWidgets;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QBrush;
use Qt::QtWidgets::QColor;
use Qt::QtWidgets::QLabel;
use Qt::QtWidgets::QPaintEvent;
use Qt::QtWidgets::QPainter;
use Qt::QtWidgets::QPen;
use Qt::QtWidgets::QSizePolicy;
use Qt::QtWidgets::QVBoxLayout;
use Qt::QtWidgets::QWidget;
use Qt::QtWidgets::Qt;




class coloredLabel is QLabel {

    has Str $.text = "";
    has Qt::GlobalColor $.color;

    submethod TWEAK { 
        # Initialize parent
        self.QLabel::subClass: $!text;
    }

    method paintEvent(QPaintEvent $ev)
    {
        my $painter = QPainter.new();
        $painter.begin(self);
            $painter.setBrush: QBrush.new: QColor.new($!color), Qt::SolidPattern;
            my $pen = QPen.new: QColor.new(Qt::black);
            $pen.setWidth(3);
            $painter.setPen: $pen;
            $painter.drawRect: 0, 0, $ev.rect.width, $ev.rect.height;
            $painter.drawText: $ev.rect, Qt::AlignCenter, $!text;
        $painter.end();
    }


}


# Objects creation
my $qApp = QApplication.new;
my $window = QWidget.new;          # main window
my $layout = QVBoxLayout.new;
$window.setLayout($layout);
$window.setWindowTitle("Test size policy");

#
#         Fixed => 0,
#         Minimum => 1,
#         Maximum => 4,
#         Preferred => 5,
#         MinimumExpanding => 3,
#         Expanding => 7,
#         Ignored => 13,
my $l0 = QLabel.new:   "Resize the main window to see\n"
                     ~ "the size policy effects";

my $l1 = coloredLabel.new: text => "Label default", color => Qt::yellow;

my $l2 = coloredLabel.new: text => "Fixed, Fixed", color => Qt::green;
$l2.setSizePolicy: QSizePolicy::Fixed, QSizePolicy::Fixed;

my $l3 = coloredLabel.new: text => "Minimum, Minimum", color => Qt::green;
$l3.setSizePolicy: QSizePolicy::Minimum, QSizePolicy::Minimum;

my $l4 = coloredLabel.new: text => "Maximum, Maximum", color => Qt::cyan;
$l4.setSizePolicy: QSizePolicy::Maximum, QSizePolicy::Maximum;

my $l5 = coloredLabel.new: text => "Preferred, Preferred", color => Qt::cyan;
$l5.setSizePolicy: QSizePolicy::Preferred, QSizePolicy::Preferred;

my $l6 = coloredLabel.new: text => "MinimumExpanding, MinimumExpanding", color => Qt::cyan;
$l6.setSizePolicy: QSizePolicy::MinimumExpanding, QSizePolicy::MinimumExpanding;

my $l7 = coloredLabel.new: text => "Expanding, Expanding", color => Qt::cyan;
$l7.setSizePolicy: QSizePolicy::Expanding, QSizePolicy::Expanding;



# Layout
$layout.addWidget($l0);
$layout.addWidget($l1);
$layout.addWidget($l2);
$layout.addWidget($l3);
$layout.addWidget($l4);
$layout.addWidget($l5);
$layout.addWidget($l6);
$layout.addWidget($l7);


# Show the main window
$window.show;

# Run the graphical application
my $status = $qApp.exec;
say "Returned status = $status";




