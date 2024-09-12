
use Qt::QtWidgets;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QBrush;
use Qt::QtWidgets::QColor;
use Qt::QtWidgets::QHBoxLayout;
use Qt::QtWidgets::QLabel;
use Qt::QtWidgets::QPaintEvent;
use Qt::QtWidgets::QPainter;
use Qt::QtWidgets::QPen;
use Qt::QtWidgets::QPoint;
use Qt::QtWidgets::QTextEdit;
use Qt::QtWidgets::QWidget;
use Qt::QtWidgets::Qt;



class Bloc is QLabel {

    has $.name = "";

    has QWidget $.parent;
    has $.r is rw = 255;
    has $.g is rw = 255;
    has $.b is rw = 0;
    has $.alpha is rw = 128;
    has $.w = 100;
    has $.h = 100;
    has $.xb is rw = 50;
    has $.yb is rw = 50;

    submethod TWEAK { 
        # Initialize parent
        self.QWidget::subClass($!parent);
        self.setFixedSize: $!w, $!h;
    }

    method paintEvent(QPaintEvent $ev)
    {
        say $!name, " : paintEvent";
        my $painter = QPainter.new;
        $painter.begin(self);
            $painter.setBrush: QBrush.new: QColor.new($.r, $.g, $.b, $.alpha), Qt::SolidPattern;
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






# Objects creation
my $qApp = QApplication.new;
my $window = Bloc.new: name => "window", w => 500, h => 400;          # main window
# my $window = QWidget.new;

my $b1 = Bloc.new: name => "b1", parent => $window, r => 0, g => 255, b => 0, alpha => 120;
my $b2 = Bloc.new: name => "b2", parent => $window, r => 0, g => 0, b => 255, alpha => 120;



# Layout
my $layout = QHBoxLayout.new;
$layout.setContentsMargins(50, 50, 50, 50);
$layout.setSpacing(0);
$layout.addWidget($b1);
$layout.addWidget($b2);

$window.setLayout($layout);

# Set up a first title and show the main window
$window.setWindowTitle("mapTo mapFrom test");
$window.show;

say "MAPTO :";
my $u = $b1.mapTo($window, QPoint.new(50, 50));
say "B1 : ", $u.x, ", ", $u.y;
my $v = $b2.mapTo($window, QPoint.new(50, 50));
say "B2 : ", $v.x, ", ", $v.y;

say "MAPFROM :";
$u = $b1.mapFrom($window, QPoint.new(50, 50));
say "B1 : ", $u.x, ", ", $u.y;
$v = $b2.mapFrom($window, QPoint.new(50, 50));
say "B2 : ", $v.x, ", ", $v.y;

# $window.setVisible(False);
$layout.setContentsMargins(0, 0, 0, 0);
$layout.setSpacing(0);
$window.setLayout($layout);
$window.repaint;

say "MAPTO :";
$u = $b1.mapTo($window, QPoint.new(50, 50));
say "B1 : ", $u.x, ", ", $u.y;
$v = $b2.mapTo($window, QPoint.new(50, 50));
say "B2 : ", $v.x, ", ", $v.y;

say "MAPFROM :";
$u = $b1.mapFrom($window, QPoint.new(50, 50));
say "B1 : ", $u.x, ", ", $u.y;
$v = $b2.mapFrom($window, QPoint.new(50, 50));
say "B2 : ", $v.x, ", ", $v.y;


# $window.hide;
$layout.setContentsMargins(0, 0, 0, 0);
$layout.setSpacing(50);
$window.setLayout($layout);
$window.update;

say "MAPTO :";
$u = $b1.mapTo($window, QPoint.new(50, 50));
say "B1 : ", $u.x, ", ", $u.y;
$v = $b2.mapTo($window, QPoint.new(50, 50));
say "B2 : ", $v.x, ", ", $v.y;

say "MAPFROM :";
$u = $b1.mapFrom($window, QPoint.new(50, 50));
say "B1 : ", $u.x, ", ", $u.y;
$v = $b2.mapFrom($window, QPoint.new(50, 50));
say "B2 : ", $v.x, ", ", $v.y;



# Run the graphical application
my $status = $qApp.exec;
say "Returned status = $status";





