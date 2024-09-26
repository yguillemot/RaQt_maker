
use Qt::QtWidgets;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QBrush;
use Qt::QtWidgets::QColor;
use Qt::QtWidgets::QEvent;
use Qt::QtWidgets::QHBoxLayout;
use Qt::QtWidgets::QLabel;
use Qt::QtWidgets::QMouseEvent;
use Qt::QtWidgets::QPaintEvent;
use Qt::QtWidgets::QPainter;
use Qt::QtWidgets::QPoint;
use Qt::QtWidgets::QPen;
use Qt::QtWidgets::QTextEdit;
use Qt::QtWidgets::QVBoxLayout;
use Qt::QtWidgets::QWidget;
use Qt::QtWidgets::Qt;



# The main window is a QWidget gathering a QLabel used as a test field and
# a QTextEdit use to display the found events.
# This QLabel is subclassed to add it an event handler.


# The test field widget is a subclass of QLabel
class BlocA is QLabel {

    has $.parent;

    submethod TWEAK { 
        # Initialize parent
        self.QLabel::subClass($!parent);
        self.setFixedSize: 200, 200;
    }

    method paintEvent(QPaintEvent $ev)
    {
        my $painter = QPainter.new;
        $painter.begin(self);
            $painter.setBrush: QBrush.new: QColor.new(250,250,0,125), Qt::SolidPattern;
            my $pen = QPen.new: QColor.new(Qt::black);
            $pen.setWidth(3);
            $painter.setPen: $pen;
            $painter.drawRect: 0, 0, $ev.rect.width, $ev.rect.height;
            $pen.setWidth(1);
            $painter.setPen: $pen;
            $painter.drawRect: 50, 50, 5, 5;
        $painter.end();
    }
}

class BlocB is QLabel {

    has $.parent;

    submethod TWEAK {
        # Initialize parent
        self.QLabel::subClass($!parent);
        self.setFixedSize: 200, 200;
    }

    method paintEvent(QPaintEvent $ev)
    {
        my $painter = QPainter.new;
        $painter.begin(self);
            $painter.setBrush: QBrush.new: QColor.new(0,250,0,125), Qt::SolidPattern;
            my $pen = QPen.new: QColor.new(Qt::black);
            $pen.setWidth(3);
            $painter.setPen: $pen;
            $painter.drawRect: 0, 0, $ev.rect.width, $ev.rect.height;
            $pen.setWidth(1);
            $painter.setPen: $pen;
            $painter.drawRect: 50, 50, 5, 5;
        $painter.end();
    }
}




class GrosBloc is QWidget {

    submethod TWEAK {
        # Initialize parent
        self.QWidget::subClass;
        self.setFixedSize: 700, 300;
    }

    method paintEvent(QPaintEvent $ev)
    {
        my $painter = QPainter.new();
        $painter.begin(self);
            $painter.setBrush: QBrush.new: QColor.new(125,125,250,125), Qt::SolidPattern;
            my $pen = QPen.new: QColor.new(Qt::black);
            $pen.setWidth(3);
            $painter.setPen: $pen;
            # $painter.drawRect: 0, 0, $ev.rect.width, $ev.rect.height;
            $pen.setWidth(1);
            $painter.setPen: $pen;
            $painter.drawRect: 100, 100, 5, 5;
        $painter.end();
    }
}




# Objects creation
my $qApp = QApplication.new;
my $window = GrosBloc.new;          # main window
my $b1 = BlocA.new: parent => $window;
my $b2 = BlocB.new: parent => $window;



# Layout
my $layout = QHBoxLayout.new;
$layout.addWidget($b1);
$layout.addWidget($b2);

$window.setLayout($layout);

# Set up a first title and show the main window
$window.setWindowTitle("mapTo mapFrom test");
$window.show;

my $u = $b1.mapTo($window, QPoint(50, 59));
say "B1 : ", $u.x, ", ", $u.y;
my $v = $b2.mapTo($window, QPoint(50, 59));
say "B2 : ", $v.x, ", ", $v.y;

# Run the graphical application
my $status = $qApp.exec;
say "Returned status = $status";





