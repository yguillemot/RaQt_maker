
# A digital clock

use Qt::QtWidgets;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QFont;
use Qt::QtWidgets::QLabel;
use Qt::QtWidgets::QMainWindow;
use Qt::QtWidgets::QMenu;
use Qt::QtWidgets::QSize;



# Main window class subclassing QMainWindow

class MainWindow is QMainWindow {

    has QLabel $.label;
    has QFont $.font;
    has QMenu $.fileMenu;

    submethod TWEAK
    {
        # Call the constructor of the parent QMainWindow
        self.QMainWindow::subClass;

        # Create the label used as central widget and give it a large font size
        $!label = QLabel.new("00-00-00");
        $!font = $!label.font;
        $!font.setPointSize(50);
        $!label.setFont($!font);
        $!label.setMargin(10);

        # Set $label as the central widget
        self.setCentralWidget($!label);

        $!fileMenu = self.menuBar.addMenu("&File");
        $!fileMenu.addAction("newAct");
        $!fileMenu.addAction("openAct");
        $!fileMenu.addAction("saveAct");

        self.statusBar.showMessage: "Ready";

        connect self, "iconSizeChanged", self, "somethingHappens";

        # Initialize the display
        self.refresh;
    }

    method refresh
    {
        $!label.setText(DateTime.new(now).local.hh-mm-ss);
    }

    method setStatus(Str $msg)
    {
        self.statusBar.showMessage: $msg;

        if $msg ~~ "10" {
            my $sz = self.iconSize;
            say "Icon size : w=", $sz.width, " h=", $sz.height;
        }

        if $msg ~~ "20" {
            self.setIconSize: QSize.new(33, 35);
        }

        if $msg ~~ "30" {
            my $sz = self.iconSize;
            say "Icon size : w=", $sz.width, " h=", $sz.height;
        }
    }

    method somethingHappens(QSize $s) is QtSlot {
        say "A : w=", $s.width, " h=", $s.height;
        my $sz = self.iconSize;
        say "B : w=", $sz.width, " h=", $sz.height;
    }

}


# Create the application object first (the first argument will be
# the window title)
my $qApp = QApplication.new("What time is it ?", @*ARGS);

# Create the main window
my $mw = MainWindow.new;


$mw.show;

# # Make resizing the window impossible
# $label.setFixedSize($label.width, $label.height);

# Thread which refreshes the displayed time
start {
    loop {
        sleep 0.2;
        $mw.refresh;
    }
}

# Thread which modify the status bar
start {
    my $count = 0;
    loop {
        sleep 0.45;
        $count++;
        $mw.setStatus: ~$count;
    }
}


# Run the graphical application
$qApp.exec;





