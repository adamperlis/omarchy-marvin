import QtQuick
import QtQuick.Controls
import QtQuick.Effects
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
  readonly property string bgLink: root.home + "/.local/state/omarchy/current/background"
  property string themeName: ""
  readonly property bool isLight: themeName.indexOf("light") !== -1

  property bool popupOpen: false
  property bool reduceMotion: false
  property bool scheduled: false
  property bool autoUpdate: false

  // Wallpaper picker state. currentBg is the resolved file the symlink points
  // at (resolved, so it changes when the wallpaper changes and the preview
  // reloads); wallpapers is every image alongside it.
  property bool pickerOpen: false
  property string currentBg: ""
  property var wallpapers: []

  function refreshMode() { if (!modeProc.running) modeProc.running = true }
  function refreshAuto() { if (!autoProc.running) autoProc.running = true }
  function refreshStatus() { if (!statusProc.running) statusProc.running = true }
  function refreshBg() { if (!bgProc.running) bgProc.running = true }
  function close() { popupOpen = false }

  function applyMode(m) {
    if (m === "light") root.themeName = "marvin-light"
    else if (m === "dark") root.themeName = "marvin"
    Quickshell.execDetached([root.modeBin, m])
    settle.restart()
  }
  function toggleReduceMotion() {
    root.reduceMotion = !root.reduceMotion
    Quickshell.execDetached(["hyprctl", "keyword", "animations:enabled", root.reduceMotion ? "0" : "1"])
  }
  // Appearance is one exclusive choice: Light, Dark, or Auto. Picking a manual
  // tone turns the daily schedule off (if it was on); picking Auto turns it on.
  function setManual(m) {
    if (root.scheduled) { root.scheduled = false; Quickshell.execDetached([root.modeBin, "unschedule"]) }
    root.applyMode(m)
  }
  function setAuto() {
    root.scheduled = true
    Quickshell.execDetached([root.modeBin, "schedule"])
    settle.restart()
  }
  function toggleAutoUpdate() {
    root.autoUpdate = !root.autoUpdate
    Quickshell.execDetached([root.updateBin, root.autoUpdate ? "--enable" : "--disable"])
  }

  // ---- Wallpaper. The symlink's directory holds the theme's whole set; list
  //      it so the picker can offer every one.
  function listWallpapers() {
    var d = root.currentBg.substring(0, root.currentBg.lastIndexOf("/"))
    if (!d.length) return
    listProc.command = ["find", d, "-maxdepth", "1", "-type", "f",
      "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", ")"]
    if (!listProc.running) listProc.running = true
  }
  function pickWallpaper(path) {
    Quickshell.execDetached(["omarchy-theme-bg-set", path])
    root.currentBg = path
    root.pickerOpen = false
    bgSettle.restart()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  Component.onCompleted: { refreshMode(); refreshAuto(); refreshStatus(); refreshBg() }

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

  // Whether the daily light/dark schedule is on, so the Auto segment reflects
  // reality. `marvin-mode status` prints "schedule: off" or the two times.
  Process {
    id: statusProc
    running: false
    command: [root.modeBin, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var t = String(text || "")
        root.scheduled = t.indexOf("schedule:") !== -1 && t.indexOf("schedule: off") === -1
      }
    }
  }

  // Resolve the current wallpaper (following the symlink) and then list the set.
  Process {
    id: bgProc
    running: false
    command: ["readlink", "-f", root.bgLink]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var p = String(text || "").trim()
        if (p.length) { root.currentBg = p; root.listWallpapers() }
      }
    }
  }

  Process {
    id: listProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").split("\n").filter(function(x) { return x.trim().length })
        lines.sort()
        root.wallpapers = lines
      }
    }
  }

  // omarchy-theme-set is asynchronous; re-read once it has had time to land.
  Timer {
    id: settle
    interval: 900
    onTriggered: root.refreshMode()
  }
  // A wallpaper set lands quickly; re-resolve so the preview updates.
  Timer {
    id: bgSettle
    interval: 700
    onTriggered: root.refreshBg()
  }

  // A wallpaper thumbnail masked to rounded corners. A rounded Rectangle with
  // clip:true does NOT clip children to its corners, so a full-bleed image
  // spills past them and looks like it's sitting on top of the frame;
  // MultiEffect masks the image to the rounded shape properly.
  component RoundedShot: Item {
    id: shot
    property string path: ""
    property real corner: Style.spacing.sm

    Image {
      id: shotImg
      anchors.fill: parent
      source: shot.path.length ? ("file://" + shot.path) : ""
      fillMode: Image.PreserveAspectCrop
      sourceSize.width: Style.space(200)
      asynchronous: true
      cache: false
      visible: false
    }
    MultiEffect {
      anchors.fill: parent
      source: shotImg
      maskEnabled: true
      maskSource: shotMask
    }
    Item {
      id: shotMask
      anchors.fill: parent
      layer.enabled: true
      layer.smooth: true
      visible: false
      Rectangle { anchors.fill: parent; radius: shot.corner }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot
    text: root.isLight ? "" : ""   // Nerd Font: sun / moon
    tooltipText: "Marvin — left: panel · right: quick toggle"

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.themeName = root.isLight ? "marvin" : "marvin-light"
        Quickshell.execDetached([root.modeBin, "toggle"])
        settle.restart()
      } else {
        root.popupOpen = !root.popupOpen
        if (root.popupOpen) { root.refreshMode(); root.refreshAuto(); root.refreshStatus(); root.refreshBg() }
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

      // ---- Appearance: one exclusive segmented control — Light, Dark or Auto.
      //      A filled track groups the three; the selected segment sits in a
      //      stronger fill so the grouping and selection read at a glance.
      Text {
        text: "Appearance"
        color: Color.muted
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
      }
      Rectangle {
        id: apprTrack
        width: parent.width
        height: Style.space(34)
        radius: Style.space(9)
        color: Style.normalFillFor(root.bar.foreground, root.bar.foreground)

        Row {
          anchors.fill: parent
          anchors.margins: Style.space(3)
          spacing: Style.space(3)

          Repeater {
            model: [
              { label: "Light", mode: "light" },
              { label: "Dark",  mode: "dark"  },
              { label: "Auto",  mode: "auto"  }
            ]

            Rectangle {
              required property var modelData
              width: (apprTrack.width - Style.space(12)) / 3
              height: parent.height
              radius: Style.space(7)
              readonly property bool selected: modelData.mode === "auto"
                ? root.scheduled
                : (modelData.mode === "light" ? (root.isLight && !root.scheduled)
                                              : (!root.isLight && !root.scheduled))
              color: selected ? Style.selectedFillFor(root.bar.foreground, Color.accent) : "transparent"

              Text {
                anchors.centerIn: parent
                text: modelData.label
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: modelData.mode === "auto" ? root.setAuto() : root.setManual(modelData.mode)
              }
            }
          }
        }
      }

      // When Auto is on, say what it does — no tooltip needed.
      Text {
        visible: root.scheduled
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Light in the morning, dark in the evening — every day."
        color: Color.muted
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
      }

      // ---- Wallpaper: a preview of the current one; click to choose another.
      Text {
        text: "Wallpaper"
        color: Color.muted
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
      }
      Item {
        width: parent.width
        height: Style.space(44)

        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.md

          RoundedShot {
            id: bgThumb
            width: Style.space(72)
            height: Style.space(44)
            corner: Style.spacing.sm
            path: root.currentBg
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.pickerOpen ? "Close" : "Select wallpaper"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { root.pickerOpen = !root.pickerOpen; if (root.pickerOpen) root.refreshBg() }
        }
      }

      // The picker: every wallpaper in the set, scrollable, current one ringed.
      Flickable {
        id: bgFlick
        visible: root.pickerOpen
        width: parent.width
        height: root.pickerOpen ? Math.min(grid.implicitHeight, Style.space(216)) : 0
        contentWidth: width
        contentHeight: grid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 6000
        interactive: contentHeight > height

        // A styled bar, visible in both tones and draggable. The default bar is
        // nearly invisible on a light surface, so paint the handle ourselves.
        ScrollBar.vertical: ScrollBar {
          id: bgBar
          policy: bgFlick.contentHeight > bgFlick.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
          width: Style.space(10)
          contentItem: Rectangle {
            implicitWidth: Style.space(5)
            radius: width / 2
            color: bgBar.pressed ? root.bar.foreground : Color.muted
            opacity: bgBar.pressed ? 0.9 : 0.55
          }
        }

        // Smooth the wheel: animate contentY rather than jumping a notch. Handles
        // mouse and touchpad alike (angleDelta, or pixelDelta when that's what
        // the device sends).
        WheelHandler {
          onWheel: function(ev) {
            var d = ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.pixelDelta.y
            var maxY = Math.max(0, bgFlick.contentHeight - bgFlick.height)
            bgScroll.to = Math.max(0, Math.min(maxY, bgFlick.contentY - d))
            bgScroll.restart()
          }
        }
        NumberAnimation {
          id: bgScroll
          target: bgFlick
          property: "contentY"
          duration: 160
          easing.type: Easing.OutCubic
        }

        Flow {
          id: grid
          width: bgFlick.width - Style.space(14)   // room for the scrollbar
          spacing: Style.spacing.sm

          Repeater {
            model: root.wallpapers

            Item {
              required property var modelData
              width: Style.space(84)
              height: Style.space(52)

              RoundedShot {
                anchors.fill: parent
                path: modelData
                corner: Style.spacing.sm
              }

              // Selection ring, on top of the masked image.
              Rectangle {
                anchors.fill: parent
                radius: Style.spacing.sm
                color: "transparent"
                visible: modelData === root.currentBg
                border.width: 2
                border.color: Color.accent
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pickWallpaper(modelData)
              }
            }
          }
        }
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
          bordered: true
          active: root.reduceMotion
          onClicked: root.toggleReduceMotion()
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
          bordered: true
          active: root.autoUpdate
          onClicked: root.toggleAutoUpdate()
        }
      }
    }
  }
}
