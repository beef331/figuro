import figuro/widgets/slider
import figuro/widget
import figuro

let
  typeface = loadTypeFace("IBMPlexSans-Regular.ttf")
  font = UiFont(typefaceId: typeface, size: 22)

type
  Main* = ref object of BasicFiguro
    mainRect: Figuro
    fVal: float32

proc slide[T: SomeNumber](rng: Slice[T], t: float32): T =  T(float32(rng.a) + float32(rng.b - rng.a) * t)
proc invSlide[T: SomeNumber](val: T, rng: Slice[T]): float32 = float32(val) / float32(rng.b - rng.a)

proc drag(
  main: Main;
  kind: EventKind,
  initial: Position;
  current: Position;
) {.slot.} =
  refresh(main)

proc draw*(self: Main) {.slot.} =
  withDraw(self):
    self.name.setLen(0)
    self.name.add "main"
    fill "#9F2B00"
    box 0'ui, 0'ui, 400'vw, 300'vh
    rectangle "slider":
      var theSlider: Slider[float32]
      slider "floatSlider", state(float32):
        widget.valueRange = 0f..10f
        theSlider = widget
        connect(current, doDrag, self, Main.drag)
      text "val":
        setText({font: $theSlider.value}) 
        box 10'ux, 10'ux, 400'ux, 100'ux
        fill parseHtmlColor"#FFFFFF"
    rectangle "slider":
      var theSlider: Slider[int]
      slider "intSlider", state(int):
        widget.valueRange = 0..10
        theSlider = widget
        connect(current, doDrag, self, Main.drag)
      text "val":
        setText({font: $theSlider.value}) 
        box 10'ux, 10'ux, 400'ux, 100'ux
        fill parseHtmlColor"#FFFFFF"

var main = Main.new()
connect(main, doDraw, main, Main.draw)
connect(main, doTick, main, Main.tick)

app.width = 720
app.height = 140
startFiguro(main)
