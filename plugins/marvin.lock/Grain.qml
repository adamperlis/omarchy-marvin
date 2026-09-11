// Film grain, as its own surface so it can sit over everything its caller
// draws — the screensaver's mark, the lock screen's password field — and the
// frame reads as one exposure rather than content sitting on a gradient. It
// also breaks up the last of the banding the blur leaves behind.
//
// Tiles are resolved relative to this file, so they travel with it.

import QtQuick

Item {
  id: grain

  // Film grain. Over everything, mark included, so the frame reads as one
  // exposure instead of a logo sitting on a gradient. It also breaks up
  // the last of the banding the blur leaves behind.
  //
  // Two continuous-tone tiles, one lightening and one darkening, because
  // real grain moves both ways — a white-only overlay just fogs the frame.
  // Both are per-texel noise already: blurring the tile by 0.7px drops its
  // alpha spread from 11.6 to 4.4, which is what white noise does. So the
  // tile was never the loose part.
  //
  // The render was. Drawing at 3x and scaling to a third put each texel at
  // two thirds of a buffer pixel — finer than the buffer can hold, so the
  // GPU averaged neighbours away and what survived was the beat between
  // the texel grid and the pixel grid: soft clumps. Fine noise minified
  // into coarse mush, at sd 2.8 across a flat part of the frame.
  //
  // So the grid is matched to the buffer instead: the item is laid out in
  // device pixels and scaled back by the same ratio, one texel to one
  // buffer pixel, and smoothing is off because at 1:1 there is nothing to
  // interpolate, only contrast to lose. sd 4.1, and it reads as grain
  // rather than haze. Weights come down from 0.85/0.70 to compensate —
  // nothing is averaging the specks away now, so the same tiles carry
  // further.
  //
  // That is as tight as it goes from in here. This panel is a 1.5 scale,
  // which Qt rounds up to a buffer scale of 2, so Hyprland samples the
  // 2560-wide buffer down to 1920 and no client-side grain survives that
  // at full contrast. Sizing to the true 1.5 instead was measured and
  // moves the neighbour correlation by 0.02 — not worth reading the
  // monitor scale over IPC to get, and devicePixelRatio is exactly right
  // on any whole-number scale.
  Repeater {
    model: [
      { src: "grain-light.png", weight: 0.62 },
      { src: "grain-dark.png", weight: 0.52 }
    ]
    Image {
      required property var modelData
      // Qt's buffer scale for this screen. The floor keeps a screen that
      // reports 0 or nothing from collapsing the tile to a point.
      readonly property real dpr: Math.max(1, Screen.devicePixelRatio)
      x: 0
      y: 0
      width: grain.width * dpr
      height: grain.height * dpr
      transformOrigin: Item.TopLeft
      scale: 1 / dpr
      source: Qt.resolvedUrl(modelData.src)
      fillMode: Image.Tile
      opacity: modelData.weight
      smooth: false
    }
  }
}
