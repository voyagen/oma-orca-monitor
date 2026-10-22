import QtQuick
import QtQuick.Effects
import qs.Commons as Commons

Image {
    id: root
    property color color: Commons.Color.muted
    property bool tinted: true
    fillMode: Image.PreserveAspectFit
    layer.enabled: tinted
    layer.effect: MultiEffect {
        colorization: 1
        colorizationColor: root.color
    }
}
