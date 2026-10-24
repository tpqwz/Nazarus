# GTK backends for the NCL controls, plus the constructors the palette and the
# streaming factory call.

proc gtkMnemonic(s: string): string =
  result = ""
  var i = 0
  while i < s.len:
    if s[i] == '&':
      if i + 1 < s.len and s[i + 1] == '&':
        result.add '&'
        inc i, 2
      else:
        result.add '_'
        inc i
    elif s[i] == '_':
      result.add "__"
      inc i
    else:
      result.add s[i]
      inc i

proc clearGtkChildren(w: pointer) =
  if w == nil: return
  var ptrs: seq[pointer]
  var child = gtk_container_get_children(w)
  let head = child
  while child != nil:
    let gl = cast[ptr GList](child)
    ptrs.add(gl.data)
    child = gl.next
  if head != nil: g_list_free(head)
  for p in ptrs: gtk_widget_destroy(p)

proc onClicked(widget: pointer, data: pointer) {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TControl): return
  let ctrl = TControl(c)
  if ctrl.designing or ctrl.refreshing: return
  if ctrl.onClick != nil: guard proc() = ctrl.onClick(ctrl)

proc onDbl(widget: pointer, data: pointer) {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TControl): return
  let ctrl = TControl(c)
  if ctrl.designing: return
  if ctrl.onDblClick != nil: guard proc() = ctrl.onDblClick(ctrl)

proc onToggled(widget: pointer, data: pointer) {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TControl) or TControl(c).refreshing: return
  let ctrl = TControl(c)
  if ctrl of TCheckBox:
    TCheckBox(ctrl).fChecked = gtk_toggle_button_get_active(ctrl.handle) != 0
  elif ctrl of TRadioButton:
    TRadioButton(ctrl).fChecked = gtk_toggle_button_get_active(ctrl.handle) != 0
  if ctrl.designing: return
  if ctrl.onClick != nil: guard proc() = ctrl.onClick(ctrl)
  if ctrl.onChange != nil: guard proc() = ctrl.onChange(ctrl)

proc onEntryChanged(widget: pointer, data: pointer) {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TEdit) or TEdit(c).refreshing: return
  let ed = TEdit(c)
  if ed.handle != nil:
    let p = gtk_entry_get_text(ed.handle)
    ed.fText = if p == nil: "" else: $p
  if ed.designing: return
  if ed.onChange != nil: guard proc() = ed.onChange(ed)

proc onComboChanged(widget: pointer, data: pointer) {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TComboBox) or TComboBox(c).refreshing: return
  let cb = TComboBox(c)
  cb.fItemIndex = int(gtk_combo_box_get_active(cb.handle))
  let owned = gtk_combo_box_text_get_active_text(cb.handle)
  if owned != nil:
    cb.fText = $owned
    g_free(cast[pointer](owned))
  if cb.designing: return
  if cb.onChange != nil: guard proc() = cb.onChange(cb)
  if cb.onClick != nil: guard proc() = cb.onClick(cb)

proc onRowSelected(box, row, data: pointer) {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TListBox) or TListBox(c).refreshing: return
  let lb = TListBox(c)
  if row == nil: lb.fItemIndex = -1
  else: lb.fItemIndex = int(gtk_list_box_row_get_index(row))
  if lb.designing: return
  if lb.onClick != nil: guard proc() = lb.onClick(lb)
  if lb.onChange != nil: guard proc() = lb.onChange(lb)

proc onRowActivated(box, row, data: pointer) {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TListBox) or TListBox(c).refreshing: return
  let lb = TListBox(c)
  if row != nil: lb.fItemIndex = int(gtk_list_box_row_get_index(row))
  if lb.designing: return
  if lb.onDblClick != nil: guard proc() = lb.onDblClick(lb)

proc onRangeChanged(widget: pointer, data: pointer) {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TTrackBar) or TTrackBar(c).refreshing: return
  let tb = TTrackBar(c)
  tb.fPosition = int(gtk_range_get_value(tb.handle))
  if tb.designing: return
  if tb.onChange != nil: guard proc() = tb.onChange(tb)

proc onPageSwitch(nb, page: pointer, index: cuint, data: pointer) {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TPageControl) or TPageControl(c).refreshing: return
  let pc = TPageControl(c)
  pc.fActive = int(index)
  if pc.designing: return
  if pc.onChangePage != nil: guard proc() = pc.onChangePage(pc)
  if pc.onChange != nil: guard proc() = pc.onChange(pc)

proc onMenuActivate(widget: pointer, data: pointer) {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TMenuItem): return
  let item = TMenuItem(c)
  if item.designing: return
  # A check item toggles itself before activate. Read that, or the handler
  # still sees the previous Checked value.
  if item.fCheckable and item.gtkItem != nil:
    item.fChecked = gtk_check_menu_item_get_active(item.gtkItem) != 0
  if item.onClick != nil: guard proc() = item.onClick(item)

proc onDeleteEvent(widget, event, data: pointer): cint {.cdecl.} =
  result = 1
  let c = recall(data)
  if c == nil or not (c of TForm): return
  let f = TForm(c)
  if f.designing: return
  var action = caHide
  if f.onClose != nil:
    guard proc() = f.onClose(f, action)
  if action == caNone: return
  if application != nil and application.mainForm == f:
    application.terminate()
  else:
    gtk_widget_hide(f.handle)

proc onTimeout(data: pointer): cint {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TTimer): return 0
  let t = TTimer(c)
  if t.dead or not t.fEnabled: return 0
  if t.designing: return 1
  if t.onTimer != nil: guard proc() = t.onTimer(t)
  1

proc textOfBuffer(buf: pointer): string =
  if buf == nil: return ""
  var s, e: array[32, int64]
  gtk_text_buffer_get_start_iter(buf, addr s[0])
  gtk_text_buffer_get_end_iter(buf, addr e[0])
  let p = gtk_text_buffer_get_text(buf, addr s[0], addr e[0], 0)
  if p == nil: return ""
  result = $p
  g_free(cast[pointer](p))

proc setBufferText(buf: pointer, s: string) =
  if buf == nil: return
  gtk_text_buffer_set_text(buf, s.cstring, -1)

proc onMemoChanged(widget: pointer, data: pointer) {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TControl) or TControl(c).refreshing: return
  if c of TMemo:
    let m = TMemo(c)
    m.fText = textOfBuffer(m.inner)
    if not m.designing and m.onChange != nil: guard proc() = m.onChange(m)
  elif c of TSourceEditor:
    let ed = TSourceEditor(c)
    if ed.gutter != nil: gtk_widget_queue_draw(ed.gutter)
    if ed.mute: return
    if ed.onChange != nil: guard proc() = ed.onChange(ed)

# ---- buttons, labels, edits -------------------------------------------------

proc pushButton(self: TControl) =
  if self.handle == nil: return
  gtk_button_set_label(self.handle, gtkMnemonic(self.fCaption).cstring)
  gtk_button_set_use_underline(self.handle, 1)

proc createButton(self: TControl) =
  self.handle = gtk_button_new_with_label("")
  connect(self.handle, "clicked", cast[pointer](onClicked), self.liveId)
  pushButton(self)

proc naturalSize*(self: TControl): tuple[w, h: int] =
  ## Size the widget wants for its content. A size request already applied is
  ## cleared first, because that request becomes the minimum and hides the label.
  if headless or self.handle == nil:
    return (max(1, self.fWidth), max(1, self.fHeight))
  gtk_widget_set_size_request(self.handle, -1, -1)
  var nat: GtkRequisition
  gtk_widget_get_preferred_size(self.handle, nil, addr nat)
  let w = if nat.width > 1: int(nat.width) else: max(1, self.fWidth)
  let h = if nat.height > 1: int(nat.height) else: max(1, self.fHeight)
  (w, h)

proc new*(_: typedesc[TButton], owner: TComponent = nil): TButton =
  result = TButton()
  initControl(result, "TButton", owner)
  result.fWidth = 75
  result.fHeight = 25
  result.fCaption = result.fName
  result.createImpl = createButton
  result.pushState = pushButton

proc pushLabel(self: TControl) =
  let lb = TLabel(self)
  if lb.handle == nil: return
  gtk_label_set_text(lb.handle, lb.fCaption.cstring)
  gtk_label_set_line_wrap(lb.handle, if lb.fWordWrap: 1 else: 0)
  case lb.fAlignment
  of taLeftJustify: gtk_label_set_xalign(lb.handle, 0)
  of taCenter: gtk_label_set_xalign(lb.handle, 0.5)
  of taRightJustify: gtk_label_set_xalign(lb.handle, 1)
  if lb.fAutoSize:
    var nat: GtkRequisition
    gtk_widget_get_preferred_size(lb.handle, nil, addr nat)
    if nat.width > 0:
      lb.fWidth = int(nat.width) + 2
      lb.fHeight = max(16, int(nat.height))
      lb.placeWidget()

proc createLabel(self: TControl) =
  self.handle = gtk_label_new("")
  gtk_label_set_xalign(self.handle, 0)
  pushLabel(self)

proc new*(_: typedesc[TLabel], owner: TComponent = nil): TLabel =
  result = TLabel()
  initControl(result, "TLabel", owner)
  result.fAutoSize = true
  result.fCaption = result.fName
  result.fWidth = 48
  result.fHeight = 18
  result.createImpl = createLabel
  result.pushState = pushLabel

proc alignment*(self: TLabel): TAlignment = self.fAlignment
proc `alignment=`*(self: TLabel, v: TAlignment) =
  self.fAlignment = v
  self.applyChrome()
proc autoSize*(self: TLabel): bool = self.fAutoSize
proc `autoSize=`*(self: TLabel, v: bool) =
  self.fAutoSize = v
  self.applyChrome()
proc wordWrap*(self: TLabel): bool = self.fWordWrap
proc `wordWrap=`*(self: TLabel, v: bool) =
  self.fWordWrap = v
  self.applyChrome()

proc text*(self: TEdit): string = self.fText
proc `text=`*(self: TEdit, v: string) =
  self.fText = v
  if self.handle != nil and not self.refreshing:
    self.refreshing = true
    gtk_entry_set_text(self.handle, v.cstring)
    self.refreshing = false

proc readOnly*(self: TEdit): bool = self.fReadOnly
proc `readOnly=`*(self: TEdit, v: bool) =
  self.fReadOnly = v
  if self.handle != nil: gtk_editable_set_editable(self.handle, if v: 0 else: 1)

proc password*(self: TEdit): bool = self.fPassword
proc `password=`*(self: TEdit, v: bool) =
  self.fPassword = v
  if self.handle != nil: gtk_entry_set_visibility(self.handle, if v: 0 else: 1)

proc pushEdit(self: TControl) =
  let ed = TEdit(self)
  if ed.handle == nil: return
  ed.refreshing = true
  gtk_entry_set_text(ed.handle, ed.fText.cstring)
  gtk_editable_set_editable(ed.handle, if ed.fReadOnly: 0 else: 1)
  gtk_entry_set_visibility(ed.handle, if ed.fPassword: 0 else: 1)
  ed.refreshing = false

proc createEdit(self: TControl) =
  self.handle = gtk_entry_new()
  connect(self.handle, "changed", cast[pointer](onEntryChanged), self.liveId)
  pushEdit(self)

proc new*(_: typedesc[TEdit], owner: TComponent = nil): TEdit =
  result = TEdit()
  initControl(result, "TEdit", owner)
  result.fWidth = 120
  result.fHeight = 26
  result.createImpl = createEdit
  result.pushState = pushEdit

proc text*(self: TMemo): string = self.fText
proc `text=`*(self: TMemo, v: string) =
  self.fText = v
  if self.inner != nil and not self.refreshing:
    self.refreshing = true
    setBufferText(self.inner, v)
    self.refreshing = false

proc scrollMemoEnd(data: pointer): cint {.cdecl.} =
  let c = recall(data)
  if c != nil and c of TMemo:
    let m = TMemo(c)
    if m.handle != nil:
      let adj = gtk_scrolled_window_get_vadjustment(m.handle)
      if adj != nil:
        let top = gtk_adjustment_get_upper(adj) - gtk_adjustment_get_page_size(adj)
        gtk_adjustment_set_value(adj, if top > 0: top else: 0)
  0

proc scrollToEnd*(self: TMemo) =
  ## Replacing the buffer jumps back to the first line. The compile log
  ## wants the line that just arrived, after GTK has remeasured the text.
  if headless or self.handle == nil: return
  discard g_timeout_add(0, cast[pointer](scrollMemoEnd), cast[pointer](self.liveId))
proc lines*(self: TMemo): string = self.fText
proc `lines=`*(self: TMemo, v: string) = self.text = v
proc readOnly*(self: TMemo): bool = self.fReadOnly
proc `readOnly=`*(self: TMemo, v: bool) =
  self.fReadOnly = v
  if self.extra != nil: gtk_text_view_set_editable(self.extra, if v: 0 else: 1)
proc wordWrap*(self: TMemo): bool = self.fWordWrap
proc `wordWrap=`*(self: TMemo, v: bool) =
  self.fWordWrap = v
  if self.extra != nil:
    gtk_text_view_set_wrap_mode(self.extra, if v: 2 else: 0)

proc pushMemo(self: TControl) =
  let m = TMemo(self)
  if m.inner == nil: return
  m.refreshing = true
  setBufferText(m.inner, m.fText)
  if m.extra != nil:
    gtk_text_view_set_editable(m.extra, if m.fReadOnly: 0 else: 1)
    gtk_text_view_set_wrap_mode(m.extra, if m.fWordWrap: 2 else: 0)
    gtk_text_view_set_monospace(m.extra, if m.fMonospace: 1 else: 0)
  m.refreshing = false

proc `monospace=`*(self: TMemo, v: bool) =
  self.fMonospace = v
  if self.extra != nil: gtk_text_view_set_monospace(self.extra, if v: 1 else: 0)

proc selectRange*(self: TMemo, start, length: int) =
  ## Select `length` characters at `start` and scroll that spot into view.
  ## Offsets count characters, so a multibyte letter is one position.
  if headless or self.inner == nil: return
  let a = max(0, start)
  let b = a + max(0, length)
  var ia, ib: array[32, int64]
  gtk_text_buffer_get_iter_at_offset(self.inner, addr ia[0], cint(a))
  gtk_text_buffer_get_iter_at_offset(self.inner, addr ib[0], cint(b))
  gtk_text_buffer_select_range(self.inner, addr ia[0], addr ib[0])
  if self.extra != nil:
    gtk_text_view_scroll_to_iter(self.extra, addr ia[0], 0.05, 1, 0.0, 0.3)

proc selection*(self: TMemo): tuple[start, length: int] =
  if headless or self.inner == nil: return (-1, 0)
  var ia, ib: array[32, int64]
  if gtk_text_buffer_get_selection_bounds(self.inner, addr ia[0], addr ib[0]) == 0:
    return (int(gtk_text_iter_get_offset(addr ia[0])), 0)
  let s = int(gtk_text_iter_get_offset(addr ia[0]))
  let e = int(gtk_text_iter_get_offset(addr ib[0]))
  (min(s, e), abs(e - s))

proc memoCaret(self: TMemo): tuple[line, column: int] =
  ## 1-based insert caret. Both are 0 when the memo has no text buffer.
  if self.inner == nil: return
  let mark = gtk_text_buffer_get_insert(self.inner)
  if mark == nil: return
  var it: array[32, int64]
  gtk_text_buffer_get_iter_at_mark(self.inner, addr it[0], mark)
  (int(gtk_text_iter_get_line(addr it[0])) + 1, int(gtk_text_iter_get_line_offset(addr it[0])) + 1)

proc caretLine*(self: TMemo): int = self.memoCaret.line
proc caretColumn*(self: TMemo): int = self.memoCaret.column

proc onMemoRelease(widget, ev, data: pointer): cint {.cdecl.} =
  var b: cuint
  discard gdk_event_get_button(ev, addr b)
  if b != 1: return 0
  let c = recall(data)
  if c != nil and c of TMemo:
    let m = TMemo(c)
    if m.onClick != nil:
      guard proc() = m.onClick(m)
  0

proc createMemo(self: TControl) =
  let m = TMemo(self)
  let sw = gtk_scrolled_window_new(nil, nil)
  gtk_scrolled_window_set_policy(sw, GtkPolicyAuto, GtkPolicyAuto)
  gtk_scrolled_window_set_shadow_type(sw, GtkShadowIn)
  let tv = gtk_text_view_new()
  gtk_text_view_set_wrap_mode(tv, 2)
  let buf = gtk_text_view_get_buffer(tv)
  gtk_container_add(sw, tv)
  m.handle = sw
  m.inner = buf
  m.extra = tv
  m.fWordWrap = true
  connect(buf, "changed", cast[pointer](onMemoChanged), m.liveId)
  connect(tv, "button-release-event", cast[pointer](onMemoRelease), m.liveId)
  pushMemo(m)

proc new*(_: typedesc[TMemo], owner: TComponent = nil): TMemo =
  result = TMemo()
  initControl(result, "TMemo", owner)
  result.fWidth = 185
  result.fHeight = 90
  result.fWordWrap = true
  result.createImpl = createMemo
  result.pushState = pushMemo

proc checked*(self: TCheckBox): bool = self.fChecked
proc `checked=`*(self: TCheckBox, v: bool) =
  self.fChecked = v
  if self.handle != nil and not self.refreshing:
    self.refreshing = true
    gtk_toggle_button_set_active(self.handle, if v: 1 else: 0)
    self.refreshing = false

proc pushCheck(self: TControl) =
  let b = TCheckBox(self)
  if b.handle == nil: return
  gtk_button_set_label(b.handle, gtkMnemonic(b.fCaption).cstring)
  gtk_button_set_use_underline(b.handle, 1)
  b.refreshing = true
  gtk_toggle_button_set_active(b.handle, if b.fChecked: 1 else: 0)
  b.refreshing = false

proc createCheck(self: TControl) =
  self.handle = gtk_check_button_new_with_label("")
  connect(self.handle, "toggled", cast[pointer](onToggled), self.liveId)
  pushCheck(self)

proc new*(_: typedesc[TCheckBox], owner: TComponent = nil): TCheckBox =
  result = TCheckBox()
  initControl(result, "TCheckBox", owner)
  result.fWidth = 110
  result.fHeight = 22
  result.fCaption = result.fName
  result.createImpl = createCheck
  result.pushState = pushCheck

proc checked*(self: TRadioButton): bool = self.fChecked
proc `checked=`*(self: TRadioButton, v: bool) =
  self.fChecked = v
  if self.handle != nil and not self.refreshing:
    self.refreshing = true
    gtk_toggle_button_set_active(self.handle, if v: 1 else: 0)
    self.refreshing = false

proc pushRadio(self: TControl) =
  let b = TRadioButton(self)
  if b.handle == nil: return
  gtk_button_set_label(b.handle, b.fCaption.cstring)
  b.refreshing = true
  gtk_toggle_button_set_active(b.handle, if b.fChecked: 1 else: 0)
  b.refreshing = false

proc createRadio(self: TControl) =
  var groupFrom: pointer = nil
  if self.fParent != nil:
    for c in self.fParent.controls:
      if c of TRadioButton and c != self and c.handle != nil:
        groupFrom = c.handle
        break
  if groupFrom == nil:
    self.handle = gtk_radio_button_new_with_label(nil, "".cstring)
  else:
    self.handle = gtk_radio_button_new_with_label_from_widget(groupFrom, "".cstring)
  connect(self.handle, "toggled", cast[pointer](onToggled), self.liveId)
  pushRadio(self)

proc new*(_: typedesc[TRadioButton], owner: TComponent = nil): TRadioButton =
  result = TRadioButton()
  initControl(result, "TRadioButton", owner)
  result.fWidth = 110
  result.fHeight = 22
  result.fCaption = result.fName
  result.createImpl = createRadio
  result.pushState = pushRadio

proc items*(self: TListBox): seq[string] = self.fItems
proc itemIndex*(self: TListBox): int = self.fItemIndex

proc selectList(self: TListBox) =
  if self.inner == nil: return
  if self.fItemIndex < 0: return
  # Rows are direct children; select by walking them in order.
  var child = gtk_container_get_children(self.inner)
  let head = child
  var i = 0
  while child != nil:
    let gl = cast[ptr GList](child)
    if i == self.fItemIndex:
      gtk_list_box_select_row(self.inner, gl.data)
      break
    child = gl.next
    inc i
  if head != nil: g_list_free(head)

proc pushList(self: TControl) =
  let lb = TListBox(self)
  if lb.inner == nil: return
  lb.refreshing = true
  clearGtkChildren(lb.inner)
  for item in lb.fItems:
    let lab = gtk_label_new(item.cstring)
    gtk_label_set_xalign(lab, 0)
    gtk_widget_set_margin_start(lab, 4)
    gtk_widget_show(lab)
    gtk_list_box_insert(lb.inner, lab, -1)
  lb.selectList()
  lb.refreshing = false

proc `items=`*(self: TListBox, v: seq[string]) =
  self.fItems = v
  if self.fItemIndex >= v.len: self.fItemIndex = v.len - 1
  self.applyChrome()

proc `itemIndex=`*(self: TListBox, v: int) =
  self.fItemIndex = v
  if self.inner != nil and not self.refreshing:
    self.refreshing = true
    self.selectList()
    self.refreshing = false

proc createList(self: TControl) =
  let lb = TListBox(self)
  let sw = gtk_scrolled_window_new(nil, nil)
  gtk_scrolled_window_set_policy(sw, GtkPolicyAuto, GtkPolicyAuto)
  gtk_scrolled_window_set_shadow_type(sw, GtkShadowIn)
  let box = gtk_list_box_new()
  gtk_container_add(sw, box)
  lb.handle = sw
  lb.inner = box
  connect(box, "row-selected", cast[pointer](onRowSelected), lb.liveId)
  connect(box, "row-activated", cast[pointer](onRowActivated), lb.liveId)
  pushList(lb)

proc new*(_: typedesc[TListBox], owner: TComponent = nil): TListBox =
  result = TListBox()
  initControl(result, "TListBox", owner)
  result.fWidth = 130
  result.fHeight = 90
  result.fItemIndex = -1
  result.createImpl = createList
  result.pushState = pushList

proc items*(self: TComboBox): seq[string] = self.fItems
proc itemIndex*(self: TComboBox): int = self.fItemIndex
proc text*(self: TComboBox): string = self.fText
proc style*(self: TComboBox): TComboBoxStyle = self.fStyle

proc pushCombo(self: TControl) =
  let cb = TComboBox(self)
  if cb.handle == nil: return
  cb.refreshing = true
  gtk_combo_box_text_remove_all(cb.handle)
  for item in cb.fItems:
    gtk_combo_box_text_append_text(cb.handle, item.cstring)
  if cb.fItemIndex >= 0 and cb.fItemIndex < cb.fItems.len:
    gtk_combo_box_set_active(cb.handle, cb.fItemIndex.cint)
  cb.refreshing = false

proc `items=`*(self: TComboBox, v: seq[string]) =
  self.fItems = v
  if self.fItemIndex >= v.len: self.fItemIndex = v.len - 1
  self.applyChrome()

proc `itemIndex=`*(self: TComboBox, v: int) =
  self.fItemIndex = v
  if v >= 0 and v < self.fItems.len: self.fText = self.fItems[v]
  if self.handle != nil and not self.refreshing:
    self.refreshing = true
    gtk_combo_box_set_active(self.handle, v.cint)
    self.refreshing = false

proc `text=`*(self: TComboBox, v: string) =
  self.fText = v
  self.applyChrome()

proc recreateCombo(self: TComboBox) =
  let parent = self.fParent
  if self.socket != nil:
    gtk_widget_destroy(self.socket)
    self.socket = nil
  elif self.handle != nil:
    gtk_widget_destroy(self.handle)
  self.handle = nil
  self.placed = false
  self.held = false
  self.css = nil
  if self.createImpl != nil: self.createImpl(self)
  self.applyChrome()
  if parent != nil: self.placeWidget()

proc `style=`*(self: TComboBox, v: TComboBoxStyle) =
  if v == self.fStyle: return
  self.fStyle = v
  if self.handle != nil: self.recreateCombo()

proc createCombo(self: TControl) =
  let cb = TComboBox(self)
  if cb.fStyle == csDropDown:
    cb.handle = gtk_combo_box_text_new_with_entry()
  else:
    cb.handle = gtk_combo_box_text_new()
  connect(cb.handle, "changed", cast[pointer](onComboChanged), cb.liveId)
  pushCombo(cb)

proc new*(_: typedesc[TComboBox], owner: TComponent = nil): TComboBox =
  result = TComboBox()
  initControl(result, "TComboBox", owner)
  result.fWidth = 130
  result.fHeight = 28
  result.fItemIndex = -1
  result.fStyle = csDropDownList
  result.createImpl = createCombo
  result.pushState = pushCombo

proc installFrame(self: TWinControl, title: string) =
  let frame = gtk_frame_new(title.cstring)
  let box = gtk_box_new(GtkOrientVertical, 0)
  let lay = gtk_layout_new(nil, nil)
  gtk_widget_set_hexpand(lay, 1)
  gtk_widget_set_vexpand(lay, 1)
  gtk_box_pack_start(box, lay, 1, 1, 0)
  gtk_container_add(frame, box)
  self.handle = frame
  self.client = lay
  self.borderLeft = 6
  self.borderRight = 6
  self.borderBottom = 6
  self.borderTop = 20

proc pushGroup(self: TControl) =
  if self.handle != nil:
    gtk_frame_set_label(self.handle, self.fCaption.cstring)

proc createGroup(self: TControl) =
  TWinControl(self).installFrame(self.fCaption)
  pushGroup(self)

proc new*(_: typedesc[TGroupBox], owner: TComponent = nil): TGroupBox =
  result = TGroupBox()
  initControl(result, "TGroupBox", owner)
  result.fWidth = 185
  result.fHeight = 105
  result.fCaption = result.fName
  result.createImpl = createGroup
  result.pushState = pushGroup

proc items*(self: TRadioGroup): seq[string] = self.fItems
proc itemIndex*(self: TRadioGroup): int = self.fItemIndex

proc rebuildRadios(self: TRadioGroup) =
  var kept: seq[TControl]
  for c in self.controls:
    if c.internal:
      if c.handle != nil: gtk_widget_destroy(c.handle)
      c.handle = nil
      c.dead = true
      c.fParent = nil
      if c.liveId > 0 and c.liveId < live.len: live[c.liveId] = nil
    else:
      kept.add(c)
  self.controls = kept
  var still: seq[TComponent]
  for c in self.owned:
    if not c.dead and not c.internal: still.add(c)
  self.owned = still
  self.refreshing = true
  for i, item in self.fItems:
    let rb = TRadioButton.new(self)
    rb.internal = true
    rb.fCaption = item
    rb.fLeft = 8
    rb.fTop = 4 + i * 22
    rb.fWidth = max(40, self.fWidth - 24)
    rb.fHeight = 22
    rb.parent = self
    if i == self.fItemIndex: rb.checked = true
    let idx = i
    let group = self
    rb.onClick = proc(sender: TObject) =
      if group.refreshing: return
      group.fItemIndex = idx
      if not group.designing and group.onClick != nil: group.onClick(group)
  self.refreshing = false

proc `items=`*(self: TRadioGroup, v: seq[string]) =
  self.fItems = v
  if self.fItemIndex >= v.len: self.fItemIndex = v.len - 1
  self.rebuildRadios()

proc `itemIndex=`*(self: TRadioGroup, v: int) =
  self.fItemIndex = v
  self.refreshing = true
  var i = 0
  for c in self.controls:
    if c of TRadioButton and c.internal:
      TRadioButton(c).checked = i == v
      inc i
  self.refreshing = false

proc pushRadioGroup(self: TControl) =
  if self.handle != nil:
    gtk_frame_set_label(self.handle, self.fCaption.cstring)

proc createRadioGroup(self: TControl) =
  let g = TRadioGroup(self)
  g.installFrame(g.fCaption)
  g.rebuildRadios()

proc new*(_: typedesc[TRadioGroup], owner: TComponent = nil): TRadioGroup =
  result = TRadioGroup()
  initControl(result, "TRadioGroup", owner)
  result.fWidth = 185
  result.fHeight = 105
  result.fCaption = result.fName
  result.fItemIndex = -1
  result.createImpl = createRadioGroup
  result.pushState = pushRadioGroup

proc bevel*(self: TPanel): TBevelCut = self.fBevel
proc `bevel=`*(self: TPanel, v: TBevelCut) =
  self.fBevel = v
  if v == bvNone:
    self.borderLeft = 0
    self.borderTop = 0
    self.borderRight = 0
    self.borderBottom = 0
  else:
    self.borderLeft = 2
    self.borderTop = 2
    self.borderRight = 2
    self.borderBottom = 2
  self.relayoutFrom()

proc pushPanel(self: TControl) =
  let p = TPanel(self)
  if p.capLabel != nil:
    gtk_label_set_text(p.capLabel, p.fCaption.cstring)
    if p.fCaption.len == 0: gtk_widget_hide(p.capLabel)
    else: gtk_widget_show(p.capLabel)

proc createPanel(self: TControl) =
  let p = TPanel(self)
  let eb = gtk_event_box_new()
  let lay = gtk_layout_new(nil, nil)
  gtk_widget_set_hexpand(lay, 1)
  gtk_widget_set_vexpand(lay, 1)
  p.capLabel = gtk_label_new(p.fCaption.cstring)
  gtk_layout_put(lay, p.capLabel, 8, 8)
  gtk_widget_show(p.capLabel)
  gtk_container_add(eb, lay)
  p.handle = eb
  p.client = lay
  p.bevel = p.fBevel
  pushPanel(p)

proc new*(_: typedesc[TPanel], owner: TComponent = nil): TPanel =
  result = TPanel()
  initControl(result, "TPanel", owner)
  result.fWidth = 185
  result.fHeight = 80
  result.fBevel = bvRaised
  result.fCaption = ""
  result.borderLeft = 2
  result.borderTop = 2
  result.borderRight = 2
  result.borderBottom = 2
  result.createImpl = createPanel
  result.pushState = pushPanel

proc onBevelDraw(widget, cr, data: pointer): cint {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TBevel): return 0
  let b = TBevel(c)
  let w = float(max(2, b.fWidth))
  let h = float(max(2, b.fHeight))
  cairo_set_line_width(cr, 1)
  cairo_set_source_rgba(cr, 0.45, 0.45, 0.48, 1)
  case b.fShape
  of bsBox, bsFrame:
    cairo_rectangle(cr, 0.5, 0.5, w - 1, h - 1)
    cairo_stroke(cr)
  of bsTopLine:
    cairo_move_to(cr, 0, 0.5); cairo_line_to(cr, w, 0.5); cairo_stroke(cr)
  of bsBottomLine:
    cairo_move_to(cr, 0, h - 0.5); cairo_line_to(cr, w, h - 0.5); cairo_stroke(cr)
  of bsLeftLine:
    cairo_move_to(cr, 0.5, 0); cairo_line_to(cr, 0.5, h); cairo_stroke(cr)
  of bsRightLine:
    cairo_move_to(cr, w - 0.5, 0); cairo_line_to(cr, w - 0.5, h); cairo_stroke(cr)
  0

proc shape*(self: TBevel): TBevelShape = self.fShape
proc `shape=`*(self: TBevel, v: TBevelShape) =
  self.fShape = v
  if self.handle != nil: gtk_widget_queue_draw(self.handle)
proc bevel*(self: TBevel): TBevelCut = self.fBevel
proc `bevel=`*(self: TBevel, v: TBevelCut) = self.fBevel = v

proc createBevel(self: TControl) =
  self.handle = gtk_drawing_area_new()
  connect(self.handle, "draw", cast[pointer](onBevelDraw), self.liveId)

proc new*(_: typedesc[TBevel], owner: TComponent = nil): TBevel =
  result = TBevel()
  initControl(result, "TBevel", owner)
  result.fWidth = 80
  result.fHeight = 80
  result.fShape = bsBox
  result.fBevel = bvLowered
  result.createImpl = createBevel

proc onPaintDraw(widget, cr, data: pointer): cint {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TPaintBox): return 0
  let pb = TPaintBox(c)
  if pb.onPaint != nil and not pb.designing:
    let canvas = TCanvas(cr: cr)
    guard proc() = pb.onPaint(pb, canvas)
  if pb.designing or pb.onPaint == nil:
    cairo_set_source_rgba(cr, 0.55, 0.6, 0.7, 1)
    cairo_set_line_width(cr, 1)
    cairo_rectangle(cr, 0.5, 0.5, float(max(2, pb.fWidth)) - 1, float(max(2, pb.fHeight)) - 1)
    cairo_stroke(cr)
  0

proc createPaint(self: TControl) =
  self.handle = gtk_drawing_area_new()
  gtk_widget_set_app_paintable(self.handle, 1)
  connect(self.handle, "draw", cast[pointer](onPaintDraw), self.liveId)

proc new*(_: typedesc[TPaintBox], owner: TComponent = nil): TPaintBox =
  result = TPaintBox()
  initControl(result, "TPaintBox", owner)
  result.fWidth = 120
  result.fHeight = 80
  result.createImpl = createPaint

proc prevSplitSibling(self: TSplitter): TControl =
  if self.fParent == nil: return nil
  var prev: TControl = nil
  for c in self.fParent.controls:
    if c == self: return prev
    if c.fVisible and not (c of TSplitter): prev = c

proc onSplitPress(widget, ev, data: pointer): cint {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TSplitter): return 0
  let sp = TSplitter(c)
  if sp.designing: return 0
  var x, y: cdouble
  discard gdk_event_get_coords(ev, addr x, addr y)
  sp.sibling = sp.prevSplitSibling()
  if sp.sibling == nil: return 0
  sp.dragging = true
  if sp.fAlign in {alTop, alBottom}:
    sp.dragOrigin = int(y)
    sp.siblingOrigin = sp.sibling.fHeight
  else:
    sp.dragOrigin = int(x)
    sp.siblingOrigin = sp.sibling.fWidth
  1

proc onSplitMotion(widget, ev, data: pointer): cint {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TSplitter): return 0
  let sp = TSplitter(c)
  if not sp.dragging or sp.sibling == nil: return 0
  var x, y: cdouble
  discard gdk_event_get_coords(ev, addr x, addr y)
  if sp.fAlign in {alTop, alBottom}:
    let d = int(y) - sp.dragOrigin
    let h = if sp.fAlign == alBottom: sp.siblingOrigin - d else: sp.siblingOrigin + d
    sp.sibling.height = max(20, h)
  else:
    let d = int(x) - sp.dragOrigin
    let w = if sp.fAlign == alRight: sp.siblingOrigin - d else: sp.siblingOrigin + d
    sp.sibling.width = max(20, w)
  1

proc onSplitRelease(widget, ev, data: pointer): cint {.cdecl.} =
  let c = recall(data)
  if c != nil and c of TSplitter: TSplitter(c).dragging = false
  0

proc createSplitter(self: TControl) =
  self.handle = gtk_event_box_new()
  let css = gtk_css_provider_new()
  cssLoad(css, "* { background-color: #c8c8c8; }")
  gtk_style_context_add_provider(gtk_widget_get_style_context(self.handle), css, CssPrioApp)
  self.css = css
  let mask = GdkButtonPressMask or GdkButtonReleaseMask or GdkPointerMotionMask or GdkButtonMotionMask
  gtk_widget_add_events(self.handle, mask.cint)
  connect(self.handle, "button-press-event", cast[pointer](onSplitPress), self.liveId)
  connect(self.handle, "motion-notify-event", cast[pointer](onSplitMotion), self.liveId)
  connect(self.handle, "button-release-event", cast[pointer](onSplitRelease), self.liveId)

proc new*(_: typedesc[TSplitter], owner: TComponent = nil): TSplitter =
  result = TSplitter()
  initControl(result, "TSplitter", owner)
  result.fAlign = alLeft
  result.fWidth = 5
  result.fHeight = 80
  result.createImpl = createSplitter

proc nudgeAdj(adj: pointer, delta: float) =
  if adj == nil or abs(delta) < 0.0001: return
  let lower = gtk_adjustment_get_lower(adj)
  let upper = gtk_adjustment_get_upper(adj)
  let page = gtk_adjustment_get_page_size(adj)
  let step = max(32.0, page * 0.15)
  var v = gtk_adjustment_get_value(adj) + delta * step
  let maxv = max(lower, upper - page)
  if v < lower: v = lower
  if v > maxv: v = maxv
  gtk_adjustment_set_value(adj, v)

proc scrollBy(sw: pointer, ev: pointer, foldV = false): cint =
  ## One wheel notch is a delta of about 1. Smooth pads send fractions of that.
  if sw == nil or ev == nil: return 0
  var dx, dy: cdouble
  var dir: cuint
  if gdk_event_get_scroll_deltas(ev, addr dx, addr dy) == 0:
    if gdk_event_get_scroll_direction(ev, addr dir) == 0: return 0
    if dir == 0: dy = -1
    elif dir == 1: dy = 1
    elif dir == 2: dx = -1
    elif dir == 3: dx = 1
    else: return 0
  if abs(dx) < 0.0001 and abs(dy) < 0.0001: return 0
  if foldV:
    # A one-row strip has no vertical range. The wheel moves it sideways.
    nudgeAdj(gtk_scrolled_window_get_hadjustment(sw), dx + dy)
  else:
    nudgeAdj(gtk_scrolled_window_get_hadjustment(sw), dx)
    nudgeAdj(gtk_scrolled_window_get_vadjustment(sw), dy)
  1

proc onLayoutScroll(widget, ev, data: pointer): cint {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TWinControl): return 0
  let fold = c of TScrollBox and TScrollBox(c).strip
  scrollBy(TWinControl(c).handle, ev, fold)

proc createScroll(self: TControl) =
  let sw = gtk_scrolled_window_new(nil, nil)
  gtk_scrolled_window_set_shadow_type(sw, GtkShadowIn)
  let box = TScrollBox(self)
  if box.layoutKind == lkRow:
    # lkRow has to be chosen before this runs. GtkLayout inside this scrolled
    # window paints a few pixels of each button and then the background.
    # A horizontal box paints the whole caption; the rest of the row scrolls.
    box.strip = true
    gtk_scrolled_window_set_policy(sw, GtkPolicyAuto, GtkPolicyNever)
    # An overlay bar draws on top of the captions. Keep it in its own band.
    gtk_scrolled_window_set_overlay_scrolling(sw, 0)
    let hb = gtk_box_new(GtkOrientHorizontal, 4)
    gtk_widget_set_margin_start(hb, 4)
    gtk_widget_set_margin_end(hb, 4)
    gtk_widget_set_margin_top(hb, 2)
    gtk_widget_set_margin_bottom(hb, 2)
    gtk_widget_add_events(sw, GdkScrollMask.cint)
    connect(sw, "scroll-event", cast[pointer](onLayoutScroll), self.liveId)
    gtk_container_add(sw, hb)
    self.handle = sw
    box.client = hb
    return
  if box.flow:
    # `flow` has to be set before this runs. A horizontal scrollbar would
    # adopt the one-row width of the buttons and the flow box would never wrap.
    gtk_scrolled_window_set_policy(sw, GtkPolicyNever, GtkPolicyAuto)
    let flowb = gtk_flow_box_new()
    gtk_flow_box_set_selection_mode(flowb, 0)
    gtk_flow_box_set_homogeneous(flowb, 0)
    gtk_flow_box_set_column_spacing(flowb, 4)
    gtk_flow_box_set_row_spacing(flowb, 4)
    # The default maximum is 7, so a wide bar would show seven stretched
    # buttons and wrap the rest early.
    gtk_flow_box_set_max_children_per_line(flowb, 64)
    gtk_widget_set_hexpand(flowb, 1)
    # vexpand would make the box fill the viewport and clip the wrapped
    # rows instead of scrolling them.
    gtk_widget_set_margin_start(flowb, 4)
    gtk_widget_set_margin_end(flowb, 4)
    gtk_widget_set_margin_top(flowb, 4)
    gtk_widget_set_margin_bottom(flowb, 4)
    gtk_container_add(sw, flowb)
    self.handle = sw
    box.client = flowb
    return
  gtk_scrolled_window_set_policy(sw, GtkPolicyAuto, GtkPolicyAuto)
  let lay = gtk_layout_new(nil, nil)
  gtk_widget_set_hexpand(lay, 1)
  gtk_widget_set_vexpand(lay, 1)
  gtk_layout_set_size(lay, 400, 300)
  gtk_widget_add_events(lay, GdkScrollMask.cint)
  connect(lay, "scroll-event", cast[pointer](onLayoutScroll), self.liveId)
  gtk_container_add(sw, lay)
  self.handle = sw
  box.client = lay

proc new*(_: typedesc[TScrollBox], owner: TComponent = nil): TScrollBox =
  result = TScrollBox()
  initControl(result, "TScrollBox", owner)
  result.fWidth = 200
  result.fHeight = 140
  result.createImpl = createScroll

proc position*(self: TTrackBar): int = self.fPosition
proc `position=`*(self: TTrackBar, v: int) =
  self.fPosition = clamp(v, self.fMin, self.fMax)
  if self.handle != nil and not self.refreshing:
    self.refreshing = true
    gtk_range_set_value(self.handle, float(self.fPosition))
    self.refreshing = false
proc min*(self: TTrackBar): int = self.fMin
proc `min=`*(self: TTrackBar, v: int) =
  self.fMin = v
  if self.fMax < v: self.fMax = v
  if self.handle != nil: gtk_range_set_range(self.handle, float(self.fMin), float(self.fMax))
proc max*(self: TTrackBar): int = self.fMax
proc `max=`*(self: TTrackBar, v: int) =
  self.fMax = v
  if self.handle != nil: gtk_range_set_range(self.handle, float(self.fMin), float(self.fMax))
proc orientation*(self: TTrackBar): TOrientation = self.fOrientation

proc pushTrack(self: TControl) =
  let tb = TTrackBar(self)
  if tb.handle == nil: return
  tb.refreshing = true
  gtk_range_set_range(tb.handle, float(tb.fMin), float(tb.fMax))
  gtk_range_set_value(tb.handle, float(clamp(tb.fPosition, tb.fMin, tb.fMax)))
  tb.refreshing = false

proc createTrack(self: TControl) =
  let tb = TTrackBar(self)
  let orient = if tb.fOrientation == orVertical: GtkOrientVertical else: GtkOrientHorizontal
  tb.handle = gtk_scale_new_with_range(orient.cint, float(tb.fMin), float(max(tb.fMax, tb.fMin + 1)), 1)
  gtk_scale_set_draw_value(tb.handle, 0)
  connect(tb.handle, "value-changed", cast[pointer](onRangeChanged), tb.liveId)
  pushTrack(tb)

proc new*(_: typedesc[TTrackBar], owner: TComponent = nil): TTrackBar =
  result = TTrackBar()
  initControl(result, "TTrackBar", owner)
  result.fWidth = 150
  result.fHeight = 28
  result.fMin = 0
  result.fMax = 100
  result.fPosition = 0
  result.createImpl = createTrack
  result.pushState = pushTrack

proc position*(self: TProgressBar): int = self.fPosition
proc `position=`*(self: TProgressBar, v: int) =
  self.fPosition = v
  self.applyChrome()
proc min*(self: TProgressBar): int = self.fMin
proc `min=`*(self: TProgressBar, v: int) = (self.fMin = v; self.applyChrome())
proc max*(self: TProgressBar): int = self.fMax
proc `max=`*(self: TProgressBar, v: int) = (self.fMax = v; self.applyChrome())

proc pushProgress(self: TControl) =
  let pb = TProgressBar(self)
  if pb.handle == nil: return
  let span = max(1, pb.fMax - pb.fMin)
  var frac = (pb.fPosition - pb.fMin) / span
  if frac < 0: frac = 0
  if frac > 1: frac = 1
  gtk_progress_bar_set_fraction(pb.handle, frac)

proc createProgress(self: TControl) =
  self.handle = gtk_progress_bar_new()
  pushProgress(self)

proc new*(_: typedesc[TProgressBar], owner: TComponent = nil): TProgressBar =
  result = TProgressBar()
  initControl(result, "TProgressBar", owner)
  result.fWidth = 150
  result.fHeight = 20
  result.fMin = 0
  result.fMax = 100
  result.createImpl = createProgress
  result.pushState = pushProgress

proc simpleText*(self: TStatusBar): string = self.fSimpleText
proc `simpleText=`*(self: TStatusBar, v: string) =
  self.fSimpleText = v
  if self.inner != nil: gtk_label_set_text(self.inner, v.cstring)

proc pushStatus(self: TControl) =
  let sb = TStatusBar(self)
  if sb.inner != nil: gtk_label_set_text(sb.inner, sb.fSimpleText.cstring)

proc createStatus(self: TControl) =
  let sb = TStatusBar(self)
  let eb = gtk_event_box_new()
  let lab = gtk_label_new(sb.fSimpleText.cstring)
  gtk_label_set_xalign(lab, 0)
  gtk_widget_set_margin_start(lab, 6)
  gtk_container_add(eb, lab)
  let css = gtk_css_provider_new()
  cssLoad(css, "* { background-color: #ececec; }")
  gtk_style_context_add_provider(gtk_widget_get_style_context(eb), css, CssPrioApp)
  sb.handle = eb
  sb.inner = lab
  sb.css = css

proc new*(_: typedesc[TStatusBar], owner: TComponent = nil): TStatusBar =
  result = TStatusBar()
  initControl(result, "TStatusBar", owner)
  result.fAlign = alBottom
  result.fHeight = 24
  result.fWidth = 200
  result.fSimpleText = ""
  result.createImpl = createStatus
  result.pushState = pushStatus

proc new*(_: typedesc[TToolBar], owner: TComponent = nil): TToolBar =
  result = TToolBar()
  initControl(result, "TToolBar", owner)
  result.fAlign = alTop
  result.fHeight = 36
  result.fWidth = 200
  result.layoutKind = lkRow
  result.createImpl = proc(self: TControl) =
    let eb = gtk_event_box_new()
    let lay = gtk_layout_new(nil, nil)
    gtk_widget_set_hexpand(lay, 1)
    gtk_widget_set_vexpand(lay, 1)
    gtk_container_add(eb, lay)
    let css = gtk_css_provider_new()
    cssLoad(css, "* { background-color: #f2f2f2; }")
    gtk_style_context_add_provider(gtk_widget_get_style_context(eb), css, CssPrioApp)
    self.handle = eb
    TWinControl(self).client = lay
    self.css = css

proc caption*(self: TTabSheet): string = self.fCaption
proc `caption=`*(self: TTabSheet, v: string) =
  self.fCaption = v
  if self.pageAdded and self.fParent != nil and self.fParent.handle != nil and self.handle != nil:
    gtk_notebook_set_tab_label_text(self.fParent.handle, self.handle, v.cstring)

proc createTab(self: TControl) =
  let lay = gtk_layout_new(nil, nil)
  gtk_widget_set_hexpand(lay, 1)
  gtk_widget_set_vexpand(lay, 1)
  self.handle = lay
  TWinControl(self).client = lay
  TWinControl(self).borderLeft = 4
  TWinControl(self).borderTop = 4
  TWinControl(self).borderRight = 4
  TWinControl(self).borderBottom = 4

proc new*(_: typedesc[TTabSheet], owner: TComponent = nil): TTabSheet =
  result = TTabSheet()
  initControl(result, "TTabSheet", owner)
  result.fCaption = result.fName
  result.fWidth = 200
  result.fHeight = 120
  result.createImpl = createTab

proc adoptPage(pc: TPageControl, ts: TTabSheet) =
  if ts.pageAdded: return
  var known = false
  for p in pc.pages:
    if p == ts: known = true
  if not known: pc.pages.add(ts)
  if pc.handle == nil or headless: return
  if ts.handle == nil and ts.createImpl != nil:
    ts.createImpl(ts)
    ts.applyChrome()
  let lab = gtk_label_new(ts.fCaption.cstring)
  discard gtk_notebook_append_page(pc.handle, ts.handle, lab)
  gtk_widget_show(lab)
  gtk_widget_show(ts.handle)
  ts.pageAdded = true
  ts.placed = true
  ts.hookSize()

proc activePageIndex*(self: TPageControl): int = self.fActive
proc `activePageIndex=`*(self: TPageControl, v: int) =
  self.fActive = v
  if self.handle != nil:
    self.refreshing = true
    gtk_notebook_set_current_page(self.handle, v.cint)
    self.refreshing = false

proc pushPage(self: TControl) =
  let pc = TPageControl(self)
  if pc.handle != nil and pc.fActive >= 0:
    gtk_notebook_set_current_page(pc.handle, pc.fActive.cint)

proc showTabs*(self: TPageControl): bool = self.fShowTabs
proc `showTabs=`*(self: TPageControl, v: bool) =
  self.fShowTabs = v
  if self.handle != nil: gtk_notebook_set_show_tabs(self.handle, if v: 1 else: 0)

proc createPage(self: TControl) =
  let pc = TPageControl(self)
  pc.handle = gtk_notebook_new()
  gtk_notebook_set_show_tabs(pc.handle, if pc.fShowTabs: 1 else: 0)
  connect(pc.handle, "switch-page", cast[pointer](onPageSwitch), pc.liveId)
  pushPage(pc)

proc new*(_: typedesc[TPageControl], owner: TComponent = nil): TPageControl =
  result = TPageControl()
  initControl(result, "TPageControl", owner)
  result.fWidth = 260
  result.fHeight = 160
  result.fActive = 0
  result.fShowTabs = true
  result.createImpl = createPage
  result.pushState = pushPage

proc text*(n: TTreeNode): string = n.text
proc obj*(n: TTreeNode): TObject = n.obj
proc selectedNode*(self: TTreeView): TTreeNode = self.selected

proc storeSet(store: pointer, it: ptr GtkTreeIter, col: int, s: string, id: int) =
  var vs, vi: GValue
  # g_value_init requires a zeroed GValue. A leftover gtype makes GLib warn.
  zeroMem(addr vs, sizeof(vs))
  zeroMem(addr vi, sizeof(vi))
  g_value_init(addr vs, GTypeString)
  g_value_set_string(addr vs, s.cstring)
  gtk_tree_store_set_value(store, it, 0, addr vs)
  g_value_unset(addr vs)
  g_value_init(addr vi, GTypeInt)
  g_value_set_int(addr vi, id.cint)
  gtk_tree_store_set_value(store, it, 1, addr vi)
  g_value_unset(addr vi)

proc appendNode(self: TTreeView, parent: TTreeNode, node: TTreeNode) =
  if self.store == nil: return
  var it: GtkTreeIter
  var parentPtr: pointer = nil
  if parent != nil and parent.hasIter: parentPtr = addr parent.iter
  gtk_tree_store_append(self.store, addr it, parentPtr)
  node.iter = it
  node.hasIter = true
  storeSet(self.store, addr node.iter, 0, node.text, node.id)

proc addNode*(self: TTreeView, parent: TTreeNode, text: string, obj: TObject = nil): TTreeNode =
  result = TTreeNode()
  result.text = text
  result.obj = obj
  result.parentNode = parent
  if self.nodeMap.len == 0: self.nodeMap = initTable[int, TTreeNode]()
  inc self.nextNode
  result.id = self.nextNode
  self.nodeMap[result.id] = result
  if parent == nil: self.roots.add(result)
  else: parent.kids.add(result)
  self.appendNode(parent, result)

proc clear*(self: TTreeView) =
  self.roots = @[]
  self.nodeMap = initTable[int, TTreeNode]()
  self.selected = nil
  self.nextNode = 0
  if self.store != nil:
    self.refreshing = true
    gtk_tree_store_clear(self.store)
    self.refreshing = false

proc expandAll*(self: TTreeView) =
  if self.inner != nil: gtk_tree_view_expand_all(self.inner)

proc onTreeSel(sel: pointer, data: pointer) {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TTreeView) or TTreeView(c).refreshing: return
  let tv = TTreeView(c)
  var it: GtkTreeIter
  if gtk_tree_selection_get_selected(sel, nil, addr it) == 0:
    tv.selected = nil
    return
  var v: GValue
  # gtk_tree_model_get_value initializes the GValue. Doing it first warns
  # "already been initialized as gint" on every tree selection.
  zeroMem(addr v, sizeof(v))
  gtk_tree_model_get_value(tv.store, addr it, 1, addr v)
  let id = int(g_value_get_int(addr v))
  g_value_unset(addr v)
  if tv.nodeMap.hasKey(id):
    tv.selected = tv.nodeMap[id]
    if tv.onSelect != nil: guard proc() = tv.onSelect(tv, tv.selected)

proc createTree(self: TControl) =
  let tv = TTreeView(self)
  let sw = gtk_scrolled_window_new(nil, nil)
  gtk_scrolled_window_set_policy(sw, GtkPolicyAuto, GtkPolicyAuto)
  var types = [GTypeString, GTypeInt]
  tv.store = gtk_tree_store_newv(2, addr types[0])
  let view = gtk_tree_view_new()
  gtk_tree_view_set_model(view, tv.store)
  gtk_tree_view_set_headers_visible(view, 0)
  let col = gtk_tree_view_column_new()
  let rend = gtk_cell_renderer_text_new()
  gtk_tree_view_column_pack_start(col, rend, 1)
  gtk_tree_view_column_add_attribute(col, rend, "text", 0)
  discard gtk_tree_view_append_column(view, col)
  gtk_container_add(sw, view)
  tv.handle = sw
  tv.inner = view
  if tv.nodeMap.len == 0: tv.nodeMap = initTable[int, TTreeNode]()
  let sel = gtk_tree_view_get_selection(view)
  connect(sel, "changed", cast[pointer](onTreeSel), tv.liveId)
  for n in tv.roots:
    proc walk(parent, node: TTreeNode) =
      tv.appendNode(parent, node)
      for k in node.kids: walk(node, k)
    walk(nil, n)

proc new*(_: typedesc[TTreeView], owner: TComponent = nil): TTreeView =
  result = TTreeView()
  initControl(result, "TTreeView", owner)
  result.fWidth = 160
  result.fHeight = 120
  result.nodeMap = initTable[int, TTreeNode]()
  result.createImpl = createTree

# ---- menus, dialogs, timer, editor, form -----------------------------------

proc caption*(self: TMenuItem): string = self.fCaption
proc `caption=`*(self: TMenuItem, v: string) =
  self.fCaption = v
  let root = ownerRoot(self)
  if root of TForm: TForm(root).rebuildMenu()
proc shortCut*(self: TMenuItem): string = self.fShortCut
proc `shortCut=`*(self: TMenuItem, v: string) =
  self.fShortCut = v
  let root = ownerRoot(self)
  if root of TForm: TForm(root).rebuildMenu()
proc enabled*(self: TMenuItem): bool = self.fEnabled
proc `enabled=`*(self: TMenuItem, v: bool) =
  self.fEnabled = v
  if self.gtkItem != nil:
    gtk_widget_set_sensitive(self.gtkItem, if v: 1 else: 0)
proc checked*(self: TMenuItem): bool = self.fChecked
proc `checked=`*(self: TMenuItem, v: bool) =
  # Setting Checked makes a normal item into a check item. Clearing it
  # leaves the box in place, so a View toggle can be turned back on.
  let promote = v and not self.fCheckable
  self.fChecked = v
  if promote: self.fCheckable = true
  if self.gtkItem == nil: return
  if promote:
    let root = ownerRoot(self)
    if root of TForm: TForm(root).rebuildMenu()
  elif self.fCheckable:
    gtk_check_menu_item_set_active(self.gtkItem, if v: 1 else: 0)
proc menuItems*(self: TMenuItem): seq[TMenuItem] = self.fItems
proc menuItems*(self: TMainMenu): seq[TMenuItem] = self.fItems
proc menuItems*(self: TPopupMenu): seq[TMenuItem] = self.fItems

proc new*(_: typedesc[TMenuItem], owner: TComponent = nil): TMenuItem =
  result = TMenuItem()
  initComponent(result, "TMenuItem", owner)
  result.fCaption = result.fName
  result.fEnabled = true

proc new*(_: typedesc[TMainMenu], owner: TComponent = nil): TMainMenu =
  result = TMainMenu()
  initComponent(result, "TMainMenu", owner)

proc new*(_: typedesc[TPopupMenu], owner: TComponent = nil): TPopupMenu =
  result = TPopupMenu()
  initComponent(result, "TPopupMenu", owner)

proc add*(self: TMainMenu, caption: string): TMenuItem =
  let root = if self.owner != nil: ownerRoot(self) else: self
  result = TMenuItem.new(root)
  result.fCaption = caption
  result.container = self
  self.fItems.add(result)
  if root of TForm: TForm(root).rebuildMenu()

proc add*(self: TPopupMenu, caption: string): TMenuItem =
  let root = if self.owner != nil: ownerRoot(self) else: self
  result = TMenuItem.new(root)
  result.fCaption = caption
  result.container = self
  self.fItems.add(result)

proc add*(self: TMenuItem, caption: string): TMenuItem =
  let root = if self.owner != nil: ownerRoot(self) else: self
  result = TMenuItem.new(root)
  result.fCaption = caption
  result.container = self
  self.fItems.add(result)
  if root of TForm: TForm(root).rebuildMenu()

proc parseShortcut(s: string): tuple[key: cuint, mods: cint] =
  var mods = 0
  var key = ""
  for part in s.split('+'):
    let t = part.strip.toLowerAscii
    case t
    of "ctrl", "control": mods = mods or 4
    of "shift": mods = mods or 1
    of "alt": mods = mods or 8
    else: key = part.strip
  var kv: cuint = 0
  if key.len == 1:
    kv = cuint(ord(key.toLowerAscii[0]))
  elif key.len >= 2 and (key[0] == 'F' or key[0] == 'f'):
    var n = 0
    try: n = parseInt(key[1 .. ^1]) except: n = 0
    if n >= 1 and n <= 12: kv = 0xffbe'u32 + cuint(n - 1)
  else:
    case key.toLowerAscii
    of "delete", "del": kv = GdkKeyDelete
    of "esc", "escape": kv = GdkKeyEscape
    of "enter", "return": kv = GdkKeyReturn
    of "left": kv = GdkKeyLeft
    of "right": kv = GdkKeyRight
    of "up": kv = GdkKeyUp
    of "down": kv = GdkKeyDown
    else: discard
  (kv, cint(mods))

proc buildGtkItem(item: TMenuItem, accel: pointer): pointer =
  if item.fCaption == "-":
    return gtk_separator_menu_item_new()
  let text = gtkMnemonic(item.fCaption)
  let gi = if item.fCheckable: gtk_check_menu_item_new_with_mnemonic(text.cstring)
           else: gtk_menu_item_new_with_label(text.cstring)
  gtk_menu_item_set_use_underline(gi, 1)
  gtk_widget_set_sensitive(gi, if item.fEnabled: 1 else: 0)
  item.gtkItem = gi
  if item.fCheckable:
    gtk_check_menu_item_set_active(gi, if item.fChecked: 1 else: 0)
  connect(gi, "activate", cast[pointer](onMenuActivate), item.liveId)
  if item.fShortCut.len > 0 and accel != nil:
    let sc = parseShortcut(item.fShortCut)
    if sc.key != 0:
      gtk_widget_add_accelerator(gi, "activate", accel, sc.key, sc.mods, GtkAccelVisible)
  if item.fItems.len > 0:
    let sub = gtk_menu_new()
    for ch in item.fItems:
      gtk_menu_shell_append(sub, buildGtkItem(ch, accel))
    gtk_menu_item_set_submenu(gi, sub)
  gi

proc rebuildMenu(self: TForm) =
  if self.designing or self.vbox == nil or headless: return
  if self.menuBar != nil:
    let bar = self.menuBar
    let parent = gtk_widget_get_parent(bar)
    self.menuBar = nil
    if parent != nil:
      gtk_container_remove(parent, bar)
  if self.fMenu == nil or self.fMenu.fItems.len == 0: return
  if self.accel == nil and self.handle != nil and self.fParent == nil:
    self.accel = gtk_accel_group_new()
    gtk_window_add_accel_group(self.handle, self.accel)
  self.menuBar = gtk_menu_bar_new()
  for it in self.fMenu.fItems:
    gtk_menu_shell_append(self.menuBar, buildGtkItem(it, self.accel))
  gtk_box_pack_start(self.vbox, self.menuBar, 0, 1, 0)
  gtk_box_reorder_child(self.vbox, self.menuBar, 0)
  gtk_widget_show_all(self.menuBar)

proc menu*(self: TForm): TMainMenu = self.fMenu

proc `menu=`*(self: TForm, m: TMainMenu) =
  self.fMenu = m
  if m != nil: m.container = self
  self.rebuildMenu()

proc arm(self: TTimer) =
  if self.timerId != 0:
    discard g_source_remove(self.timerId)
    self.timerId = 0
  if headless or self.designing or not self.fEnabled or self.owner == nil: return
  if self.fInterval < 1: return
  self.timerId = g_timeout_add(cuint(self.fInterval), cast[pointer](onTimeout), cast[pointer](self.liveId))

proc disarm(self: TTimer) =
  if self.timerId != 0:
    discard g_source_remove(self.timerId)
    self.timerId = 0

proc interval*(self: TTimer): int = self.fInterval
proc `interval=`*(self: TTimer, v: int) =
  self.fInterval = max(1, v)
  if self.fEnabled: self.arm()
proc enabled*(self: TTimer): bool = self.fEnabled
proc `enabled=`*(self: TTimer, v: bool) =
  self.fEnabled = v
  if v: self.arm() else: self.disarm()

proc new*(_: typedesc[TTimer], owner: TComponent = nil): TTimer =
  result = TTimer()
  initComponent(result, "TTimer", owner)
  result.fInterval = 1000
  result.fEnabled = true

proc armTimers(c: TComponent) =
  if c of TTimer: TTimer(c).arm()
  for ch in c.owned: armTimers(ch)

proc title*(self: TOpenDialog): string = self.fTitle
proc `title=`*(self: TOpenDialog, v: string) = self.fTitle = v
proc filter*(self: TOpenDialog): string = self.fFilter
proc `filter=`*(self: TOpenDialog, v: string) = self.fFilter = v
proc fileName*(self: TOpenDialog): string = self.fFileName
proc `fileName=`*(self: TOpenDialog, v: string) = self.fFileName = v
proc defaultExt*(self: TOpenDialog): string = self.fDefaultExt
proc `defaultExt=`*(self: TOpenDialog, v: string) = self.fDefaultExt = v

proc new*(_: typedesc[TOpenDialog], owner: TComponent = nil): TOpenDialog =
  result = TOpenDialog()
  initComponent(result, "TOpenDialog", owner)
  result.fTitle = "Open"
  result.fFilter = "All files|*"

proc new*(_: typedesc[TSaveDialog], owner: TComponent = nil): TSaveDialog =
  result = TSaveDialog()
  initComponent(result, "TSaveDialog", owner)
  result.fTitle = "Save"
  result.fFilter = "All files|*"

proc dialogParent(): pointer =
  if application != nil and application.mainForm != nil and
      application.mainForm.handle != nil and not application.mainForm.designing and
      application.mainForm.fParent == nil:
    return application.mainForm.handle

proc addFilters(chooser: pointer, filter: string) =
  if filter.len == 0: return
  let parts = filter.split('|')
  var i = 0
  while i + 1 < parts.len:
    let f = gtk_file_filter_new()
    gtk_file_filter_set_name(f, parts[i].cstring)
    for pat in parts[i + 1].split(','):
      let p = pat.strip
      if p.len > 0: gtk_file_filter_add_pattern(f, p.cstring)
    gtk_file_chooser_add_filter(chooser, f)
    inc i, 2

proc execute*(self: TOpenDialog): bool =
  if headless: return false
  ensureGtk()
  let saving = self of TSaveDialog
  let action = if saving: GtkFileSave else: GtkFileOpen
  let accept = if saving: "_Save" else: "_Open"
  let caption = if self.fTitle.len > 0: self.fTitle else: "Choose file"
  let dlg = gtk_file_chooser_dialog_new(caption.cstring, dialogParent(), action.cint,
    "_Cancel".cstring, GtkResponseCancel.cint, accept.cstring, GtkResponseAccept.cint, nil)
  addFilters(dlg, self.fFilter)
  if self.fFileName.len > 0:
    if saving: gtk_file_chooser_set_current_name(dlg, self.fFileName.extractFilename.cstring)
    else: gtk_file_chooser_set_filename(dlg, self.fFileName.cstring)
  if saving: gtk_file_chooser_set_do_overwrite_confirmation(dlg, 1)
  let response = gtk_dialog_run(dlg)
  if response == GtkResponseAccept:
    let p = gtk_file_chooser_get_filename(dlg)
    if p != nil:
      self.fFileName = $p
      g_free(cast[pointer](p))
    result = self.fFileName.len > 0
  gtk_widget_destroy(dlg)

proc messageDlg*(text: string, kind: TMsgDlgType, buttons: TMsgButtons): TModalResult =
  if headless:
    stderr.writeLine(text)
    return mrOk
  ensureGtk()
  var typ = GtkMessageInfo
  case kind
  of mtInfo: typ = GtkMessageInfo
  of mtWarning: typ = GtkMessageWarning
  of mtError: typ = GtkMessageError
  of mtConfirmation: typ = GtkMessageQuestion
  let dlg = gtk_message_dialog_new(dialogParent(), GtkDialogModal.cint, typ.cint,
    GtkButtonsNone.cint, "%s".cstring, text.cstring)
  if buttons == {}: discard gtk_dialog_add_button(dlg, "_OK", GtkResponseOk)
  if mbOK in buttons: discard gtk_dialog_add_button(dlg, "_OK", GtkResponseOk)
  if mbYes in buttons: discard gtk_dialog_add_button(dlg, "_Yes", GtkResponseYes)
  if mbNo in buttons: discard gtk_dialog_add_button(dlg, "_No", GtkResponseNo)
  if mbCancel in buttons: discard gtk_dialog_add_button(dlg, "_Cancel", GtkResponseCancel)
  let response = gtk_dialog_run(dlg)
  gtk_widget_destroy(dlg)
  case response
  of GtkResponseOk: mrOk
  of GtkResponseYes: mrYes
  of GtkResponseNo: mrNo
  of GtkResponseCancel: mrCancel
  else: mrCancel

proc showMessage*(text: string) =
  discard messageDlg(text, mtInfo, {mbOK})

proc hideWalk(c: TControl) =
  if not c.fVisible and c.handle != nil: gtk_widget_hide(c.handle)
  if c of TWinControl:
    for ch in TWinControl(c).controls: hideWalk(ch)

proc show*(self: TForm) =
  if headless: return
  ensureGtk()
  if self.handle == nil: self.realizeTree()
  if not self.designing and self.fParent == nil and self.handle != nil:
    if self.fPosition == poScreenCenter:
      gtk_window_set_position(self.handle, GtkWinPosCenter)
    elif self.fPosition == poDesigned:
      gtk_window_move(self.handle, self.fLeft.cint, self.fTop.cint)
  if self.handle != nil: gtk_widget_show_all(self.handle)
  hideWalk(self)
  if not self.designing:
    if not self.opened:
      self.opened = true
      if self.onCreate != nil: guard proc() = self.onCreate(self)
    armTimers(self)
    if self.onShow != nil: guard proc() = self.onShow(self)
  if self.handle != nil and not self.designing:
    gtk_window_present(self.handle)

proc pushForm(self: TControl) =
  let f = TForm(self)
  if f.handle == nil: return
  if f.designing:
    if f.extra != nil: gtk_label_set_text(f.extra, f.fCaption.cstring)
  else:
    gtk_window_set_title(f.handle, f.fCaption.cstring)
    gtk_window_set_default_size(f.handle, max(80, f.fWidth).cint, max(60, f.fHeight).cint)
    case f.fBorder
    of bsSizeable:
      gtk_window_set_resizable(f.handle, 1)
      gtk_window_set_decorated(f.handle, 1)
    of bsSingle, bsDialog:
      gtk_window_set_resizable(f.handle, 0)
      gtk_window_set_decorated(f.handle, 1)
    of bsNone:
      gtk_window_set_resizable(f.handle, 0)
      gtk_window_set_decorated(f.handle, 0)
    f.rebuildMenu()

proc createDesignForm(f: TForm) =
  let vbox = gtk_box_new(GtkOrientVertical, 0)
  let title = gtk_event_box_new()
  gtk_widget_set_size_request(title, -1, 26)
  let lab = gtk_label_new(f.fCaption.cstring)
  gtk_label_set_xalign(lab, 0)
  gtk_widget_set_margin_start(lab, 8)
  gtk_container_add(title, lab)
  let titleCss = gtk_css_provider_new()
  cssLoad(titleCss, "* { background-color: #2458a6; color: white; font-weight: bold; }")
  gtk_style_context_add_provider(gtk_widget_get_style_context(title), titleCss, CssPrioApp)
  let lay = gtk_layout_new(nil, nil)
  gtk_widget_set_hexpand(lay, 1)
  gtk_widget_set_vexpand(lay, 1)
  gtk_widget_set_margin_start(lay, 2)
  gtk_widget_set_margin_end(lay, 2)
  gtk_widget_set_margin_bottom(lay, 2)
  gtk_box_pack_start(vbox, title, 0, 0, 0)
  gtk_box_pack_start(vbox, lay, 1, 1, 0)
  let frameCss = gtk_css_provider_new()
  cssLoad(frameCss, "* { background-color: #d4d4d4; }")
  gtk_style_context_add_provider(gtk_widget_get_style_context(vbox), frameCss, CssPrioApp)
  let clientCss = gtk_css_provider_new()
  cssLoad(clientCss, "* { background-color: #ececec; }")
  gtk_style_context_add_provider(gtk_widget_get_style_context(lay), clientCss, CssPrioApp)
  # GtkLayout only places windowed children. A bare box has no window, so the
  # whole design form (and everything in it) never appears.
  let frame = gtk_event_box_new()
  gtk_container_add(frame, vbox)
  gtk_style_context_add_provider(gtk_widget_get_style_context(frame), frameCss, CssPrioApp)
  f.handle = frame
  f.client = lay
  f.vbox = vbox
  f.extra = lab
  f.borderTop = 26
  f.borderLeft = 2
  f.borderRight = 2
  f.borderBottom = 2
  # placeWidget shows this frame later. The widgets inside it are not NCL
  # controls, so they have to be mapped here or the design form stays blank.
  gtk_widget_show_all(frame)

proc createRuntimeForm(f: TForm) =
  let win = gtk_window_new(0)
  gtk_window_set_title(win, f.fCaption.cstring)
  gtk_window_set_default_size(win, max(100, f.fWidth).cint, max(80, f.fHeight).cint)
  let vbox = gtk_box_new(GtkOrientVertical, 0)
  let lay = gtk_layout_new(nil, nil)
  gtk_widget_set_hexpand(lay, 1)
  gtk_widget_set_vexpand(lay, 1)
  gtk_box_pack_start(vbox, lay, 1, 1, 0)
  gtk_container_add(win, vbox)
  f.handle = win
  f.client = lay
  f.vbox = vbox
  connect(win, "delete-event", cast[pointer](onDeleteEvent), f.liveId)

proc createForm(self: TControl) =
  let f = TForm(self)
  if f.designing or f.fParent != nil: createDesignForm(f)
  else: createRuntimeForm(f)
  pushForm(f)

proc new*(_: typedesc[TForm], owner: TComponent = nil): TForm =
  result = TForm()
  initControl(result, "TForm", owner)
  result.fWidth = 480
  result.fHeight = 320
  result.fLeft = 40
  result.fTop = 30
  result.fCaption = result.fName
  result.fBorder = bsSizeable
  result.fPosition = poDesigned
  result.createImpl = createForm
  result.pushState = pushForm

proc newForm*[T: TForm](_: typedesc[T]): T =
  ## User form types are `ref object of TForm`. This constructs one of those.
  result = T()
  initControl(result, "TForm", nil)
  result.fWidth = 480
  result.fHeight = 320
  result.fLeft = 40
  result.fTop = 30
  result.fCaption = result.fName
  result.fBorder = bsSizeable
  result.fPosition = poDesigned
  result.createImpl = createForm
  result.pushState = pushForm

proc position*(self: TForm): TPosition = self.fPosition
proc `position=`*(self: TForm, v: TPosition) = self.fPosition = v
proc borderStyle*(self: TForm): TFormBorderStyle = self.fBorder
proc `borderStyle=`*(self: TForm, v: TFormBorderStyle) =
  self.fBorder = v
  self.applyChrome()

var nimLang: pointer
var langTried = false

proc nimLanguage(): pointer =
  if langTried: return nimLang
  langTried = true
  let mgr = gtk_source_language_manager_get_default()
  let dirs = allocCStringArray([NazarusShare, "/usr/share/gtksourceview-4/language-specs"])
  gtk_source_language_manager_set_search_path(mgr, dirs)
  nimLang = gtk_source_language_manager_get_language(mgr, "nim".cstring)
  if nimLang == nil:
    stderr.writeLine("Nazarus: no Nim syntax spec in " & NazarusShare)

proc text*(self: TSourceEditor): string =
  if self.buffer == nil: "" else: textOfBuffer(self.buffer)

proc `text=`*(self: TSourceEditor, s: string) =
  if self.buffer == nil: return
  self.mute = true
  setBufferText(self.buffer, s)
  gtk_text_buffer_set_modified(self.buffer, 0)
  self.mute = false

proc modified*(self: TSourceEditor): bool =
  self.buffer != nil and gtk_text_buffer_get_modified(self.buffer) != 0

proc `modified=`*(self: TSourceEditor, v: bool) =
  if self.buffer != nil:
    gtk_text_buffer_set_modified(self.buffer, if v: 1 else: 0)

proc undo*(self: TSourceEditor) =
  if self.buffer != nil and gtk_source_buffer_can_undo(self.buffer) != 0:
    gtk_source_buffer_undo(self.buffer)

proc redo*(self: TSourceEditor) =
  if self.buffer != nil and gtk_source_buffer_can_redo(self.buffer) != 0:
    gtk_source_buffer_redo(self.buffer)

proc hasBuffer*(self: TSourceEditor): bool = self.buffer != nil

proc focus*(self: TSourceEditor) =
  if self.inner != nil: gtk_widget_grab_focus(self.inner)
  elif self.handle != nil: gtk_widget_grab_focus(self.handle)

proc editorClipboard(self: TSourceEditor): pointer =
  if self.inner == nil: return nil
  gtk_widget_get_clipboard(self.inner, gdk_atom_intern("CLIPBOARD", 0))

proc editCopy*(self: TSourceEditor) =
  let clip = self.editorClipboard()
  if self.buffer == nil or clip == nil: return
  gtk_text_buffer_copy_clipboard(self.buffer, clip)

proc editCut*(self: TSourceEditor) =
  let clip = self.editorClipboard()
  if self.buffer == nil or clip == nil: return
  gtk_text_buffer_cut_clipboard(self.buffer, clip, 1)

proc editPaste*(self: TSourceEditor) =
  let clip = self.editorClipboard()
  if self.buffer == nil or clip == nil: return
  gtk_text_buffer_paste_clipboard(self.buffer, clip, nil, 1)

proc focus*(self: TEdit) =
  if self.handle != nil: gtk_widget_grab_focus(self.handle)

proc gotoLine*(self: TSourceEditor, line: int, column = 1) =
  if self.buffer == nil: return
  var it: array[32, int64]
  gtk_text_buffer_get_iter_at_line_offset(self.buffer, addr it[0],
    cint(max(0, line - 1)), cint(max(0, column - 1)))
  gtk_text_buffer_place_cursor(self.buffer, addr it[0])
  if self.inner != nil:
    gtk_text_view_scroll_to_iter(self.inner, addr it[0], 0.05, 1, 0.0, 0.25)
    gtk_widget_grab_focus(self.inner)

proc caretLine*(self: TSourceEditor): int =
  ## 1-based insert line. 0 when the editor has no buffer.
  if self.buffer == nil: return 0
  let mark = gtk_text_buffer_get_insert(self.buffer)
  if mark == nil: return 0
  var it: array[32, int64]
  gtk_text_buffer_get_iter_at_mark(self.buffer, addr it[0], mark)
  int(gtk_text_iter_get_line(addr it[0])) + 1

proc `scopeRails=`*(self: TSourceEditor, v: seq[TScopeRail]) =
  self.rails = v
  if self.gutter != nil: gtk_widget_queue_draw(self.gutter)

proc gutterLineY(ed: TSourceEditor, line1: int): float =
  ## Window y of the vertical center of a 1-based source line.
  if ed.inner == nil or ed.buffer == nil: return -10000
  var count = int(gtk_text_buffer_get_line_count(ed.buffer))
  if count < 1: count = 1
  var line0 = line1 - 1
  if line0 < 0: line0 = 0
  if line0 >= count: line0 = count - 1
  var it: array[32, int64]
  gtk_text_buffer_get_iter_at_line(ed.buffer, addr it[0], cint(line0))
  var y, h: cint
  gtk_text_view_get_line_yrange(ed.inner, addr it[0], addr y, addr h)
  var wx, wy: cint
  let mid = y + max(h, 1) div 2
  gtk_text_view_buffer_to_window_coords(ed.inner, GtkTextWindowText, 0, mid, addr wx, addr wy)
  float(wy)

proc onGutterScroll(adj: pointer, data: pointer) {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TSourceEditor): return
  let g = TSourceEditor(c).gutter
  if g != nil: gtk_widget_queue_draw(g)

proc onEditorMark(buf, iter, mark, data: pointer) {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TSourceEditor): return
  let ed = TSourceEditor(c)
  if mark != gtk_text_buffer_get_insert(buf): return
  if ed.gutter != nil: gtk_widget_queue_draw(ed.gutter)
  if ed.mute or ed.onCaret == nil: return
  let line = int(gtk_text_iter_get_line(iter)) + 1
  guard proc() = ed.onCaret(line)

proc onGutterDraw(widget, cr, data: pointer): cint {.cdecl.} =
  let c = recall(data)
  if c == nil or not (c of TSourceEditor): return 0
  let ed = TSourceEditor(c)
  let w = float(max(2, gtk_widget_get_allocated_width(widget)))
  let h = float(max(2, gtk_widget_get_allocated_height(widget)))
  cairo_set_source_rgba(cr, 0.965, 0.965, 0.965, 1)
  cairo_rectangle(cr, 0, 0, w, h)
  cairo_fill(cr)
  let caret = ed.caretLine()
  var hot = -1
  for rail in ed.rails:
    if rail.openLine <= caret and caret <= rail.closeLine and rail.depth > hot:
      hot = rail.depth
  cairo_set_line_width(cr, 1)
  for rail in ed.rails:
    if rail.depth < 0 or rail.depth >= 6: continue
    let y0 = gutterLineY(ed, rail.openLine)
    let y1 = gutterLineY(ed, rail.closeLine)
    if y1 < -8 and y0 < -8: continue
    if y0 > h + 8 and y1 > h + 8: continue
    let x = float(int(6 + rail.depth * 8)) + 0.5
    let active = hot == rail.depth and rail.openLine <= caret and caret <= rail.closeLine
    if active: cairo_set_source_rgba(cr, 0.114, 0.306, 0.537, 1)
    else: cairo_set_source_rgba(cr, 0.72, 0.71, 0.68, 1)
    let top = min(y0, y1)
    let bot = max(y0, y1)
    if abs(y0 - y1) < 1:
      cairo_move_to(cr, x, y0)
      cairo_line_to(cr, x + 5, y0)
      cairo_stroke(cr)
    else:
      cairo_move_to(cr, x, top)
      cairo_line_to(cr, x, bot)
      cairo_stroke(cr)
      cairo_move_to(cr, x, top)
      cairo_line_to(cr, x + 5, top)
      cairo_stroke(cr)
      cairo_move_to(cr, x, bot)
      cairo_line_to(cr, x + 5, bot)
      cairo_stroke(cr)
  0

proc findText*(self: TSourceEditor, needle: string, startAt: int): int =
  if needle.len == 0: return 0
  let t = self.text
  var fromPos = startAt
  if fromPos < 0 or fromPos > t.len: fromPos = 0
  let idx = t.find(needle, fromPos)
  if idx < 0: return 0
  var line = 1
  for i in 0 ..< idx:
    if t[i] == '\n': inc line
  self.gotoLine(line)
  line

proc createEditor(self: TControl) =
  let ed = TSourceEditor(self)
  let lang = nimLanguage()
  let buf = if lang != nil: gtk_source_buffer_new_with_language(lang) else: gtk_source_buffer_new(nil)
  gtk_source_buffer_set_highlight_syntax(buf, 1)
  let view = gtk_source_view_new_with_buffer(buf)
  gtk_source_view_set_show_line_numbers(view, 1)
  gtk_source_view_set_highlight_current_line(view, 1)
  gtk_source_view_set_tab_width(view, 2)
  gtk_source_view_set_indent_width(view, 2)
  gtk_source_view_set_insert_spaces_instead_of_tabs(view, 1)
  gtk_source_view_set_auto_indent(view, 1)
  gtk_source_view_set_show_right_margin(view, 1)
  gtk_source_view_set_right_margin_position(view, 80)
  gtk_text_view_set_monospace(view, 1)
  gtk_text_view_set_wrap_mode(view, 0)
  let sw = gtk_scrolled_window_new(nil, nil)
  gtk_scrolled_window_set_policy(sw, GtkPolicyAuto, GtkPolicyAuto)
  gtk_scrolled_window_set_shadow_type(sw, 0)
  gtk_container_add(sw, view)
  gtk_widget_set_hexpand(sw, 1)
  gtk_widget_set_vexpand(sw, 1)
  let gutter = gtk_drawing_area_new()
  gtk_widget_set_size_request(gutter, 54, 1)
  gtk_widget_set_vexpand(gutter, 1)
  let box = gtk_box_new(0, 0)
  gtk_box_pack_start(box, gutter, 0, 1, 0)
  gtk_box_pack_start(box, sw, 1, 1, 0)
  ed.handle = box
  ed.inner = view
  ed.buffer = buf
  ed.gutter = gutter
  connect(buf, "changed", cast[pointer](onMemoChanged), ed.liveId)
  connect(buf, "mark-set", cast[pointer](onEditorMark), ed.liveId)
  connect(gutter, "draw", cast[pointer](onGutterDraw), ed.liveId)
  let vadj = gtk_scrolled_window_get_vadjustment(sw)
  if vadj != nil:
    connect(vadj, "value-changed", cast[pointer](onGutterScroll), ed.liveId)

proc new*(_: typedesc[TSourceEditor], owner: TComponent = nil): TSourceEditor =
  result = TSourceEditor()
  initControl(result, "TSourceEditor", owner)
  result.fWidth = 400
  result.fHeight = 240
  result.createImpl = createEditor

proc freeComponent*(self: TComponent) =
  if self == nil or self.dead: return
  var kids: seq[TComponent] = @[]
  for k in self.owned: kids.add(k)
  for k in kids: freeComponent(k)
  if self of TTimer: TTimer(self).disarm()
  if self of TControl:
    let c = TControl(self)
    if c.fParent != nil: c.parent = nil
    if not headless and (c.socket != nil or c.handle != nil):
      let laid = if c.socket != nil: c.socket else: c.handle
      if c.held:
        g_object_unref(laid)
        c.held = false
      else:
        gtk_widget_destroy(laid)
      c.socket = nil
      c.handle = nil
  if self.owner != nil:
    var kept: seq[TComponent]
    for c in self.owner.owned:
      if c != self: kept.add(c)
    self.owner.owned = kept
    self.owner = nil
  self.dead = true
  if self.liveId > 0 and self.liveId < live.len: live[self.liveId] = nil

proc publishCaption(cls: string) =
  propStr(cls, "Caption", pkString,
    proc(c: TComponent): string =
      if c of TMenuItem: TMenuItem(c).fCaption
      elif c of TControl: TControl(c).fCaption
      else: "",
    proc(c: TComponent, v: string) =
      if c of TMenuItem: TMenuItem(c).caption = v
      elif c of TControl: TControl(c).caption = v)

proc parseList(s: string): seq[string] =
  if s.len == 0: return @[]
  var norm = ""
  var i = 0
  while i < s.len:
    if s[i] == '\\' and i + 1 < s.len and s[i + 1] == 'n':
      norm.add '\n'
      inc i, 2
    else:
      norm.add s[i]
      inc i
  if '\n' in norm:
    result = norm.splitLines()
    if result.len > 0 and result[^1].len == 0: result.setLen(result.high)
  elif '|' in norm:
    result = norm.split('|')
  else:
    result = @[norm]

proc registerWidgets() =
  registerClass("TForm", "TWinControl", proc(o: TComponent): TComponent = TForm.new(o))
  publishCaption("TForm")
  propEnum("TForm", "Position", ["poDesigned", "poDefault", "poScreenCenter"],
    proc(c: TComponent): string = $TForm(c).fPosition,
    proc(c: TComponent, v: string) = TForm(c).position = parseEnum[TPosition](v.strip))
  propEnum("TForm", "BorderStyle", ["bsNone", "bsSingle", "bsSizeable", "bsDialog"],
    proc(c: TComponent): string = $TForm(c).fBorder,
    proc(c: TComponent, v: string) = TForm(c).borderStyle = parseEnum[TFormBorderStyle](v.strip))
  propEvent("TForm", "OnCreate", "notify")
  propEvent("TForm", "OnShow", "notify")
  propEvent("TForm", "OnClose", "close")
  setDefaultEvent("TForm", "OnCreate")

  registerClass("TButton", "TWinControl", proc(o: TComponent): TComponent = TButton.new(o))
  addPalette("TButton", "Standard", "Button")
  publishCaption("TButton")
  setDefaultEvent("TButton", "OnClick")

  registerClass("TLabel", "TControl", proc(o: TComponent): TComponent = TLabel.new(o))
  addPalette("TLabel", "Standard", "Label")
  publishCaption("TLabel")
  propEnum("TLabel", "Alignment", ["taLeftJustify", "taCenter", "taRightJustify"],
    proc(c: TComponent): string = $TLabel(c).fAlignment,
    proc(c: TComponent, v: string) = TLabel(c).alignment = parseEnum[TAlignment](v.strip))
  propBool("TLabel", "AutoSize", proc(c: TComponent): bool = TLabel(c).fAutoSize,
    proc(c: TComponent, v: bool) = TLabel(c).autoSize = v)
  propBool("TLabel", "WordWrap", proc(c: TComponent): bool = TLabel(c).fWordWrap,
    proc(c: TComponent, v: bool) = TLabel(c).wordWrap = v)

  registerClass("TEdit", "TWinControl", proc(o: TComponent): TComponent = TEdit.new(o))
  addPalette("TEdit", "Standard", "Edit")
  propStr("TEdit", "Text", pkString, proc(c: TComponent): string = TEdit(c).fText,
    proc(c: TComponent, v: string) = TEdit(c).text = v)
  propBool("TEdit", "ReadOnly", proc(c: TComponent): bool = TEdit(c).fReadOnly,
    proc(c: TComponent, v: bool) = TEdit(c).readOnly = v)
  propBool("TEdit", "Password", proc(c: TComponent): bool = TEdit(c).fPassword,
    proc(c: TComponent, v: bool) = TEdit(c).password = v)
  propEvent("TEdit", "OnChange", "notify")
  setDefaultEvent("TEdit", "OnChange")

  registerClass("TMemo", "TWinControl", proc(o: TComponent): TComponent = TMemo.new(o))
  addPalette("TMemo", "Standard", "Memo")
  propStr("TMemo", "Lines", pkStrings, proc(c: TComponent): string = TMemo(c).fText,
    proc(c: TComponent, v: string) = TMemo(c).text = v)
  propBool("TMemo", "ReadOnly", proc(c: TComponent): bool = TMemo(c).fReadOnly,
    proc(c: TComponent, v: bool) = TMemo(c).readOnly = v)
  propBool("TMemo", "WordWrap", proc(c: TComponent): bool = TMemo(c).fWordWrap,
    proc(c: TComponent, v: bool) = TMemo(c).wordWrap = v)
  propEvent("TMemo", "OnChange", "notify")
  setDefaultEvent("TMemo", "OnChange")

  registerClass("TCheckBox", "TWinControl", proc(o: TComponent): TComponent = TCheckBox.new(o))
  addPalette("TCheckBox", "Standard", "CheckBox")
  publishCaption("TCheckBox")
  propBool("TCheckBox", "Checked", proc(c: TComponent): bool = TCheckBox(c).fChecked,
    proc(c: TComponent, v: bool) = TCheckBox(c).checked = v)
  setDefaultEvent("TCheckBox", "OnClick")

  registerClass("TRadioButton", "TWinControl", proc(o: TComponent): TComponent = TRadioButton.new(o))
  addPalette("TRadioButton", "Standard", "Radio")
  publishCaption("TRadioButton")
  propBool("TRadioButton", "Checked", proc(c: TComponent): bool = TRadioButton(c).fChecked,
    proc(c: TComponent, v: bool) = TRadioButton(c).checked = v)
  setDefaultEvent("TRadioButton", "OnClick")

  registerClass("TListBox", "TWinControl", proc(o: TComponent): TComponent = TListBox.new(o))
  addPalette("TListBox", "Standard", "ListBox")
  propStr("TListBox", "Items", pkStrings, proc(c: TComponent): string = TListBox(c).fItems.join("\n"),
    proc(c: TComponent, v: string) = TListBox(c).items = parseList(v))
  propInt("TListBox", "ItemIndex", proc(c: TComponent): int = TListBox(c).fItemIndex,
    proc(c: TComponent, v: int) = TListBox(c).itemIndex = v)
  propEvent("TListBox", "OnChange", "notify")
  setDefaultEvent("TListBox", "OnClick")

  registerClass("TComboBox", "TWinControl", proc(o: TComponent): TComponent = TComboBox.new(o))
  addPalette("TComboBox", "Standard", "ComboBox")
  propStr("TComboBox", "Items", pkStrings, proc(c: TComponent): string = TComboBox(c).fItems.join("\n"),
    proc(c: TComponent, v: string) = TComboBox(c).items = parseList(v))
  propInt("TComboBox", "ItemIndex", proc(c: TComponent): int = TComboBox(c).fItemIndex,
    proc(c: TComponent, v: int) = TComboBox(c).itemIndex = v)
  propStr("TComboBox", "Text", pkString, proc(c: TComponent): string = TComboBox(c).fText,
    proc(c: TComponent, v: string) = TComboBox(c).text = v)
  propEnum("TComboBox", "Style", ["csDropDown", "csDropDownList"],
    proc(c: TComponent): string = $TComboBox(c).fStyle,
    proc(c: TComponent, v: string) = TComboBox(c).style = parseEnum[TComboBoxStyle](v.strip))
  propEvent("TComboBox", "OnChange", "notify")
  setDefaultEvent("TComboBox", "OnChange")

  registerClass("TGroupBox", "TWinControl", proc(o: TComponent): TComponent = TGroupBox.new(o))
  addPalette("TGroupBox", "Standard", "GroupBox")
  publishCaption("TGroupBox")

  registerClass("TRadioGroup", "TWinControl", proc(o: TComponent): TComponent = TRadioGroup.new(o))
  addPalette("TRadioGroup", "Standard", "RadioGroup")
  publishCaption("TRadioGroup")
  propStr("TRadioGroup", "Items", pkStrings, proc(c: TComponent): string = TRadioGroup(c).fItems.join("\n"),
    proc(c: TComponent, v: string) = TRadioGroup(c).items = parseList(v))
  propInt("TRadioGroup", "ItemIndex", proc(c: TComponent): int = TRadioGroup(c).fItemIndex,
    proc(c: TComponent, v: int) = TRadioGroup(c).itemIndex = v)
  setDefaultEvent("TRadioGroup", "OnClick")

  registerClass("TPanel", "TWinControl", proc(o: TComponent): TComponent = TPanel.new(o))
  addPalette("TPanel", "Standard", "Panel")
  publishCaption("TPanel")
  propEnum("TPanel", "Bevel", ["bvNone", "bvLowered", "bvRaised", "bvSpace"],
    proc(c: TComponent): string = $TPanel(c).fBevel,
    proc(c: TComponent, v: string) = TPanel(c).bevel = parseEnum[TBevelCut](v.strip))

  registerClass("TMainMenu", "TComponent", proc(o: TComponent): TComponent = TMainMenu.new(o), visual = false)
  addPalette("TMainMenu", "Standard", "MainMenu")
  registerClass("TPopupMenu", "TComponent", proc(o: TComponent): TComponent = TPopupMenu.new(o), visual = false)
  addPalette("TPopupMenu", "Standard", "PopupMenu")
  registerClass("TMenuItem", "TComponent", proc(o: TComponent): TComponent = TMenuItem.new(o), visual = false)
  publishCaption("TMenuItem")
  propStr("TMenuItem", "ShortCut", pkString, proc(c: TComponent): string = TMenuItem(c).fShortCut,
    proc(c: TComponent, v: string) = TMenuItem(c).shortCut = v)
  propBool("TMenuItem", "Enabled", proc(c: TComponent): bool = TMenuItem(c).fEnabled,
    proc(c: TComponent, v: bool) = TMenuItem(c).enabled = v)
  propBool("TMenuItem", "Checked", proc(c: TComponent): bool = TMenuItem(c).fChecked,
    proc(c: TComponent, v: bool) = TMenuItem(c).checked = v)
  propEvent("TMenuItem", "OnClick", "notify")
  setDefaultEvent("TMenuItem", "OnClick")

  registerClass("TBevel", "TControl", proc(o: TComponent): TComponent = TBevel.new(o))
  addPalette("TBevel", "Additional", "Bevel")
  propEnum("TBevel", "Shape", ["bsBox", "bsFrame", "bsTopLine", "bsBottomLine", "bsLeftLine", "bsRightLine"],
    proc(c: TComponent): string = $TBevel(c).fShape,
    proc(c: TComponent, v: string) = TBevel(c).shape = parseEnum[TBevelShape](v.strip))

  registerClass("TPaintBox", "TControl", proc(o: TComponent): TComponent = TPaintBox.new(o))
  addPalette("TPaintBox", "Additional", "PaintBox")
  propEvent("TPaintBox", "OnPaint", "paint")
  setDefaultEvent("TPaintBox", "OnPaint")

  registerClass("TSplitter", "TWinControl", proc(o: TComponent): TComponent = TSplitter.new(o))
  addPalette("TSplitter", "Additional", "Splitter")

  registerClass("TScrollBox", "TWinControl", proc(o: TComponent): TComponent = TScrollBox.new(o))
  addPalette("TScrollBox", "Additional", "ScrollBox")

  registerClass("TTrackBar", "TWinControl", proc(o: TComponent): TComponent = TTrackBar.new(o))
  addPalette("TTrackBar", "Common Controls", "TrackBar")
  propInt("TTrackBar", "Min", proc(c: TComponent): int = TTrackBar(c).fMin, proc(c: TComponent, v: int) = TTrackBar(c).min = v)
  propInt("TTrackBar", "Max", proc(c: TComponent): int = TTrackBar(c).fMax, proc(c: TComponent, v: int) = TTrackBar(c).max = v)
  propInt("TTrackBar", "Position", proc(c: TComponent): int = TTrackBar(c).fPosition, proc(c: TComponent, v: int) = TTrackBar(c).position = v)
  propEvent("TTrackBar", "OnChange", "notify")
  setDefaultEvent("TTrackBar", "OnChange")

  registerClass("TProgressBar", "TWinControl", proc(o: TComponent): TComponent = TProgressBar.new(o))
  addPalette("TProgressBar", "Common Controls", "ProgressBar")
  propInt("TProgressBar", "Min", proc(c: TComponent): int = TProgressBar(c).fMin, proc(c: TComponent, v: int) = TProgressBar(c).min = v)
  propInt("TProgressBar", "Max", proc(c: TComponent): int = TProgressBar(c).fMax, proc(c: TComponent, v: int) = TProgressBar(c).max = v)
  propInt("TProgressBar", "Position", proc(c: TComponent): int = TProgressBar(c).fPosition, proc(c: TComponent, v: int) = TProgressBar(c).position = v)

  registerClass("TTreeView", "TWinControl", proc(o: TComponent): TComponent = TTreeView.new(o))
  addPalette("TTreeView", "Common Controls", "TreeView")

  registerClass("TStatusBar", "TWinControl", proc(o: TComponent): TComponent = TStatusBar.new(o))
  addPalette("TStatusBar", "Common Controls", "StatusBar")
  propStr("TStatusBar", "SimpleText", pkString, proc(c: TComponent): string = TStatusBar(c).fSimpleText,
    proc(c: TComponent, v: string) = TStatusBar(c).simpleText = v)

  registerClass("TToolBar", "TWinControl", proc(o: TComponent): TComponent = TToolBar.new(o))
  addPalette("TToolBar", "Common Controls", "ToolBar")

  registerClass("TPageControl", "TWinControl", proc(o: TComponent): TComponent = TPageControl.new(o))
  addPalette("TPageControl", "Common Controls", "PageControl")
  propInt("TPageControl", "ActivePageIndex", proc(c: TComponent): int = TPageControl(c).fActive,
    proc(c: TComponent, v: int) = TPageControl(c).activePageIndex = v)
  propEvent("TPageControl", "OnChange", "notify")
  registerClass("TTabSheet", "TWinControl", proc(o: TComponent): TComponent = TTabSheet.new(o))
  publishCaption("TTabSheet")

  registerClass("TOpenDialog", "TComponent", proc(o: TComponent): TComponent = TOpenDialog.new(o), visual = false)
  addPalette("TOpenDialog", "Dialogs", "OpenDialog")
  propStr("TOpenDialog", "Title", pkString, proc(c: TComponent): string = TOpenDialog(c).fTitle,
    proc(c: TComponent, v: string) = TOpenDialog(c).title = v)
  propStr("TOpenDialog", "Filter", pkString, proc(c: TComponent): string = TOpenDialog(c).fFilter,
    proc(c: TComponent, v: string) = TOpenDialog(c).filter = v)
  propStr("TOpenDialog", "FileName", pkString, proc(c: TComponent): string = TOpenDialog(c).fFileName,
    proc(c: TComponent, v: string) = TOpenDialog(c).fileName = v)

  registerClass("TSaveDialog", "TOpenDialog", proc(o: TComponent): TComponent = TSaveDialog.new(o), visual = false)
  addPalette("TSaveDialog", "Dialogs", "SaveDialog")

  registerClass("TTimer", "TComponent", proc(o: TComponent): TComponent = TTimer.new(o), visual = false)
  addPalette("TTimer", "System", "Timer")
  propInt("TTimer", "Interval", proc(c: TComponent): int = TTimer(c).fInterval,
    proc(c: TComponent, v: int) = TTimer(c).interval = v)
  propBool("TTimer", "Enabled", proc(c: TComponent): bool = TTimer(c).fEnabled,
    proc(c: TComponent, v: bool) = TTimer(c).enabled = v)
  propEvent("TTimer", "OnTimer", "notify")
  setDefaultEvent("TTimer", "OnTimer")

  registerClass("TSourceEditor", "TWinControl", proc(o: TComponent): TComponent = TSourceEditor.new(o))

proc registerAll() =
  registerCoreProps()
  registerWidgets()
  onRefresh = proc(c: TComponent) =
    let root = ownerRoot(c)
    if root of TForm and (c of TMenuItem or c of TMainMenu or c of TPopupMenu):
      TForm(root).rebuildMenu()
