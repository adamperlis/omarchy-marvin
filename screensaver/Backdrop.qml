// The Marvin wash — the animated background shared by the screensaver and the
// lock screen, so the two are the same surface rather than two that resemble
// each other. Screensaver at 150s, lock at 300s: the composition carries
// straight through the handover instead of cutting to a still.
//
// The look is the theme's wallpapers — soft mesh gradients in periwinkle,
// amber and lilac over near-white. There is no qsb on this system, so no
// compiled shaders: the fields are large solid circles under a heavy blur,
// which is what a blurred circle is for.
//
// Motion is layered on purpose. Every field drifts, breathes and the whole
// plate turns, all on long durations that share no common multiple, so the
// composition never returns to a pose you have already seen. Nothing moves
// fast enough to read as an animation while you are looking at it — it should
// look different when you glance back, not busy while you watch.
//
// Grain is deliberately not in here: it belongs over everything a surface
// draws, mark or password field included, so each caller puts Grain on top of
// its own content. See Grain.qml.

import QtQuick
import QtQuick.Effects

Item {
  id: backdrop

  property color base: "#968b76"

  Rectangle { anchors.fill: parent; color: backdrop.base }

  // The plate is oversized and centred so it can rotate without ever
  // bringing an edge into frame.
  // Blurred twice. One pass at blurMax 64 still left the fields reading
  // as circles with visible arcs; passing the already-blurred plate
  // through a second blur melts the edges completely and what is left is
  // the wash between them, which is the whole point of the look.
  Item {
    id: softened
    anchors.fill: parent
    layer.enabled: true
    // Saturation and contrast live on the effect, which is the reliable
    // way to get punch here. A Qt5Compat Blend was tried first and is the
    // obvious answer, but a layer-effect item cannot also serve as a
    // Blend source — the composite collapsed to the flat base colour.
    layer.effect: MultiEffect {
      blurEnabled: true
      blur: 1.0
      blurMax: 64
      autoPaddingEnabled: false
      saturation: 1.45
      contrast: 0.12
    }

  Item {
    id: plate
    width: parent.width * 1.9
    height: parent.height * 1.9
    anchors.centerIn: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      blurEnabled: true
      blur: 1.0
      blurMax: 64
      autoPaddingEnabled: false
    }

    NumberAnimation on rotation {
      running: true
      loops: Animation.Infinite
      from: 0
      to: 360
      duration: 48000
    }

    // One colour field. A rigid circle sliding around still reads as a
    // circle no matter how hard it is blurred — what sells fluid is the
    // shape changing while it travels. So each field is an ellipse that
    // stretches on one axis while squashing on the other, turns on its
    // own axis, and drifts, all on clocks that never line up. The arcs
    // dissolve into each other and the result moves like liquid rather
    // than like sprites.
    component Field: Rectangle {
      id: field
      property real ax: 0
      property real ay: 0
      property real bx: 0
      property real by: 0
      property int driftX: 6500
      property int driftY: 8500
      property int breathe: 5500
      property int spin: 20000
      property real minScale: 0.75
      property real maxScale: 1.35
      radius: width / 2
      transformOrigin: Item.Center

      transform: Scale {
        id: morph
        origin.x: field.width / 2
        origin.y: field.height / 2
        xScale: 1
        yScale: 1
        SequentialAnimation on xScale {
          loops: Animation.Infinite
          NumberAnimation { from: field.minScale; to: field.maxScale; duration: field.breathe; easing.type: Easing.InOutSine }
          NumberAnimation { to: field.minScale; duration: field.breathe; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on yScale {
          loops: Animation.Infinite
          NumberAnimation { from: field.maxScale; to: field.minScale; duration: Math.round(field.breathe * 1.37); easing.type: Easing.InOutSine }
          NumberAnimation { to: field.maxScale; duration: Math.round(field.breathe * 1.37); easing.type: Easing.InOutSine }
        }
      }

      NumberAnimation on rotation {
        running: true
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: field.spin
      }

      SequentialAnimation on x {
        loops: Animation.Infinite
        NumberAnimation { from: field.ax; to: field.bx; duration: field.driftX; easing.type: Easing.InOutSine }
        NumberAnimation { to: field.ax; duration: field.driftX; easing.type: Easing.InOutSine }
      }
      SequentialAnimation on y {
        loops: Animation.Infinite
        NumberAnimation { from: field.ay; to: field.by; duration: field.driftY; easing.type: Easing.InOutSine }
        NumberAnimation { to: field.ay; duration: field.driftY; easing.type: Easing.InOutSine }
      }
    }

    // Sampled off the current wallpaper, but few and large rather than
    // many and small: eight overlapping semi-opaque warm fields averaged
    // into flat cream and took the hue variety with them. The wallpaper
    // is alive because warm gold sits against cool periwinkle, so the
    // set is kept to five with real hue separation and enough weight to
    // survive the blur.
    Field {
      width: plate.width * 0.46; height: width
      color: "#b38d41"; opacity: 0.72
      ax: plate.width * 0.02;  ay: plate.height * 0.06
      bx: plate.width * 0.30;  by: plate.height * 0.40
      spin: 19000
      driftX: 9000; driftY: 11000; breathe: 7000
    }
    Field {
      width: plate.width * 0.38; height: width
      color: "#7881ae"; opacity: 0.88
      ax: plate.width * 0.54;  ay: plate.height * 0.04
      bx: plate.width * 0.18;  by: plate.height * 0.36
      spin: 23000
      driftX: 13000; driftY: 8000; breathe: 6000
    }
    Field {
      width: plate.width * 0.42; height: width
      color: "#c8bc9e"; opacity: 0.34
      ax: plate.width * 0.28;  ay: plate.height * 0.46
      bx: plate.width * 0.58;  by: plate.height * 0.16
      spin: 17000
      driftX: 10000; driftY: 14000; breathe: 9000
    }
    Field {
      width: plate.width * 0.34; height: width
      color: "#8d714b"; opacity: 0.62
      ax: plate.width * 0.14;  ay: plate.height * 0.50
      bx: plate.width * 0.46;  by: plate.height * 0.24
      spin: 27000
      driftX: 12000; driftY: 9000; breathe: 5000
    }
    Field {
      width: plate.width * 0.36; height: width
      color: "#968b97"; opacity: 0.66
      ax: plate.width * 0.56;  ay: plate.height * 0.50
      bx: plate.width * 0.26;  by: plate.height * 0.32
      spin: 21000
      driftX: 15000; driftY: 12000; breathe: 8000
    }

    // Colour pops. The wash is deliberately muted to sit near the
    // wallpaper, which leaves it a little inert, so these three saturated
    // fields spend most of their cycle at zero and briefly surface. The
    // frame gets an event rather than a constant, and because they ride
    // inside the plate they are blurred and turned with everything else
    // instead of reading as discs laid on top.
    component Pop: Rectangle {
      id: pop
      property int cycle: 31000
      property real peak: 0.5
      property int offset: 0
      radius: width / 2
      opacity: 0
      transformOrigin: Item.Center
      SequentialAnimation on opacity {
        running: true
        loops: Animation.Infinite
        PauseAnimation { duration: pop.offset }
        NumberAnimation { to: pop.peak; duration: Math.round(pop.cycle * 0.24); easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: Math.round(pop.cycle * 0.32); easing.type: Easing.InOutSine }
        PauseAnimation { duration: Math.round(pop.cycle * 0.44) }
      }
      SequentialAnimation on scale {
        running: true
        loops: Animation.Infinite
        NumberAnimation { from: 0.7; to: 1.25; duration: pop.cycle; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.7; duration: pop.cycle; easing.type: Easing.InOutSine }
      }
    }

    Pop {
      width: plate.width * 0.26; height: width
      color: "#ffb02e"
      x: plate.width * 0.20; y: plate.height * 0.16
      cycle: 31000; peak: 0.55; offset: 2000
    }
    Pop {
      width: plate.width * 0.22; height: width
      color: "#ff5f8f"
      x: plate.width * 0.52; y: plate.height * 0.44
      cycle: 43000; peak: 0.45; offset: 13000
    }
    Pop {
      width: plate.width * 0.24; height: width
      color: "#3fc8f0"
      x: plate.width * 0.14; y: plate.height * 0.52
      cycle: 37000; peak: 0.40; offset: 25000
    }

    // Keeps the middle luminous so the name always has quiet to sit on.
    Rectangle {
      width: plate.width * 0.62; height: width
      radius: width / 2
      color: "#ffffff"
      anchors.centerIn: parent
      SequentialAnimation on opacity {
        loops: Animation.Infinite
        NumberAnimation { from: 0.46; to: 0.70; duration: 6000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.46; duration: 6000; easing.type: Easing.InOutSine }
      }
    }
  }

  }

  // A slow specular pass — a wide soft band crossing the frame every
  // couple of minutes. It is the one event in the composition.
  Item {
    anchors.fill: parent
    clip: true
    Rectangle {
      id: sweep
      width: parent.width * 0.5
      height: parent.height * 2.2
      y: -parent.height * 0.6
      rotation: 18
      opacity: 0.12
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "#00ffffff" }
        GradientStop { position: 0.5; color: "#ffffffff" }
        GradientStop { position: 1.0; color: "#00ffffff" }
      }
      SequentialAnimation on x {
        loops: Animation.Infinite
        NumberAnimation { from: -sweep.width; to: backdrop.width + sweep.width; duration: 8500; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 13000 }
      }
    }
  }
}
