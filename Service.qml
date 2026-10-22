import QtQuick

// Keep one backend per QML engine without relying on a custom bar's service facade.
Item {
    Component.onCompleted: Backend.consumers++
    Component.onDestruction: Backend.consumers--
}
