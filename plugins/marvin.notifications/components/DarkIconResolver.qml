// Resolves a themed icon name against the *dark* variant of the active icon
// theme, for the one Marvin surface that is dark in both themes.
//
// Icon themes ship the same status icon in two inks. Yaru's `battery-caution`
// is #333 in `Yaru-yellow` and #fff in `Yaru-yellow-dark`, both keeping the
// yellow charge fill — the outline is what changes, because one is drawn for a
// light panel and one for a dark one. Qt binds a single icon theme for the
// whole process, so on `marvin-light` — light bar, light menu, light launcher,
// all correctly served by the light theme — the notification card's signature
// navy gets the dark-inked icons and they read as a hole. That is the black
// battery on the blue card.
//
// Quickshell's icon provider has no per-lookup theme (its `?path=` adds a
// search path, it does not switch themes), so the dark sibling is found on
// disk here and handed back as a file URL. A name with no dark override —
// every real app icon, `firefox` and friends — misses, and the card falls back
// to the normal themed lookup untouched. Nothing that already reads well is
// recoloured.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: resolver

  // The only bindable output. Bumped whenever an answer lands, so a card that
  // asked before the lookup finished re-runs its binding and swaps the icon in
  // place instead of keeping the first frame's fallback.
  property int revision: 0

  // Everything mutable lives on one object that is never reassigned, and is
  // read through state() rather than as a property. resolve() is called from
  // inside a card's binding: a QML property written on that path would make
  // the binding depend on the queue and re-enter itself, which is a binding
  // loop, not a lookup. Plain JavaScript fields signal nothing, so the only
  // way an answer reaches a card is the explicit `revision` bump below.
  //
  //   cache:    name -> file URL, or "" for "no dark variant". A miss is
  //             cached as hard as a hit; only `undefined` is "not asked yet",
  //             so a name is never searched twice.
  //   pending:  names waiting for the one lookup process.
  //   inFlight: the name that process is currently answering.
  property var store: ({ cache: ({}), pending: [], inFlight: "" })
  function state() { return store }

  // The theme `omarchy theme set` applied. A `-dark` theme overrides only the
  // monochrome panel/status icons and inherits the rest, so a theme that is
  // already dark is its own dark variant.
  property string iconTheme: ""
  readonly property string darkTheme: iconTheme.length === 0
    ? ""
    : (/-dark$/.test(iconTheme) ? iconTheme : iconTheme + "-dark")

  // Icon names come from whatever app sent the notification and end up in a
  // `find -name` pattern below. Anything outside this set could be a glob or a
  // path segment, so it is refused rather than escaped.
  readonly property var safeName: /^[A-Za-z0-9][A-Za-z0-9._+-]*$/

  // $1 is the icon name and $2 the theme directory — both positional, never
  // spliced into the script text. `find -L` because icon themes are mostly
  // symlink farms (Yaru points `battery-caution` at `gpm-primary-020`), and a
  // plain `-type f` walk finds none of them.
  readonly property string lookupScript:
    'n=$1; t=$2;' +
    'for root in "$HOME/.local/share/icons" "$HOME/.icons" /usr/share/icons; do' +
    '  [ -d "$root/$t" ] || continue;' +
    '  find -L "$root/$t" -type f \\( -name "$n.svg" -o -name "$n.png" \\) 2>/dev/null;' +
    'done'

  function resolve(name) {
    // Read so the calling binding re-runs when an answer lands.
    void resolver.revision

    var key = String(name || "")
    if (key.length === 0 || darkTheme.length === 0) return ""
    if (!safeName.test(key)) return ""

    var s = state()
    var hit = s.cache[key]
    if (hit !== undefined) return hit

    enqueue(key)
    return ""
  }

  function enqueue(key) {
    var s = state()
    if (s.inFlight === key || s.pending.indexOf(key) >= 0) return
    s.pending.push(key)
    // Deferred: starting the process here would write QML properties while a
    // card's binding is still evaluating. No arguments, so Qt's collapsing of
    // repeated callLater calls is exactly what we want.
    Qt.callLater(resolver.runNext)
  }

  // One lookup at a time: a burst of toasts is a handful of names, and a queue
  // keeps that from becoming a handful of concurrent finds.
  function runNext() {
    var s = state()
    if (s.inFlight.length > 0 || s.pending.length === 0) return
    s.inFlight = s.pending.shift()
    lookup.command = ["sh", "-c", lookupScript, "sh", s.inFlight, darkTheme]
    lookup.running = true
  }

  // The card draws the mark at roughly 24px. Icon themes draw a different
  // amount of detail per size rather than scaling one drawing, so the nearest
  // drawn size beats the biggest one.
  function sizeScore(path) {
    if (path.indexOf("/24x24/") >= 0) return 6
    if (path.indexOf("/22x22/") >= 0) return 5
    if (path.indexOf("/32x32/") >= 0) return 4
    if (path.indexOf("/scalable/") >= 0) return 3
    if (path.indexOf("/48x48/") >= 0) return 2
    if (path.indexOf("/16x16/") >= 0) return 1
    return 0
  }

  function record(raw) {
    var s = state()
    var key = s.inFlight
    s.inFlight = ""
    if (key.length === 0) return

    var best = ""
    var bestScore = -1
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (line.length === 0) continue
      // @2x is the same drawing at twice the pixels; sourceSize already asks
      // for the device ratio, so the plain directory is the one to match.
      if (line.indexOf("@2x") >= 0) continue
      var score = sizeScore(line)
      if (score > bestScore) {
        bestScore = score
        best = line
      }
    }

    s.cache[key] = best.length > 0 ? Util.fileUrl(best) : ""
    revision++
    Qt.callLater(resolver.runNext)
  }

  Process {
    id: lookup
    running: false
    // StdioCollector fires streamFinished once per run, before onExited, and
    // fires it on empty output too — so the queue advances on a miss as well.
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: resolver.record(text)
    }
  }

  // Startup read. A theme switch restarts the shell, so there is nothing to
  // watch; dropping the cache here is for the plugin-reload path.
  FileView {
    path: Color.currentThemePath + "/icons.theme"
    watchChanges: false
    printErrors: false
    onLoaded: {
      resolver.state().cache = ({})
      resolver.iconTheme = text().trim()
      resolver.revision++
    }
    onLoadFailed: resolver.iconTheme = ""
  }
}
