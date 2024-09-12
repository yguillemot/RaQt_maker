
# A digital clock

use Qt::QtWidgets;
use Qt::QtWidgets::QAction;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QBrush;
use Qt::QtWidgets::QColor;
use Qt::QtWidgets::QFont;
use Qt::QtWidgets::QLabel;
use Qt::QtWidgets::QMainWindow;
use Qt::QtWidgets::QMenu;
use Qt::QtWidgets::QPaintEvent;
use Qt::QtWidgets::QPainter;
use Qt::QtWidgets::QPen;
use Qt::QtWidgets::Qt;



# Center widget class subclassing QLabel

class ColoredLabel is QLabel {

    has Str $.text is rw;
    has QColor $.color is rw;

    submethod TWEAK {
        self.QLabel::subClass: $!text;
        $!color = QColor.new(Qt::yellow);
    }

    method paintEvent(QPaintEvent $ev)
    {
        say "label paint";
        my $painter = QPainter.new();
        $painter.begin(self);
        say $!color;
            $painter.setBrush: QBrush.new(QColor.new(Qt::yellow), Qt::SolidPattern);
            $painter.drawRect: 0, 0, $ev.rect.width, $ev.rect.height;
            my $pen = QPen.new: QColor.new(Qt::black);
            $painter.setPen: $pen;
            $painter.drawText: $ev.rect, Qt::AlignCenter, $!text;
        $painter.end();
    }
}



# Main window class subclassing QMainWindow

class MainWindow is QMainWindow {

    has ColoredLabel $.label;
    has QFont $.labelFont;
    has QMenu $.sizeMenu;
    has QMenu $.colorMenu;
    has QLabel $.message;

    submethod TWEAK
    {
        # Call the constructor of the parent QMainWindow
        self.QMainWindow::subClass;

        # Create the label used as central widget and give it a large font size
        $!label = ColoredLabel.new: text => "00-00-00",
                                    color => QColor.new: Qt::yellow;
        $!labelFont = $!label.font;
        $!labelFont.setPointSize(100);
        $!label.setFont($!labelFont);
        $!label.setMargin(10);
#         $!label.setFixedSize($!label.width, $!label.height);

        # Set $label as the central widget
        self.setCentralWidget($!label);

        # Create a label to store a message in the status bar


        # Create the menus
        my QAction $action;

        $!sizeMenu = self.menuBar.addMenu("&Font");
        $action = $!sizeMenu.addAction("Large");
        connect $action, "triggered", self, "largeFont";
        $action = $!sizeMenu.addAction("Medium");
        connect $action, "triggered", self, "mediumFont";
        $action = $!sizeMenu.addAction("Small");
        connect $action, "triggered", self, "smallFont";

        $!colorMenu = self.menuBar.addMenu("&Color");
        $action = $!colorMenu.addAction("Red");
        connect $action, "triggered", self, "redBackground";
        $action = $!colorMenu.addAction("Green");
        connect $action, "triggered", self, "greenBackground";
        $action = $!colorMenu.addAction("Yellow");
        connect $action, "triggered", self, "yellowBackground";

        $!message = QLabel.new;
        self.statusBar.addPermanentWidget: $!message;

        # Initialize the display
        self.refresh;
    }

    method statusMessage(Str $msg) {
        $!message.setText: $msg;
    }

    method refresh
    {
    say "Refresh";
        $!label.text = DateTime.new(now).local.hh-mm-ss;
        $!label.update;
    }

    method largeFont is QtSlot {
        self.statusBar.showMessage: "Font size set to large";
        $!labelFont.setPointSize(100);
        $!label.setFont($!labelFont);

    }

    method mediumFont is QtSlot {
        self.statusBar.showMessage: "Font size set to medium";
        $!labelFont.setPointSize(50);
        $!label.setFont($!labelFont);
    }

    method smallFont is QtSlot {
        self.statusBar.showMessage: "Font size set to small";
        $!labelFont.setPointSize(20);
        $!label.setFont($!labelFont);
    }

    method redBackground is QtSlot {
        self.statusBar.showMessage: "Background color set to red";
    }

    method greenBackground is QtSlot {
        self.statusBar.showMessage: "Background color set to green";
    }

    method yellowBackground is QtSlot {
        self.statusBar.showMessage: "Background color set to yellow";
    }

}


# Create the application object first (the first argument will be
# the window title)
my $qApp = QApplication.new("What time is it ?", @*ARGS);

# Create the main window
my $mw = MainWindow.new;


$mw.show;


# my $lab = ColoredLabel.new: text => "00-00-00",
#                                     color => QColor.new: Qt::yellow;
# my $font = $lab.font;
# $font.setPointSize(50);
# $lab.setFont($font);
# $lab.setMargin(0);
# say "size: ", $lab.width, ", ", $lab.height;
# # $lab.setFixedSize($lab.width, $lab.height);
#
# $lab.show;



# Thread which refreshes the displayed time
start {
    loop {
        sleep 0.2;
        $mw.refresh;
    }
}



# Run the graphical application
$qApp.exec;





