import QtQuick
import Quickshell

ShellRoot {
    id: test
    property int attempts: 0
    Component.onCompleted: Backend.consumers++
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            test.attempts++
            if (!Backend.healthy) {
                if (test.attempts > 100) {
                    console.error("RUNTIME_FAIL: no live snapshot: " + Backend.error)
                    Qt.quit()
                }
                return
            }
            if (typeof Backend.focusSession !== "function") {
                console.error("RUNTIME_FAIL: navigation method is not callable")
                Qt.quit()
                return
            }
            var previous = Backend.snapshot
            Backend.error = "unavailable"
            if (Backend.healthy || Backend.snapshot !== previous) {
                console.error("RUNTIME_FAIL: failure must retain stale data")
                Qt.quit()
                return
            }
            Backend.consumers--
            if (Backend.active || Backend.busy || Backend.healthy) {
                console.error("RUNTIME_FAIL: disabled backend still active")
                Qt.quit()
                return
            }
            console.log("RUNTIME_PASS: live snapshot, stale retention, disabled polling")
            Qt.quit()
        }
    }
}
