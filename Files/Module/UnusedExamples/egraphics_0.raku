
use Qt::QtWidgets;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QBrush;
use Qt::QtWidgets::QColor;
use Qt::QtWidgets::QGraphicsScene;
use Qt::QtWidgets::QGraphicsView;
use Qt::QtWidgets::QPen;
use Qt::QtWidgets::Qt;



my $qApp = QApplication.new("Essai graphics", @*ARGS);


my $scene = QGraphicsScene.new;
$scene.addText("Hello, world!");

# Create a pen with a color and a size
my $fgc = QColor.new(Qt::blue);
my $pen = QPen.new($fgc);
$pen.setWidth(2);

# Create a brush with a color and a pattern
my $bgc = QColor.new(Qt::yellow);
my $brush = QBrush.new($bgc, Qt::SolidPattern);

$scene.addEllipse(10, 10, 20, 20, $pen, $brush);

my $view = QGraphicsView.new($scene);
$view.show();

# Run the graphical application
$qApp.exec;

