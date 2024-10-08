
use Qt::QtWidgets;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QBrush;
use Qt::QtWidgets::QColor;
use Qt::QtWidgets::QFont;
use Qt::QtWidgets::QGraphicsEllipseItem;
use Qt::QtWidgets::QGraphicsItem;
use Qt::QtWidgets::QGraphicsRectItem;
use Qt::QtWidgets::QGraphicsScene;
use Qt::QtWidgets::QGraphicsSimpleTextItem;
use Qt::QtWidgets::QGraphicsView;
use Qt::QtWidgets::QPen;
use Qt::QtWidgets::QRectF;
use Qt::QtWidgets::QTimer;
use Qt::QtWidgets::Qt;


# Size of the ground
constant W = 800;
constant H = 400;

# Margin (Don't start too close to the edges)
constant M = 150;

# Size of the objects
constant D = 20;

# Horizontal and vertical speed range (px/ms)
constant Vmin = 0.02;
constant Vmax = 0.20;

# Timer period (ms)
constant T = 10;


# Give a value with a random sign and a random module in the given range
sub randomSpeed { (-1,+1).pick * (Vmin + rand * (Vmax - Vmin)) }

# Give a random position inside margins
sub randomX { M + rand * (W - 2 * M) }
sub randomY { M + rand * (H - 2 * M) }

class Ground { ... }

role ColoredObject
{
    has QPen $.pen;
    has QBrush $.brush;

    method setupColor
    {
        self.gitem.setPen: $.pen with $.pen;
        self.gitem.setBrush: $.brush with $.brush;
    }
}

role FontedObject
{
    has QFont $.font is rw;
    has Int $.pointSize;

    method setupFont
    {
        with $.pointSize {
            $.font = self.gitem.font without $.font;
            $.font.setPointSize: $.pointSize ;
            self.gitem.setFont: $.font;
        }
    }
}


class MovingObject does ColoredObject does FontedObject
{
    has Ground $.ground is rw;
    has QGraphicsItem $.gitem;
    has Real ($.w, $.h);   # Item size

    has Real $.vx is rw;   # Speed
    has Real $.vy is rw;

    has QGraphicsSimpleTextItem $.speed;
    has QGraphicsSimpleTextItem $.coords;

    submethod TWEAK
    {
        self.setupColor;
        self.setupFont;

        $!w = $!gitem.boundingRect.width;
        $!h = $!gitem.boundingRect.height;

        self.setupMovingObject;

        $!ground.addItem: $!gitem;
        $!ground.mobjs.push: self;

        $!gitem.setPos: randomX, randomY;
    }

    method setupMovingObject
    {
        # Initialize speed at a random value
        $!vx = randomSpeed;
        $!vy = randomSpeed;

        # Create a child text object to show the speed
        $!speed = QGraphicsSimpleTextItem.new:
                            "{(1000 * sqrt($.vx**2 + $.vy**2)).Int} px/s";
        my $sh = $.speed.boundingRect.height;
        $.speed.setParentItem: $.gitem;
        $.speed.setPos: $.gitem.x, $.gitem.y + $.h;

        # Create a child text object to show the coordinates
        $!coords = QGraphicsSimpleTextItem.new;
        $.coords.setParentItem: $.gitem;
        $.coords.setPos: $.gitem.x, $.gitem.y + $.h + $sh;
    }

    method move  # Move after a timer periodl
    {
        # Compute and set new position
        my $x = $.gitem.x + T * $.vx;
        my $y = $.gitem.y + T * $.vy;
        $!gitem.setPos: $x, $y;

        # Show the current coordinates of the object
        $.coords.setText: "(" ~ $x.Int ~ ", " ~ $y.Int ~ ")";

        # Modify speed vector if borders of the ground have been reached
        $!vx = -$.vx unless $.ground.x1 < $x < $.ground.x2 - $.w;
        $!vy = -$.vy unless $.ground.y1 < $y < $.ground.y2 - $.h;
    }
}

class Ground is QGraphicsScene
{
    has Int ($.x1, $.x2, $.y1, $.y2);
    has @.mobjs;

    submethod TWEAK
    {
        self.QGraphicsScene::subClass: $!x1, $!y1, $!x2, $!y2;

        # Draw a border around the ground
        my QColor $fgc = QColor.new: Qt::red;
        my QPen $pen = QPen.new: $fgc;
        $pen.setWidth: 2;
        my QRectF $r = self.sceneRect;
        self.addLine: $r.left, $r.top, $r.right, $r.top, $pen;
        self.addLine: $r.left, $r.bottom, $r.right, $r.bottom, $pen;
        self.addLine: $r.left, $r.top, $r.left, $r.bottom, $pen;
        self.addLine: $r.right, $r.top, $r.right, $r.bottom, $pen;
    }

    method tick is QtSlot    # Timer input
    {
        @.mobjs>>.move;
    }

}





# Initialize the random number generator
srand now.Int;

my $qApp = QApplication.new("Moving objects example", @*ARGS);

# Create a ground
my $scene = Ground.new: x1 => 0, y1 => 0, x2 => W, y2 => H;

# Create a timer and connect it to the ground
my $timer = QTimer.new;
connect $timer, "timeout", $scene, "tick";

# Set refresh time interval
my $dt = T;
$timer.setInterval: T;

# Create the pen and brush needed to draw the graphical objects
my QColor $fgc = QColor.new: Qt::blue;
my QPen $pen = QPen.new: $fgc;
$pen.setWidth: 1;
my QColor $bgc = QColor.new: Qt::yellow;
my QBrush $brush = QBrush.new: $bgc, Qt::SolidPattern;


# Create graphical objects and place them on the ground

MovingObject.new:
    ground => $scene,
    gitem => QGraphicsEllipseItem.new(0, 0, D, D),
    pen => $pen,
    brush => $brush;

MovingObject.new:
    ground => $scene,
    gitem => QGraphicsRectItem.new(0, 0, D, D),
    pen => $pen,
    brush => $brush;

MovingObject.new:
    ground => $scene,
    gitem => QGraphicsSimpleTextItem.new("Hello !"),
    pen => $pen,
    brush => $brush,
    pointSize => 20;


# Show the ground
my QGraphicsView $view = QGraphicsView.new: $scene;
$view.setMinimumSize: W + 5, H + 5;   # Full ground always visible
$view.show;

# Start the timer
$timer.start;

# Run the graphical application
$qApp.exec;





