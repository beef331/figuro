import commons
import ../ui/utils

type
  Slidable* = concept s, type S
    slide(s..s, float32) is S ## Practically lerp, but avoiding that term to allow user defined ops with `lerp`
    invSlide(s, s..s) is float32 ## Inverse lerp
  Slider*[T: Slidable] = ref object of StatefulFiguro[T]
    valueRange*: Slice[T]
    value*: T

proc dragged*[T](
  slider: Slider[T];
  kind: EventKind;
  intial: Position;
  cursor: Position;
) {.slot.} =
  mixin slide
  let progress = (cursor.positionRelative(slider).x) / 200'ui
  slider.value = slide(slider.valueRange, clamp(float32 progress, 0f, 1f))
  refresh(slider)

proc draw*[T](slider: Slider[T]) {.slot.} =
  mixin invSlide
  withDraw(slider):
    box 10'ui, 10'ui, 200'ui, 30'ui
    fill parseHtmlColor"#111111"
    rectangle "fill":
      box 0'ui, 0'ui, 200'ui *  UICoord(invSlide(slider.value, slider.valueRange).clamp(0f, 1f)), 30'ui
      fill parseHtmlColor"#555555"
    connect(current, doDrag, current, Slider[T].dragged)
exportWidget(slider, Slider)
