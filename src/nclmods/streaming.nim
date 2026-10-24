# .nfm form files. Same idea as a Lazarus .lfm: a text tree of published properties.

type
  NfmNode = ref object
    name: string
    className: string
    props: seq[tuple[name, value: string]]
    children: seq[NfmNode]

var defaultCache: Table[string, Table[string, string]]

proc quoteNfm(s: string): string =
  result = "'"
  let bytes = s
  var i = 0
  while i < bytes.len:
    let ch = bytes[i]
    case ch
    of '\'': result.add "''"
    of '\\': result.add "\\\\"
    of '\n': result.add "\\n"
    of '\r': result.add "\\r"
    else: result.add ch
    inc i
  result.add "'"

proc defaultsFor(cls: string): Table[string, string] =
  if defaultCache.hasKey(cls): return defaultCache[cls]
  result = initTable[string, string]()
  if factories.hasKey(cls) and factories[cls] != nil:
    let tmp = factories[cls](nil)
    for p in allProps(cls):
      try:
        result[p.name] = p.get(tmp)
      except CatchableError:
        discard
    freeComponent(tmp)
  defaultCache[cls] = result

proc streamChildren*(c: TComponent): seq[TComponent] =
  var seen = initHashSet[int]()
  if c of TPageControl:
    for page in TPageControl(c).pages:
      if not page.internal and not page.dead:
        result.add(page)
        seen.incl(page.liveId)
  elif c of TWinControl:
    for ch in TWinControl(c).controls:
      if ch.internal or ch.dead: continue
      if ch of TTabSheet: continue
      result.add(ch)
      seen.incl(ch.liveId)
  let root = ownerRoot(c)
  if root == nil: return
  for ch in root.owned:
    if ch.internal or ch.dead: continue
    if ch.liveId in seen: continue
    if ch.container == c: result.add(ch)

proc renderValue(kind: TPropKind, v: string): string =
  case kind
  of pkString, pkStrings: quoteNfm(v)
  of pkColor:
    if v.len > 0 and (v[0] == '#' or ' ' in v): quoteNfm(v) else: v
  else: v

proc saveComponent(c: TComponent, indent: int): string =
  let pad = repeat(' ', indent)
  result = pad & "object " & c.name & ": " & c.className & "\n"
  let defs = defaultsFor(c.className)
  for p in allProps(c.className):
    if p.name == "Name": continue
    var value = ""
    try:
      value = p.get(c)
    except CatchableError:
      continue
    let d = if defs.hasKey(p.name): defs[p.name] else: ""
    if value == d: continue
    result.add(pad & "  " & p.name & " = " & renderValue(p.kind, value) & "\n")
  for ch in streamChildren(c):
    result.add(saveComponent(ch, indent + 2))
  result.add(pad & "end\n")

proc saveNfm*(root: TComponent): string = saveComponent(root, 0)

proc skipWs(s: string, i: var int) =
  while i < s.len and s[i] in {' ', '\t', '\r', '\n'}: inc i

proc parseQuoted(s: string, i: var int): string =
  if i >= s.len or s[i] != '\'':
    raise newException(ValueError, "expected a quoted value in the form file")
  inc i
  while i < s.len:
    if s[i] == '\'':
      if i + 1 < s.len and s[i + 1] == '\'':
        result.add '\''
        inc i, 2
      else:
        inc i
        return
    elif s[i] == '\\' and i + 1 < s.len:
      case s[i + 1]
      of 'n': result.add '\n'
      of 'r': result.add '\r'
      of '\\': result.add '\\'
      of '\'': result.add '\''
      else: result.add s[i + 1]
      inc i, 2
    else:
      result.add s[i]
      inc i

proc parseRaw(s: string, i: var int): string =
  skipWs(s, i)
  if i < s.len and s[i] == '\'': return parseQuoted(s, i)
  let start = i
  while i < s.len and s[i] notin {'\n', '\r'}: inc i
  s[start ..< i].strip

proc parseNfm(s: string): NfmNode =
  var i = 0
  proc atKeyword(word: string): bool =
    if i + word.len > s.len: return false
    if s[i ..< i + word.len] != word: return false
    let after = i + word.len
    after >= s.len or s[after] in {' ', '\t', '\n', '\r', ':'}
  proc parseObject(): NfmNode =
    skipWs(s, i)
    if not atKeyword("object"):
      raise newException(ValueError, "expected 'object' in the form file at " & $i)
    inc i, "object".len
    skipWs(s, i)
    let ns = i
    while i < s.len and s[i] notin {':', ' ', '\t', '\n', '\r'}: inc i
    result = NfmNode(name: s[ns ..< i].strip)
    skipWs(s, i)
    if i < s.len and s[i] == ':':
      inc i
      skipWs(s, i)
      let cs = i
      while i < s.len and s[i] notin {' ', '\t', '\n', '\r'}: inc i
      result.className = s[cs ..< i].strip
    while true:
      skipWs(s, i)
      if i >= s.len: break
      if atKeyword("end"):
        inc i, 3
        break
      if atKeyword("object"):
        result.children.add(parseObject())
        continue
      let ps = i
      while i < s.len and s[i] notin {'=', '\n', '\r'}: inc i
      let pname = s[ps ..< i].strip
      if pname.len == 0: break
      if i < s.len and s[i] == '=': inc i
      result.props.add((pname, parseRaw(s, i)))
  parseObject()

proc attachLogical(container, child: TComponent) =
  child.container = container
  if container of TForm and child of TMainMenu:
    TForm(container).menu = TMainMenu(child)
  elif container of TMainMenu and child of TMenuItem:
    TMainMenu(container).fItems.add(TMenuItem(child))
  elif container of TPopupMenu and child of TMenuItem:
    TPopupMenu(container).fItems.add(TMenuItem(child))
  elif container of TMenuItem and child of TMenuItem:
    TMenuItem(container).fItems.add(TMenuItem(child))
  elif container of TWinControl and child of TControl and not isNonVisualClass(child.className):
    TControl(child).parent = TWinControl(container)

proc applyNode(node: NfmNode, obj: TComponent) =
  for p in node.props:
    if obj.hasProp(p.name):
      try:
        obj.setProp(p.name, p.value)
      except CatchableError as e:
        stderr.writeLine("nfm: " & obj.name & "." & p.name & ": " & e.msg)

proc buildChild(node: NfmNode, root, container: TComponent) =
  if node.className.len == 0:
    raise newException(ValueError, "form object without a class")
  let obj = createComponent(node.className, root)
  if node.name.len > 0: obj.name = node.name
  obj.container = container
  applyNode(node, obj)
  attachLogical(container, obj)
  for ch in node.children:
    buildChild(ch, root, obj)

proc loadNfm*(root: TComponent, text: string) =
  if text.strip.len == 0: return
  let node = parseNfm(text)
  if node.name.len > 0: root.name = node.name
  applyNode(node, root)
  let rootOwner = ownerRoot(root)
  for ch in node.children:
    buildChild(ch, rootOwner, root)

proc nonVisualOf*(form: TForm): seq[TComponent] =
  for c in form.owned:
    if not c.internal and not c.dead and isNonVisualClass(c.className):
      result.add(c)
