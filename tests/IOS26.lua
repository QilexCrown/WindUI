local Mock = {Active = 0, Tweens = {}}
function Mock.Signal()
    local handlers = {}
    local signal = {}
    function signal:Connect(fn)
        local c = {Connected = true}
        Mock.Active = Mock.Active + 1
        function c:Disconnect() if self.Connected then self.Connected = false; Mock.Active = Mock.Active - 1 end end
        handlers[#handlers + 1] = {c, fn}
        return c
    end
    function signal:Once(fn)
        local c
        c = self:Connect(function(...) c:Disconnect(); fn(...) end)
        return c
    end
    function signal:Fire(...)
        local copy = {}; for i, entry in ipairs(handlers) do copy[i] = entry end
        for _, entry in ipairs(copy) do if entry[1].Connected then entry[2](...) end end
    end
    return signal
end
function Mock.Node(class)
    local item = {ClassName = class, Children = {}, Signals = {}, AbsoluteSize = {X = 300, Y = 30}}
    for _, key in ipairs({'Destroying', 'InputBegan', 'InputEnded', 'MouseLeave', 'SelectionLost'}) do item[key] = Mock.Signal() end
    function item:GetPropertyChangedSignal(key)
        self.Signals[key] = self.Signals[key] or Mock.Signal(); return self.Signals[key]
    end
    function item:GetChildren() return self.Children end
    function item:FindFirstChildOfClass(name)
        for _, child in ipairs(self.Children) do if not child.Destroyed and child.ClassName == name then return child end end
    end
    function item:IsA(name) return self.ClassName == name end
    function item:Destroy()
        if self.Destroyed then return end
        self.Destroying:Fire(); self.Destroyed = true
        for _, child in ipairs(self.Children) do child:Destroy() end
    end
    return item
end
local Creator = {Font = 'test'}
function Creator.New(class, props, children)
    local item = Mock.Node(class)
    for key, value in pairs(props or {}) do item[key] = value end
    if item.Parent then table.insert(item.Parent.Children, item) end
    for _, child in ipairs(children or {}) do child.Parent = item; table.insert(item.Children, child) end
    return item
end
function Creator.NewRoundFrame(_, _, props, children) return Creator.New('ImageLabel', props, children) end
function Creator.Image() local item = Mock.Node('Frame'); item.ImageLabel = Mock.Node('ImageLabel'); return item end
function Creator.AddThemeObject() end
function Creator.GetTextColorForHSB() return {} end
function Creator.GetThemeProperty() return {} end
function Creator.GetAverageColor() return {} end
local themes = Mock.Signal()
function Creator:OnThemeChange(fn) return themes:Connect(fn) end
function Creator.Tween(item, _, props)
    local tween = {Completed = Mock.Signal()}
    function tween:Play() self.Played = true; for k,v in pairs(props) do item[k] = v end end
    function tween:Cancel() self.Cancelled = true; self.Completed:Fire('Cancelled') end
    Mock.Tweens[#Mock.Tweens + 1] = tween
    return tween
end
local enum = setmetatable({}, {__index = function(t, k)
    local e = setmetatable({}, {__index = function(_, v) return v end}); t[k] = e; return e
end})
local env = setmetatable({Enum = enum,
    UDim2 = {new = function(x,xo,y,yo) return {X={Scale=x,Offset=xo},Y={Scale=y,Offset=yo}} end},
    Vector2 = {new = function(x,y) return {X=x,Y=y} end}, Font = {new = function() return {} end},
    Color3 = {new = function() return {kind='Color3'} end, fromHex = function() return {kind='Color3'} end},
    typeof = function(v) return type(v) == 'table' and v.kind or type(v) end,
    game = {GetService = function() return {GetTextSize = function(_, text) return {X=#text*7} end} end},
}, {__index = _G})
local cache = {}
local paths = {Creator = Creator}
env.require = function(id)
    local key = id:match('([^/]+)$')
    if paths[key] then return paths[key] end
    if cache[key] then return cache[key] end
    local file = 'src/components/'..(key == 'Tag' and 'ui/' or '')..key..'.lua'
    local chunk = assert(loadfile(file)); setfenv(chunk, env); cache[key] = chunk(); return cache[key]
end
local Tag, Dock = env.require('Tag'), env.require('ToolbarDock')
local parent = Mock.Node('ScrollingFrame')
local dock = Dock.New(parent, {UIScale = 1})
local version = Tag:New({Title='v2.7.6', Style='Glass', Priority=100}, parent)
local github = Tag:New({Title='GitHub', Icon='github', Style='Glass', Priority=10}, parent)
dock:Add(version); dock:Add(github)
for _, width in ipairs({300, 180, 100, 60, 0, 300}) do
    parent.AbsoluteSize.X = width; parent:GetPropertyChangedSignal('AbsoluteSize'):Fire()
    for _, tag in ipairs(dock.Tags) do
        local f = tag.Frame
        if f.Visible then assert(f.Position.X.Offset + f.Size.X.Offset <= width) end
    end
end
version:SetTitle('A very long translated title'):SetColor({Color={}}):SetIcon('star'):SetIcon(nil)
version.Frame.Children[2].Text = 'localized'
version.Frame.Children[2]:GetPropertyChangedSignal('Text'):Fire()
assert(version.Title == 'localized', 'localization updates measurement')
local compact = Tag:New({Title='Full title', CompactTitle='Long compact label', Style='Glass'}, parent)
dock:Add(compact)
local label = compact.Frame.Children[3]
label.Text = 'EN'; label:GetPropertyChangedSignal('Text'):Fire()
assert(compact:GetMetrics().CompactWidth == 34, 'translated compact width is stale')
compact:SetLayout({Width=34,Compact=true,Visible=true})
assert(compact.Title == 'Full title', 'compaction corrupted full title')
compact:Destroy()
version:Destroy(); assert(#dock.Tags == 1)
parent:Destroy(); assert(Mock.Active == 0, 'tag/dock leaked '..Mock.Active..' connections')
local Motion = env.require('PressMotion')
local existing = Mock.Node('TextButton')
local owned = Creator.New('UIScale', {Scale=1, Parent=existing})
Motion.Bind(existing)
assert(Mock.Active == 0, 'unowned scale should be respected')
Motion.Bind(existing,false,owned)
existing.InputBegan:Fire({UserInputType='MouseButton1'})
assert(owned.Scale == 0.97, 'explicit toolbar scale owner not bound')
existing:Destroy(); assert(Mock.Active == 0)
local button = Mock.Node('TextButton'); Motion.Bind(button)
button.InputBegan:Fire({UserInputType='MouseButton1'})
local first = Mock.Tweens[#Mock.Tweens]
button.InputEnded:Fire({UserInputType='MouseButton1'})
assert(first.Cancelled, 'rapid press did not cancel its prior tween')
assert(button:FindFirstChildOfClass('UIScale').Scale == 1)
Motion.Reduced = true
button.InputBegan:Fire({UserInputType='MouseButton1'})
assert(button:FindFirstChildOfClass('UIScale').Scale == 1, 'reduced motion was ignored')
Motion.Reduced = false
button:Destroy(); assert(Mock.Active == 0, 'press connections leaked')
local Tabs = env.require('TabMotion')
local pages = {Mock.Node('Frame'),Mock.Node('Frame')}
Tabs.Select(pages,1); local old = Mock.Tweens[#Mock.Tweens]
Tabs.Select(pages,2); assert(old.Cancelled and not pages[1].Visible and pages[2].Visible)
Mock.Tweens[#Mock.Tweens].Completed:Fire('Completed')
Tabs.Select(pages,1,true); assert(pages[1].AnchorPoint.Y == 0)
for _, page in ipairs(pages) do page:Destroy() end
assert(Mock.Active == 0, 'tab connections leaked: '..Mock.Active)
print('iOS controls: resize, localization, destruction and rapid motion passed')
