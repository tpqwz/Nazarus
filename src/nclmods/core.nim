# Component model, layout, published properties. Widget backends live in widgets.nim.

type
  TColor* = distinct int

proc `==`*(a, b: TColor): bool {.borrow.}

const
  clNone* = TColor(-1)
  clBlack* = TColor(0x000000)
  clWhite* = TColor(0xFFFFFF)
  clRed* = TColor(0xDC1E1E)
  clGreen* = TColor(0x1E8C28)
  clBlue* = TColor(0x1E5AC8)
  clYellow* = TColor(0xF0C828)
  clGray* = TColor(0x808080)
  clSilver* = TColor(0xC0C0C0)
  clNavy* = TColor(0x000080)
  clTeal* = TColor(0x008080)
  clMaroon* = TColor(0x800000)
  clPurple* = TColor(0x800080)
  clOlive* = TColor(0x808000)
  clLime* = TColor(0x00FF00)
  clAqua* = TColor(0x00FFFF)
  clFuchsia* = TColor(0xFF00FF)
  clBtnFace* = TColor(0xEFEFEF)
  clBtnText* = TColor(0x000000)
  clWindow* = TColor(0xFFFFFF)
  clWindowText* = TColor(0x000000)
  clHighlight* = TColor(0x326EC8)
  clHighlightText* = TColor(0xFFFFFF)
  clForm* = TColor(0xF0F0F0)

type
  TAlign* = enum alNone, alTop, alBottom, alLeft, alRight, alClient
  TAnchorKind* = enum akLeft, akTop, akRight, akBottom
  TMouseButton* = enum mbLeft, mbRight, mbMiddle
  TFormBorderStyle* = enum bsNone, bsSingle, bsSizeable, bsDialog
  TPosition* = enum poDesigned, poDefault, poScreenCenter
  TCloseAction* = enum caNone, caHide, caFree
  TModalResult* = enum mrNone, mrOk, mrCancel, mrYes, mrNo
  TAlignment* = enum taLeftJustify, taCenter, taRightJustify
  TBevelCut* = enum bvNone, bvLowered, bvRaised, bvSpace
  TBevelShape* = enum bsBox, bsFrame, bsTopLine, bsBottomLine, bsLeftLine, bsRightLine
  TOrientation* = enum orHorizontal, orVertical
  TComboBoxStyle* = enum csDropDown, csDropDownList
  TFontStyle* = enum fsBold, fsItalic, fsUnderline
  TMsgDlgType* = enum mtInfo, mtWarning, mtError, mtConfirmation
  TMsgButton* = enum mbOK, mbCancel, mbYes, mbNo
  TMsgButtons* = set[TMsgButton]
  TLayoutKind* = enum lkAlign, lkRow, lkWrap
  TPropKind* = enum pkString, pkInt, pkBool, pkEnum, pkColor, pkEvent, pkStrings

  TObject* = ref object of RootObj
  TCanvas* = ref object
    cr: pointer
  TFont* = ref object
    name*: string
    size*: int
    styles*: set[TFontStyle]
    color*: TColor

  TNotifyEvent* = proc(sender: TObject) {.closure.}
  TPaintEvent* = proc(sender: TObject, canvas: TCanvas) {.closure.}
  TCloseEvent* = proc(sender: TObject, action: var TCloseAction) {.closure.}

  TComponent* = ref object of TObject
    fName: string
    fTag: int
    fClass: string
    owner: TComponent
    owned: seq[TComponent]
    container: TComponent
    liveId: int
    designing: bool
    internal: bool
    dead: bool
    refreshing: bool
    events: Table[string, string]

  TControl* = ref object of TComponent
    fLeft, fTop, fWidth, fHeight: int
    fVisible: bool
    fEnabled: bool
    fAlign: TAlign
    ## Column width kept for alLeft and alRight while a narrow layout paints another width.
    fSideSpan: int
    fAnchors: set[TAnchorKind]
    fColor: TColor
    fParentColor: bool
    fFont: TFont
    fParentFont: bool
    fHint: string
    fShowHint: bool
    fCaption: string
    fParent: TWinControl
    handle: pointer
    ## Windowed stand-in put into a GtkLayout when `handle` itself has no window.
    ## GtkLayout does not paint no-window children (labels, frames, boxes).
    socket: pointer
    css: pointer
    placed: bool
    held: bool
    createImpl: proc(self: TControl) {.closure.}
    pushState: proc(self: TControl) {.closure.}
    onClick*: TNotifyEvent
    onDblClick*: TNotifyEvent
    onChange*: TNotifyEvent
    onEnter*: TNotifyEvent
    onExit*: TNotifyEvent

  TWinControl* = ref object of TControl
    controls: seq[TControl]
    client: pointer
    vbox: pointer
    inner: pointer
    extra: pointer
    menuBar: pointer
    layoutKind: TLayoutKind
    ## Stack alLeft, alRight, and alClient when the client is narrower than BreakWidth.
    fResponsive: bool
    fBreakWidth: int
    ## True after the last layout stacked the side-by-side band.
    fStacked: bool
    layouting: bool
    designOverlay: pointer
    lastClientW, lastClientH: int
    lastAllocW, lastAllocH: int
    scrollMinW, scrollMinH: int
    borderLeft, borderTop, borderRight, borderBottom: int
    accel: pointer

  TForm* = ref object of TWinControl
    fPosition: TPosition
    fBorder: TFormBorderStyle
    fMenu: TMainMenu
    onCreate*: TNotifyEvent
    onShow*: TNotifyEvent
    onClose*: TCloseEvent
    opened: bool

  TLabel* = ref object of TControl
    fAlignment: TAlignment
    fAutoSize: bool
    fWordWrap: bool

  TButton* = ref object of TWinControl
  TEdit* = ref object of TWinControl
    fText: string
    fReadOnly: bool
    fPassword: bool
    fCue: string
    onReturn*: TNotifyEvent
  TMemo* = ref object of TWinControl
    fText: string
    fReadOnly: bool
    fWordWrap: bool
    fMonospace: bool
  TCheckBox* = ref object of TWinControl
    fChecked: bool
  TRadioButton* = ref object of TWinControl
    fChecked: bool
  TListBox* = ref object of TWinControl
    fItems: seq[string]
    fItemIndex: int
  TComboBox* = ref object of TWinControl
    fItems: seq[string]
    fItemIndex: int
    fStyle: TComboBoxStyle
    fText: string
  TGroupBox* = ref object of TWinControl
  TRadioGroup* = ref object of TWinControl
    fItems: seq[string]
    fItemIndex: int
  TPanel* = ref object of TWinControl
    fBevel: TBevelCut
    capLabel: pointer
  TBevel* = ref object of TControl
    fShape: TBevelShape
    fBevel: TBevelCut
  TPaintBox* = ref object of TControl
    onPaint*: TPaintEvent
  TTimer* = ref object of TComponent
    fInterval: int
    fEnabled: bool
    onTimer*: TNotifyEvent
    timerId: cuint
  TSplitter* = ref object of TWinControl
    dragging: bool
    dragOrigin: int
    siblingOrigin: int
    sibling: TControl
  TScrollBox* = ref object of TWinControl
    ## When set before the scroll box is realized, children wrap in a flow box.
    flow*: bool
    ## Realized as a horizontal box. Set from lkRow before the widget exists.
    ## A GtkLayout in this scrolled window paints only a sliver of each button.
    strip: bool
  TTrackBar* = ref object of TWinControl
    fMin, fMax, fPosition: int
    fOrientation: TOrientation
  TProgressBar* = ref object of TWinControl
    fMin, fMax, fPosition: int
  TStatusBar* = ref object of TWinControl
    fSimpleText: string
  TTabSheet* = ref object of TWinControl
    pageAdded: bool
  TPageControl* = ref object of TWinControl
    pages: seq[TTabSheet]
    fActive: int
    fShowTabs: bool
    onChangePage*: TNotifyEvent
  TTreeNode* = ref object
    text: string
    obj: TObject
    kids: seq[TTreeNode]
    parentNode: TTreeNode
    id: int
    iter: GtkTreeIter
    hasIter: bool
  TTreeView* = ref object of TWinControl
    roots: seq[TTreeNode]
    store: pointer
    nodeMap: Table[int, TTreeNode]
    nextNode: int
    selected: TTreeNode
    onSelect*: proc(sender: TObject, node: TTreeNode) {.closure.}
  TToolBar* = ref object of TWinControl
  TMenuItem* = ref object of TComponent
    fCaption: string
    fShortCut: string
    fEnabled: bool
    fChecked: bool
    # A check item keeps its box when it is unchecked. A normal item never has one.
    fCheckable: bool
    fItems: seq[TMenuItem]
    onClick*: TNotifyEvent
    gtkItem: pointer
  TMainMenu* = ref object of TComponent
    fItems: seq[TMenuItem]
  TPopupMenu* = ref object of TComponent
    fItems: seq[TMenuItem]
    gtkMenu: pointer
  TOpenDialog* = ref object of TComponent
    fTitle: string
    fFilter: string
    fFileName: string
    fDefaultExt: string
  TSaveDialog* = ref object of TOpenDialog
  TScopeRail* = object
    openLine*, closeLine*, depth*: int
  TJumpMark* = object
    ## column 0 is the lane nearest the code. backward is a continue.
    fromLine*, toLine*, column*: int
    backward*: bool
  TSourceEditor* = ref object of TWinControl
    buffer: pointer
    mute: bool
    gutter: pointer
    rails: seq[TScopeRail]
    jumps: seq[TJumpMark]
    jumpCols: int
    jumpLine: int
    jumpCol: int
    onCaret*: proc(line: int) {.closure.}
  TApplication* = ref object
    title*: string
    mainForm*: TForm
    terminated: bool
    running: bool

  TProp = object
    name: string
    kind: TPropKind
    enums: seq[string]
    sig: string
    get: proc(c: TComponent): string {.closure.}
    set: proc(c: TComponent, v: string) {.closure.}

  TPropInfo* = object
    name*: string
    kind*: TPropKind
    enums*: seq[string]
    sig*: string

  TPaletteItem* = object
    cls*: string
    category*: string
    caption*: string

# Identity across the widget hierarchy. Nim's ref `==` only accepts one type.
proc `==`*(a, b: TObject): bool {.inline.} =
  cast[pointer](a) == cast[pointer](b)

var
  headless* = false
  application*: TApplication
  live: seq[TComponent]
  classParent: Table[string, string]
  factories: Table[string, proc(owner: TComponent): TComponent {.closure.}]
  declaredProps: Table[string, seq[TProp]]
  defaultEvents: Table[string, string]
  nonVisual: HashSet[string]
  palette: seq[TPaletteItem]
  afterLayout*: proc(self: TWinControl) {.closure.}
  onRefresh*: proc(c: TComponent) {.closure.}
  reportError*: proc(msg: string) {.closure.}

proc cssHex*(c: TColor): string =
  if c == clNone: return "transparent"
  "#" & toHex(int(c) and 0xFFFFFF, 6)

proc colorName*(c: TColor): string =
  const names = [
    (clNone, "clNone"), (clBlack, "clBlack"), (clWhite, "clWhite"),
    (clRed, "clRed"), (clGreen, "clGreen"), (clBlue, "clBlue"),
    (clYellow, "clYellow"), (clGray, "clGray"), (clSilver, "clSilver"),
    (clNavy, "clNavy"), (clTeal, "clTeal"), (clMaroon, "clMaroon"),
    (clPurple, "clPurple"), (clOlive, "clOlive"), (clLime, "clLime"),
    (clAqua, "clAqua"), (clFuchsia, "clFuchsia"), (clBtnFace, "clBtnFace"),
    (clBtnText, "clBtnText"), (clWindow, "clWindow"), (clWindowText, "clWindowText"),
    (clHighlight, "clHighlight"), (clHighlightText, "clHighlightText"), (clForm, "clForm")]
  for pair in names:
    if pair[0] == c: return pair[1]
  cssHex(c)

proc parseColor*(s: string): TColor =
  let t = s.strip
  if t.len == 0 or t.toLowerAscii == "clnone": return clNone
  if t[0] == '#':
    return TColor(parseHexInt(t[1 .. ^1]))
  let key = t.toLowerAscii
  const names = [
    ("clnone", clNone), ("clblack", clBlack), ("clwhite", clWhite),
    ("clred", clRed), ("clgreen", clGreen), ("clblue", clBlue),
    ("clyellow", clYellow), ("clgray", clGray), ("clsilver", clSilver),
    ("clnavy", clNavy), ("clteal", clTeal), ("clmaroon", clMaroon),
    ("clpurple", clPurple), ("clolive", clOlive), ("cllime", clLime),
    ("claqua", clAqua), ("clfuchsia", clFuchsia), ("clbtnface", clBtnFace),
    ("clwindow", clWindow), ("clwindowtext", clWindowText),
    ("clhighlight", clHighlight), ("clform", clForm),
    ("clbtntext", clBtnText), ("clhighlighttext", clHighlightText)]
  for pair in names:
    if pair[0] == key: return pair[1]
  TColor(parseInt(t))

proc guard*(body: proc()) =
  try:
    body()
  except CatchableError as e:
    let msg = e.msg
    stderr.writeLine("Nazarus: " & msg)
    if reportError != nil:
      try: reportError(msg) except: discard

proc remember(c: TComponent): int =
  if live.len == 0: live.add(nil)
  live.add(c)
  live.high

proc recall(data: pointer): TComponent =
  let id = cast[int](data)
  if id > 0 and id < live.len:
    result = live[id]
    if result != nil and result.dead: result = nil

proc className*(self: TComponent): string = self.fClass
proc name*(self: TComponent): string = self.fName
proc tag*(self: TComponent): int = self.fTag
proc `tag=`*(self: TComponent, v: int) = self.fTag = v

proc ownerRoot(c: TComponent): TComponent =
  result = c
  while result != nil and result.owner != nil:
    result = result.owner

proc nameTaken(owner: TComponent, name: string): bool =
  if owner.fName == name: return true
  for c in owner.owned:
    if c.fName == name: return true

proc classPrefix(cls: string): string =
  if cls.len > 1 and cls[0] == 'T' and cls[1] in {'A' .. 'Z'}: cls[1 .. ^1]
  else: cls

proc uniqueName(owner: TComponent, cls: string): string =
  let prefix = classPrefix(cls)
  var i = 1
  while nameTaken(owner, prefix & $i): inc i
  prefix & $i

proc findComponent*(self: TComponent, name: string): TComponent =
  if self.fName == name and not self.internal: return self
  for c in self.owned:
    if c.internal: continue
    if c.fName == name: return c
    result = c.findComponent(name)
    if result != nil: return

proc `name=`*(self: TComponent, v: string) =
  if v == self.fName: return
  if v.len == 0:
    raise newException(ValueError, "component name is empty")
  if self.owner != nil:
    if self.owner.fName == v:
      raise newException(ValueError, "duplicate component name: " & v)
    for c in self.owner.owned:
      if c != self and c.fName == v:
        raise newException(ValueError, "duplicate component name: " & v)
  self.fName = v

proc initComponent(self: TComponent, cls: string, owner: TComponent) =
  self.fClass = cls
  self.events = initTable[string, string]()
  self.liveId = remember(self)
  if owner != nil:
    self.fName = uniqueName(owner, cls)
    self.owner = owner
    self.container = owner
    owner.owned.add(self)
  else:
    self.fName = classPrefix(cls) & "1"

proc ownedComponents*(self: TComponent): seq[TComponent] =
  for c in self.owned:
    if not c.internal: result.add(c)

proc handler*(self: TComponent, event: string): string =
  if self.events.hasKey(event): self.events[event] else: ""

proc `handler=`*(self: TComponent, event, value: string) =
  if value.len == 0: self.events.del(event)
  else: self.events[event] = value

proc initControl(self: TControl, cls: string, owner: TComponent) =
  initComponent(self, cls, owner)
  self.fVisible = true
  self.fEnabled = true
  self.fAlign = alNone
  self.fAnchors = {akLeft, akTop}
  self.fColor = clNone
  self.fParentColor = true
  self.fParentFont = true
  self.fFont = TFont()
  self.fFont.name = "Sans"
  self.fFont.size = 10
  self.fFont.color = clWindowText
  self.fWidth = 80
  self.fHeight = 24
  if self of TWinControl:
    TWinControl(self).fBreakWidth = 640

proc left*(self: TControl): int = self.fLeft
proc top*(self: TControl): int = self.fTop
proc width*(self: TControl): int =
  ## alLeft and alRight report the column, including while a narrow layout
  ## paints that column as a full-width band.
  if self.fAlign in {alLeft, alRight} and self.fSideSpan > 0: self.fSideSpan
  else: self.fWidth
proc height*(self: TControl): int = self.fHeight
proc align*(self: TControl): TAlign = self.fAlign
proc visible*(self: TControl): bool = self.fVisible
proc enabled*(self: TControl): bool = self.fEnabled
proc caption*(self: TControl): string = self.fCaption
proc hint*(self: TControl): string = self.fHint
proc color*(self: TControl): TColor = self.fColor
proc font*(self: TControl): TFont = self.fFont
proc parent*(self: TControl): TWinControl = self.fParent
proc anchors*(self: TControl): set[TAnchorKind] = self.fAnchors

proc clientExtent(self: TWinControl): tuple[w, h: int] =
  # A scroll box's layout widget grows to its content. Wrapping and aligning
  # have to use the widget's own allocation (the viewport), or one pass makes
  # the content wider and the next pass treats that width as the client.
  if not headless and self of TScrollBox and self.handle != nil:
    let aw = int(gtk_widget_get_allocated_width(self.handle))
    let ah = int(gtk_widget_get_allocated_height(self.handle))
    if aw > 20 and ah > 20:
      return (aw, ah)
  if self.client != nil and not headless:
    let w = gtk_widget_get_allocated_width(self.client)
    let h = gtk_widget_get_allocated_height(self.client)
    if w > 1 and h > 1:
      return (int(w), int(h))
  (max(0, self.fWidth - self.borderLeft - self.borderRight),
   max(0, self.fHeight - self.borderTop - self.borderBottom))

proc clientWidth*(self: TWinControl): int = self.clientExtent.w
proc clientHeight*(self: TWinControl): int = self.clientExtent.h

proc layoutChild(self: TControl): pointer =
  if self.socket != nil: self.socket else: self.handle

proc inFlow(self: TControl): bool =
  self.fParent != nil and self.fParent of TScrollBox and TScrollBox(self.fParent).flow

proc inStrip(self: TControl): bool =
  self.fParent != nil and self.fParent of TScrollBox and TScrollBox(self.fParent).strip

proc setMinContent*(self: TScrollBox, w, h: int) =
  ## Keep a wrapping palette from collapsing to a single row of buttons.
  if headless or self.handle == nil: return
  if w > 0: gtk_scrolled_window_set_min_content_width(self.handle, w.cint)
  if h > 0: gtk_scrolled_window_set_min_content_height(self.handle, h.cint)

proc prepareLayoutChild(self: TControl): pointer =
  ## GtkLayout only shows children that own a GdkWindow. Wrap the rest.
  ## The wrapper stays transparent so a label does not paint a solid plate.
  ## A flow box or a horizontal strip paints ordinary buttons, so those stay unwrapped.
  if self.inFlow() or self.inStrip(): return self.handle
  if self.socket != nil: return self.socket
  if self.handle == nil: return nil
  if gtk_widget_get_has_window(self.handle) != 0: return self.handle
  let eb = gtk_event_box_new()
  gtk_container_add(eb, self.handle)
  gtk_widget_show(self.handle)
  let css = gtk_css_provider_new()
  cssLoad(css, "* { background-color: transparent; background-image: none; }")
  gtk_style_context_add_provider(gtk_widget_get_style_context(eb), css, CssPrioApp)
  self.socket = eb
  eb

proc placeWidget(self: TControl) =
  if headless or self.handle == nil or self.fParent == nil: return
  let parent = self.fParent
  if parent.client == nil: return
  if self of TTabSheet: return
  let hadSocket = self.socket != nil
  let child = self.prepareLayoutChild()
  if child == nil: return
  if self.inFlow():
    if not self.placed:
      gtk_flow_box_insert(parent.client, child, -1)
      self.placed = true
      if self.held:
        g_object_unref(child)
        self.held = false
    gtk_widget_set_halign(child, GtkAlignStart)
    gtk_widget_set_size_request(child, max(1, self.fWidth).cint, max(1, self.fHeight).cint)
    if self.fVisible: gtk_widget_show_all(child)
    else: gtk_widget_hide(child)
    return
  if self.inStrip():
    if not self.placed:
      # expand/fill stay off so a short caption does not stretch across the bar.
      gtk_box_pack_start(parent.client, child, 0, 0, 0)
      self.placed = true
      if self.held:
        g_object_unref(child)
        self.held = false
    gtk_widget_set_valign(child, GtkAlignCenter)
    gtk_widget_set_size_request(child, max(1, self.fWidth).cint, max(1, self.fHeight).cint)
    if self.fVisible: gtk_widget_show_all(child)
    else: gtk_widget_hide(child)
    return
  let freshWrap = self.socket != nil and not hadSocket and self.placed
  if freshWrap:
    # Reparenting into the socket already pulled the bare widget out of the layout.
    self.placed = false
  if not self.placed:
    gtk_layout_put(parent.client, child, self.fLeft.cint, self.fTop.cint)
    self.placed = true
    if self.held:
      g_object_unref(child)
      self.held = false
  else:
    gtk_layout_move(parent.client, child, self.fLeft.cint, self.fTop.cint)
  let rw = max(1, self.fWidth).cint
  let rh = max(1, self.fHeight).cint
  gtk_widget_set_size_request(child, rw, rh)
  if self.fVisible:
    gtk_widget_show_all(child)
  else:
    gtk_widget_hide(child)
  # GtkLayout copies the child's minimum size into its allocation, and a
  # queue_resize issued while the parent is already allocating is often
  # dropped. Push the rectangle ourselves so a newly placed control cannot
  # stay 1x1.
  var box: GtkAllocation
  box.x = self.fLeft.cint
  box.y = self.fTop.cint
  box.width = rw
  box.height = rh
  gtk_widget_size_allocate(child, addr box)

proc layoutChildren(self: TWinControl)

proc setBoundsInternal(self: TControl, x, y, w, h: int) =
  let nw = max(0, w)
  let nh = max(0, h)
  let changed = self.fLeft != x or self.fTop != y or self.fWidth != nw or self.fHeight != nh
  self.fLeft = x
  self.fTop = y
  self.fWidth = nw
  self.fHeight = nh
  self.placeWidget()
  if changed and self of TWinControl:
    let wc = TWinControl(self)
    if not wc.layouting:
      wc.layoutChildren()

proc applyAnchors(c: TControl, oldW, oldH, newW, newH: int) =
  let dw = newW - oldW
  let dh = newH - oldH
  if dw == 0 and dh == 0: return
  var x = c.fLeft
  var y = c.fTop
  var w = c.fWidth
  var h = c.fHeight
  if akRight in c.fAnchors and akLeft notin c.fAnchors: x += dw
  elif akRight in c.fAnchors and akLeft in c.fAnchors: w += dw
  if akBottom in c.fAnchors and akTop notin c.fAnchors: y += dh
  elif akBottom in c.fAnchors and akTop in c.fAnchors: h += dh
  c.setBoundsInternal(x, y, max(8, w), max(8, h))

proc designDocument(self: TWinControl, c: TControl): bool =
  ## The form on the design scroll box keeps Left, Top, Width, and Height.
  ## Align and anchors apply when the program runs, not while it is being drawn.
  c of TForm and c.designing and self of TScrollBox

proc columnSpan(c: TControl): int =
  ## Width an alLeft or alRight control keeps across a stack.
  ## The painted width changes while the band is stacked. This one does not.
  if c.fAlign in {alLeft, alRight}:
    if c.fSideSpan <= 0:
      c.fSideSpan = max(0, c.fWidth)
    if c.fSideSpan > 0:
      return c.fSideSpan
  max(0, c.fWidth)

proc doAlign(self: TWinControl, cw, ch: int) =
  var x = 0
  var y = 0
  var right = cw
  var bottom = ch
  for c in self.controls:
    if self.designDocument(c): continue
    if not c.fVisible or c.fAlign != alTop: continue
    c.setBoundsInternal(x, y, max(0, right - x), c.fHeight)
    y += c.fHeight
  for c in self.controls:
    if self.designDocument(c): continue
    if not c.fVisible or c.fAlign != alBottom: continue
    let bh = c.fHeight
    bottom -= bh
    if bottom < y: bottom = y
    c.setBoundsInternal(x, bottom, max(0, right - x), bh)
  # The design surface keeps the wide columns. Stacking applies when the program runs.
  let stack = not self.designing and self.fResponsive and self.fBreakWidth > 0 and cw < self.fBreakWidth
  self.fStacked = stack
  if stack:
    var bands: seq[tuple[ctrl: TControl, band: int, client: bool]]
    var fixed = 0
    var clients = 0
    for c in self.controls:
      if self.designDocument(c): continue
      if not c.fVisible or c.fAlign notin {alLeft, alRight, alClient}: continue
      if c.fAlign == alClient:
        bands.add((c, 0, true))
        inc clients
      else:
        let band = c.columnSpan()
        bands.add((c, band, false))
        fixed += band
    let room = max(0, bottom - y)
    let clientH = if clients > 0: max(0, room - fixed) else: 0
    let full = max(0, right - x)
    var gave = false
    for b in bands:
      var h = b.band
      if b.client:
        h = if not gave: clientH else: 0
        gave = true
      b.ctrl.setBoundsInternal(x, y, full, h)
      y += h
  else:
    for c in self.controls:
      if self.designDocument(c): continue
      if not c.fVisible or c.fAlign != alLeft: continue
      let span = c.columnSpan()
      c.setBoundsInternal(x, y, span, max(0, bottom - y))
      x += span
    for c in self.controls:
      if self.designDocument(c): continue
      if not c.fVisible or c.fAlign != alRight: continue
      let bw = c.columnSpan()
      right -= bw
      if right < x: right = x
      c.setBoundsInternal(right, y, bw, max(0, bottom - y))
    for c in self.controls:
      if self.designDocument(c): continue
      if not c.fVisible or c.fAlign != alClient: continue
      c.setBoundsInternal(x, y, max(0, right - x), max(0, bottom - y))
      x = right
      y = bottom

proc doRow(self: TWinControl, cw, ch: int) =
  var x = 4
  for c in self.controls:
    if not c.fVisible: continue
    let y = max(0, (ch - c.fHeight) div 2)
    c.setBoundsInternal(x, y, c.fWidth, c.fHeight)
    x += c.fWidth + 4

proc wrapViewport(self: TWinControl, cw: int): int =
  ## Width a wrapping bar should break lines at. A scroll box's layout widget,
  ## and sometimes the scrolled window itself, report the content width, which
  ## keeps every palette button on one row past the edge of the window.
  if not (self of TScrollBox):
    return max(cw, 1)
  result = 0
  if not headless and self.handle != nil:
    let top = gtk_widget_get_toplevel(self.handle)
    if top != nil and top != self.handle:
      let tw = int(gtk_widget_get_allocated_width(top))
      if tw > 80: result = tw
    let adj = gtk_scrolled_window_get_hadjustment(self.handle)
    if adj != nil:
      let page = int(gtk_adjustment_get_page_size(adj))
      if page > 40 and (result == 0 or page < result):
        result = page
  if self.fWidth > 40 and (result == 0 or self.fWidth < result):
    result = self.fWidth
  if result <= 40:
    result = max(cw, 1)

proc doWrap(self: TWinControl, cw, ch: int) =
  var x = 4
  var y = 4
  var rowH = 0
  for c in self.controls:
    if not c.fVisible: continue
    if x > 4 and x + c.fWidth > cw:
      x = 4
      y += rowH + 4
      rowH = 0
    c.setBoundsInternal(x, y, c.fWidth, c.fHeight)
    x += c.fWidth + 4
    if c.fHeight > rowH: rowH = c.fHeight

proc updateScrollExtent(self: TWinControl) =
  if headless or self.client == nil: return
  if not (self of TScrollBox): return
  # A flow box or a strip is not a GtkLayout. Its size request is the scrollable size.
  if TScrollBox(self).flow or TScrollBox(self).strip: return
  var maxx = max(self.fWidth, self.scrollMinW)
  var maxy = max(self.fHeight, self.scrollMinH)
  for c in self.controls:
    if c.fAlign != alNone and not self.designDocument(c): continue
    maxx = max(maxx, c.fLeft + c.fWidth + 16)
    maxy = max(maxy, c.fTop + c.fHeight + 16)
  gtk_layout_set_size(self.client, cuint(max(maxx, 1)), cuint(max(maxy, 1)))

proc raiseDesignOverlay(self: TWinControl) =
  # designOverlay is an input-only GdkWindow. Raising it keeps mouse capture
  # above the controls without painting over them.
  if headless or self.designOverlay == nil: return
  let w = max(self.scrollMinW, 1600)
  let h = max(self.scrollMinH, 1200)
  gdk_window_move_resize(self.designOverlay, 0, 0, w.cint, h.cint)
  gdk_window_raise(self.designOverlay)

proc layoutChildren(self: TWinControl) =
  if self.layouting: return
  if self of TScrollBox and (TScrollBox(self).flow or TScrollBox(self).strip):
    # The flow box or the horizontal strip places these children. Nested controls still lay out.
    self.layouting = true
    self.layouting = false
    for c in self.controls:
      if c of TWinControl:
        TWinControl(c).layoutChildren()
    if afterLayout != nil: afterLayout(self)
    return
  if self of TPageControl:
    self.layouting = true
    # A notebook page is not given a GTK allocation from its NCL width. Size
    # each page to the page control, or the design surface stays at the
    # tab sheet's 200x120 default in the corner of the page.
    let ext = self.clientExtent()
    for page in TPageControl(self).pages:
      if ext.w > 20 and ext.h > 20:
        page.setBoundsInternal(0, 0, ext.w, ext.h)
      else:
        page.layoutChildren()
    self.layouting = false
    if afterLayout != nil: afterLayout(self)
    return
  self.layouting = true
  let ext = self.clientExtent()
  let cw = ext.w
  let ch = ext.h
  case self.layoutKind
  of lkAlign:
    self.doAlign(cw, ch)
    if self.lastClientW > 0 or self.lastClientH > 0:
      for c in self.controls:
        if self.designDocument(c): continue
        if c.fVisible and c.fAlign == alNone:
          applyAnchors(c, self.lastClientW, self.lastClientH, cw, ch)
    self.lastClientW = cw
    self.lastClientH = ch
  of lkRow:
    self.doRow(cw, ch)
  of lkWrap:
    self.doWrap(self.wrapViewport(cw), ch)
  self.updateScrollExtent()
  self.raiseDesignOverlay()
  self.layouting = false
  for c in self.controls:
    if c of TWinControl and not (c of TTabSheet and self of TPageControl):
      TWinControl(c).layoutChildren()
  if afterLayout != nil:
    afterLayout(self)

proc `layout=`*(self: TWinControl, v: TLayoutKind) =
  self.layoutKind = v
  if not self.layouting: self.layoutChildren()

proc chromeCss(self: TControl): string =
  var decls: seq[string]
  if self.fColor != clNone:
    decls.add("background-color: " & cssHex(self.fColor) & ";")
    decls.add("background-image: none;")
  if not self.fParentFont and self.fFont != nil:
    let f = self.fFont
    decls.add("font-family: \"" & f.name & "\";")
    decls.add("font-size: " & $f.size & "pt;")
    if fsBold in f.styles: decls.add("font-weight: bold;")
    else: decls.add("font-weight: normal;")
    if fsItalic in f.styles: decls.add("font-style: italic;")
    if f.color != clNone: decls.add("color: " & cssHex(f.color) & ";")
  if decls.len == 0: return ""
  let body = decls.join(" ")
  "* { " & body & " }\nbutton, entry, textview, label, checkbutton, radiobutton { " & body & " }\n"

proc applyChrome(self: TControl) =
  if headless or self.handle == nil: return
  gtk_widget_set_sensitive(self.handle, if self.fEnabled: 1 else: 0)
  if self.fHint.len > 0 and self.fShowHint:
    gtk_widget_set_tooltip_text(self.handle, self.fHint.cstring)
  let css = self.chromeCss()
  if css.len > 0:
    if self.css == nil:
      self.css = gtk_css_provider_new()
      gtk_style_context_add_provider(gtk_widget_get_style_context(self.handle), self.css, CssPrioApp)
    cssLoad(self.css, css)
  if self.pushState != nil and not self.refreshing:
    self.refreshing = true
    self.pushState(self)
    self.refreshing = false

proc refreshControl*(c: TComponent) =
  if c of TControl: TControl(c).applyChrome()
  if onRefresh != nil: onRefresh(c)

proc onSized(widget: pointer, alloc: pointer, data: pointer) {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TWinControl): return
  let wc = TWinControl(c)
  if wc.layouting or wc.client == nil: return
  let w = int(gtk_widget_get_allocated_width(wc.client))
  let h = int(gtk_widget_get_allocated_height(wc.client))
  if w <= 1 or h <= 1: return
  if w == wc.lastAllocW and h == wc.lastAllocH: return
  wc.lastAllocW = w
  wc.lastAllocH = h
  wc.layoutChildren()

proc hookSize(self: TWinControl) =
  if self.client == nil: return
  connect(self.client, "size-allocate", cast[pointer](onSized), self.liveId)

proc adoptPage(pc: TPageControl, ts: TTabSheet)

proc realizeTree(self: TControl) =
  if headless: return
  if self.handle == nil and self.createImpl != nil:
    self.createImpl(self)
    self.applyChrome()
  self.placeWidget()
  if self of TPageControl:
    let pc = TPageControl(self)
    for ch in pc.controls:
      if ch of TTabSheet:
        adoptPage(pc, TTabSheet(ch))
  if self of TWinControl:
    let wc = TWinControl(self)
    wc.hookSize()
    for ch in wc.controls:
      ch.realizeTree()
    wc.layoutChildren()

proc `parent=`*(self: TControl, p: TWinControl) =
  if self.fParent == p: return
  let old = self.fParent
  if old != nil:
    var kept: seq[TControl]
    for c in old.controls:
      if c != self: kept.add(c)
    old.controls = kept
    let laid = self.layoutChild()
    if self.placed and old.client != nil and laid != nil and not (self of TTabSheet):
      if not self.held:
        discard g_object_ref(laid)
        self.held = true
      gtk_container_remove(old.client, laid)
    self.placed = false
  self.fParent = p
  if p == nil:
    self.container = self.owner
    if old != nil and not old.layouting: old.layoutChildren()
    return
  self.container = p
  if p.designing: self.designing = true
  p.controls.add(self)
  if self of TTabSheet and p of TPageControl:
    adoptPage(TPageControl(p), TTabSheet(self))
  elif p.handle != nil:
    self.realizeTree()
  if not p.layouting: p.layoutChildren()
  if old != nil and not old.layouting: old.layoutChildren()

proc relayoutFrom(self: TControl) =
  if self of TWinControl:
    let wc = TWinControl(self)
    if not wc.layouting: wc.layoutChildren()
  if self.fParent != nil and not self.fParent.layouting:
    self.fParent.layoutChildren()

proc `left=`*(self: TControl, v: int) =
  self.fLeft = v
  if self.fAlign == alNone: self.placeWidget()
  elif self.fParent != nil and not self.fParent.layouting: self.fParent.layoutChildren()

proc `top=`*(self: TControl, v: int) =
  self.fTop = v
  if self.fAlign == alNone: self.placeWidget()
  elif self.fParent != nil and not self.fParent.layouting: self.fParent.layoutChildren()

proc `width=`*(self: TControl, v: int) =
  let n = max(0, v)
  self.fWidth = n
  if self.fAlign in {alLeft, alRight}:
    self.fSideSpan = n
  self.placeWidget()
  self.relayoutFrom()

proc `height=`*(self: TControl, v: int) =
  self.fHeight = max(0, v)
  self.placeWidget()
  self.relayoutFrom()

proc setBounds*(self: TControl, x, y, w, h: int) =
  self.fLeft = x
  self.fTop = y
  self.fWidth = max(0, w)
  self.fHeight = max(0, h)
  if self.fAlign in {alLeft, alRight}:
    self.fSideSpan = self.fWidth
  self.placeWidget()
  self.relayoutFrom()

proc `align=`*(self: TControl, v: TAlign) =
  self.fAlign = v
  if v in {alLeft, alRight}:
    if self.fSideSpan <= 0:
      self.fSideSpan = max(0, self.fWidth)
  else:
    self.fSideSpan = 0
  if self.fParent != nil: self.fParent.layoutChildren()

proc responsive*(self: TWinControl): bool = self.fResponsive
proc `responsive=`*(self: TWinControl, v: bool) =
  self.fResponsive = v
  if not self.layouting: self.layoutChildren()

proc breakWidth*(self: TWinControl): int = self.fBreakWidth
proc `breakWidth=`*(self: TWinControl, v: int) =
  self.fBreakWidth = max(0, v)
  if not self.layouting: self.layoutChildren()

proc `anchors=`*(self: TControl, v: set[TAnchorKind]) = self.fAnchors = v

proc `visible=`*(self: TControl, v: bool) =
  self.fVisible = v
  let laid = self.layoutChild()
  if laid != nil:
    if v: gtk_widget_show_all(laid) else: gtk_widget_hide(laid)
  if self.fParent != nil and not self.fParent.layouting:
    self.fParent.layoutChildren()

proc `enabled=`*(self: TControl, v: bool) =
  self.fEnabled = v
  if self.handle != nil:
    gtk_widget_set_sensitive(self.handle, if v: 1 else: 0)

proc `hint=`*(self: TControl, v: string) =
  self.fHint = v
  self.fShowHint = v.len > 0
  if self.handle != nil:
    if v.len > 0: gtk_widget_set_tooltip_text(self.handle, v.cstring)
    else: gtk_widget_set_tooltip_text(self.handle, nil)

proc `color=`*(self: TControl, v: TColor) =
  self.fColor = v
  self.fParentColor = v == clNone
  self.applyChrome()

proc touchFont(self: TControl) =
  self.fParentFont = false
  self.applyChrome()

proc `caption=`*(self: TControl, v: string) =
  self.fCaption = v
  self.applyChrome()

proc childControls*(self: TWinControl): seq[TControl] =
  for c in self.controls:
    if not c.internal: result.add(c)

proc markDesign(self: TComponent, v: bool) =
  if self.designing == v and self.owned.len == 0 and (not (self of TWinControl) or TWinControl(self).controls.len == 0):
    self.designing = v
    return
  self.designing = v
  if self of TWinControl:
    for c in TWinControl(self).controls:
      if c.designing != v: c.markDesign(v)
  for c in self.owned:
    if c.designing != v: c.markDesign(v)

proc isNonVisualClass*(cls: string): bool = cls in nonVisual

proc registerClass(cls, parent: string, factory: proc(owner: TComponent): TComponent {.closure.} = nil, visual = true) =
  classParent[cls] = parent
  if factory != nil: factories[cls] = factory
  if cls notin declaredProps: declaredProps[cls] = @[]
  if not visual: nonVisual.incl(cls)

proc addPalette(cls, category, caption: string) =
  palette.add(TPaletteItem(cls: cls, category: category, caption: caption))

proc paletteItems*(): seq[TPaletteItem] = palette

proc registeredClasses*(): seq[string] =
  for k in factories.keys: result.add(k)

proc createComponent*(cls: string, owner: TComponent): TComponent =
  if cls notin factories:
    raise newException(ValueError, "unknown component " & cls)
  factories[cls](owner)

proc addProp(cls: string, p: TProp) =
  if cls notin declaredProps: declaredProps[cls] = @[]
  declaredProps[cls].add(p)

proc propInt(cls, name: string, get: proc(c: TComponent): int {.closure.}, set: proc(c: TComponent, v: int) {.closure.}) =
  addProp(cls, TProp(name: name, kind: pkInt,
    get: proc(c: TComponent): string = $get(c),
    set: proc(c: TComponent, v: string) = set(c, parseInt(v.strip))))

proc propBool(cls, name: string, get: proc(c: TComponent): bool {.closure.}, set: proc(c: TComponent, v: bool) {.closure.}) =
  addProp(cls, TProp(name: name, kind: pkBool,
    get: proc(c: TComponent): string = (if get(c): "True" else: "False"),
    set: proc(c: TComponent, v: string) =
      let t = v.toLowerAscii
      set(c, t == "true" or t == "1" or t == "yes")))

proc propStr(cls, name: string, kind: TPropKind, get: proc(c: TComponent): string {.closure.}, set: proc(c: TComponent, v: string) {.closure.}) =
  addProp(cls, TProp(name: name, kind: kind, get: get, set: set))

proc propEnum(cls, name: string, names: openArray[string], get: proc(c: TComponent): string {.closure.}, set: proc(c: TComponent, v: string) {.closure.}) =
  var en: seq[string]
  for n in names: en.add(n)
  addProp(cls, TProp(name: name, kind: pkEnum, enums: en, get: get, set: set))

proc propEvent(cls, name, sig: string) =
  let ev = name
  addProp(cls, TProp(name: name, kind: pkEvent, sig: sig,
    get: proc(c: TComponent): string = c.handler(ev),
    set: proc(c: TComponent, v: string) =
      c.`handler=`(ev, v.strip)))

proc setDefaultEvent(cls, ev: string) = defaultEvents[cls] = ev

proc allProps(cls: string): seq[TProp] =
  var chain: seq[string]
  var c = cls
  var guardN = 0
  while c.len > 0 and guardN < 24:
    chain.add(c)
    if classParent.hasKey(c): c = classParent[c] else: break
    inc guardN
  for i in countdown(chain.high, 0):
    if declaredProps.hasKey(chain[i]):
      for p in declaredProps[chain[i]]:
        result.add(p)

proc publishedProps*(cls: string): seq[TPropInfo] =
  for p in allProps(cls):
    result.add(TPropInfo(name: p.name, kind: p.kind, enums: p.enums, sig: p.sig))

proc getProp*(c: TComponent, name: string): string =
  for p in allProps(c.fClass):
    if cmpIgnoreCase(p.name, name) == 0: return p.get(c)
  raise newException(ValueError, c.fClass & " has no property " & name)

proc hasProp*(c: TComponent, name: string): bool =
  for p in allProps(c.fClass):
    if cmpIgnoreCase(p.name, name) == 0: return true

proc setProp*(c: TComponent, name, value: string) =
  for p in allProps(c.fClass):
    if cmpIgnoreCase(p.name, name) == 0:
      p.set(c, value)
      return
  raise newException(ValueError, c.fClass & " has no property " & name)

proc defaultEvent*(cls: string): string =
  var c = cls
  var guardN = 0
  while c.len > 0 and guardN < 24:
    if defaultEvents.hasKey(c): return defaultEvents[c]
    if classParent.hasKey(c): c = classParent[c] else: break
    inc guardN

proc eventSigOf*(cls, event: string): string =
  for p in allProps(cls):
    if p.name == event: return if p.sig.len > 0: p.sig else: "notify"
  "notify"

proc registerCoreProps() =
  registerClass("TComponent", "")
  propStr("TComponent", "Name", pkString,
    proc(c: TComponent): string = c.fName,
    proc(c: TComponent, v: string) = c.name = v.strip)
  propInt("TComponent", "Tag",
    proc(c: TComponent): int = c.fTag,
    proc(c: TComponent, v: int) = c.fTag = v)

  registerClass("TControl", "TComponent")
  propInt("TControl", "Left", proc(c: TComponent): int = TControl(c).fLeft, proc(c: TComponent, v: int) = TControl(c).left = v)
  propInt("TControl", "Top", proc(c: TComponent): int = TControl(c).fTop, proc(c: TComponent, v: int) = TControl(c).top = v)
  propInt("TControl", "Width", proc(c: TComponent): int = TControl(c).width, proc(c: TComponent, v: int) = TControl(c).width = v)
  propInt("TControl", "Height", proc(c: TComponent): int = TControl(c).fHeight, proc(c: TComponent, v: int) = TControl(c).height = v)
  propEnum("TControl", "Align", ["alNone", "alTop", "alBottom", "alLeft", "alRight", "alClient"],
    proc(c: TComponent): string = $TControl(c).fAlign,
    proc(c: TComponent, v: string) = TControl(c).align = parseEnum[TAlign](v.strip))
  propStr("TControl", "Anchors", pkString,
    proc(c: TComponent): string =
      var bits: seq[string]
      for a in TControl(c).fAnchors: bits.add($a)
      bits.join(","),
    proc(c: TComponent, v: string) =
      var s: set[TAnchorKind]
      for part in v.split(','):
        let t = part.strip
        if t.len > 0: s.incl(parseEnum[TAnchorKind](t))
      TControl(c).anchors = s)
  propBool("TControl", "Visible",
    proc(c: TComponent): bool = TControl(c).fVisible,
    proc(c: TComponent, v: bool) = TControl(c).visible = v)
  propBool("TControl", "Enabled",
    proc(c: TComponent): bool = TControl(c).fEnabled,
    proc(c: TComponent, v: bool) = TControl(c).enabled = v)
  propStr("TControl", "Hint", pkString,
    proc(c: TComponent): string = TControl(c).fHint,
    proc(c: TComponent, v: string) = TControl(c).hint = v)
  propStr("TControl", "Color", pkColor,
    proc(c: TComponent): string = colorName(TControl(c).fColor),
    proc(c: TComponent, v: string) = TControl(c).color = parseColor(v))
  propStr("TControl", "Font.Name", pkString,
    proc(c: TComponent): string = TControl(c).fFont.name,
    proc(c: TComponent, v: string) =
      TControl(c).fFont.name = v.strip
      TControl(c).touchFont())
  propInt("TControl", "Font.Size",
    proc(c: TComponent): int = TControl(c).fFont.size,
    proc(c: TComponent, v: int) =
      TControl(c).fFont.size = max(1, v)
      TControl(c).touchFont())
  propBool("TControl", "Font.Bold",
    proc(c: TComponent): bool = fsBold in TControl(c).fFont.styles,
    proc(c: TComponent, v: bool) =
      if v: TControl(c).fFont.styles.incl(fsBold)
      else: TControl(c).fFont.styles.excl(fsBold)
      TControl(c).touchFont())
  propStr("TControl", "Font.Color", pkColor,
    proc(c: TComponent): string = colorName(TControl(c).fFont.color),
    proc(c: TComponent, v: string) =
      TControl(c).fFont.color = parseColor(v)
      TControl(c).touchFont())
  propEvent("TControl", "OnClick", "notify")
  propEvent("TControl", "OnDblClick", "notify")

  registerClass("TWinControl", "TControl")
  propBool("TWinControl", "Responsive",
    proc(c: TComponent): bool = TWinControl(c).fResponsive,
    proc(c: TComponent, v: bool) = TWinControl(c).responsive = v)
  propInt("TWinControl", "BreakWidth",
    proc(c: TComponent): int = TWinControl(c).fBreakWidth,
    proc(c: TComponent, v: int) = TWinControl(c).breakWidth = v)

proc fillRect*(canvas: TCanvas, x, y, w, h: int, color: TColor) =
  if canvas == nil or canvas.cr == nil: return
  let n = int(color) and 0xFFFFFF
  cairo_set_source_rgba(canvas.cr, ((n shr 16) and 255) / 255, ((n shr 8) and 255) / 255, (n and 255) / 255, 1)
  cairo_rectangle(canvas.cr, x.float, y.float, w.float, h.float)
  cairo_fill(canvas.cr)

proc strokeRect*(canvas: TCanvas, x, y, w, h: int, color: TColor) =
  if canvas == nil or canvas.cr == nil: return
  let n = int(color) and 0xFFFFFF
  cairo_set_source_rgba(canvas.cr, ((n shr 16) and 255) / 255, ((n shr 8) and 255) / 255, (n and 255) / 255, 1)
  cairo_set_line_width(canvas.cr, 1)
  cairo_rectangle(canvas.cr, x.float + 0.5, y.float + 0.5, w.float - 1, h.float - 1)
  cairo_stroke(canvas.cr)

proc line*(canvas: TCanvas, x1, y1, x2, y2: int, color: TColor) =
  if canvas == nil or canvas.cr == nil: return
  let n = int(color) and 0xFFFFFF
  cairo_set_source_rgba(canvas.cr, ((n shr 16) and 255) / 255, ((n shr 8) and 255) / 255, (n and 255) / 255, 1)
  cairo_set_line_width(canvas.cr, 1)
  cairo_move_to(canvas.cr, x1.float, y1.float)
  cairo_line_to(canvas.cr, x2.float, y2.float)
  cairo_stroke(canvas.cr)

proc textOut*(canvas: TCanvas, x, y: int, s: string, color: TColor) =
  if canvas == nil or canvas.cr == nil: return
  let n = int(color) and 0xFFFFFF
  cairo_set_source_rgba(canvas.cr, ((n shr 16) and 255) / 255, ((n shr 8) and 255) / 255, (n and 255) / 255, 1)
  cairo_select_font_face(canvas.cr, "Sans", 0, 0)
  cairo_set_font_size(canvas.cr, 13)
  cairo_move_to(canvas.cr, x.float, y.float + 13)
  cairo_show_text(canvas.cr, s.cstring)

proc processMessages*(self: TApplication) =
  if headless or not gtkStarted: return
  var n = 0
  while gtk_events_pending() != 0 and n < 50:
    discard gtk_main_iteration()
    inc n

proc terminate*(self: TApplication) =
  self.terminated = true
  if self.running and gtkStarted:
    gtk_main_quit()

proc quitTimer(data: pointer): cint {.cdecl.} =
  if application != nil: application.terminate()
  return 0

proc armTimers(c: TComponent)
proc show*(self: TForm)
proc rebuildMenu(self: TForm)

proc run*(self: TApplication) =
  if self.terminated: return
  if headless: return
  ensureGtk()
  self.running = true
  if self.mainForm != nil:
    self.mainForm.show()
  let ms = getEnv("NAZARUS_QUIT_AFTER_MS")
  if ms.len > 0:
    discard g_timeout_add(cuint(parseInt(ms)), cast[pointer](quitTimer), nil)
  if not self.terminated:
    gtk_main()
  self.running = false

proc run*(self: TForm) =
  application.mainForm = self
  application.run()
