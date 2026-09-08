import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Marvin's light/dark control, as a bar widget with a pop-out panel.
//
// The bar icon is a sun in light, a moon in dark. Left click opens the panel
// (appearance, wallpaper, reduce motion, a daily schedule, auto-update); right
// click is a quick light/dark flip. The logic lives in marvin-mode and
// marvin-update, installed to ~/.local/bin by the config layer.
BarWidget {
  id: root
  moduleName: "marvin.mode"

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string modeBin: root.home + "/.local/bin/marvin-mode"
  readonly property string updateBin: root.home + "/.local/bin/marvin-update"
  property string themeName: ""
  readonly property bool isLight: themeName.indexOf("light") !== -1

  property bool popupOpen: false
  property bool reduceMotion: false
  property bool scheduled: false
  property bool autoUpdate: false

  function refreshMode() { if (!modeProc.running) modeProc.running = true }
  function refreshAuto() { if (!autoProc.running) autoProc.running = true }
  function close() { popupOpen = false }

  function applyMode(m) {
    if (m === "light") root.themeName = "marvin-light"
    else if (m === "dark") root.themeName = "marvin"
    Quickshell.execDetached([root.modeBin, m])
    settle.restart()
  }
  function nextWallpaper() { Quickshell.execDetached(["omarchy-theme-bg-next"]) }
  function toggleReduceMotion() {
    root.reduceMotion = !root.reduceMotion
    Quickshell.execDetached(["hyprctl", "keyword", "animations:enabled", root.reduceMotion ? "0" : "1"])
  }
  function toggleSchedule() {
    root.scheduled = !root.scheduled
    Quickshell.execDetached([root.modeBin, root.scheduled ? "schedule" : "unschedule"])
  }
  function toggleAutoUpdate() {
    root.autoUpdate = !root.autoUpdate
    Quickshell.execDetached([root.updateBin, root.autoUpdate ? "--enable" : "--disable"])
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  Component.onCompleted: { refreshMode(); refreshAuto() }

  // The live theme, so the glyph is a sun or a moon.
  Process {
    id: modeProc
    running: false
    command: ["cat", root.home + "/.local/state/omarchy/current/theme.name"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.themeName = String(text || "").trim()
    }
  }

  // Whether the auto-update timer is on, so the toggle reflects reality.
  Process {
    id: autoProc
    running: false
    command: [root.updateBin, "--status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.autoUpdate = String(text || "").indexOf("on") !== -1
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
    tooltipText: "Marvin — left: panel · right: quick toggle"

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.themeName = root.isLight ? "marvin" : "marvin-light"
        Quickshell.execDetached([root.modeBin, "toggle"])
        settle.restart()
      } else {
        root.popupOpen = !root.popupOpen
        if (root.popupOpen) { root.refreshMode(); root.refreshAuto() }
      }
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(288))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.spacing.lg

      // ---- Appearance: light, dark, or follow the system scheme.
      Text {
        text: "Appearance"
        color: Color.muted
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
      }
      Row {
        width: parent.width
        spacing: Style.spacing.sm

        Button {
          text: "Light"
          fontSize: Style.font.body
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          bordered: false
          active: root.isLight
          onClicked: root.applyMode("light")
        }
        Button {
          text: "Dark"
          fontSize: Style.font.body
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          bordered: false
          active: !root.isLight
          onClicked: root.applyMode("dark")
        }
        Button {
          text: "System"
          fontSize: Style.font.body
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          bordered: false
          onClicked: root.applyMode("system")
        }
      }

      // ---- Wallpaper: step to the next one in the theme's set.
      Text {
        text: "Wallpaper"
        color: Color.muted
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
      }
      Button {
        text: "Next wallpaper"
        fontSize: Style.font.body
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
        horizontalPadding: Style.spacing.controlPaddingX
        verticalPadding: Style.spacing.controlPaddingY
        bordered: false
        onClicked: root.nextWallpaper()
      }

      // ---- Reduce motion: turn compositor animations off (shell motion is
      //      Omarchy's own and cannot be themed).
      Item {
        width: parent.width
        height: rmButton.implicitHeight
        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Reduce motion"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
        }
        Button {
          id: rmButton
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.reduceMotion ? "On" : "Off"
          fontSize: Style.font.body
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          bordered: false
          active: root.reduceMotion
          onClicked: root.toggleReduceMotion()
        }
      }

      // ---- Daily schedule: light in the morning, dark in the evening.
      Item {
        width: parent.width
        height: schedButton.implicitHeight
        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Daily light/dark"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
        }
        Button {
          id: schedButton
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.scheduled ? "On" : "Off"
          fontSize: Style.font.body
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          bordered: false
          active: root.scheduled
          onClicked: root.toggleSchedule()
        }
      }

      // ---- Auto-update: pull and re-apply Marvin on a daily timer.
      Item {
        width: parent.width
        height: autoButton.implicitHeight
        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Auto-update"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
        }
        Button {
          id: autoButton
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.autoUpdate ? "On" : "Off"
          fontSize: Style.font.body
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          bordered: false
          active: root.autoUpdate
          onClicked: root.toggleAutoUpdate()
        }
      }
    }
  }
}
