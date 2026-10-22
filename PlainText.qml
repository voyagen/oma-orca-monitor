import QtQuick
import qs.Commons as Commons

Text {
    textFormat: Text.PlainText
    FontLoader { id: geist; source: Qt.resolvedUrl("fonts/Geist.ttf") }
    color: Commons.Color.popups.text
    font.family: geist.status === FontLoader.Ready ? geist.name : Commons.Style.font.family
    font.pixelSize: Commons.Style.space(13)
    elide: Text.ElideRight
}
