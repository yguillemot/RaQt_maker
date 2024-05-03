
#############
# Module info

# Version of the generator
our constant GENEVERSION = "0.0.6";

# Version of the produced code
our constant MODNAME = "Qt::QtWidgets";
our constant MODVERSION = "0.0.6";
our constant MODAUTH = "cpan:YGUILLEMO";
our constant MODAPI = "2";

# Source repository
our constant REPOSITORY = "https://github.com/yguillemot/RaQt_maker";


###################################################################
# Names of the files defining which classes and methods to generate

# Input files
our constant $iWhiteList = "WhiteList.input";
our constant $iBlackList = "BlackList.input";

# Output files
our constant $oWhiteList = "WhiteList.output";
our constant $oBlackList = "BlackList.output";
our constant $oGrayList = "GrayList.output";
our constant $oColorlessList = "ColorlessList.output";


###########################################
# Names of the target files and directories
our constant TARGETDIR = "../module/";
our constant CPPDIR = TARGETDIR ~ "src/";
our constant LIBBASEDIR = TARGETDIR ~ "lib/Qt/";
our constant LIBDIR = LIBBASEDIR ~ "QtWidgets/";

our constant LIBBASEPREFIX = "Qt::";
our constant LIBPREFIX = LIBBASEPREFIX ~ "QtWidgets::";

our constant $hFile = "QtWidgetsWrapper.h";
our constant $hppFile = "QtWidgetsWrapper.hpp";
our constant $cppFile = "QtWidgetsWrapper.cpp";

our constant WRAPPERLIBNAME = "RakuQtWidgets";

our constant DOCDIR = TARGETDIR ~ "doc/Qt/QtWidgets/";
our constant TITLEFILE = DOCDIR ~ "Title.md";
our constant DOCFILE = DOCDIR ~ "Classes.md";
our constant HTMLFILE = DOCDIR ~ "Classes.html";

our constant TESTSDIR = TARGETDIR ~ "t/";
our constant EXAMPLESDIR = TARGETDIR ~ "examples/";

our constant BINDIR = TARGETDIR ~ "bin/";

#######################
# Prefixes and suffixes
our constant $prefixWrapper = "QW";
#our constant $prefixRaku = "Qt";
our constant $suffixCtor = "Ctor";
our constant $suffixDtor = "Dtor";
our constant $prefixSubclass = "SC";
our constant $prefixSubclassWrapper = "SCW";
our constant PREFIXROLE = "R";

########################################
# Indentation quantum of generated files
our constant IND = ' ' x 4;

#########
# Markers
our constant CNOM = '[)';    # Class Name Open Marker
our constant CNCM = '(]';    # Class Name Close Marker
