# Design surface. The form is a real NCL form parented into a host; a transparent
# GTK drawing area above it takes the mouse the way the Lazarus designer does.

type
  TDragKind = enum dkNone, dkMove, dkResize

var
  dForm: TForm
  dHost: TWinControl
  dSel: TComponent
  dTool = ""
  dGrid = 8
  dSnap = true
  drag = dkNone
  dragHandle = -1
  downX, downY: int
  startL, startT, startW, startH: int

var
  onDesignSelect*: proc(c: TComponent) {.closure.}
  onDesignChange*: proc() {.closure.}
  onDesignActivate*: proc(c: TComponent) {.closure.}

proc designForm*(): TForm = dForm
proc designSelected*(): TComponent = dSel
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
  if dHost != nil and dHost.designOverlay != nil:
    gtk_widget_queue_draw(dHost.designOverlay)

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

proc selectComponent*(c: TComponent) =
  dSel = c
  redrawDesign()
  if onDesignSelect != nil: onDesignSelect(c)

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
  if dSel == nil or dSel == dForm: return
  let parent = if dSel of TControl and TControl(dSel).parent != nil: TComponent(TControl(dSel).parent)
               elif dSel.container != nil: dSel.container
               else: TComponent(dForm)
  deleteTree(dSel)
  selectComponent(parent)
  if onDesignChange != nil: onDesignChange()

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
  c.setBounds(l, t, max(8, w), max(8, h))

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
  let h = hitHandle(mx, my)
  if h >= 0 and dSel of TControl:
    drag = dkResize
    dragHandle = h
  else:
    let hit = hitAt(mx, my)
    selectComponent(if hit == nil: dForm else: hit)
    drag = if dSel of TControl: dkMove else: dkNone
    dragHandle = -1
  if dSel of TControl:
    let c = TControl(dSel)
    startL = c.left
    startT = c.top
    startW = c.width
    startH = c.height
  downX = mx
  downY = my
  if widget != nil: gtk_widget_grab_focus(widget)
  1

proc onDesignMotion(widget, ev, data: pointer): cint {.cdecl.} =
  if drag == dkNone or dSel == nil or not (dSel of TControl): return 0
  var x, y: cdouble
  discard gdk_event_get_coords(ev, addr x, addr y)
  let mx = int(x)
  let my = int(y)
  if abs(mx - downX) + abs(my - downY) < 3: return 1
  let c = TControl(dSel)
  if drag == dkMove:
    c.setBounds(snapv(startL + mx - downX), snapv(startT + my - downY), startW, startH)
  else:
    applyResize(c, mx, my)
  redrawDesign()
  if onDesignChange != nil: onDesignChange()
  1

proc onDesignRelease(widget, ev, data: pointer): cint {.cdecl.} =
  drag = dkNone
  1

proc onDesignKey(widget, ev, data: pointer): cint {.cdecl.} =
  var key: cuint
  var state: cuint
  discard gdk_event_get_keyval(ev, addr key)
  discard gdk_event_get_state(ev, addr state)
  if key == GdkKeyEscape:
    if dSel of TControl and TControl(dSel).parent != nil and dSel != dForm:
      selectComponent(TControl(dSel).parent)
    else:
      selectComponent(dForm)
    return 1
  if key == GdkKeyDelete or key == GdkKeyBackSpace:
    deleteSelected()
    return 1
  if dSel == nil or not (dSel of TControl): return 0
  let step = if (state and GdkShiftMask) != 0: dGrid else: 1
  let c = TControl(dSel)
  case key
  of GdkKeyLeft: c.left = c.left - step
  of GdkKeyRight: c.left = c.left + step
  of GdkKeyUp: c.top = c.top - step
  of GdkKeyDown: c.top = c.top + step
  else: return 0
  redrawDesign()
  if onDesignChange != nil: onDesignChange()
  1

proc onDesignDraw(widget, cr, data: pointer): cint {.cdecl.} =
  cairo_set_operator(cr, CairoOpSource.cint)
  cairo_set_source_rgba(cr, 0, 0, 0, 0)
  cairo_paint(cr)
  cairo_set_operator(cr, CairoOpOver.cint)
  if dForm != nil:
    let x0 = dForm.left + dForm.borderLeft
    let y0 = dForm.top + dForm.borderTop
    let cw = max(0, dForm.width - dForm.borderLeft - dForm.borderRight)
    let ch = max(0, dForm.height - dForm.borderTop - dForm.borderBottom)
    cairo_set_source_rgba(cr, 0.72, 0.76, 0.82, 1)
    var yy = y0
    while yy < y0 + ch:
      var xx = x0
      while xx < x0 + cw:
        cairo_rectangle(cr, float(xx), float(yy), 1.2, 1.2)
        inc xx, dGrid
      inc yy, dGrid
    cairo_fill(cr)
  if dSel of TControl:
    let r = hostRect(TControl(dSel))
    cairo_set_source_rgba(cr, 0.14, 0.38, 0.72, 1)
    cairo_set_line_width(cr, 1)
    cairo_rectangle(cr, float(r.x) + 0.5, float(r.y) + 0.5, float(max(1, r.w)) - 1, float(max(1, r.h)) - 1)
    cairo_stroke(cr)
    for p in handlePoints(r.x, r.y, r.w, r.h):
      cairo_set_source_rgba(cr, 1, 1, 1, 1)
      cairo_rectangle(cr, float(p.x - 3), float(p.y - 3), 6, 6)
      cairo_fill(cr)
      cairo_set_source_rgba(cr, 0.1, 0.25, 0.5, 1)
      cairo_set_line_width(cr, 1)
      cairo_rectangle(cr, float(p.x - 3) + 0.5, float(p.y - 3) + 0.5, 5, 5)
      cairo_stroke(cr)
    let label = dSel.name & ": " & dSel.className
    let tw = float(label.len * 7 + 10)
    var ty = float(r.y) - 16
    if ty < 0: ty = float(r.y + r.h)
    cairo_set_source_rgba(cr, 0.14, 0.38, 0.72, 1)
    cairo_rectangle(cr, float(r.x), ty, tw, 16)
    cairo_fill(cr)
    cairo_set_source_rgba(cr, 1, 1, 1, 1)
    cairo_select_font_face(cr, "Sans", 0, 0)
    cairo_set_font_size(cr, 11)
    cairo_move_to(cr, float(r.x) + 4, ty + 12)
    cairo_show_text(cr, label.cstring)
  0

proc installOverlay(host: TWinControl) =
  if host.designOverlay != nil or host.client == nil or headless: return
  let d = gtk_drawing_area_new()
  gtk_widget_set_app_paintable(d, 1)
  gtk_widget_set_can_focus(d, 1)
  if host.handle != nil:
    let screen = gtk_widget_get_screen(host.handle)
    let vis = gdk_screen_get_rgba_visual(screen)
    if vis != nil: gtk_widget_set_visual(d, vis)
  let mask = GdkButtonPressMask or GdkButtonReleaseMask or GdkPointerMotionMask or
    GdkButtonMotionMask or GdkKeyPressMask
  gtk_widget_add_events(d, mask.cint)
  gtk_layout_put(host.client, d, 0, 0)
  gtk_widget_set_size_request(d, 1800, 1400)
  gtk_widget_show(d)
  host.designOverlay = d
  connect(d, "draw", cast[pointer](onDesignDraw), host.liveId)
  connect(d, "button-press-event", cast[pointer](onDesignPress), host.liveId)
  connect(d, "motion-notify-event", cast[pointer](onDesignMotion), host.liveId)
  connect(d, "button-release-event", cast[pointer](onDesignRelease), host.liveId)
  connect(d, "key-press-event", cast[pointer](onDesignKey), host.liveId)

proc enableDesign*(form: TForm, host: TWinControl) =
  dForm = form
  dHost = host
  markDesign(form, true)
  if form.parent != host: form.parent = host
  if not headless and host.client != nil:
    gtk_layout_set_size(host.client, 1800'u32, 1400'u32)
  installOverlay(host)
  if not headless: host.layoutChildren()
  selectComponent(form)

proc refreshDesign*() =
  if dHost != nil and not headless: dHost.layoutChildren()
  redrawDesign()

proc closeDesign*() =
  dForm = nil
  dSel = nil
  dTool = ""
  drag = dkNone
  redrawDesign()

afterLayout = proc(self: TWinControl) =
  if dHost == nil or dHost.designOverlay == nil: return
  if self == dHost or self == dForm or (self.parent != nil and self.parent == dForm):
    gtk_widget_queue_draw(dHost.designOverlay)
