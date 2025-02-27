import figuro/widgets/button
import figuro/widget
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22)

type
  Counter* = object

  Main* = ref object of Figuro
    value: int
    hasHovered: bool
    hoveredAlpha: float
    mainRect: Figuro

proc update*(fig: Main) {.signal.}

proc btnTick*(self: Button[int]) {.slot.} =
  self.state.inc
  # echo "btnTick: ", self.getid
  refresh(self)

proc btnClicked*(self: Button[int],
                  kind: EventKind,
                  buttons: UiButtonView) {.slot.} =
  if buttons == {MouseLeft} or buttons == {DoubleClick}:
    echo ""
    echo nd(), "tclick:button:clicked: ", self.state, " button: ", buttons
    if kind == Enter:
      self.state.inc
      refresh(self)

proc txtHovered*(self: Figuro, kind: EventKind) {.slot.} =
  echo "TEXT hover! ", kind, " :: ", self.getId

proc txtClicked*(self: Figuro,
                  kind: EventKind,
                  buttons: UiButtonView) {.slot.} =
  echo "TEXT clicked! ", kind, " buttons ", buttons, " :: ", self.getId

proc hovered*[T](self: Button[T], kind: EventKind) {.slot.} =
  echo "button:hovered: ", kind, " :: ", self.getId

proc tick*(self: Main) {.slot.} =
  if self.hoveredAlpha < 0.15 and self.hasHovered:
    self.hoveredAlpha += 0.010
    refresh(self)
  elif self.hoveredAlpha > 0.00 and not self.hasHovered:
    self.hoveredAlpha -= 0.005
    refresh(self)
  self.value.inc()
  emit self.update()

proc hover*(self: Main, kind: EventKind) {.slot.} =
  self.hasHovered = kind == Enter
  refresh(self)

proc draw*(self: Main) {.slot.} =
  withDraw(self):
    self.name.setLen(0)
    self.name.add "main"

    rectangle "body":
      self.mainRect = current
      box 10, 10, 600, 120
      cornerRadius 10.0
      fill whiteColor.darken(self.hoveredAlpha).
                      spin(10*self.hoveredAlpha)
      for i in 0 .. 4:
        button "btn", state(int), captures(i):
          box 10 + i*120, 10, 100, 100

          connect(current, doHover, self, Main.hover)
          connect(current, doClick, current, btnClicked)
          if i == 0:
            connect(self, update, current, btnTick)

          node nkText, "text":
            box 10'pw, 10'pw, 80'pw, 80'ph
            fill blackColor
            setText({font: $(Button[int](current.parent).state)})
            connect(current, doClick, current, Figuro.txtClicked())
            bubble(doClick)
            connect(current, doHover, current, Figuro.txtHovered())

var main = Main.new()
connect(main, doDraw, main, Main.draw())
connect(main, doTick, main, Main.tick())

app.width = 720
app.height = 140
startFiguro(main)
