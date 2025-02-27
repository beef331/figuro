
## This minimal example shows 5 blue squares.

import figuro/widgets/button
import figuro/widget
import figuro

type
  Main* = ref object of Figuro
    value: float

proc tick*(self: Main) {.slot.} =
  refresh(self)
  # if self.mainRect != nil:
  #   echo "tick main: ", self.mainRect.uid
  self.value = 0.004 * (1+app.tickCount).toFloat
  self.value = clamp(self.value mod 1.0, 0, 1.0)

proc draw*(self: Main) {.slot.} =
  withDraw(self):
    # echo "draw widget!"
    rectangle "main":
      # echo "draw mainRect"
      # connect(current, onDraw, self, Main.draw)
      box 0, 0, 620, 140
      for i in 0 .. 5:
        button "btn", captures(i):
          let value = self.value
          fill "#AA0000"
          onHover:
            fill "#F00000"
          box 20 + (i.toFloat + value) * 120,
              30 + 20 * sin(value + i.toFloat),
              60, 60
          if i == 0:
            current.fill.a = value * 1.0

var fig = Main.new()

connect(fig, doDraw, fig, Main.draw)
connect(fig, doTick, fig, Main.tick)

app.width = 720
app.height = 140

startFiguro(fig)
