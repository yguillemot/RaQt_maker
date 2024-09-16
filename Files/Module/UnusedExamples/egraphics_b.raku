
use Qt::QtWidgets;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QBrush;
use Qt::QtWidgets::QColor;
use Qt::QtWidgets::QGraphicsScene;
use Qt::QtWidgets::QGraphicsView;
use Qt::QtWidgets::QPen;
use Qt::QtWidgets::Qt;


class World is QtObject {
    has $.i;
    has $.e;
    has $.t;
    method init
    {
        my $scene = QGraphicsScene.new(0, 0, 400, 200);
        $!t = $scene.addText("Hello, world!");

        # Create a pen with a color and a size
        my $fgc = QColor.new(Qt::blue);
        my $pen = QPen.new($fgc);
        $pen.setWidth(2);

        # Create a brush with a color and a pattern
        my $bgc = QColor.new(Qt::yellow);
        my $brush = QBrush.new($bgc, Qt::SolidPattern);

        $!e = $scene.addEllipse(0, 0, 20, 20, $pen, $brush);

        my $view = QGraphicsView.new($scene);
        $view.show();

        $!i = 0;
    }

    method go is QtSlot
    {
        $.t.setPlainText(DateTime.new(now).local.hh-mm-ss);
        $.e.setPos(4*$.i, 2*$.i);
        $!i = $.i == 100 ?? 0 !! $.i+1;
    }
}

class Tempo is QtObject {
    method finish is QtSignal { ... }
    method travail {
        start {
            loop {
                sleep 0.01;
                self.finish;
            }
        }
    }
}

my $qApp = QApplication.new("Essai graphics", @*ARGS);

my $w = World.new;
my $t = Tempo.new;
connect $t, "finish", $w, "go";

$w.init;

$t.travail;


# start {
#     loop {
#         sleep 0.2;
#         # $text.setPlainText(DateTime.new(now).local.hh-mm-ss);
#         # $ellipse.setPos(4*$i, 2*$i);
#         $i = $i == 100 ?? 0 !! $i+1;
#     }
# }




# Run the graphical application
$qApp.exec;

