

# Version of the generator
our constant $geneVersion = "0.0.1";

# Version of the produced code
### our constant RAQTNAME = "RaQt::QtWidgets";
our constant RAQTNAME = "RaQt";        ### ATTENTION : UTILISE DANS LE CODE
our constant RAQTVERSION = "0.0.0";

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
our constant $hFile = "RaQtWrapper.h";
our constant $hppFile = "RaQtWrapper.hpp";
our constant $cppFile = "RaQtWrapper.cpp";
our constant $LibDirectory = "Qt";
our constant $LibSubDirectory = "Qt/RaQt";
our constant $mainRakuFile = "RaQt.rakumod";
our constant $helpersRakuFile = "RaQtHelpers.rakumod";
our constant $wrappersRakuFile = "RaQtWrappers.rakumod";
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


