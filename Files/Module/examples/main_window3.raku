
# A digital clock

use Qt::QtWidgets;
use Qt::QtWidgets::QAction;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QBrush;
use Qt::QtWidgets::QColor;
use Qt::QtWidgets::QFont;
use Qt::QtWidgets::QLabel;
use Qt::QtWidgets::QMainWindow;
use Qt::QtWidgets::QMenu;
use Qt::QtWidgets::QPaintEvent;
use Qt::QtWidgets::QPainter;
use Qt::QtWidgets::QPen;
use Qt::QtWidgets::Qt;



# Center widget class subclassing QLabel

class ColoredLabel is QLabel {

    has Str $.text is rw;
    has QColor $.color is rw;

    submethod TWEAK {
        self.QLabel::subClass: $!text;
    }

    method paintEvent(QPaintEvent $ev)
    {
        say "label paint";
        my $painter = QPainter.new();
        $painter.begin(self);
        say $!color;
            $painter.setBrush: QBrush.new(QColor.new(Qt::yellow), Qt::SolidPattern);
            my $pen = QPen.new: QColor.new(Qt::black);
            $painter.setPen: $pen;
            $painter.drawText: $ev.rect, Qt::AlignCenter, $!text;
        $painter.end();
    }
}


# Objects creation
my $qApp = QApplication.new;

my $lab = ColoredLabel.new: text => "00-00-00",
                                    color => QColor.new: Qt::yellow;
$lab.show;


# Run the graphical application
$qApp.exec;





