
## This minimal example shows 5 blue squares.

import figuro/[timers, widgets]
import figuro

type
  Main* = ref object of Figuro
    value: float

method tick(self: Main) =
  refresh()
  self.value = 0.008 * (1+app.frameCount).toFloat
  self.value = clamp(self.value mod 1.0, 0, 1.0)

method render(app: Main) =
  frame "main":
    box 0, 0, 620, 140
    for i in 0 .. 4:
      rectangle "block":
        box 20 + (i.toFloat + app.value) * 120, 20, 100, 100
        current.fill = parseHtmlColor "#2B9FEA"
        if i == 0:
          current.fill.a = app.value * 1.0

startFiguro(Main(), w = 620, h = 140)
