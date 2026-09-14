// Marvin — voxtype's dictation OSD, drawn as Marvin's OSD card.
//
// voxtype's Quickshell frontend loads this through a style package
// (voxtype-osd.toml → qml_entry) and hands it daemonState, audio and theme.
// It replaces voxtype's card outright rather than restyling it, because the two
// things that make a Marvin surface are hard-coded in voxtype's OsdSurface and
// out of reach of its config: the radius is 12, not 24, and the border is 2px
// in the state colour, where Marvin allows one hairline at 10% of the text.
//
// The card is Omarchy's volume and brightness OSD, measured off
// shell/plugins/osd/Osd.qml under Marvin's tokens — pad 16, gap 16, a 142px
// middle column, a 56px glyph, background at 0.97, the popups hairline,
// radius 24, 67 above the screen edge. Dictating and changing the volume put
// up one kind of surface: glyph, a live signal where the bar goes, a readout
// where the percentage goes.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  // Wired by voxtype's OsdSurface (_syncCustomItem).
  property string daemonState: "idle"
  property var audio: null
  property var theme: null
  property var recipe: null
  property string assetRoot: ""

  readonly property bool active: daemonState !== "idle" && daemonState !== ""
  readonly property bool listening: daemonState === "recording" || daemonState === "streaming"

  // ---------------------------------------------------------------- tone
  // Read from the live colors.toml rather than from voxtype's resolved roles.
  // voxtype resolves the Omarchy palette once, when the OSD process starts, so
  // a light/dark switch would leave the card in the old tone until the daemon
  // restarts. This follows the switch, and re-reads at the start of every
  // dictation. voxtype's roles are only the fallback.
  property var palette: ({})

  function parseColors(text) {
    var out = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = /^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9a-fA-F]{6})"/.exec(lines[i])
      if (m) out[m[1]] = m[2]
    }
    return out
  }

  function tone(key, role, fallback) {
    if (palette[key]) return palette[key]
    return theme && theme.color ? theme.color(role, fallback) : fallback
  }

  function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  readonly property color ink:    tone("foreground", "foreground", "#d6d6d6")
  readonly property color muted:  tone("muted", "muted", "#8c8c8c")
  readonly property color ground: tone("background", "background", "#161616")
  readonly property color accent: tone("accent", "accent", "#6db8ee")
  // color1 is the positional alias of Marvin's red (colors.toml), so this is
  // the ramp's soft red, never voxtype's saturated one.
  readonly property color danger: tone("color1", "error", "#e38484")

  readonly property string stateDir: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")

  FileView {
    id: colorsFile
    path: root.stateDir + "/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.palette = root.parseColors(text())
    onFileChanged: reload()
  }

  // ------------------------------------------------------------ geometry
  readonly property int pad: 16
  readonly property int gap: 16
  readonly property int middleWidth: 142
  readonly property int glyphSize: 56
  readonly property int hairline: 1

  readonly property string glyphFamily: "JetBrainsMono Nerd Font"
  readonly property string micGlyph: String.fromCodePoint(0xF036C)   // microphone
  readonly property string busyGlyph: String.fromCodePoint(0xF051F)  // timer-sand

  // The glyph column is as wide as the wider of the two glyphs, measured by
  // ink, so the signal does not shift sideways when listening turns into
  // transcribing — the same reason Omarchy pins its column to the widest icon.
  TextMetrics { id: micInk;  font.family: root.glyphFamily; font.pixelSize: root.glyphSize; text: root.micGlyph }
  TextMetrics { id: busyInk; font.family: root.glyphFamily; font.pixelSize: root.glyphSize; text: root.busyGlyph }
  readonly property int glyphColumn: Math.ceil(Math.max(micInk.tightBoundingRect.width, busyInk.tightBoundingRect.width))

  // The readout is sized to its widest value so the digits never jitter.
  TextMetrics { id: readoutInk; font: readout.font; text: "0:00" }
  readonly property int readoutWidth: Math.ceil(readoutInk.advanceWidth)

  // --------------------------------------------------------------- signal
  // Peaks arrive at 100 Hz. They are folded into buckets, one per bar, so the
  // strip covers the last three seconds, and published at 30 Hz so the bars
  // re-bind thirty times a second instead of a hundred.
  readonly property int barWidth: 2
  readonly property int barGap: 2
  readonly property int barCount: Math.floor((middleWidth + barGap) / (barWidth + barGap))
  readonly property int framesPerBar: Math.max(1, Math.round(300 / barCount))
  // -3 dBFS, voxtype's own high zone. Above it a bar is drawn in the soft red.
  readonly property real clipLevel: 0.708

  property var history: []
  property real livePeak: 0
  property int liveFrames: 0
  property var levels: []

  function levelAt(i) {
    return i < levels.length ? levels[i] : 0
  }

  function resetSignal() {
    history = []
    levels = []
    livePeak = 0
    liveFrames = 0
  }

  Connections {
    target: root.audio
    enabled: root.audio !== null
    function onFrameReceived(peak, rms, vad, tsMs) {
      if (!root.listening) return
      root.livePeak = Math.max(root.livePeak, peak)
      root.liveFrames += 1
      if (root.liveFrames >= root.framesPerBar) {
        var h = root.history.slice()
        h.push(root.livePeak)
        while (h.length > root.barCount - 1) h.shift()
        root.history = h
        root.livePeak = 0
        root.liveFrames = 0
      }
    }
    function onDisconnected() { root.resetSignal() }
  }

  Timer {
    interval: 33
    repeat: true
    running: root.listening
    onTriggered: {
      var out = root.history.slice()
      out.push(root.livePeak)
      while (out.length < root.barCount) out.unshift(0)
      root.levels = out
    }
  }

  // -------------------------------------------------------------- elapsed
  property double startedAt: 0
  property int elapsedMs: 0
  readonly property string elapsedText: {
    var s = Math.floor(elapsedMs / 1000)
    return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2)
  }

  Timer {
    interval: 200
    repeat: true
    running: root.listening && root.startedAt > 0
    onTriggered: root.elapsedMs = Date.now() - root.startedAt
  }

  // Reads daemonState directly, not `listening` or `active`. A change handler
  // can run before the bindings derived from the same property re-evaluate, so
  // those still held the previous state here — and the clock was reset by the
  // very change that should have started it, leaving the readout at 0:00.
  function syncState() {
    var s = daemonState
    var nowListening = s === "recording" || s === "streaming"
    var nowActive = s !== "idle" && s !== ""
    if (nowListening && startedAt === 0) {
      startedAt = Date.now()
      elapsedMs = 0
      colorsFile.reload()
    } else if (!nowActive) {
      startedAt = 0
      elapsedMs = 0
      resetSignal()
    }
  }
  onDaemonStateChanged: syncState()
  Component.onCompleted: syncState()

  // ----------------------------------------------------------------- card
  Rectangle {
    id: card
    // State is muted text: while transcribing, everything that was live —
    // glyph, signal, readout — drops to the muted tone and holds still.
    readonly property color liveInk: root.listening ? root.ink : root.muted

    width: root.hairline + root.pad + root.glyphColumn + root.gap + root.middleWidth + root.gap + root.readoutWidth + root.pad + root.hairline
    height: root.hairline + root.pad + root.glyphSize + root.pad + root.hairline
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 67
    radius: 24
    color: root.withAlpha(root.ground, 0.97)
    border.width: root.hairline
    border.color: root.withAlpha(root.ink, 0.10)

    Item {
      x: root.hairline + root.pad
      y: root.hairline + root.pad
      width: card.width - 2 * (root.hairline + root.pad)
      height: root.glyphSize

      Text {
        id: glyph
        textFormat: Text.PlainText
        readonly property var ink: root.listening ? micInk : busyInk
        // Ink flush in the column, centred when the column is wider than
        // this glyph — Omarchy's placement, so both OSDs sit their icon alike.
        x: Math.round((root.glyphColumn - ink.tightBoundingRect.width) / 2 - ink.tightBoundingRect.x)
        anchors.verticalCenter: parent.verticalCenter
        text: root.listening ? root.micGlyph : root.busyGlyph
        font.family: root.glyphFamily
        font.pixelSize: root.glyphSize
        font.hintingPreference: Font.PreferFullHinting
        color: card.liveInk
        Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }
      }

      Item {
        id: signal
        x: root.glyphColumn + root.gap
        width: root.middleWidth
        height: 40
        anchors.verticalCenter: parent.verticalCenter

        // Silence is a row of 2px dots on the centre line — the hairline track
        // a Marvin progress bar keeps under its fill.
        Repeater {
          model: root.barCount
          Rectangle {
            required property int index
            readonly property real level: root.levelAt(index)
            x: index * (root.barWidth + root.barGap)
            width: root.barWidth
            // Square root, because a voice peaks around 0.1–0.3 of full scale
            // and a linear strip would sit near the floor. Even heights keep
            // the mirror centred on a whole pixel.
            height: Math.max(2, Math.round(Math.sqrt(Math.min(1, level * 1.6)) * signal.height / 2) * 2)
            anchors.verticalCenter: parent.verticalCenter
            radius: width / 2
            color: !root.listening ? root.muted
                 : level >= root.clipLevel ? root.danger
                 : root.accent
          }
        }
      }

      Text {
        id: readout
        textFormat: Text.PlainText
        x: root.glyphColumn + root.gap + root.middleWidth + root.gap
        width: root.readoutWidth
        horizontalAlignment: Text.AlignRight
        anchors.verticalCenter: parent.verticalCenter
        text: root.elapsedText
        // Omarchy's readout font (title, bold) with tabular figures, and
        // full hinting for the reason docs/platform-constraints.md gives
        // under Text rendering at fractional scale.
        font.family: "Inter"
        font.pixelSize: 16
        font.bold: true
        font.features: ({ "tnum": 1 })
        font.hintingPreference: Font.PreferFullHinting
        color: card.liveInk
        Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }
      }
    }
  }
}
