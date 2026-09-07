import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

// Marvin media widget. A clone of omarchy.media: the service, the bar strip
// and its mouse handling are upstream's. The popup is rewritten to the
// Marvin rules: art at a nested radius, title and artist in two tones, the
// play button as the card's one inverted element, progress as a 2px
// hairline, sources as 32px rows with a fill for the selected one.
BarWidget {
  id: root
  moduleName: "omarchy.media"

  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("omarchy.media")
  readonly property var activePlayer: mediaService ? mediaService.activePlayer : null
  readonly property var sourcePlayers: mediaService ? mediaService.sourcePlayers : []

  readonly property bool hasMedia: activePlayer !== null && (activePlayer.trackTitle || activePlayer.trackArtist)
  readonly property string playIcon: activePlayer && activePlayer.isPlaying ? "󰏤" : "󰐊"
  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""

  property bool popupOpen: false

  function close() { popupOpen = false }
  property real maxLabelWidth: 180

  visible: hasMedia
  implicitWidth: hasMedia ? row.implicitWidth + Style.space(14) : 0
  implicitHeight: barSize

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      id: glyph
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      text: root.playIcon
      color: activePlayer && activePlayer.isPlaying ? root.bar.barForeground : Color.muted
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
      Behavior on color {
        enabled: !root.bar || root.bar.foregroundAnimationEnabled
        ColorAnimation { duration: 160 }
      }
    }

    Item {
      id: scrollClip
      width: Math.min(root.maxLabelWidth, labelText.implicitWidth)
      height: glyph.height
      clip: true
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.bar.vertical && root.title !== ""

      Text {
        id: labelText
        textFormat: Text.PlainText
        text: root.title + (root.artist ? "  ·  " + root.artist : "")
        color: root.bar.barForeground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter

        property bool needsScroll: implicitWidth > scrollClip.width

        NumberAnimation on x {
          id: scrollAnim
          running: labelText.needsScroll && !root.popupOpen && !root.bar.vertical
          loops: Animation.Infinite
          duration: Math.max(6000, labelText.implicitWidth * 25)
          from: scrollClip.width
          to: -labelText.implicitWidth
          easing.type: Easing.Linear
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.activePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (!root.activePlayer) return
      if (mouse.button === Qt.MiddleButton) {
        if (root.mediaService) root.mediaService.runAction("next", false)
      } else if (mouse.button === Qt.RightButton) {
        root.popupOpen = !root.popupOpen
      } else {
        if (root.mediaService) root.mediaService.runAction("playPause", false)
      }
    }
    onWheel: function(wheel) {
      if (!root.activePlayer) return
      if (wheel.angleDelta.y > 0 && root.mediaService) root.mediaService.runAction("previous", false)
      else if (wheel.angleDelta.y < 0 && root.mediaService) root.mediaService.runAction("next", false)
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.hasMedia ? (root.title + (root.artist ? " — " + root.artist : "")) : "")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  // Progress. MprisPlayer reports position on demand; while the popup is
  // open a 1s tick asks for it. Guarded on the player advertising both.
  property int positionTick: 0
  readonly property bool scrubVisible: !!(activePlayer && activePlayer.lengthSupported && activePlayer.positionSupported && activePlayer.length > 0)
  readonly property real scrub: {
    var tick = positionTick
    if (!scrubVisible) return 0
    return Math.max(0, Math.min(1, activePlayer.position / activePlayer.length))
  }
  function clockText(seconds) {
    var s = Math.max(0, Math.round(Number(seconds) || 0))
    var m = Math.floor(s / 60)
    return m + ":" + (s % 60 < 10 ? "0" : "") + (s % 60)
  }
  Timer {
    interval: 1000
    running: root.popupOpen && root.scrubVisible
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      try { if (root.activePlayer) root.activePlayer.positionChanged() } catch (e) {}
      root.positionTick++
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(328))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.spacing.lg

      // ---- Art and titles. Nested radius: outer 16 minus padding 16 would be
      //      zero, so the art takes the small step instead.
      Row {
        width: parent.width
        spacing: Style.spacing.md

        Rectangle {
          width: Style.spacing.huge + Style.spacing.lg   // 64
          height: width
          radius: Style.spacing.sm
          color: Style.normalFillFor(root.bar.foreground, Color.accent)
          clip: true

          Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
            visible: source !== ""
          }

          Text {
            anchors.centerIn: parent
            visible: !root.activePlayer || !root.activePlayer.trackArtUrl
            text: "󰝚"
            color: Color.muted
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
          }
        }

        Column {
          width: parent.width - Style.spacing.huge - Style.spacing.lg - Style.spacing.md
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.xs

          Text {
            textFormat: Text.PlainText
            text: root.title || "Nothing playing"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.title
            font.weight: Font.Medium
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            textFormat: Text.PlainText
            text: root.artist
            color: Color.muted
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }

          Text {
            textFormat: Text.PlainText
            text: root.activePlayer && root.activePlayer.trackAlbum ? root.activePlayer.trackAlbum : ""
            color: Color.muted
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }
        }
      }

      // ---- Progress. A hairline; times as captions beneath it.
      Column {
        visible: root.scrubVisible
        width: parent.width
        spacing: Style.spacing.xs

        Rectangle {
          width: parent.width
          height: Style.spacing.xxs
          radius: 1
          color: Style.normalFillFor(root.bar.foreground, Color.accent)

          Rectangle {
            width: Math.round(parent.width * root.scrub)
            height: parent.height
            radius: parent.radius
            color: root.bar.foreground
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
          }
        }

        Item {
          width: parent.width
          height: Style.font.caption + Style.spacing.xxs
          Text {
            anchors.left: parent.left
            text: root.scrubVisible ? root.clockText(root.activePlayer.position) : ""
            color: Color.muted
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }
          Text {
            anchors.right: parent.right
            text: root.scrubVisible ? root.clockText(root.activePlayer.length) : ""
            color: Color.muted
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      // ---- Transport. Play is the one inverted element on the card.
      Row {
        spacing: Style.spacing.sm

        Button {
          iconText: "󰒮"
          iconSize: Style.font.icon
          foreground: root.bar.foreground
          bordered: false
          horizontalPadding: Style.spacing.controlPaddingY
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoPrevious
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("previous", false, root.mediaService.playerKey(root.activePlayer))
        }

        Rectangle {
          id: playButton
          width: Style.spacing.controlHeight
          height: Style.spacing.controlHeight
          radius: Style.cornerRadius
          color: root.bar.foreground
          readonly property bool usable: !!(root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause))
          opacity: !usable ? 0.4 : (playMouse.containsMouse ? 0.85 : 1.0)
          Behavior on opacity { NumberAnimation { duration: 120 } }

          Text {
            anchors.centerIn: parent
            text: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"
            color: Color.popups.background
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.icon
          }

          MouseArea {
            id: playMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: playButton.usable
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (root.mediaService) root.mediaService.runAction("playPause", false, root.mediaService.playerKey(root.activePlayer))
          }
        }

        Button {
          iconText: "󰒭"
          iconSize: Style.font.icon
          foreground: root.bar.foreground
          bordered: false
          horizontalPadding: Style.spacing.controlPaddingY
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoNext
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("next", false, root.mediaService.playerKey(root.activePlayer))
        }
      }

      // ---- Sources. A caption and 32px rows; the selected one is a fill.
      Column {
        id: sourceList
        visible: root.sourcePlayers.length > 1
        width: parent.width
        spacing: Style.spacing.sm

        Text {
          text: "Sources"
          color: Color.muted
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }

        Repeater {
          model: root.sourcePlayers

          Rectangle {
            id: sourceRow
            required property var modelData

            readonly property var player: modelData
            readonly property bool selected: root.activePlayer && player
              && root.mediaService.playerKey(root.activePlayer) === root.mediaService.playerKey(player)
            readonly property string sourceTitle: player ? (player.trackTitle || player.identity || player.desktopEntry || "Media source") : "Media source"
            readonly property string sourceDetail: player && player.trackArtist ? player.trackArtist : (player && player.identity ? player.identity : "")

            width: sourceList.width
            height: Style.spacing.controlHeight
            radius: Style.cornerRadius
            color: selected ? Style.selectedFillFor(root.bar.foreground, Color.accent)
                 : (sourceMouse.containsMouse ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent")

            Row {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.spacing.rowPaddingX
              anchors.rightMargin: Style.spacing.rowPaddingX
              spacing: Style.spacing.sm

              Text {
                textFormat: Text.PlainText
                text: sourceRow.player && sourceRow.player.isPlaying ? "󰏤" : "󰐊"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.iconSmall
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: sourceRow.sourceTitle
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
                width: parent.width - Style.font.iconSmall - Style.spacing.sm * 2 - detail.width
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: detail
                textFormat: Text.PlainText
                text: sourceRow.sourceDetail
                color: Color.muted
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
              }
            }

            MouseArea {
              id: sourceMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.mediaService) root.mediaService.selectPlayer(root.mediaService.playerKey(sourceRow.player))
            }
          }
        }
      }
    }
  }
}
