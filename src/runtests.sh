#!/usr/bin/bash

export LD_LIBRARY_PATH=.
export RAKULIB=.

raku tests/05-QApplication.t
raku tests/10-QEvent.t
raku tests/20-QPoint.t
raku tests/30-QPointF.t
raku tests/40-connect.t
raku tests/41-disconnect.t
raku tests/50-QPushButton.t
raku tests/60-QBoxLayout.t

