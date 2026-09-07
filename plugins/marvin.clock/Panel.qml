import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model
// Marvin clock panel. A clone of omarchy.clock: the date logic, settings
// persistence, keyboard handling and system clock below are upstream's,
// verbatim. Only the layout after KeyboardPanel is rewritten, to the Marvin
// rules: the day number is the largest thing on the card and the month is
// its caption; progress is a 2px hairline; the grid has no rules and no
// gutter line; today is a fill, not an outline; two text tones.
// anchor against.
Panel {
  id: root
  moduleName: "omarchy.clock"
  ipcTarget: "omarchy.clock"
  manageIpc: false

  property var anchorItem: null

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel. Everything the bar identifies a panel by has to be that
  // widget: the popout coordinator (and with it the open-panel dot under the
  // pill) compares against `slot.activeItem`, and switchPanelFrom looks the
  // slot up the same way.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // ---- Today. SystemClock keeps this honest across midnight so the
  //      highlight rolls over without the panel being reopened.
  property date today: new Date()
  readonly property string todayKey: Model.keyForDate(today)

  // The month on screen. Stepping moves this and nothing else: the grid is
  // a read-out, not a picker, so there is no per-day cursor to keep in sync.
  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()

  readonly property date viewDate: new Date(viewYear, viewMonth, 1)
  readonly property bool viewingCurrentMonth: viewYear === today.getFullYear() && viewMonth === today.getMonth()

  // Pinned to today, not to the month being browsed — stepping through the
  // calendar does not change how much of the year is gone.
  readonly property real yearDone: Model.yearProgress(today.getFullYear(), today.getMonth(), today.getDate())
  readonly property int yearDonePercent: Model.yearProgressPercent(today.getFullYear(), today.getMonth(), today.getDate())

  // Memento mori, for anyone who goes looking: double-tapping the year bar
  // asks for a birth year and a life expectancy, and a second bar tracks one
  // against the other. A birth year rather than an age, so it keeps counting
  // on its own. Without one the bar stays hidden.
  readonly property int birthYear: Model.parseBirthYear(setting("birthYear", 0), today.getFullYear())
  readonly property int age: Model.ageFromBirthYear(birthYear, today.getFullYear())
  readonly property int lifeExpectancy: Model.parseLifeExpectancy(setting("lifeExpectancy", 0))
  readonly property real lifeDone: Model.lifeProgress(age, lifeExpectancy)
  readonly property int lifeDonePercent: Model.lifeProgressPercent(age, lifeExpectancy)
  property bool editingLife: false

  // Unset falls through to the locale's own first day, so a fresh install
  // starts out matching the rest of the desktop rather than a hardcoded
  // convention. Clicking the grid's "W" heading writes the choice back to
  // shell.json.
  readonly property int weekStart: Model.normalizedWeekStart(setting("weekStartDay", null), Qt.locale().firstDayOfWeek)
  // The interface is English throughout, so day names are not taken from the
  // system locale. Where the week starts still is: that is a regional
  // convention rather than a translation, and it stays overridable above.
  readonly property var labelLocale: Qt.locale("en_US")
  readonly property string nextWeekStartLabel: labelLocale.dayName(Model.toggledWeekStart(weekStart), Locale.LongFormat)
  readonly property var weekdays: Model.weekdayOrder(weekStart)
  readonly property var weeks: Model.monthGrid(viewYear, viewMonth, weekStart, todayKey)


  // Guarded so the widget renders before the bar is injected (the bar-widget
  // contract instantiates it bare).
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property int cellWidth: Style.spacing.xxxl + Style.spacing.xs   // 36
  readonly property int cellHeight: Style.spacing.controlHeight             // 32
  readonly property int cellSpacing: 0
  readonly property int weekColumnWidth: Style.spacing.xxxl                  // 32
  readonly property int gutterWidth: Style.spacing.xl                       // 20

  function open() {
    refresh()
    root.controller.show()
    // Set after showing, not before: showing hands the popout coordinator
    // over, which closes whichever panel was open, and that close clears the
    // shared flag. Deferring means the panel taking over always wins, while
    // a handoff to a panel that does not manage the flag still leaves it
    // cleared rather than stuck on.
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    // Dismissing the panel mid-edit would otherwise leave the inputs up,
    // waiting behind a closed popup for the next time it opens.
    if (root.editingLife) root.cancelEditingLife()
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // Summoning by hotkey moves no pointer, so a hover the bar was still
  // holding must not keep the center indicators revealed behind the panel.
  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function refresh() {
    root.today = new Date()
    root.goToToday()
  }

  function goToToday() {
    root.viewYear = today.getFullYear()
    root.viewMonth = today.getMonth()
  }

  function moveMonth(delta) {
    var next = Model.stepMonth(viewYear, viewMonth, delta)
    root.viewYear = next.year
    root.viewMonth = next.month
  }

  function moveYear(delta) {
    moveMonth(delta * 12)
  }

  // Applied locally first so the panel redraws on the click itself; the
  // shell.json write comes back through the bar as the same value. With no
  // writable entry (the widget is not in the layout) it stays a session-only
  // preference rather than doing nothing. The host widget builds its own
  // entry when the label format is cycled, so it has to be kept in step or
  // it would write this key straight back out from a stale copy.
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setWeekStart(day) {
    var next = Model.normalizedWeekStart(day, root.weekStart)
    if (next === root.weekStart) return
    persistSettings({ weekStartDay: Model.weekStartSettingName(next) })
  }

  function startEditingLife() {
    root.editingLife = true
    Qt.callLater(function() {
      bornField.text = root.birthYear > 0 ? String(root.birthYear) : ""
      expectancyField.text = String(root.lifeExpectancy)
      bornField.selectAll()
      bornField.forceActiveFocus()
    })
  }

  function cancelEditingLife() {
    root.editingLife = false
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  // Shared by both fields: Tab hops to the other one, Enter commits the pair,
  // Escape drops the lot.
  function handleLifeKey(event, other) {
    if (event.key === Qt.Key_Escape) {
      root.cancelEditingLife()
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.commitLife()
      event.accepted = true
    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      other.selectAll()
      other.forceActiveFocus()
      event.accepted = true
    }
  }

  // Double-tapping the life bar puts it away again. The expectancy stays in
  // the config so setting a birth year again brings your own number back
  // rather than the default.
  function clearLife() {
    if (root.birthYear <= 0) return
    persistSettings({ birthYear: 0 })
  }

  function commitLife() {
    var born = Model.parseBirthYear(bornField.text, today.getFullYear())
    var span = Model.parseLifeExpectancy(expectancyField.text)
    if (born !== root.birthYear || span !== root.lifeExpectancy)
      persistSettings({ birthYear: born, lifeExpectancy: span })
    cancelEditingLife()
  }

  function toggleWeekStart() {
    setWeekStart(Model.toggledWeekStart(root.weekStart))
  }

  // English short day names, matching the rest of the interface.
  function weekdayLabel(weekday) {
    return String(labelLocale.dayName(weekday, Locale.ShortFormat)).toUpperCase()
  }

  // Sentence case: the grid header is a label, not a heading.
  function shortWeekdayLabel(weekday) {
    return String(labelLocale.dayName(weekday, Locale.ShortFormat))
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: {
      if (Model.keyForDate(clock.date) === String(root.todayKey)) return
      var followToday = root.viewingCurrentMonth
      root.today = clock.date
      if (followToday) root.goToToday()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.weekColumnWidth + root.gutterWidth + root.cellWidth * 7)
    contentHeight: panel.fittedContentHeight(calendarColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editingLife
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.moveMonth(dx)
        if (dy !== 0) root.moveYear(dy)
      }
      onActivateRequested: root.goToToday()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "[") root.moveMonth(-1)
        else if (t === "]") root.moveMonth(1)
        else if (t === "{") root.moveYear(-1)
        else if (t === "}") root.moveYear(1)
        else if (t === "t" || t === "T") root.goToToday()
        else if (t === "w" || t === "W") root.toggleWeekStart()
      }

      Flickable {
        id: calendarScroll
        anchors.fill: parent
        contentWidth: calendarColumn.width
        contentHeight: calendarColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height || contentWidth > width

        Column {
          id: calendarColumn
          width: Math.max(calendarScroll.width, gridColumn.width)
          spacing: Style.spacing.xxl

          // ---- Hero: the day number, with the month and weekday as its caption.
          //      Once the view has stepped away it is also the way home.
          Item {
            width: parent.width
            height: heroDay.implicitHeight

            Row {
              id: heroRow
              anchors.left: parent.left
              spacing: Style.spacing.md   // the day numeral and the month need air between them

              Text {
                id: heroDay
                textFormat: Text.PlainText
                text: Qt.formatDate(root.today, "d")
                color: heroMouse.containsMouse ? Color.accent : root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.displayLarge
                font.letterSpacing: -Style.font.displayLarge * 0.03
                font.weight: Font.Normal
              }

              Column {
                anchors.top: heroDay.top
                anchors.topMargin: Style.spacing.sm
                spacing: Style.spacing.xxs

                Text {
                  textFormat: Text.PlainText
                  text: Qt.formatDate(root.today, "MMMM")
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                }
                Text {
                  textFormat: Text.PlainText
                  text: Qt.formatDate(root.today, "dddd")
                  color: Color.muted
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }

            MouseArea {
              id: heroMouse
              x: heroRow.x
              y: heroRow.y
              width: heroRow.width
              height: heroRow.height
              enabled: !root.viewingCurrentMonth
              hoverEnabled: enabled
              cursorShape: Qt.PointingHandCursor
              onClicked: root.goToToday()

              PanelToolTip {
                visible: heroMouse.containsMouse
                text: "Back to today"
                fontFamily: root.contentFontFamily
              }
            }
          }

          // ---- Year progress. A 2px hairline; the year and the percent as captions.
          Column {
            width: parent.width
            spacing: Style.spacing.sm

            TapHandler {
              enabled: !root.editingLife
              onDoubleTapped: root.startEditingLife()
            }

            Row {
              visible: root.editingLife
              spacing: Style.spacing.sm

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Born"
                color: Color.muted
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
              TextField {
                id: bornField
                width: Style.space(72)
                anchors.verticalCenter: parent.verticalCenter
                placeholderText: "year"
                foreground: root.contentForeground
                font.family: root.contentFontFamily
                inputMethodHints: Qt.ImhDigitsOnly
                Keys.onPressed: function(event) { root.handleLifeKey(event, expectancyField) }
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: Style.spacing.sm
                text: "Live to"
                color: Color.muted
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
              TextField {
                id: expectancyField
                width: Style.space(64)
                anchors.verticalCenter: parent.verticalCenter
                placeholderText: "90"
                foreground: root.contentForeground
                font.family: root.contentFontFamily
                inputMethodHints: Qt.ImhDigitsOnly
                Keys.onPressed: function(event) { root.handleLifeKey(event, bornField) }
              }
            }

            Item {
              visible: !root.editingLife
              width: parent.width
              height: yearLabel.implicitHeight

              Text {
                id: yearLabel
                textFormat: Text.PlainText
                anchors.left: parent.left
                text: root.today.getFullYear()
                color: Color.muted
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
              Text {
                textFormat: Text.PlainText
                anchors.right: parent.right
                text: root.yearDonePercent + "%"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              visible: !root.editingLife
              width: parent.width
              height: Style.spacing.xxs
              radius: 1
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, Style.normalFillAlpha)

              Rectangle {
                width: Math.round(parent.width * root.yearDone)
                height: parent.height
                radius: parent.radius
                color: root.contentForeground
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
              }
            }
          }

          // ---- Memento mori. Same hairline, only once a birth year is set.
          Column {
            visible: root.birthYear > 0
            width: parent.width
            spacing: Style.spacing.sm

            TapHandler { onDoubleTapped: root.clearLife() }

            Item {
              width: parent.width
              height: lifeLabel.implicitHeight

              Text {
                id: lifeLabel
                anchors.left: parent.left
                text: "Life"
                color: Color.muted
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
              Text {
                textFormat: Text.PlainText
                anchors.right: parent.right
                text: root.lifeDonePercent + "%"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                id: lifeMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                PanelToolTip {
                  visible: lifeMouse.containsMouse
                  text: "Memento Mori"
                  fontFamily: root.contentFontFamily
                }
              }
            }

            Rectangle {
              width: parent.width
              height: Style.spacing.xxs
              radius: 1
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, Style.normalFillAlpha)

              Rectangle {
                width: Math.round(parent.width * root.lifeDone)
                height: parent.height
                radius: parent.radius
                color: root.contentForeground
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
              }
            }
          }

          // ---- Month stepping: the month on the left, chevrons on the right.
          Item {
            width: parent.width
            height: Style.spacing.controlHeight

            Text {
              id: monthLabel
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: Qt.formatDate(root.viewDate, "MMMM yyyy")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.title
              font.weight: Font.Medium
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.xs

              PanelActionButton {
                iconText: "󰅁"
                tooltipText: "Previous month"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.moveMonth(-1)
              }
              PanelActionButton {
                iconText: "󰅂"
                tooltipText: "Next month"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.moveMonth(1)
              }
            }
          }

          // ---- Month grid. Week numbers in a gutter, seven day columns, six rows.
          //      No lines anywhere: the gutter gap is the rule.
          Item {
            width: parent.width
            height: gridColumn.height

            WheelHandler {
              onWheel: function(event) {
                if (event.angleDelta.y === 0) return
                root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
              }
            }

            Column {
              id: gridColumn
              anchors.left: parent.left
              spacing: root.cellSpacing

              Row {
                id: headerRow
                spacing: root.cellSpacing

                Rectangle {
                  width: root.weekColumnWidth
                  height: Style.spacing.xxl
                  radius: Style.cornerRadius
                  color: weekStartMouse.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : "transparent"

                  Text {
                    anchors.centerIn: parent
                    text: "W"
                    color: Color.muted
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }

                  MouseArea {
                    id: weekStartMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleWeekStart()
                  }

                  PanelToolTip {
                    visible: weekStartMouse.containsMouse
                    text: "Start weeks on " + root.nextWeekStartLabel
                    fontFamily: root.contentFontFamily
                  }
                }

                Item { width: root.gutterWidth; height: Style.spacing.xxl }

                Repeater {
                  model: root.weekdays

                  Text {
                    textFormat: Text.PlainText
                    required property var modelData
                    width: root.cellWidth
                    height: Style.spacing.xxl
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.shortWeekdayLabel(modelData)
                    color: Color.muted
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }

              Repeater {
                model: root.weeks

                Row {
                  required property var modelData
                  spacing: root.cellSpacing

                  Text {
                    textFormat: Text.PlainText
                    width: root.weekColumnWidth
                    height: root.cellHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.week
                    color: Color.muted
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Item { width: root.gutterWidth; height: root.cellHeight }

                  Repeater {
                    model: modelData.days

                    Rectangle {
                      required property var modelData
                      width: root.cellWidth
                      height: root.cellHeight
                      radius: Style.cornerRadius
                      // Today is a fill, the same selected fill every other surface uses.
                      color: modelData.today ? Style.selectedFillFor(root.contentForeground, Color.accent, Color.urgent) : "transparent"

                      Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: modelData.day
                        color: modelData.inMonth ? root.contentForeground : Color.muted
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.body
                        font.weight: modelData.today ? Font.Medium : Font.Normal
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
