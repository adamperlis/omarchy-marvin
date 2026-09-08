import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Marvin To-dos: a to-do list in the bar. Not a clone of anything — Omarchy
// ships no to-do app. Tasks live in ~/todos.md as Markdown checkboxes, so
// Obsidian and OmaWrite read and edit the same list. All file work is in
// marvin-todo (installed to ~/.local/bin by the config layer); this widget
// shows the list and calls it.
BarWidget {
  id: root
  moduleName: "marvin.todos"

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string bin: root.home + "/.local/bin/marvin-todo"
  property var items: []
  property bool popupOpen: false

  readonly property int openCount: {
    var n = 0
    for (var i = 0; i < items.length; i++) if (items[i].state === "open") n++
    return n
  }

  function refresh() { if (!listProc.running) listProc.running = true }
  function toggle(line) { Quickshell.execDetached([root.bin, "toggle", String(line)]); reload.restart() }
  function add(text) { if (text && text.length) { Quickshell.execDetached([root.bin, "add", text]); reload.restart() } }
  function clearDone() { Quickshell.execDetached([root.bin, "clear-done"]); reload.restart() }

  function parseList(out) {
    var lines = String(out || "").split("\n")
    var arr = []
    for (var i = 0; i < lines.length; i++) {
      var p = lines[i].split("\t")
      if (p.length >= 3) arr.push({ state: p[0], line: parseInt(p[1]), text: p[2] })
    }
    root.items = arr
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  Component.onCompleted: refresh()

  Process {
    id: listProc
    running: false
    command: [root.bin, "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseList(text)
    }
  }

  // Small settle so the file write lands before we re-read it.
  Timer {
    id: reload
    interval: 250
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot
    text: "\uf0ae"   // Nerd Font: checklist
    tooltipText: root.openCount + " to do"
    onPressed: function(b) {
      root.popupOpen = !root.popupOpen
      if (root.popupOpen) root.refresh()
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.spacing.lg

      // ---- Header: the name, and the open count as a caption.
      Item {
        width: parent.width
        height: heading.implicitHeight
        Text {
          id: heading
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "To-dos"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.title
          font.weight: Font.Medium
        }
        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.openCount + " open"
          color: Color.muted
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      // ---- Add a task. Enter commits and clears the field.
      TextField {
        id: input
        width: parent.width
        placeholderText: "Add a task…"
        foreground: root.bar.foreground
        font.family: root.bar.fontFamily
        onAccepted: { root.add(text); text = "" }
      }

      // ---- The list. A filled square is done; the text is struck and muted.
      Column {
        width: parent.width
        spacing: Style.spacing.sm

        Repeater {
          model: root.items

          Item {
            required property var modelData
            width: column.width
            height: Style.spacing.controlHeight

            Row {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.md

              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(18)
                height: Style.space(18)
                radius: Style.space(6)
                color: modelData.state === "done" ? Color.accent : "transparent"
                border.width: modelData.state === "done" ? 0 : 1
                border.color: Color.muted

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggle(modelData.line)
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.text
                color: modelData.state === "done" ? Color.muted : root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                font.strikeout: modelData.state === "done"
                elide: Text.ElideRight
                width: column.width - Style.space(18) - Style.spacing.md
              }
            }
          }
        }
      }

      // ---- Clear the completed tasks.
      Button {
        visible: root.items.length > root.openCount
        text: "Clear done"
        fontSize: Style.font.body
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
        horizontalPadding: Style.spacing.controlPaddingX
        verticalPadding: Style.spacing.controlPaddingY
        bordered: false
        onClicked: root.clearDone()
      }
    }
  }
}
