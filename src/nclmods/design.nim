# Design surface. The form is a real NCL form parented into a host. An input-only
# GdkWindow above the controls takes the mouse. The grid and the selection are
# drawn on the layout after the children paint.

type
  TDragKind = enum dkNone, dkMove, dkResize, dkMarquee
  TDesignAlign* = enum daLeft, daRight, daTop, daBottom, daCenterH, daCenterV,
    daSameW, daSameH, daSameSize, daSpaceH, daSpaceV
  TDesignKey* = enum dkeyLeft, dkeyRight, dkeyUp, dkeyDown, dkeyDelete, dkeyEscape,
    dkeyCopy, dkeyCut, dkeyPaste

var
  dForm: TForm
  dHost: TWinControl
  dSel: TComponent
  dSels: seq[TComponent]
  dTool = ""
  dGrid = 8
  dSnap = true
  clipText = ""
  clipGen = 0
  drag = dkNone
  dragHandle = -1
  marqueeAdd = false
  downX, downY, curX, curY: int
  startL, startT, startW, startH: int
  moveStart: seq[tuple[c: TControl, l, t: int]]

var
  onDesignSelect*: proc(c: TComponent) {.closure.}
  onDesignChange*: proc() {.closure.}
  onDesignActivate*: proc(c: TComponent) {.closure.}
  onDesignNote*: proc(s: string) {.closure.}

proc designNote(s: string) =
  if onDesignNote != nil: onDesignNote(s)

proc designForm*(): TForm = dForm
proc designSelected*(): TComponent = dSel
proc designSelection*(): seq[TComponent] = dSels
proc designSelectionCount*(): int = dSels.len

proc designApplyTargets*(prop: string): seq[TComponent] =
  ## The inspector primary, plus every other selected control that has the
  ## property. Name stays on the primary. The form is not added beside it.
  if dSel == nil: return
  result.add(dSel)
  if prop == "Name": return
  for c in dSels:
    if c == nil or c == dSel or c == dForm: continue
    if c.hasProp(prop): result.add(c)
proc designTool*(): string = dTool
proc `designTool=`*(v: string) = dTool = v
proc designSnapOn*(): bool = dSnap
proc toggleSnap*() = dSnap = not dSnap
proc setDesignGrid*(size: int, snap: bool) =
  dGrid = max(1, size)
  dSnap = snap

proc snapv(v: int): int =
  if not dSnap or dGrid <= 1: return v
  let g = dGrid
  ((v + g div 2) div g) * g

proc redrawDesign() =
  if dHost != nil and dHost.client != nil: gtk_widget_queue_draw(dHost.client)
  if dForm != nil and dForm.client != nil: gtk_widget_queue_draw(dForm.client)
  for s in dSels:
    if s of TControl:
      let p = TControl(s).parent
      if p != nil and p.client != nil: gtk_widget_queue_draw(p.client)

proc formClientOrigin(c: TControl, form: TForm): tuple[x, y: int] =
  if c == nil or c == form or c.parent == nil: return (0, 0)
  if c.parent == form: return (c.left, c.top)
  let p = formClientOrigin(c.parent, form)
  (p.x + c.parent.borderLeft + c.left, p.y + c.parent.borderTop + c.top)

proc hostRect(c: TControl): tuple[x, y, w, h: int] =
  if dForm == nil or c == nil: return (0, 0, 0, 0)
  if c == dForm: return (c.left, c.top, c.width, c.height)
  let o = formClientOrigin(c, dForm)
  (dForm.left + dForm.borderLeft + o.x, dForm.top + dForm.borderTop + o.y, c.width, c.height)

proc hitDeep(parent: TWinControl, x, y: int): TControl =
  for i in countdown(parent.controls.high, 0):
    let c = parent.controls[i]
    if c.internal or not c.fVisible or c of TTabSheet: continue
    if x >= c.left and y >= c.top and x < c.left + c.width and y < c.top + c.height:
      if c of TWinControl and TWinControl(c).client != nil:
        let wc = TWinControl(c)
        let inner = hitDeep(wc, x - c.left - wc.borderLeft, y - c.top - wc.borderTop)
        if inner != nil: return inner
      return c

proc hitAt(mx, my: int): TComponent =
  if dForm == nil: return nil
  if mx < dForm.left or my < dForm.top or mx >= dForm.left + dForm.width or my >= dForm.top + dForm.height:
    return nil
  if my < dForm.top + dForm.borderTop: return dForm
  let hit = hitDeep(dForm, mx - dForm.left - dForm.borderLeft, my - dForm.top - dForm.borderTop)
  if hit == nil: dForm else: hit

proc handlePoints(x, y, w, h: int): array[8, tuple[x, y: int]] =
  [
    (x, y), (x + w div 2, y), (x + w, y),
    (x + w, y + h div 2),
    (x + w, y + h), (x + w div 2, y + h), (x, y + h),
    (x, y + h div 2)
  ]

proc hitHandle(mx, my: int): int =
  result = -1
  if dSel == nil or not (dSel of TControl): return
  let r = hostRect(TControl(dSel))
  let pts = handlePoints(r.x, r.y, r.w, r.h)
  for i, p in pts:
    if abs(mx - p.x) <= 5 and abs(my - p.y) <= 5: return i

proc chosen(c: TComponent): bool =
  for s in dSels:
    if s == c: return true

proc selectComponent*(c: TComponent) =
  dSels.setLen(0)
  if c != nil: dSels.add(c)
  dSel = c
  redrawDesign()
  if onDesignSelect != nil: onDesignSelect(c)

proc commitSelection(acc: seq[TComponent]) =
  if acc.len == 0:
    selectComponent(dForm)
  else:
    dSels = acc
    dSel = acc[0]
    redrawDesign()
    if onDesignSelect != nil: onDesignSelect(dSel)

proc designToggle*(c: TComponent) =
  ## Shift-click or Ctrl-click. The form stays out of a multi-selection.
  if c == nil or c == dForm or dForm == nil: return
  if chosen(c):
    var kept: seq[TComponent]
    for s in dSels:
      if s != c and s != dForm: kept.add(s)
    commitSelection(kept)
  else:
    var acc: seq[TComponent]
    acc.add(c)
    for s in dSels:
      if s != c and s != dForm: acc.add(s)
    commitSelection(acc)

proc selectionRoots(): seq[TControl] =
  ## Controls to move or delete together. A selected child of a selected
  ## parent rides along with the parent, so it is not in this list.
  for s in dSels:
    if not (s of TControl) or s == dForm: continue
    let c = TControl(s)
    var skip = false
    var p = c.parent
    while p != nil:
      if chosen(p):
        skip = true
        break
      p = p.parent
    if not skip: result.add(c)

proc rememberMove() =
  moveStart.setLen(0)
  if dSels.len <= 1 and dSel of TControl:
    let c = TControl(dSel)
    moveStart.add((c, c.left, c.top))
    return
  for c in selectionRoots():
    moveStart.add((c, c.left, c.top))

proc detachFromContainer(c: TComponent) =
  let p = c.container
  if p == nil: return
  if p of TMainMenu:
    var kept: seq[TMenuItem]
    for it in TMainMenu(p).fItems:
      if it != c: kept.add(it)
    TMainMenu(p).fItems = kept
  elif p of TPopupMenu:
    var kept: seq[TMenuItem]
    for it in TPopupMenu(p).fItems:
      if it != c: kept.add(it)
    TPopupMenu(p).fItems = kept
  elif p of TMenuItem:
    var kept: seq[TMenuItem]
    for it in TMenuItem(p).fItems:
      if it != c: kept.add(it)
    TMenuItem(p).fItems = kept
  elif p of TPageControl and c of TTabSheet:
    var kept: seq[TTabSheet]
    for it in TPageControl(p).pages:
      if it != c: kept.add(it)
    TPageControl(p).pages = kept
  elif p of TForm and c of TMainMenu and TForm(p).menu == TMainMenu(c):
    TForm(p).menu = nil

proc deleteTree(c: TComponent) =
  if c == nil or c.dead: return
  var kids: seq[TComponent]
  for ch in streamChildren(c): kids.add(ch)
  for k in kids:
    if not k.dead: deleteTree(k)
  detachFromContainer(c)
  freeComponent(c)

proc deleteSelected*() =
  var victims: seq[TComponent]
  if dSels.len <= 1:
    if dSel != nil and dSel != dForm: victims.add(dSel)
  else:
    for c in selectionRoots(): victims.add(c)
  if victims.len == 0: return
  for v in victims:
    if not v.dead: deleteTree(v)
  selectComponent(dForm)
  if onDesignChange != nil: onDesignChange()

proc copySources(): seq[TComponent] =
  ## What Cut and Copy store. A selected child of a selected parent is already
  ## inside the parent's text, so it is not stored a second time.
  for s in dSels:
    if s == nil or s.dead or s == dForm: continue
    var skip = false
    var p: TComponent
    if s of TControl: p = TControl(s).parent
    else: p = s.container
    while p != nil and p != dForm:
      if chosen(p):
        skip = true
        break
      if p of TControl: p = TControl(p).parent
      else: p = p.container
    if not skip: result.add(s)

proc canHold(c: TComponent): bool =
  c of TForm or c of TPanel or c of TGroupBox or c of TScrollBox or
    c of TTabSheet or c of TToolBar

proc pasteTarget(): TWinControl =
  ## Where a pasted control lands: the selected container, or the parent of
  ## whatever is selected, or the form. The form's own parent is the design
  ## scroll box, and a paste must not drop controls onto that.
  result = dForm
  if dSel == nil or dSel == dForm or dSel == dHost: return
  if canHold(dSel) and dSel of TWinControl:
    return TWinControl(dSel)
  if dSel of TControl:
    let p = TControl(dSel).parent
    if p != nil and p != dHost and canHold(p): return p

proc pasteContainer(node: NfmNode): TComponent =
  if not isNonVisualClass(node.className): return pasteTarget()
  if node.className == "TMenuItem" and
      (dSel of TMainMenu or dSel of TPopupMenu or dSel of TMenuItem):
    return dSel
  dForm

proc nameFree(name: string, reserved: var HashSet[string]): bool =
  name.len > 0 and name notin reserved and not nameTaken(dForm, name)

proc claimNames(node: NfmNode, reserved: var HashSet[string]) =
  if not nameFree(node.name, reserved):
    let prefix = classPrefix(node.className)
    var i = 1
    while not nameFree(prefix & $i, reserved): inc i
    node.name = prefix & $i
  reserved.incl(node.name)
  for ch in node.children:
    claimNames(ch, reserved)

proc shiftProp(node: NfmNode, prop: string, by: int) =
  for i in 0 ..< node.props.len:
    if node.props[i].name == prop:
      var n = 0
      try: n = parseInt(node.props[i].value) except CatchableError: n = 0
      node.props[i].value = $(n + by)
      return
  node.props.add((name: prop, value: $by))

proc rememberClip(): int =
  if dForm == nil: return 0
  let roots = copySources()
  if roots.len == 0: return 0
  result = roots.len
  clipText = ""
  for c in roots:
    clipText.add(saveComponent(c, 0))
  clipGen = 0

proc designCopy*(): int =
  ## Store the selection as form text. The system clipboard is left alone,
  ## so the code editor keeps Ctrl+C for source.
  if dForm == nil:
    designNote("Open a form to copy controls")
    return 0
  let roots = copySources()
  result = rememberClip()
  if result == 0: designNote("Select a control to copy")
  elif result == 1: designNote("Copied " & roots[0].name)
  else: designNote("Copied " & $result & " controls")

proc designCut*(): int =
  if dForm == nil:
    designNote("Open a form to copy controls")
    return 0
  var victims: seq[TComponent]
  for c in copySources(): victims.add(c)
  if victims.len == 0:
    designNote("Select a control to copy")
    return 0
  var label = ""
  if victims.len == 1: label = victims[0].name
  result = rememberClip()
  for v in victims:
    if not v.dead: deleteTree(v)
  selectComponent(dForm)
  if onDesignChange != nil: onDesignChange()
  if result == 1: designNote("Cut " & label)
  else: designNote("Cut " & $result & " controls")

proc designPaste*(): int =
  ## Paste into the selected container, one grid step from the copied spot.
  ## Another paste steps again. Names that are already on the form are replaced.
  if dForm == nil:
    designNote("Open a form to paste controls")
    return 0
  if clipText.len == 0:
    designNote("Clipboard is empty")
    return 0
  var nodes: seq[NfmNode]
  try:
    nodes = parseNfmSequence(clipText)
  except CatchableError:
    designNote("Could not paste")
    return 0
  if nodes.len == 0:
    designNote("Clipboard is empty")
    return 0
  inc clipGen
  let delta = clipGen * dGrid
  var reserved = initHashSet[string]()
  for n in nodes: claimNames(n, reserved)
  var made: seq[TComponent]
  try:
    for n in nodes:
      if not isNonVisualClass(n.className):
        shiftProp(n, "Left", delta)
        shiftProp(n, "Top", delta)
      buildChild(n, dForm, pasteContainer(n))
      let obj = dForm.findComponent(n.name)
      if obj != nil: made.add(obj)
  except CatchableError:
    designNote("Could not paste")
    return 0
  if made.len == 0:
    designNote("Could not paste")
    return 0
  commitSelection(made)
  if onDesignChange != nil: onDesignChange()
  if made.len == 1: designNote("Pasted " & made[0].name)
  else: designNote("Pasted " & $made.len & " controls")
  made.len

proc parentAt(mx, my: int): TWinControl =
  result = dForm
  let hit = hitAt(mx, my)
  if hit == nil: return
  if hit of TWinControl and TWinControl(hit).client != nil and not isNonVisualClass(hit.className):
    return TWinControl(hit)
  if hit of TControl and TControl(hit).parent != nil:
    return TControl(hit).parent

proc toParent(parent: TWinControl, mx, my: int): tuple[x, y: int] =
  if parent == nil or parent == dForm:
    return (mx - dForm.left - dForm.borderLeft, my - dForm.top - dForm.borderTop)
  let r = hostRect(parent)
  (mx - r.x - parent.borderLeft, my - r.y - parent.borderTop)

proc dropNew(cls: string, mx, my: int) =
  if dForm == nil: return
  let created = createComponent(cls, dForm)
  if created of TControl and not isNonVisualClass(cls):
    let parent = parentAt(mx, my)
    let c = TControl(created)
    let pt = toParent(parent, mx, my)
    c.left = snapv(max(0, pt.x - c.width div 2))
    c.top = snapv(max(0, pt.y - c.height div 2))
    c.parent = parent
    if cls == "TPageControl":
      let page = TTabSheet.new(dForm)
      page.caption = "Tab1"
      page.parent = TPageControl(created)
  elif created of TMainMenu:
    dForm.menu = TMainMenu(created)
  selectComponent(created)
  # One drop, then the arrow. Another of the same control is another click
  # on the palette. The next click moves or selects what was just placed.
  dTool = ""
  if onDesignChange != nil: onDesignChange()

proc applyResize(c: TControl, mx, my: int) =
  let dx = mx - downX
  let dy = my - downY
  var l = startL
  var t = startT
  var w = startW
  var h = startH
  let right = startL + startW
  let bottom = startT + startH
  case dragHandle
  of 0:
    l = snapv(startL + dx); t = snapv(startT + dy); w = right - l; h = bottom - t
  of 1:
    t = snapv(startT + dy); h = bottom - t
  of 2:
    t = snapv(startT + dy); w = snapv(right + dx) - startL; h = bottom - t
  of 3:
    w = snapv(right + dx) - startL
  of 4:
    w = snapv(right + dx) - startL; h = snapv(bottom + dy) - startT
  of 5:
    h = snapv(bottom + dy) - startT
  of 6:
    l = snapv(startL + dx); w = right - l; h = snapv(bottom + dy) - startT
  of 7:
    l = snapv(startL + dx); w = right - l
  else: discard
  # The form's frame is part of the size. A control can shrink to a few pixels.
  var minW = 8
  var minH = 8
  if c of TForm:
    let f = TForm(c)
    minW = max(80, f.borderLeft + f.borderRight + 16)
    minH = max(60, f.borderTop + f.borderBottom + 16)
  c.setBounds(l, t, max(minW, w), max(minH, h))

proc designDragResize*(handle, dx, dy: int) =
  ## Drag resize handle `handle` by `(dx, dy)` from the selection's current bounds.
  if dSel == nil or not (dSel of TControl): return
  let c = TControl(dSel)
  dragHandle = handle
  startL = c.left
  startT = c.top
  startW = c.width
  startH = c.height
  downX = 0
  downY = 0
  applyResize(c, dx, dy)

proc rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh: int): bool =
  ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah

proc gatherHits(parent: TWinControl, x, y, w, h: int, acc: var seq[TComponent]) =
  ## Deepest controls the rectangle touches. A parent is included only when
  ## none of its children are, so a box around a button does not also grab
  ## the panel that contains it.
  for i in countdown(parent.controls.high, 0):
    let c = parent.controls[i]
    if c.internal or not c.visible or c of TTabSheet: continue
    var childHit = false
    if c of TWinControl:
      let before = acc.len
      gatherHits(TWinControl(c), x, y, w, h, acc)
      childHit = acc.len > before
    if not childHit:
      let r = hostRect(c)
      if rectsOverlap(r.x, r.y, r.w, r.h, x, y, w, h):
        acc.add(c)

proc designSelectRect*(x, y, w, h: int, additive = false) =
  var acc: seq[TComponent]
  if dForm != nil and w > 0 and h > 0:
    gatherHits(dForm, x, y, w, h, acc)
  if additive:
    # A shift-drag that misses keeps the selection already made.
    if acc.len == 0:
      redrawDesign()
      return
    for s in dSels:
      if s != dForm and s notin acc: acc.add(s)
  commitSelection(acc)

proc raiseStacked(c: TControl) =
  if headless: return
  let laid = c.layoutChild()
  if laid == nil: return
  let win = gtk_widget_get_window(laid)
  if win != nil: gdk_window_raise(win)

proc restackChildren(parent: TWinControl) =
  ## Raise siblings from back to front so the last control ends on top.
  if headless: return
  for c in parent.controls: raiseStacked(c)
  if dHost != nil: dHost.raiseDesignOverlay()

proc designOrder*(front: bool): int =
  ## Move the selected controls in front of their siblings, or behind them.
  ## The form stays where it is. The selection keeps its own order.
  if dForm == nil: return 0
  var parents: seq[TWinControl]
  for s in dSels:
    if s == dForm or not (s of TControl): continue
    let p = TControl(s).parent
    if p == nil: continue
    var seen = false
    for q in parents:
      if q == p: seen = true
    if not seen: parents.add(p)
  for p in parents:
    var stay, pick: seq[TControl]
    for c in p.controls:
      if c != dForm and c in dSels: pick.add(c)
      else: stay.add(c)
    if pick.len == 0: continue
    if front: p.controls = stay & pick
    else: p.controls = pick & stay
    result += pick.len
    restackChildren(p)
  if result > 0:
    redrawDesign()
    if onDesignChange != nil: onDesignChange()

proc hostSorted(roots: seq[TControl], horizontal: bool): seq[TControl] =
  result = roots
  for i in 1 .. result.high:
    var j = i
    while j > 0:
      let a = hostRect(result[j - 1])
      let b = hostRect(result[j])
      let later = if horizontal: a.x > b.x or (a.x == b.x and a.y > b.y)
                  else: a.y > b.y or (a.y == b.y and a.x > b.x)
      if not later: break
      let tmp = result[j - 1]
      result[j - 1] = result[j]
      result[j] = tmp
      dec j

proc spaceRoots(roots: seq[TControl], horizontal: bool): int =
  ## Equal gaps between the controls. The first and the last stay put.
  if roots.len < 3: return 0
  let ordered = hostSorted(roots, horizontal)
  var along = 0
  for c in ordered:
    if horizontal: along += c.width else: along += c.height
  let a = hostRect(ordered[0])
  let b = hostRect(ordered[^1])
  let span = if horizontal: (b.x + b.w) - a.x else: (b.y + b.h) - a.y
  let gaps = ordered.len - 1
  let gap = (span - along) div gaps
  var extra = span - along - gap * gaps
  var cursor = if horizontal: a.x else: a.y
  for i, c in ordered:
    let r = hostRect(c)
    if horizontal: c.left = c.left + cursor - r.x
    else: c.top = c.top + cursor - r.y
    if horizontal: cursor += c.width else: cursor += c.height
    if i < ordered.high:
      cursor += gap
      if extra > 0:
        cursor += 1
        dec extra
  roots.len

proc designAlign*(edge: TDesignAlign): int =
  ## Line the selected controls up with the one the inspector shows.
  ## A stretched control (Align other than alNone) is left where layout put it.
  var roots: seq[TControl]
  for c in selectionRoots():
    if c.align == alNone: roots.add(c)
  if edge in {daSpaceH, daSpaceV}:
    result = spaceRoots(roots, edge == daSpaceH)
    if result == 0: return
    redrawDesign()
    if onDesignSelect != nil: onDesignSelect(dSel)
    if onDesignChange != nil: onDesignChange()
    return
  if roots.len < 2: return 0
  var refc = roots[0]
  if dSel of TControl:
    let s = TControl(dSel)
    if s in roots: refc = s
  let rr = hostRect(refc)
  for c in roots:
    if c == refc: continue
    let r = hostRect(c)
    case edge
    of daLeft: c.left = c.left + rr.x - r.x
    of daRight: c.left = c.left + (rr.x + rr.w) - (r.x + r.w)
    of daTop: c.top = c.top + rr.y - r.y
    of daBottom: c.top = c.top + (rr.y + rr.h) - (r.y + r.h)
    of daCenterH: c.left = c.left + (rr.x + rr.w div 2) - (r.x + r.w div 2)
    of daCenterV: c.top = c.top + (rr.y + rr.h div 2) - (r.y + r.h div 2)
    of daSameW: c.width = rr.w
    of daSameH: c.height = rr.h
    of daSameSize:
      c.width = rr.w
      c.height = rr.h
    of daSpaceH, daSpaceV: discard
  result = roots.len
  redrawDesign()
  if onDesignSelect != nil: onDesignSelect(dSel)
  if onDesignChange != nil: onDesignChange()

proc onFormTitle(mx, my: int): bool =
  dForm != nil and mx >= dForm.left and mx < dForm.left + dForm.width and
    my >= dForm.top and my < dForm.top + dForm.borderTop

proc onDesignPress(widget, ev, data: pointer): cint {.cdecl.} =
  if dForm == nil: return 0
  var x, y: cdouble
  var b: cuint
  discard gdk_event_get_coords(ev, addr x, addr y)
  discard gdk_event_get_button(ev, addr b)
  let mx = int(x)
  let my = int(y)
  if b == 3:
    dTool = ""
    if onDesignChange != nil: onDesignChange()
    return 1
  if eventTypeOf(ev) == Gdk2ButtonPress:
    if dTool.len == 0:
      let hit = hitAt(mx, my)
      if hit != nil:
        selectComponent(hit)
        if onDesignActivate != nil: onDesignActivate(hit)
    return 1
  if dTool.len > 0:
    dropNew(dTool, mx, my)
    return 1
  var state: cuint
  discard gdk_event_get_state(ev, addr state)
  let extend = (state and (GdkShiftMask or GdkControlMask)) != 0
  downX = mx
  downY = my
  curX = mx
  curY = my
  marqueeAdd = false
  let hit = hitAt(mx, my)
  let h = hitHandle(mx, my)
  if not extend and dSels.len == 1 and h >= 0 and dSel of TControl:
    drag = dkResize
    dragHandle = h
    let c = TControl(dSel)
    startL = c.left
    startT = c.top
    startW = c.width
    startH = c.height
  elif extend and hit != nil and hit != dForm and not onFormTitle(mx, my):
    let adding = not chosen(hit)
    designToggle(hit)
    dragHandle = -1
    if adding and chosen(hit) and hit of TControl:
      drag = dkMove
      rememberMove()
    else:
      drag = dkNone
  elif not onFormTitle(mx, my) and (hit == nil or hit == dForm):
    # Empty canvas. The drag draws a selection rectangle instead of moving.
    # Shift or Ctrl adds to the selection instead of replacing it.
    drag = dkMarquee
    marqueeAdd = extend
    dragHandle = -1
  else:
    if hit == nil or hit == dForm or not chosen(hit) or dSels.len <= 1:
      selectComponent(if hit == nil: dForm else: hit)
    drag = if dSel of TControl: dkMove else: dkNone
    dragHandle = -1
    rememberMove()
  # The overlay is input-only. Keys are delivered to the layout widget, and
  # only while that widget holds keyboard focus. Focusing the overlay window
  # leaves Delete and the arrow keys with nobody to receive them.
  if dHost != nil and dHost.client != nil:
    gtk_widget_grab_focus(dHost.client)
  1

proc onDesignMotion(widget, ev, data: pointer): cint {.cdecl.} =
  if drag == dkNone: return 0
  var x, y: cdouble
  discard gdk_event_get_coords(ev, addr x, addr y)
  let mx = int(x)
  let my = int(y)
  curX = mx
  curY = my
  if abs(mx - downX) + abs(my - downY) < 3: return 1
  if drag == dkMarquee:
    redrawDesign()
    return 1
  if drag == dkMove:
    if moveStart.len == 1:
      let it = moveStart[0]
      it.c.setBounds(snapv(it.l + mx - downX), snapv(it.t + my - downY), it.c.width, it.c.height)
    else:
      let dx = snapv(mx - downX)
      let dy = snapv(my - downY)
      for it in moveStart:
        it.c.setBounds(it.l + dx, it.t + dy, it.c.width, it.c.height)
  elif dSel of TControl:
    applyResize(TControl(dSel), mx, my)
  redrawDesign()
  if onDesignChange != nil: onDesignChange()
  1

proc onDesignRelease(widget, ev, data: pointer): cint {.cdecl.} =
  if drag == dkMarquee:
    let moved = abs(curX - downX) + abs(curY - downY) >= 3
    let adding = marqueeAdd
    drag = dkNone
    marqueeAdd = false
    if moved:
      designSelectRect(min(downX, curX), min(downY, curY),
        max(1, abs(curX - downX)), max(1, abs(curY - downY)), adding)
    elif not adding:
      selectComponent(dForm)
  else:
    drag = dkNone
    marqueeAdd = false
  redrawDesign()
  1

proc designKey*(key: TDesignKey, shift: bool): bool =
  if dForm == nil: return false
  case key
  of dkeyEscape:
    if dSel of TControl and TControl(dSel).parent != nil and dSel != dForm:
      selectComponent(TControl(dSel).parent)
    else:
      selectComponent(dForm)
    return true
  of dkeyDelete:
    deleteSelected()
    return true
  of dkeyLeft, dkeyRight, dkeyUp, dkeyDown:
    if dSel == nil or not (dSel of TControl): return false
    let step = if shift: dGrid else: 1
    var movers: seq[TControl]
    if dSels.len <= 1:
      movers.add(TControl(dSel))
    else:
      movers = selectionRoots()
    if movers.len == 0: return false
    for c in movers:
      if key == dkeyLeft: c.left = c.left - step
      elif key == dkeyRight: c.left = c.left + step
      elif key == dkeyUp: c.top = c.top - step
      elif key == dkeyDown: c.top = c.top + step
    redrawDesign()
    if onDesignChange != nil: onDesignChange()
    return true
  of dkeyCopy:
    discard designCopy()
    return true
  of dkeyCut:
    discard designCut()
    return true
  of dkeyPaste:
    discard designPaste()
    return true

proc onDesignKey(widget, ev, data: pointer): cint {.cdecl.} =
  var key: cuint
  var state: cuint
  discard gdk_event_get_keyval(ev, addr key)
  discard gdk_event_get_state(ev, addr state)
  let ctrl = (state and GdkControlMask) != 0
  let alt = (state and GdkMod1Mask) != 0
  var which: TDesignKey
  # These are not window accelerators. The source editor keeps Ctrl+C when it
  # has focus. This handler runs only while the design surface has focus.
  if ctrl and not alt:
    case gdk_keyval_to_lower(key)
    of 0x63'u32: which = dkeyCopy
    of 0x78'u32: which = dkeyCut
    of 0x76'u32: which = dkeyPaste
    else: return 0
  else:
    case key
    of GdkKeyLeft: which = dkeyLeft
    of GdkKeyRight: which = dkeyRight
    of GdkKeyUp: which = dkeyUp
    of GdkKeyDown: which = dkeyDown
    of GdkKeyDelete, GdkKeyBackSpace: which = dkeyDelete
    of GdkKeyEscape: which = dkeyEscape
    else: return 0
  if designKey(which, (state and GdkShiftMask) != 0): 1 else: 0

proc paintChrome(cr: pointer, x, y, w, h: int, label: string, handles: bool) =
  # Outset by one pixel so the stroke sits outside the control, where the
  # parent's background is still visible. A window stacked above the control
  # would hide the control itself.
  cairo_set_source_rgba(cr, 0.14, 0.38, 0.72, 1)
  cairo_set_line_width(cr, 1)
  cairo_rectangle(cr, float(x) - 1.5, float(y) - 1.5, float(max(1, w)) + 3, float(max(1, h)) + 3)
  cairo_stroke(cr)
  if not handles: return
  for p in handlePoints(x, y, w, h):
    cairo_set_source_rgba(cr, 1, 1, 1, 1)
    cairo_rectangle(cr, float(p.x - 3), float(p.y - 3), 6, 6)
    cairo_fill(cr)
    cairo_set_source_rgba(cr, 0.1, 0.25, 0.5, 1)
    cairo_set_line_width(cr, 1)
    cairo_rectangle(cr, float(p.x - 3) + 0.5, float(p.y - 3) + 0.5, 5, 5)
    cairo_stroke(cr)
  let tw = float(label.len * 7 + 10)
  var ty = float(y) - 18
  if ty < 0: ty = float(y + h) + 2
  cairo_set_source_rgba(cr, 0.14, 0.38, 0.72, 1)
  cairo_rectangle(cr, float(x), ty, tw, 16)
  cairo_fill(cr)
  cairo_set_source_rgba(cr, 1, 1, 1, 1)
  cairo_select_font_face(cr, "Sans", 0, 0)
  cairo_set_font_size(cr, 11)
  cairo_move_to(cr, float(x) + 4, ty + 12)
  cairo_show_text(cr, label.cstring)

proc onDesignDraw(widget, cr, data: pointer): cint {.cdecl.} =
  if widget == nil or cr == nil: return 0
  let bin = gtk_layout_get_bin_window(widget)
  if bin != nil:
    var bx, by: cint
    gdk_window_get_position(bin, addr bx, addr by)
    cairo_translate(cr, float(bx), float(by))
  if dForm != nil and widget == dForm.client:
    let cw = max(0, dForm.width - dForm.borderLeft - dForm.borderRight)
    let ch = max(0, dForm.height - dForm.borderTop - dForm.borderBottom)
    cairo_set_source_rgba(cr, 0.35, 0.38, 0.42, 1)
    var yy = 0
    while yy < ch:
      var xx = 0
      while xx < cw:
        cairo_rectangle(cr, float(xx), float(yy), 1.3, 1.3)
        inc xx, dGrid
      inc yy, dGrid
    cairo_fill(cr)
  let alone = dSels.len == 1
  for s in dSels:
    if not (s of TControl): continue
    let c = TControl(s)
    if c == dForm and dHost != nil and widget == dHost.client:
      paintChrome(cr, c.left, c.top, c.width, c.height, c.name & ": " & c.className, alone)
    elif c != dForm and c.parent != nil and widget == c.parent.client:
      paintChrome(cr, c.left, c.top, c.width, c.height, c.name & ": " & c.className, alone)
  if drag == dkMarquee and dHost != nil and widget == dHost.client and
      abs(curX - downX) + abs(curY - downY) >= 3:
    let rx = float(min(downX, curX))
    let ry = float(min(downY, curY))
    let rw = float(abs(curX - downX))
    let rh = float(abs(curY - downY))
    cairo_set_source_rgba(cr, 0.20, 0.45, 0.85, 0.18)
    cairo_rectangle(cr, rx, ry, rw, rh)
    cairo_fill(cr)
    cairo_set_source_rgba(cr, 0.14, 0.38, 0.72, 0.95)
    cairo_set_line_width(cr, 1)
    cairo_rectangle(cr, rx + 0.5, ry + 0.5, max(0.0, rw - 1), max(0.0, rh - 1))
    cairo_stroke(cr)
  0

var designHooked = initHashSet[pointer]()

proc hookDesignDraw(client: pointer, id: int) =
  if client == nil or client in designHooked: return
  designHooked.incl(client)
  connectAfter(client, "draw", cast[pointer](onDesignDraw), id)

proc installOverlay(host: TWinControl) =
  ## Mouse capture is an input-only window. A painted window above the form
  ## hides every control, because a transparent child does not reveal siblings.
  if host.designOverlay != nil or host.client == nil or headless: return
  let bin = gtk_layout_get_bin_window(host.client)
  if bin == nil: return
  var attr: GdkWindowAttr
  attr.eventMask = cint(GdkButtonPressMask or GdkButtonReleaseMask or GdkPointerMotionMask or
    GdkButtonMotionMask or GdkKeyPressMask or GdkScrollMask)
  attr.x = 0
  attr.y = 0
  attr.width = 1800
  attr.height = 1400
  attr.wclass = GdkInputOnly
  attr.windowType = GdkWindowChild
  let win = gdk_window_new(bin, addr attr, GdkWaXY)
  if win == nil: return
  gdk_window_set_user_data(win, host.client)
  gdk_window_show(win)
  host.designOverlay = win
  gtk_widget_set_can_focus(host.client, 1)
  let mask = GdkButtonPressMask or GdkButtonReleaseMask or GdkPointerMotionMask or
    GdkButtonMotionMask or GdkKeyPressMask or GdkScrollMask
  gtk_widget_add_events(host.client, mask.cint)
  connect(host.client, "button-press-event", cast[pointer](onDesignPress), host.liveId)
  connect(host.client, "motion-notify-event", cast[pointer](onDesignMotion), host.liveId)
  connect(host.client, "button-release-event", cast[pointer](onDesignRelease), host.liveId)
  connect(host.client, "key-press-event", cast[pointer](onDesignKey), host.liveId)
  hookDesignDraw(host.client, host.liveId)

proc focusDesign*() =
  if headless or dHost == nil or dHost.client == nil: return
  gtk_widget_grab_focus(dHost.client)

proc enableDesign*(form: TForm, host: TWinControl) =
  dForm = form
  dHost = host
  markDesign(form, true)
  if form.parent != host: form.parent = host
  host.scrollMinW = 1800
  host.scrollMinH = 1400
  if not headless and host.client != nil:
    gtk_layout_set_size(host.client, 1800'u32, 1400'u32)
  installOverlay(host)
  if not headless: host.layoutChildren()
  if form.client != nil: hookDesignDraw(form.client, form.liveId)
  selectComponent(form)

proc refreshDesign*() =
  if dHost != nil and not headless: dHost.layoutChildren()
  redrawDesign()

proc closeDesign*() =
  dForm = nil
  dSel = nil
  dSels.setLen(0)
  dTool = ""
  drag = dkNone
  marqueeAdd = false
  redrawDesign()

afterLayout = proc(self: TWinControl) =
  if dHost == nil or dHost.designOverlay == nil: return
  if self == dHost or self == dForm or (self.parent != nil and self.parent == dForm):
    if self.client != nil: hookDesignDraw(self.client, self.liveId)
    redrawDesign()
