
use Qt::QtWidgets;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QBrush;
use Qt::QtWidgets::QColor;
use Qt::QtWidgets::QFont;
use Qt::QtWidgets::QGraphicsEllipseItem;
use Qt::QtWidgets::QGraphicsScene;
use Qt::QtWidgets::QGraphicsTextItem;
use Qt::QtWidgets::QGraphicsView;
use Qt::QtWidgets::QPen;
use Qt::QtWidgets::QTimer;
use Qt::QtWidgets::Qt;



class Sequencer is QtObject {
    has $.timer;
    has $.ellipse;
    has $.text;

    has $.x;
    has $.y;

    has $.ew;
    has $.eh;
    has ($.x1, $.x2, $.y1, $.y2);
    has ($.dx, $.dy);
    has Int $.count;

    submethod TWEAK
    {
        $!timer = QTimer.new;
        connect $!timer, "timeout", self, "update";

        $!dx = 1;
        $!dy = 1;
    }

    method start
    {
        $.timer.setInterval: 10;
        $.timer.start;
        $!count = 0;
    }

    method setScene(QGraphicsScene $s)
    {
        $!x1 = $s.sceneRect.x;
        $!x2 = $.x1 + $s.sceneRect.width;
        $!y1 = $s.sceneRect.y;
        $!y2 = $.y1 + $s.sceneRect.height;

        say "x1={$.x1}  x2={$.x2}  y1={$.y1}  y2={$.y2}";
    }

    method setObj(QGraphicsEllipseItem $e, QGraphicsTextItem $t)
    {
        $!ellipse = $e;
        $!text = $t;
        $!x = $e.x;
        $!y = $e.y;
        $!ew = $e.rect.width;
        $!eh = $e.rect.height;

        say "setObj: x=", $.x, " y=", $.y, "  w=", $.ew, " h=", $.eh;

        $!x2 -= $.ew;
        $!y2 -= $.eh;
    }

    method update is QtSlot
    {
        $!x += $.dx;
        $!y += $.dy;

        if $.x > $.x2 { $!dx = -$.dx; $!count++; }
        if $.x < $.x1 { $!dx = -$.dx; $!count++; }
        if $.y > $.y2 { $!dy = -$.dy; $!count++; }
        if $.y < $.y1 { $!dy = -$.dy; $!count++; }

        $.ellipse.setPos: $.x, $.y;
        $.text.setPlainText: ~$.count;
    }

}

my $qApp = QApplication.new("Essai graphics", @*ARGS);



my $scene = QGraphicsScene.new: 0, 0, 800, 400;

my $text = $scene.addText("Hello, world!");

my QFont $font = $text.font();

$font.setPointSize: 60;



$text.setFont: $font;

$text.setPos: 350, 120;   # !!!!!!!


# Create a pen with a color and a size
my QColor $fgc = QColor.new: Qt::blue;
say "DDD";

my QPen $pen = QPen.new: $fgc;
say "EEE";

$pen.setWidth: 2;

say "FFF";

# Create a brush with a color and a pattern
my QColor $bgc = QColor.new: Qt::yellow;
my QBrush $brush = QBrush.new: $bgc, Qt::SolidPattern;

my QGraphicsEllipseItem $ellipse
            = $scene.addEllipse: 0, 0, 20, 20, $pen, $brush;
$ellipse.setPos: 200, 200;

my QGraphicsView $view = QGraphicsView.new: $scene;
$view.show;

my Sequencer $s = Sequencer.new;

say "GGG";

$s.setScene: $scene;
$s.setObj: $ellipse, $text;
$s.start;

# Run the graphical application
$qApp.exec;



