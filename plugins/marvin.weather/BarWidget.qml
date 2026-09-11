import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.weather"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = root.activeButton
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  // Shape contract for shell.summon/hide/toggle routing (Bar.findPanelWidget
  // requires open/close/opened on the bar-widget root). Open maps to the
  // panel's hotkey path so summoning suppresses the center hover reveal,
  // matching what the old per-plugin IpcHandler did.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close, and
  // KeyboardPanel reads popoutSwitchClosing back off its owner.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  // Always visible once the panel loads. It shows a placeholder glyph until the
  // first reading arrives (location auto-detects from your IP, so it fills in on
  // its own). Gating visibility on data made an enabled widget invisible while
  // it fetched, which read as "weather won't turn on".
  visible: panelLoader.item !== null
  // Whichever of the two is showing owns the slot and the panel anchor.
  readonly property var activeButton: barShowsDegree ? degreeButton : glyphButton
  implicitWidth: activeButton.implicitWidth
  implicitHeight: activeButton.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // The reading as the bar sees it: the rounded degree, no unit letter — the
  // panel carries °F/°C, the bar only needs the number. Empty until the first
  // fetch lands, and dropped on a vertical bar, where a wide text block cannot
  // fit the slot.
  readonly property string barGlyph: (panelLoader.item && panelLoader.item.label !== "") ? panelLoader.item.label : "\uf0c2"
  readonly property string barDegree: (panelLoader.item && panelLoader.item.reportTempNum) ? (panelLoader.item.reportTempNum + "°") : ""
  readonly property bool barVertical: root.bar ? root.bar.vertical : false
  readonly property bool barShowsDegree: barDegree !== "" && !barVertical
  readonly property string tooltip: (panelLoader.item && panelLoader.item.label !== "") ? "" : "Weather — fetching your location…"

  // With a reading the widget paints a text run rather than a mark, so the
  // open-panel underline takes the painted label width. Left unset, the bar
  // falls back to an icon-sized fraction of the slot and the rule stops short
  // of the glyph. Zero hands it back to that fallback for the icon-only case,
  // which is what the fallback is sized for.
  readonly property real openPanelIndicatorWidth: barShowsDegree ? degreeButton.labelWidth : 0

  function handlePress(b) {
    if (!root.bar) return
    if (b === Qt.RightButton) root.bar.run("omarchy-notification-send \"$(omarchy-weather-status)\"")
    else if (b === Qt.MiddleButton) root.refresh()
    else root.togglePanel()
  }

  // Two buttons, one showing at a time, because the two states want different
  // text machinery.
  //
  // Icon only — the cloud placeholder before the first fetch, and every
  // vertical bar — goes through BarIconButton, whose OpticalGlyph centres a
  // single mark on its painted bounds rather than its line box. That is the
  // right treatment for a mark and the wrong one for a run of characters,
  // which wants its line box centred like any other label. So the reading goes
  // through the plain label, the same path marvin.clock puts its time through.
  // It also sizes itself to what it paints, instead of the doubled icon slot
  // the previous version guessed at.
  BarIconButton {
    id: glyphButton
    anchors.fill: parent
    visible: !root.barShowsDegree
    bar: root.bar
    text: root.barGlyph
    slotSize: Style.bar.statusSlot
    tooltipText: root.tooltip
    onPressed: function(b) { root.handlePress(b) }
  }

  WidgetButton {
    id: degreeButton
    anchors.fill: parent
    visible: root.barShowsDegree
    bar: root.bar
    labelVisible: true
    // Degree then glyph, the order marvin.power uses for its percentage.
    text: root.barDegree + " " + root.barGlyph
    fontSize: Style.bar.iconFont
    tooltipText: root.tooltip
    onPressed: function(b) { root.handlePress(b) }
  }
}
