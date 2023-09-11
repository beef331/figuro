import std/[os, unicode, strutils, sets, hashes]
import std/isolation

import pkg/vmath
import pkg/pixie
import pkg/pixie/fonts
import pkg/windy
import pkg/threading/channels

import commons

import pretty

type

  GlyphPosition* = ref object
    ## Represents a glyph position after typesetting.
    fontId*: FontId
    fontSize*: float32
    rune*: Rune
    pos*: Vec2       # Where to draw the image character.
    rect*: Rect
    descent*: float32


var
  typefaceChan* = newChan[string](100)
  glyphImageChan* = newChan[(Hash, Image)](100)
  glyphImageCached*: HashSet[Hash]

proc hash*(tp: Typeface): Hash =
  var h = Hash(0)
  h = h !& hash tp.filePath
  result = !$h

proc hash*(fnt: Font): Hash =
  var h = Hash(0)
  for n, f in fnt[].fieldPairs():
    when n != "paints":
      h = h !& hash(f)
  result = !$h

proc hash*(glyph: GlyphPosition): Hash {.inline.} =
  result = hash((
    2344,
    glyph.fontId,
    glyph.rune,
  ))

proc getId*(typeface: Typeface): TypefaceId =
  TypefaceId typeface.hash()

proc getId*(typeface: Font): FontId =
  FontId typeface.hash()

iterator glyphs*(arrangement: GlyphArrangement): GlyphPosition =
  # threads: RenderThread

  var idx = 0
  if arrangement != nil:
    for (span, gfont) in zip(arrangement.spans, arrangement.fonts):
      let
        span = span[0] .. span[1]

      while idx < arrangement.runes.len():
        let
          pos = arrangement.positions[idx]
          rune = arrangement.runes[idx]
          selection = arrangement.selectionRects[idx]

        yield GlyphPosition(
          fontId: gfont.hash(),
          fontSize: gfont.size,
          rune: rune,
          pos: pos,
          rect: selection,
          descent: gfont.lineHeight,
        )

        if idx notin span:
          break
        else:
          idx.inc()

var
  typefaceTable*: Table[TypefaceId, Typeface]
  fontTable* {.threadvar.}: Table[FontId, Font]

proc generateGlyphImage*(arrangement: GlyphArrangement) =
  threads: MainThread
  ## returns Glyph's hash, will generate glyph if needed

  for glyph in arrangement.glyphs():
    let hashFill = glyph.hash()

    if hashFill notin glyphImageCached:
      let
        wh = glyph.rect.wh
        fontId = glyph.fontId
        font = fontTable[fontId]
        text = $glyph.rune
        arrangement = typeset(@[newSpan(text, font)], bounds=wh)
        snappedBounds = arrangement.computeBounds().snapToPixels()
        lh = font.defaultLineHeight()
        bounds = rect(snappedBounds.x, snappedBounds.h + snappedBounds.y - lh,
                      snappedBounds.w, lh)
        image = newImage(bounds.w.int, bounds.h.int)

      try:
        font.paint = whiteColor
        var m = translate(-bounds.xy)
        image.fillText(arrangement, m)

        # put into cache
        glyphImageCached.incl hashFill
        glyphImageChan.send(unsafeIsolate (hashFill, image,))

      except PixieError:
        discard

proc getTypeface*(name: string): FontId =
  threads: MainThread

  let
    typefacePath = DataDirPath.string / name
    typeface = readTypeface(typefacePath)
    id = typeface.getId()

  typefaceTable[id] = typeface
  typefaceChan.send(typefacePath)
  result = id
  # echo "typefaceTable:addr: ", getThreadId()
  # echo "getTypeFace: ", result
  # echo "getTypeFace:res: ", typefaceTable[id].hash()

proc convertFont*(font: GlyphFont): (FontId, Font) =
  threads: MainThread
  # echo "convertFont: ", font.typefaceId
  # echo "typefaceTable:addr: ", getThreadId()
  let
    id = FontId hash(font)
    typeface = typefaceTable[font.typefaceId]
  # echo "convertFont:res: ", typeface.hash

  if not fontTable.hasKey(id):
    var pxfont = newFont(typeface)
    pxfont.size = font.size
    pxfont.typeface = typeface
    pxfont.textCase = parseEnum[TextCase]($font.fontCase)
    # copy rest of the fields with matching names
    for pn, a in fieldPairs(pxfont[]):
      for fn, b in fieldPairs(font):
        when pn == fn:
          a = b
    if font.lineHeight < 0.0:
      pxfont.lineHeight = pxfont.defaultLineHeight()

    fontTable[id] = pxfont
    result = (id, pxfont)
    # echo "getFont:input: "
    # print font
  else:
    result = (id, fontTable[id])

proc getTypeset*(
    box: Box,
    text: string,
    gfont: GlyphFont,
): GlyphArrangement =
  threads: MainThread

  let
    rect = box.scaled()
    wh = rect.wh
    (_, pf) = convertFont(gfont)

  assert pf.isNil == false
  # echo "FONTS: ", pf.repr
  let arrangement = typeset(@[newSpan(text, pf)], bounds = rect.wh)

  # echo "getTypeset:"
  # echo "snappedBounds: ", snappedBounds
  # echo "arrangement: "
  # print arrangement
  result = GlyphArrangement(
    lines: arrangement.lines,
    spans: arrangement.spans,
    fonts: arrangement.fonts.mapIt(gfont), ## FIXME
    runes: arrangement.runes,
    positions: arrangement.positions,
    selectionRects: arrangement.selectionRects,
  )

  result.generateGlyphImage()
  # echo "font: "
  # print arrangement.fonts[0].size
  # print arrangement.fonts[0].lineHeight
  # echo "arrangement: "
  # print result
