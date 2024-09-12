
use Qt::QtWidgets;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QBrush;
use Qt::QtWidgets::QColor;
use Qt::QtWidgets::QHBoxLayout;
use Qt::QtWidgets::QLabel;
use Qt::QtWidgets::QPaintEvent;
use Qt::QtWidgets::QPainter;
use Qt::QtWidgets::QPen;
use Qt::QtWidgets::QSizePolicy;
use Qt::QtWidgets::QVBoxLayout;
use Qt::QtWidgets::QWidget;
use Qt::QtWidgets::Qt;





class ColoredLabel is QLabel {

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


sub newLabel(QSizePolicy::Policy $h, QSizePolicy::Policy $v,
                        Qt::GlobalColor $c --> ColoredLabel)
{
    my $l = ColoredLabel.new: text => ($h ~ "," ~ $v),
                              color => $c;
   $l.setSizePolicy: $h, $v;

   $l.setMinimumWidth: 30;
   $l.setMaximumWidth: 100;

   return $l;
}



my $ll1 = ColoredLabel.new: text => "Label default", color => Qt::yellow;
my $lr1 = ColoredLabel.new: text => "Label default", color => Qt::yellow;

my $ll2 = newLabel QSizePolicy::Fixed, QSizePolicy::Fixed, Qt::green;
my $lr2 = newLabel QSizePolicy::Fixed, QSizePolicy::Fixed, Qt::green;

my $ll3 = newLabel QSizePolicy::Minimum, QSizePolicy::Minimum, Qt::green;
my $lr3 = newLabel QSizePolicy::Minimum, QSizePolicy::Minimum, Qt::green;

my $ll4 = newLabel QSizePolicy::Maximum, QSizePolicy::Maximum, Qt::cyan;
my $lr4 = newLabel QSizePolicy::Maximum, QSizePolicy::Maximum, Qt::cyan;

my $ll5 = newLabel QSizePolicy::Preferred, QSizePolicy::Preferred, Qt::cyan;
my $lr5 = newLabel QSizePolicy::Preferred, QSizePolicy::Preferred, Qt::cyan;

my $ll6 = newLabel QSizePolicy::MinimumExpanding, QSizePolicy::MinimumExpanding, Qt::cyan;
my $lr6 = newLabel QSizePolicy::Minimum, QSizePolicy::MinimumExpanding, Qt::cyan;

my $ll7 = newLabel QSizePolicy::Minimum, QSizePolicy::Expanding, Qt::cyan;
my $lr7 = newLabel QSizePolicy::Maximum, QSizePolicy::Expanding, Qt::cyan;



# Layout
my $hl1 = QHBoxLayout.new;
my $hl2 = QHBoxLayout.new;
my $hl3 = QHBoxLayout.new;
my $hl4 = QHBoxLayout.new;
my $hl5 = QHBoxLayout.new;
my $hl6 = QHBoxLayout.new;
my $hl7 = QHBoxLayout.new;

$hl1.addWidget: $ll1;
$hl1.addWidget: $lr1;
$hl2.addWidget: $ll2;
$hl2.addWidget: $lr2;
$hl3.addWidget: $ll3;
$hl3.addWidget: $lr3;
$hl4.addWidget: $ll4;
$hl4.addWidget: $lr4;
$hl5.addWidget: $ll5;
$hl5.addWidget: $lr5;
$hl6.addWidget: $ll6;
$hl6.addWidget: $lr6;
$hl7.addWidget: $ll7;
$hl7.addWidget: $lr7;

$layout.addWidget($l0);
$layout.addLayout($hl1);
$layout.addLayout($hl2);
$layout.addLayout($hl3);
$layout.addLayout($hl4);
$layout.addLayout($hl5);
$layout.addLayout($hl6);
$layout.addLayout($hl7);


# Show the main window
$window.show;

# Run the graphical application
my $status = $qApp.exec;
say "Returned status = $status";




