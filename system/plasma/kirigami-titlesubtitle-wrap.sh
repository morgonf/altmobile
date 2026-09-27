#!/bin/sh
D=/usr/lib64/qt6/qml/org/kde/kirigami/delegates
[ -f $D/qmldir.orig ] || cp -a $D/qmldir $D/qmldir.orig
[ -f $D/TitleSubtitle.qml.orig ] || cp -a $D/TitleSubtitle.qml $D/TitleSubtitle.qml.orig
sed '/^prefer /d' $D/qmldir.orig > $D/qmldir
sed 's/^    property int wrapMode: Text.NoWrap$/    property int wrapMode: Text.WordWrap \/\/ ALT Mobile: перенос по словам вместо обрезки на узком экране телефона/' $D/TitleSubtitle.qml.orig > $D/TitleSubtitle.qml
grep -c prefer $D/qmldir; grep -n "property int wrapMode" $D/TitleSubtitle.qml
