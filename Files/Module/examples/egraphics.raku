
use Qt::QtWidgets;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QGraphicsScene;
use Qt::QtWidgets::QGraphicsView;



my $qApp = QApplication.new("Essai graphics", @*ARGS);


my $scene = QGraphicsScene.new;
$scene.addText("Hello, world!");

my $view = QGraphicsView.new($scene);
$view.show();

# Run the graphical application
$qApp.exec;

