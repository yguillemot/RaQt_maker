
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


class Marble is QGraphicsEllipseItem
{
    my constant R = 10;   # Radius of the marble

    has Real $.x is rw;    # Position
    has Real $.y is rw;

    has Real $.vx is rw;   # Speed
    has Real $.vy is rw;

    has Real $.dt is rw;   # Refresh time interval

    has Bool $.showV is rw = False;     # Show speed vector

    has QPen $.pen;
    has QBrush $.brush;

    has Real ($!x1, $!x2, $!y1, $!y2);

    submethod TWEAK
    {
        self.QGraphicsEllipseItem::subclass(R, R, 2 * R, 2 * R, $!pen, $!brush);
    }

    method setGround(Num $x1, Num $x2, Num $y1, Num $y2)
    {
        # Add or remove R to get limits coordinates of the center of the marble
        $!x1 = $x1 + R;
        $!x2 = $x2 - R;
        $!y1 = $y1 + R;
        $!y2 = $y2 - R;

        self.setPos: 200, 200;
    }

    method move is QtSlot  # Move after a refresh interval
    {
        # Compute and set new position
        $!x += $.dt * $.vx;
        $!y += $.dt * $.vy;
        self.setPos: $.x, $.y;

        # Modify speed vector if borders of the ground have been reached
        $!vx = -$.vx unless $!x1 < $.x < $!x2;
        $!vy = -$.vy unless $!y1 < $.y < $!y2;
    }
}



my $qApp = QApplication.new("Essai graphics", @*ARGS);

# Create a pen
my QColor $fgc = QColor.new: Qt::blue;
my QPen $pen = QPen.new: $fgc;
$pen.setWidth: 2;

# Create a brush
my QColor $bgc = QColor.new: Qt::yellow;
my QBrush $brush = QBrush.new: $bgc, Qt::SolidPattern;

# Create a ground
my $scene = QGraphicsScene.new: 0, 0, 800, 400;

# Create a marble
my $marble = Marble.new: x => 400, y=> 200,
                         vx => 1, vy => 1,
                         pen => $pen, brush => $brush;

# Place it on the ground
$marble.setGround: 0, 800, 0, 400;
$scene.addItem: $marble;

# Show the ground
my QGraphicsView $view = QGraphicsView.new: $scene;
$view.show;

# Create a timer and connect it to the marble
my $timer = QTimer.new;
connect $timer, "timeout", $marble, "move";

# Set refresh time interval (ms)
$timer.setInterval: 10;
$marble.dt = 10;

# Start the timer
$timer.start;

# Run the graphical application
$qApp.exec;





