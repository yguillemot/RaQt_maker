

# Version of the generator
our constant $geneVersion = "0.0.1";

# Version of the produced code
### our constant RAQTNAME = "RaQt::QtWidgets";
our constant RAQTNAME = "QtWidgets";        ### BEWARE : Used in the code
our constant RAQTVERSION = "0.0.1";

# Source repository
our constant $repository = "https://github.com/yguillemot/RaQt_maker.git";


# Names of the files defining which classes and methods to generate

# Input files
our constant $iWhiteList = "WhiteList.input";
our constant $iBlackList = "BlackList.input";

# Output files
our constant $oWhiteList = "WhiteList.output";
our constant $oBlackList = "BlackList.output";
our constant $oGrayList = "GrayList.output";
our constant $oColorlessList = "ColorlessList.output";


# Names of the target files
our constant $hFile = "QtWidgetsWrapper.h";
our constant $hppFile = "QtWidgetsWrapper.hpp";
our constant $cppFile = "QtWidgetsWrapper.cpp";
our constant $LibDirectory = "Qt";
our constant $LibSubDirectory = "Qt/QtWidgets";
our constant $mainRakuFile = "QtWidgets.rakumod";
our constant $helpersRakuFile = "QtHelpers.rakumod";
our constant $wrappersRakuFile = "QtWrappers.rakumod";
our constant TITLEFILE = "Title.md";
our constant DOCFILE = "Classes.md";


# Prefixes and suffixes
our constant $prefixWrapper = "QW";
#our constant $prefixRaku = "Qt";
our constant $suffixCtor = "Ctor";
our constant $suffixDtor = "Dtor";
our constant $prefixSubclass = "SC";
our constant $prefixSubclassWrapper = "SCW";

# Indentation quantum of generated files
our constant IND = ' ' x 4;


