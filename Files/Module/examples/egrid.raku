
use Qt::QtWidgets;
use Qt::QtWidgets::QAction;
use Qt::QtWidgets::QApplication;
use Qt::QtWidgets::QBrush;
use Qt::QtWidgets::QColor;
use Qt::QtWidgets::QGridLayout;
use Qt::QtWidgets::QLabel;
use Qt::QtWidgets::QMenu;
use Qt::QtWidgets::QMouseEvent;
use Qt::QtWidgets::QPaintEvent;
use Qt::QtWidgets::QPainter;
use Qt::QtWidgets::QPoint;
use Qt::QtWidgets::QWidget;
use Qt::QtWidgets::Qt;

use Qt::QtWidgets::RQWidget;


my constant H = 30;
my constant W = 30;

# The three sets of the sudoku
my @lines;
my @columns;
my @blocks;

class Box { ... }
my @boxes[9, 9];   # An array of the objects where the values are stored


class Menu is QMenu
{
    has QAction @!actions;
    
    submethod TWEAK {
        self.QMenu::subClass: "Select value";
        
        @!actions.push: self.addAction("Clear");
        for (1..9) { @!actions.push: self.addAction: ~$_ }
    }
    
    method exec(QPoint $ev --> Int) {
        my $action = self.QMenu::exec($ev);
        say "AAA: ", $action;
        
        # TODO : Define something like "method isQtNullPtr( --> Bool)" ???
        # TODO : !!! What if DTOR is called with obj.address undefined ?
        return !$action.address
            ?? -1
            !! $action.text eq "Clear"
                ?? 0
                !! +$action.text;
    }
}


class Box is QLabel
{
    has QColor $.color;
    has Str $.text;
    has Menu $.menu;
    
    has Int $.lig;
    has Int $.col;
    has Int $.blk;
    
    submethod TWEAK {
        self.QLabel::subClass;
        self.setAlignment: Qt::AlignHCenter +| Qt::AlignVCenter;
        say "Box: l=$!lig c=$!col b=$!blk";
#         say "self = ", self;
        @boxes[$!lig; $!col] = self;
    }
    
    method paintEvent(QPaintEvent $ev)
    {
        my $painter = QPainter.new();
        $painter.begin(self);
            my $brush = QBrush.new(self.color, Qt::SolidPattern);
            $painter.setBrush($brush);
            $painter.drawRect(0, 0, $ev.rect.width, $ev.rect.height);
            $painter.drawText($ev.rect, Qt::AlignCenter, self.text);
        $painter.end();
    }

    method mousePressEvent(QMouseEvent $ev)
    {
        say "Mouse Pressed !"; 
        my $a = $!menu.exec(self.mapToGlobal(QPoint.new(0,0)));
        say "ACTION : ", $a;
        
        return if $a == -1;   # Esc pressed
        
        say "l=$!lig c=$!col b=$!blk";
        $!text = !$a ?? "" !! ~$a;
        self.update;
    }
    
    method bind(@lst) {
        my $v := $!text;
        @lst[@lst.elems] := $v;
    }
}

class ColoredWidget is QWidget
{
    has QColor $.color;
    
    submethod TWEAK {
        self.QWidget::subClass;
    }
    
    method paintEvent(QPaintEvent $ev)
    {
        my $painter = QPainter.new();
        $painter.begin(self);
            my $brush = QBrush.new(self.color, Qt::SolidPattern);
            $painter.setBrush($brush);
            $painter.drawRect(0, 0, $ev.rect.width, $ev.rect.height);
        $painter.end();
    }
}

class Block is ColoredWidget
{
    
    has Int $.blNum;      # Number of the block
    has Menu $.menu;
    has QColor $.boxColor;
    
    has QGridLayout $!grid;
    has Box @!boxes;
    
    submethod TWEAK
    {
        $!grid = QGridLayout.new;
        self.setLayout: $!grid;

        say "blNum = ", $!blNum;
        
        for (0..2) X (0..2) -> ($il, $ic) {
            my $l = 3 * ($!blNum / 3).Int + $il;
            my $c = 3 * ($!blNum % 3) + $ic;
            my $box = Box.new: color => $!boxColor,
                               lig => $l,
                               col => $c,
                               blk => $!blNum,
                               text => "", 
                               menu => $!menu;
            $box.setFixedSize(W, H);
            @!boxes.push: $box;
            $!grid.addWidget: $box, $l, $c, 
            say ">>> $!blNum : $il, $ic : $l, $c";
        }
    }
}


class Board is ColoredWidget
{
    has Menu $.menu;

    has QGridLayout $!grid;
    has Block @!blocks;
    
    submethod TWEAK
    {
        $!grid = QGridLayout.new;
        self.setLayout: $!grid;

        for (0..2) X (0..2) -> ($bl, $bc) {
            my $block = Block.new:
                color => self.color, 
                menu => self.menu,
                boxColor => QColor.new(110, 160, 200),
                blNum => 3 * $bc + $bl;
            @!blocks.push: $block;
            
            $!grid.addWidget: $block, $bl, $bc;
            
            say "$bl, $bc";
        }
    }
}



my $qApp = QApplication.new;


my $menu = Menu.new;

my $window = Board.new: menu => $menu, color => QColor.new: Qt::gray;


say "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
say @boxes;
say "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";

# Clear all values and bind the sets with the grid
for (0..8) -> $l {
    my @line = ();
    for (0..8) -> $c {
        @boxes[$l; $c].bind: @line;
    }
    @lines.push: @line;
}
for (0..8) -> $c {
    my @column = ();
    for (0..8) -> $l {
        @boxes[$l; $c].bind: @column;
    }
    @columns.push: @column;
}
# for (0..8) -> $b {
#     my @block = ();
#     for (0..8) -> $i {
#         my $l =
#         my $c = 
#         @boxes[$l; $c].bind: @block;
#     }
#     @columns.push: @blocks;
# }


$window.show;

$qApp.exec;

say "Fini !";

say "--------------------------------------------------------------------";

say "L : ", @lines;
say "C : ", @columns;
