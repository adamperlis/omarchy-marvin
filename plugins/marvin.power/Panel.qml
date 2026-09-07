import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Marvin power panel. A clone of omarchy.power: UPower bindings, processes,
// profiles, IPC and the bar button below are upstream's, verbatim. Only the
// layout after KeyboardPanel is rewritten, to the Marvin rules: the charge
// percentage is the largest thing on the card; charge is a 2px hairline;
// stats are value over label; no divider before the profiles; two tones.
Panel {
  id: root
  moduleName: "omarchy.power"
  ipcTarget: "omarchy.power"

  // Tone. [marvin-power] in shell.toml inverts the card; absent, the card
  // takes the popup surface. attention-fill / attention-text make the chip.
  readonly property var toneValues: Color.shellValues
  readonly property bool tinted: !!(toneValues["marvin-power.background"])
  readonly property color tintBackground: tinted ? Color.flatColor(toneValues["marvin-power.background"], Color.popups.background) : Color.popups.background
  readonly property color ink: (tinted && toneValues["marvin-power.text"]) ? Color.flatColor(toneValues["marvin-power.text"], Color.popups.text) : Color.popups.text
  readonly property color inkMuted: (tinted && toneValues["marvin-power.muted"]) ? Color.flatColor(toneValues["marvin-power.muted"], Color.muted) : Color.muted
  readonly property color chipFill: toneValues["marvin-power.attention-fill"] ? Color.flatColor(toneValues["marvin-power.attention-fill"], Util.alpha(ink, 0.08)) : Util.alpha(ink, 0.08)
  readonly property color chipText: toneValues["marvin-power.attention-text"] ? Color.flatColor(toneValues["marvin-power.attention-text"], ink) : ink
  // manageIpc: false so this panel can own the single IpcHandler the target
  // permits — needed for the togglePercentage method below.
  manageIpc: false
  property var batteryInfo: ({})
  property var systemInfo: ({})
  property var profiles: []
  property string activeProfile: ""
  property int profileIndex: 0
  property bool cursorActive: false
  readonly property bool showPercentage: setting("showPercentage", false) === true
  // With the percentage shown the button paints a text block wider than an
  // icon, so the open-panel mark takes the painted width instead of the
  // icon-sized fraction of the slot the fallback assumes.
  readonly property real openPanelIndicatorWidth: showPercentage && !button.vertical ? button.glyphPaintedWidth : 0
  readonly property bool batteryPresent: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent)
  }

  function upowerStates() {
    return {
      Charging: UPowerDeviceState.Charging,
      Discharging: UPowerDeviceState.Discharging,
      FullyCharged: UPowerDeviceState.FullyCharged,
      PendingCharge: UPowerDeviceState.PendingCharge
    }
  }

  function selectProfileByDelta(delta) {
    profileIndex = Model.selectProfileIndex(profileIndex, delta, profiles)
  }

  function activateSelectedProfile() {
    if (profileIndex < 0 || profileIndex >= profiles.length) return
    setProfile(profiles[profileIndex])
  }

  function batteryIcon() {
    var device = UPower.displayDevice
    return Model.batteryIcon(device, root.discharging, upowerStates())
  }

  function modeLabel() {
    var device = UPower.displayDevice
    return Model.modeLabel(device, root.discharging, upowerStates())
  }

  function profileIcon(name) {
    return Model.profileIcon(name)
  }

  readonly property bool fullyCharged: {
    var device = UPower.displayDevice
    return device && device.isPresent && device.state === UPowerDeviceState.FullyCharged && !root.chargeThresholdActive
  }
  readonly property bool discharging: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent && UPower.onBattery)
  }
  readonly property bool chargeThresholdActive: {
    var device = UPower.displayDevice
    return Model.chargeThresholdActive(device, root.discharging, upowerStates())
  }
  readonly property bool batteryFull: fullyCharged || (!root.discharging && batteryFraction >= 1)
  readonly property bool batteryFlowIdle: batteryFull || chargeThresholdActive

  // 0..1 charge level, used by the visual progress bar.
  readonly property real batteryFraction: {
    var d = UPower.displayDevice
    return Model.batteryFraction(d)
  }

  readonly property bool charging: {
    var d = UPower.displayDevice
    return d && d.isPresent && !UPower.onBattery && !root.batteryFlowIdle
  }

  readonly property color batteryFillColor: {
    return root.bar ? root.bar.foreground : Color.foreground
  }

  // Cute agent-flavored phrases shown in the hero status line, rotated on a
  // timer so the panel feels alive when current is flowing (either direction).
  readonly property var chargingPhrases: [
    "Pumping power",
    "Injecting electrons",
    "Pouring juice",
    "Amassing watts",
    "Hoarding joules",
    "Sucking volts",
    "Topping reserves",
    "Soaking amps",
    "Inhaling kilowatts"
  ]
  readonly property var onBatteryPhrases: [
    "Slurping power",
    "Spending joules",
    "Draining watts",
    "Burning electrons",
    "Sipping juice",
    "Spending coulombs",
    "Bleeding amps",
    "Guzzling volts",
    "Munching reserves"
  ]
  property int phraseIndex: 0

  // Whichever list is "active" given the current power state.
  readonly property var activePhrases: {
    if (fullyCharged) return []
    if (charging) return chargingPhrases
    if (discharging) return onBatteryPhrases
    return []
  }
  readonly property bool rotatingPhrases: activePhrases.length > 0

  readonly property string heroStatusText: {
    if (fullyCharged) return "Fully charged"
    if (rotatingPhrases) return activePhrases[phraseIndex % activePhrases.length]
    return modeLabel()
  }

  function refresh() {
    if (!batteryPresent) return

    if (!batteryProc.running) batteryProc.running = true
    if (!profilesProc.running) profilesProc.running = true
    if (!systemProc.running) systemProc.running = true
  }

  function updateKeyValue(raw, targetName) {
    var next = Model.parseKeyValue(raw)
    // Keep last known good data if a refresh briefly returns nothing — happens
    // around AC plug/unplug events. Avoids the section collapsing mid-transition.
    if (Object.keys(next).length === 0) return
    if (targetName === "battery") batteryInfo = next
    else systemInfo = next
  }

  function updateProfiles(raw) {
    var parsed = Model.parseProfiles(raw, profileIndex)
    // Same guard as battery: preserve the last known profile list across
    // transient empty payloads so the buttons don't blink out.
    if (parsed.profiles.length === 0) return
    profiles = parsed.profiles
    activeProfile = parsed.activeProfile
    profileIndex = parsed.profileIndex
    if (opened && !cursorActive) {
      var idx = profiles.indexOf(activeProfile)
      if (idx >= 0) profileIndex = idx
    }
  }

  function setProfile(profile) {
    if (!profile || actionProc.running) return
    actionProc.command = ["omarchy-powerprofiles-set", root.discharging ? "battery" : "ac", profile]
    actionProc.running = true
  }

  function togglePercentage() {
    root.settings = Object.assign({}, root.settings, { showPercentage: !root.showPercentage })
    if (root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, root.settings)
  }

  IpcHandler {
    target: "omarchy.power"

    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function togglePercentage() { root.togglePercentage() }
  }

  onOpenedChanged: {
    if (opened) {
      if (!batteryPresent) {
        close()
        return
      }

      refresh()
      var idx = profiles.indexOf(activeProfile)
      profileIndex = idx >= 0 ? idx : 0
      cursorActive = false
    }
  }

  onBatteryPresentChanged: if (!batteryPresent) close()

  visible: batteryPresent
  implicitWidth: batteryPresent ? button.implicitWidth : 0
  implicitHeight: batteryPresent ? button.implicitHeight : 0

  Process {
    id: batteryProc
    command: ["omarchy-battery-status", "--shell"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateKeyValue(text, "battery") }
  }

  Process {
    id: profilesProc
    command: ["omarchy-powerprofiles-list", "--active-state"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateProfiles(text) }
  }

  Process {
    id: systemProc
    command: ["omarchy-system-stats"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateKeyValue(text, "system") }
  }

  Process {
    id: actionProc
    onExited: root.refresh()
  }

  Timer { interval: 5000; running: root.opened; repeat: true; onTriggered: root.refresh() }

  // Rotate the status phrase while the panel is open and we're in a
  // rotating state (charging or on battery). The text swap is wrapped in a
  // fade so the changeover reads as one organism rather than a hard cut.
  Timer {
    id: phraseTimer
    interval: 2800
    running: root.opened && root.rotatingPhrases
    repeat: true
    triggeredOnStart: false
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap
    PropertyAnimation {
      target: heroStatus; property: "opacity"
      to: 0.0; duration: 180; easing.type: Easing.OutQuad
    }
    ScriptAction {
      script: {
        var n = root.activePhrases.length
        if (n > 0) root.phraseIndex = (root.phraseIndex + 1) % n
      }
    }
    PropertyAnimation {
      target: heroStatus; property: "opacity"
      to: 1.0; duration: 260; easing.type: Easing.InQuad
    }
  }

  // If we leave a rotating state mid-swap, halt the animation and snap back
  // to full opacity so "FULLY CHARGED" is legible immediately rather than
  // appearing dimmed.
  Connections {
    target: root
    function onRotatingPhrasesChanged() {
      if (!root.rotatingPhrases) {
        phraseSwap.stop()
        heroStatus.opacity = 1.0
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.showPercentage && !vertical
      ? Math.round(root.batteryFraction * 100) + "% " + root.batteryIcon()
      : root.batteryIcon()
    slotSize: Style.bar.iconSlot * (root.showPercentage && !vertical ? 2 : 1)
    tooltipText: ""
    onPressed: function(b) {
      if (!root.batteryPresent) return
      if (b === Qt.RightButton) root.togglePercentage()
      else root.toggle()
    }
  }
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.batteryPresent
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(328))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    // Surface tone, drawn to the card's own shape beneath the content.
    Rectangle {
      anchors.fill: parent
      anchors.margins: -panel.padding
      radius: Style.cornerRadius
      color: root.tintBackground
      visible: root.tinted
      z: -1
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dx !== 0) root.selectProfileByDelta(dx)
        else if (dy !== 0) root.selectProfileByDelta(dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateSelectedProfile()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.spacing.xxl

        // ---- Header: the name, and the state as a soft-fill chip.
        Item {
          width: parent.width
          height: Style.spacing.controlHeight

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Battery"
            color: root.ink
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.title
            font.weight: Font.Medium
          }

          Rectangle {
            id: chip
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Style.spacing.xxl
            width: heroStatus.implicitWidth + Style.spacing.md * 2
            radius: Style.cornerRadius
            color: root.charging || root.chargeThresholdActive ? root.chipFill : Util.alpha(root.ink, Style.normalFillAlpha)
            Behavior on color { ColorAnimation { duration: 200 } }

            Text {
              id: heroStatus
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: root.heroStatusText
              color: root.charging || root.chargeThresholdActive ? root.chipText : root.inkMuted
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        // ---- Hero: the percentage inside a ring of sixty ticks, the charge
        //      lit in ink and the rest at the normal fill.
        Item {
          width: parent.width
          height: ring.height

          Item {
            id: ring
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.spacing.huge * 3          // 144
            height: width
            readonly property int lit: Math.round(root.batteryFraction * 60)

            Repeater {
              model: 60
              Rectangle {
                required property int index
                width: Style.spacing.xxs
                height: Style.spacing.sm
                radius: 1
                x: ring.width / 2 - width / 2
                y: 0
                color: index < ring.lit ? root.ink : Util.alpha(root.ink, Style.normalFillAlpha)
                transform: Rotation { origin.x: Style.spacing.xxs / 2; origin.y: ring.height / 2; angle: index * 6 }
                Behavior on color { ColorAnimation { duration: 220 } }
              }
            }

            SequentialAnimation on opacity {
              running: root.charging && !root.fullyCharged && root.opened
              loops: Animation.Infinite
              alwaysRunToEnd: true
              NumberAnimation { from: 1.0; to: 0.6; duration: 950; easing.type: Easing.InOutSine }
              NumberAnimation { from: 0.6; to: 1.0; duration: 950; easing.type: Easing.InOutSine }
            }

            Text {
              id: heroPercent
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: root.batteryInfo.percentage || "—"
              color: root.ink
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.displayLarge
              font.letterSpacing: -Style.font.displayLarge * 0.03
              font.weight: Font.Medium
            }
          }
        }

        // ---- Stats: value over label, two columns.
        Row {
          visible: root.batteryInfo.percentage !== undefined
          width: parent.width
          spacing: Style.spacing.xxl

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.lg
            Stat { value: root.batteryInfo.size || "—"; label: "Battery size" }
            Stat { value: root.batteryInfo.cycles || "—"; label: "Charge cycles" }
          }

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.lg
            Stat {
              value: root.chargeThresholdActive ? (root.batteryInfo.threshold || "—") : (root.batteryFlowIdle ? "—" : (root.batteryInfo.time || "—"))
              label: root.chargeThresholdActive ? "Charge limit" : (root.discharging ? "Time left" : "Time to full")
            }
            Stat {
              value: root.chargeThresholdActive ? "Holding" : (root.batteryFull ? "—" : (root.batteryInfo.rate || "—"))
              label: root.chargeThresholdActive ? "Battery state" : (root.discharging ? "Discharging" : "Charging")
            }
          }
        }

        // ---- Power profile. A caption and content-sized pills that wrap.
        Column {
          width: parent.width
          spacing: Style.spacing.sm

          Text {
            text: "Power profile"
            color: root.inkMuted
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }

          Flow {
            id: profileRow
            width: parent.width
            spacing: Style.spacing.sm

            Repeater {
              model: root.profiles
              Button {
                required property var modelData
                required property int index
                iconText: root.profileIcon(String(modelData))
                iconSize: Style.font.iconSmall
                text: String(modelData).charAt(0).toUpperCase() + String(modelData).slice(1)
                fontSize: Style.font.body
                foreground: root.ink
                fontFamily: root.bar.fontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY
                bordered: false
                active: root.activeProfile === modelData
                hasCursor: root.cursorActive && root.profileIndex === index
                onClicked: root.setProfile(modelData)
                onHovered: function(h) {
                  if (h) {
                    root.cursorActive = true
                    root.profileIndex = index
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  component Stat: Column {
    property string label: ""
    property string value: ""
    spacing: Style.spacing.xs

    Text {
      textFormat: Text.PlainText
      text: value
      color: root.ink
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.title
    }
    Text {
      textFormat: Text.PlainText
      text: label
      color: root.inkMuted
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
