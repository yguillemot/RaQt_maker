
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

# Speed range (px/ms)
constant Vmin = 0.02;
constant Vmax = 0.20;

# Timer period (ms)
constant T = 10;

class MObject is QtObject
{
    has QGraphicsItem $.item;
    has Real ($.w, $.h);   # Item size

    has Real $.vx is rw;   # Speed
    has Real $.vy is rw;

    has QGraphicsScene $.scene;

    has QGraphicsSimpleTextItem $.speed;
    has QGraphicsSimpleTextItem $.coords;

    method setGround(QGraphicsScene $scene;)
    {
        $!scene = $scene;
        $scene.addItem: $!item;

        # Create a child text object to show the speed
        $!speed = QGraphicsSimpleTextItem.new:
                            "{sqrt($.vx**2 + $.vy**2).round(0.01)} px/ms";
        my $sh = $.speed.boundingRect.height;
        $.speed.setParentItem: $.item;
        $.speed.setPos: $.item.x, $.item.y + $.h;

        # Create a child text object to show the coordinates
        $!coords = QGraphicsSimpleTextItem.new;
        $.coords.setParentItem: $.item;
        $.coords.setPos: $.item.x, $.item.y + $.h + $sh;
    }

    method move is QtSlot  # Move after a timer periodl
    {
        # Compute and set new position
        my $x = $!item.x + T * $.vx;
        my $y = $!item.y + T * $.vy;
        $!item.setPos: $x, $y;

        # Show the current coordinates of the object
        $.coords.setText: "(" ~ $x.Int ~ ", " ~ $y.Int ~ ")";

        # Modify speed vector if borders of the ground have been reached
        $!vx = -$.vx unless $.scene.x1 < $x < $.scene.x2 - $.w;
        $!vy = -$.vy unless $.scene.y1 < $y < $.scene.y2 - $.h;
    }
}

class Ground is QGraphicsScene
{
    has Int ($.x1, $.x2, $.y1, $.y2);
    has QPen $.pen;

    has @.mobjs;

    submethod TWEAK
    {
        self.QGraphicsScene::subClass: $!x1, $!y1, $!x2, $!y2;
        my QRectF $r = self.sceneRect;
        self.addLine: $r.left, $r.top, $r.right, $r.top, $!pen;
        self.addLine: $r.left, $r.bottom, $r.right, $r.bottom, $!pen;
        self.addLine: $r.left, $r.top, $r.left, $r.bottom, $!pen;
        self.addLine: $r.right, $r.top, $r.right, $r.bottom, $!pen;
    }

    method tick is QtSignal { ... }     # Timer input


    method addMobj(MObject $mobj)
    {
        $mobj.setGround: self;
        $mobj.item.setPos: randomX, randomY;
        connect self, "tick", $mobj, "move";
        @!mobjs.push($mobj);
    }


}

# Give a value with a random sign and a random module in the given range
sub randomSpeed { (-1,+1).pick * (Vmin + rand * (Vmax - Vmin)) }

# Give a random position inside margins
sub randomX { M + rand * (W - 2 * M) }
sub randomY { M + rand * (H - 2 * M) }


# Initialize the random number generator
srand now.Int;

my $qApp = QApplication.new("Moving objects example", @*ARGS);

# Create a pen
my QColor $fgc = QColor.new: Qt::blue;
my QPen $pen = QPen.new: $fgc;
$pen.setWidth: 2;

# Create a brush
my QColor $bgc = QColor.new: Qt::yellow;
my QBrush $brush = QBrush.new: $bgc, Qt::SolidPattern;

# Create a ground
my $scene = Ground.new: x1 => 0, y1 => 0, x2 => W, y2 => H, pen => $pen;

# Create a timer and connect it to the ground
my $timer = QTimer.new;
connect $timer, "timeout", $scene, "tick";

# Set refresh time interval
my $dt = T;
$timer.setInterval: T;

# Create graphical objects and place them on the ground
my MObject $m;
my QGraphicsItem $o;

$o = QGraphicsEllipseItem.new: 0, 0, 20, 20;
$o.setPen: $pen;
$o.setBrush: $brush;
$m = MObject.new: item => $o,
                  vx => randomSpeed,
                  vy => randomSpeed,
                  dt => $dt,
                  w => 20, h => 20,    # Graphic object size
                  pen => $pen, brush => $brush;
$scene.addMobj: $m;


$o = QGraphicsRectItem.new: 0, 0, 20, 20;
$o.setPen: $pen;
$o.setBrush: $brush;
$m = MObject.new: item => $o,
                  vx => randomSpeed,
                  vy => randomSpeed,
                  dt => $dt,
                  w => 20, h => 20,    # Graphic object size
                  pen => $pen, brush => $brush;
$scene.addMobj: $m;

$o = QGraphicsSimpleTextItem.new: "Hello !";
$pen.setWidth: 1;
$o.setPen: $pen;
$o.setBrush: $brush;
my QFont $f = $o.font();
$f.setPointSize: 20;
$o.setFont: $f;
my QRectF $r = $o.boundingRect;
$m = MObject.new: item => $o,
                  vx => randomSpeed,
                  vy => randomSpeed,
                  dt => $dt,
                  w => $r.width, h => $r.height,  # Graphic object size
                  pen => $pen, brush => $brush;
$scene.addMobj: $m;



# Show the ground
my QGraphicsView $view = QGraphicsView.new: $scene;
$view.setMinimumSize: W + 5, H + 5;   # Full ground always visible
$view.show;

# Start the timer
$timer.start;

# Run the graphical application
$qApp.exec;





