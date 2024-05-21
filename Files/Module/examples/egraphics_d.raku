
use Qt::QtWidgets;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QBrush;
use Qt::QtWidgets::QColor;
use Qt::QtWidgets::QGraphicsEllipseItem;
use Qt::QtWidgets::QGraphicsScene;
use Qt::QtWidgets::QGraphicsView;
use Qt::QtWidgets::QPen;
use Qt::QtWidgets::QRectF;
use Qt::QtWidgets::QTimer;
use Qt::QtWidgets::Qt;



class Marble is QtObject
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
    has QGraphicsEllipseItem $.ellipse;
    has QGraphicsScene $.scene;

    has Real ($!x1, $!x2, $!y1, $!y2);

#     submethod TWEAK
#     {
#     }

    method setGround(QGraphicsScene $scene;)
    {
        $!scene = $scene;
        my QRectF $r = $scene.sceneRect;
        # Add or remove R to get limits coordinates of the center of the marble
        $!x1 = $r.left + R;
        $!x2 = $r.right - R;
        $!y1 = $r.top + R;
        $!y2 = $r.bottom - R;

        $scene.addLine: $r.left, $r.top, $r.right, $r.top, $!pen;
        $scene.addLine: $r.left, $r.bottom, $r.right, $r.bottom, $!pen;
        $scene.addLine: $r.left, $r.top, $r.left, $r.bottom, $!pen;
        $scene.addLine: $r.right, $r.top, $r.right, $r.bottom, $!pen;


        $!ellipse = $scene.addEllipse: -R, -R, 2 * R, 2 * R, $!pen, $!brush;
        $!ellipse.setPos: 200, 200;
    }

    method move is QtSlot  # Move after a refresh interval
    {
        # Compute and set new position
        $!x += $.dt * $.vx;
        $!y += $.dt * $.vy;
        $!ellipse.setPos: $.x, $.y;

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
                         vx => 0.1, vy => 0.1,
                         pen => $pen, brush => $brush;

# Place it on the ground
$marble.setGround: $scene;


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





