import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Marvin's light/dark control, as a bar widget instead of a keybind.
//
// One icon: a moon in dark, a sun in light. Left click toggles; right click
// matches the system colour-scheme; middle click sets the daily schedule.
// The logic lives in marvin-mode (installed to ~/.local/bin by the config
// layer); this widget only reads the current theme and calls it.
BarWidget {
  id: root
  moduleName: "marvin.mode"

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string modeBin: root.home + "/.local/bin/marvin-mode"
  property string themeName: ""
  readonly property bool isLight: themeName.indexOf("light") !== -1

  function refreshMode() { if (!modeProc.running) modeProc.running = true }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refreshMode()

  // What theme is live right now, so the glyph can be a sun or a moon.
  Process {
    id: modeProc
    running: false
    command: ["cat", root.home + "/.local/state/omarchy/current/theme.name"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.themeName = String(text || "").trim()
    }
  }

  // omarchy-theme-set is asynchronous; re-read once it has had time to land.
  Timer {
    id: settle
    interval: 900
    onTriggered: root.refreshMode()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot
    text: root.isLight ? "\uf185" : "\uf186"   // Nerd Font: sun / moon
    tooltipText: "Marvin — left: toggle light/dark · right: match system · middle: schedule"

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        Quickshell.execDetached([root.modeBin, "system"])
      } else if (b === Qt.MiddleButton) {
        Quickshell.execDetached([root.modeBin, "schedule"])
      } else {
        // Flip the glyph on the click itself; confirm once the switch lands.
        root.themeName = root.isLight ? "marvin" : "marvin-light"
        Quickshell.execDetached([root.modeBin, "toggle"])
      }
      settle.restart()
    }
  }
}
