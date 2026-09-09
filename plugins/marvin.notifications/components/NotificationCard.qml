// Notification card. Pure presentational — no service, Notification, or
// ListModel references. The popup container drives lifetime; the history
// panel drives static rendering. Both use the same component.

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui
import "../NotificationLogic.js" as NotificationLogic

BorderSurface {
  id: root

  property string app: ""
  property string appIcon: ""
  property string summary: ""
  property string body: ""
  property string image: ""
  // Nerd Font glyph rendered in the icon slot when no real icon is set.
  // Used by omarchy-notification-send so user-action toasts (`Silenced
  // notifications` etc.) show their bell/lock/etc. glyph without leaking
  // into the summary text.
  property string glyph: ""
  // NotificationUrgency: Low=0, Normal=1, Critical=2 (upstream).
  property int urgency: 1
  property double timestamp: 0
  property int cornerRadius: 0

  // System monospace font injected by the container.
  property string fontFamily: ""

  readonly property bool hovered: hoverTracker.hovered

  // Plain {identifier, text} rows, never live NotificationAction objects —

  // see the liveRefs note in Service.qml: a QObject held here is a dangling

  // pointer once the server tears the notification down.

  property var actions: []

  signal actionInvoked(string identifier)

  signal closeRequested()
  signal cardClicked()
  // Prefer per-notification media/avatar data, then fall back to the app icon.
  // The `check` flag avoids Qt's missing-texture placeholder for unknown names.
  readonly property string smallIconSource: image.length > 0 ? image : iconSource(appIcon)
  // Every notification gets a mark. Apps that set an icon or an image keep
  // theirs; the rest fall back to a glyph picked by urgency, so a toast is
  // never a bare block of text. Same Nerd Font family the omarchy-notification-*
  // senders already use for their own toasts.
  readonly property string fallbackGlyph: urgency === 2 ? "󰀪" : (urgency === 0 ? "󰋼" : "󰂚")
  readonly property string effectiveGlyph: glyph.length > 0 ? glyph
    : (hasSmallIcon ? "" : fallbackGlyph)
  readonly property bool hasGlyph: effectiveGlyph.length > 0
  readonly property bool compactGlyph: NotificationLogic.shouldRenderCompactGlyph(effectiveGlyph, smallIconSource, singleLineToast)
  readonly property bool hasSmallIcon: smallIconSource.length > 0
  readonly property bool summaryStartsWithGlyph: NotificationLogic.summaryStartsWithGlyph(summary)
  readonly property bool singleLineToast: sanitizedBody.length === 0
  readonly property bool collapseRedundantIcon: singleLineToast && !hasGlyph && summaryStartsWithGlyph
  readonly property string sanitizedBody: sanitizeBody(body)
  readonly property string styledBody: NotificationLogic.styledBody(body, app, appIcon)

  readonly property color dimColor: Qt.darker(Color.notifications.text, 1.4)
  readonly property color bodyColor: Qt.darker(Color.notifications.text, 1.15)
  readonly property color accentColor: urgency === 2 ? Color.urgent : (urgency === 0 ? dimColor : Color.notifications.countdown)
  // Toast-only treatment. A popup floats over whatever you are doing and has to
  // lift off it; the same card in the history list sits on a panel surface,
  // where a shadow and a moving edge would just be noise.
  property bool elevated: false

  // A slow sweep around the edge. BorderSurface already routes gradient specs
  // through BorderOverlay, so this is the kit's own path, not a second border
  // painted on top: rotating the gradient angle walks the bright stop around
  // the card. Only while elevated, so the history list pays nothing for it.
  property real borderAngle: 0
  NumberAnimation on borderAngle {
    running: root.elevated
    loops: Animation.Infinite
    from: 0
    to: 360
    duration: 6000
  }

  readonly property real borderWidthPx: Math.max(1, Style.space(2))
  readonly property var cardBorderSpec: root.elevated
    ? ({
        color: Color.notifications.border,
        widths: { top: borderWidthPx, right: borderWidthPx, bottom: borderWidthPx, left: borderWidthPx },
        gradient: {
          colors: [
            Util.alpha(Color.notifications.text, 0.08),
            Util.alpha(Color.notifications.countdown, 0.85),
            Util.alpha(Color.notifications.text, 0.08)
          ],
          angle: root.borderAngle,
          enabled: true
        }
      })
    : Border.surfaceSpec("notifications", "border", Color.notifications.border, borderWidthPx)

  function sanitizeBody(s) {
    return NotificationLogic.sanitizeBody(s, app, appIcon)
  }

  function iconSource(icon) {
    var value = String(icon || "")
    if (value.length === 0) return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    return Quickshell.iconPath(value, true)
  }

  implicitWidth: Style.space(380)
  // Add vertical border insets so mainColumn (inset by border on top/left/right)
  // doesn't push content under the bottom edge.
  implicitHeight: mainColumn.implicitHeight + borderTop + borderBottom
  radius: cornerRadius
  color: Color.notifications.background
  borderSpec: cardBorderSpec

  // MultiEffect is the shell's shadow (Tray, LockView, ImagePicker all use it).
  // autoPadding keeps the blur from being clipped to the card's own bounds.
  layer.enabled: root.elevated
  layer.effect: MultiEffect {
    shadowEnabled: true
    autoPaddingEnabled: true
    shadowColor: Qt.rgba(0, 0, 0, 0.38)
    shadowBlur: 0.7
    shadowVerticalOffset: Style.space(6)
  }
  clip: true

  HoverHandler { id: hoverTracker }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        root.closeRequested()
      } else {
        root.cardClicked()
      }
    }
  }

  ColumnLayout {
    id: mainColumn
    // Inset by the card border so the content doesn't paint over the card's
    // outer border.
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.topMargin: root.borderTop
    anchors.leftMargin: root.borderLeft
    anchors.rightMargin: root.borderRight
    spacing: 0

    // Text content.
    RowLayout {
      Layout.fillWidth: true
      // On the theme grid, not raw pixels. shell.toml states the rule —
      // "padding = radius = 24" — and popup-padding is that 24, so a
      // notification is padded like every other floating surface instead of
      // the 12/10/7 it inherited, none of which sat on the 4px grid. A
      // single-line toast drops to lg (16) so it still reads as a toast;
      // both are named tokens, so a density preset moves them together.
      Layout.leftMargin: Style.spacing.popupPadding
      Layout.rightMargin: Style.spacing.popupPadding
      Layout.topMargin: root.singleLineToast ? Style.spacing.lg : Style.spacing.popupPadding
      Layout.bottomMargin: root.singleLineToast ? Style.spacing.lg : Style.spacing.popupPadding
      spacing: root.collapseRedundantIcon ? 0 : (root.compactGlyph ? Style.spacing.controlGap : Style.spacing.md)

      Rectangle {
        id: smallIconSlot
        Layout.preferredWidth: visible ? Style.spacing.xxxl : 0
        Layout.preferredHeight: visible ? Style.spacing.xxxl : 0
        radius: width / 2
        // A plate only behind the glyph. A real app icon or avatar is its own
        // mark and does not want a disc under it.
        color: root.hasSmallIcon ? "transparent" : Util.alpha(Color.notifications.text, 0.25)
        Layout.alignment: Qt.AlignVCenter
        // Hide the slot when the icon failed to resolve (themed-icon name
        // not in the user's icon theme) AND we don't have a glyph fallback
        // — prevents rendering Qt's pink broken-image placeholder.
        visible: !root.collapseRedundantIcon && !root.compactGlyph && (root.hasSmallIcon || root.hasGlyph) && (root.hasGlyph || smallIconImage.status !== Image.Error)

        Image {
          id: smallIconImage
          anchors.fill: parent
          source: root.smallIconSource
          sourceSize.width: smallIconSlot.width * Screen.devicePixelRatio
          sourceSize.height: smallIconSlot.height * Screen.devicePixelRatio
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          smooth: true
          visible: !root.hasGlyph || smallIconImage.status === Image.Ready
        }

        // Glyph fallback (Nerd Font character) when no image icon is
        // available. Used by omarchy-notification-send's `-g` flag.
        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          visible: root.hasGlyph && smallIconImage.status !== Image.Ready
          text: root.effectiveGlyph
          color: Color.notifications.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.icon
        }
      }

      Text {
        textFormat: Text.PlainText
        Layout.alignment: Qt.AlignVCenter
        visible: root.compactGlyph
        text: root.effectiveGlyph
        color: Color.notifications.text
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        // label-gap is the token for exactly this: a line and the line that
        // explains it.
        spacing: Style.spacing.labelGap

        Text {
          // The spec defines the summary as a single line of plain text, so
          // AutoText could only ever promote a hostile string to rich text.
          // The body below is StyledText on purpose — see Service.qml's
          // bodyMarkupSupported — and is stripped in NotificationLogic.
          textFormat: Text.PlainText
          Layout.fillWidth: true
          visible: root.summary.length > 0
          text: root.summary
          font.family: "Liberation Sans"
          color: Color.notifications.text
          font.pixelSize: Style.font.title
          font.bold: true
          wrapMode: Text.WordWrap
          elide: Text.ElideRight
          maximumLineCount: 2
        }

        Text {
          Layout.fillWidth: true
          Layout.topMargin: Style.spacing.labelGap
          visible: root.sanitizedBody.length > 0
          text: root.styledBody
          textFormat: Text.StyledText
          font.family: "Liberation Sans"
          color: root.bodyColor
          font.pixelSize: Style.font.title
          wrapMode: Text.WordWrap
          elide: Text.ElideRight
          maximumLineCount: 3
        }
      }
    }
    // Actions the sender registered. Rendered only when there are any, so an
    // ordinary toast keeps its shape. The first is the primary — it carries the
    // accent fill, the rest are ink washes — which is the same weighting the
    // profile pills use, so a button means the same thing across the theme.
    Flow {
      visible: root.actions.length > 0
      Layout.fillWidth: true
      Layout.leftMargin: Style.spacing.popupPadding
      Layout.rightMargin: Style.spacing.popupPadding
      Layout.bottomMargin: Style.spacing.popupPadding
      spacing: Style.spacing.controlGap

      Repeater {
        model: root.actions

        Rectangle {
          id: actionPill
          required property var modelData
          required property int index
          readonly property bool primary: index === 0
          readonly property bool hot: actionMouse.containsMouse

          implicitWidth: actionLabel.implicitWidth + Style.spacing.controlPaddingX * 2
          implicitHeight: actionLabel.implicitHeight + Style.spacing.controlPaddingY * 2
          width: implicitWidth
          height: implicitHeight
          radius: Style.cornerRadius
          color: actionPill.primary
            ? Util.alpha(Color.notifications.countdown, actionPill.hot ? 1.0 : 0.85)
            : Util.alpha(Color.notifications.text, actionPill.hot ? 0.24 : 0.14)
          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            id: actionLabel
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: String(actionPill.modelData.text || actionPill.modelData.identifier || "")
            color: Color.notifications.text
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.actionInvoked(String(actionPill.modelData.identifier || ""))
          }
        }
      }
    }

  }

  // Close. Right-click anywhere on the card already dismissed, but that is a
  // gesture you have to know; this is the one that is visible. It fades in on
  // hover so a resting stack of notifications stays clean, and it sits above
  // the card-wide MouseArea so its own click is not swallowed into cardClicked.
  Rectangle {
    id: closeButton
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: root.borderTop + Style.spacing.sm
    anchors.rightMargin: root.borderRight + Style.spacing.sm
    width: Style.spacing.xxl
    height: Style.spacing.xxl
    radius: width / 2
    color: closeMouse.containsMouse
      ? Util.alpha(Color.notifications.text, 0.28)
      : Util.alpha(Color.notifications.text, 0.14)
    opacity: root.hovered ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: "\u00d7"
      color: Color.notifications.text
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    MouseArea {
      id: closeMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.closeRequested()
    }
  }

}
