local active, tweens, timers = 0, {}, {}
local function signal()
 local handlers={}
 return {Connect=function(_,fn)
  local c={Connected=true};active=active+1
  function c:Disconnect()if self.Connected then self.Connected=false;active=active-1 end end
  handlers[#handlers+1]={c,fn};return c
 end,Fire=function(_,...)local copy={};for i,v in ipairs(handlers)do copy[i]=v end;for _,v in ipairs(copy)do if v[1].Connected then v[2](...)end end end}
end
local function node(class)
 local n={ClassName=class,Children={},Parent={}}
 for _,key in ipairs({'Destroying','MouseEnter','MouseLeave','SelectionGained','SelectionLost','InputBegan','InputEnded','Activated'})do n[key]=signal()end
 function n:Destroy()if self.Dead then return end;self.Dead=true;self.Destroying:Fire();self.Parent=nil;for _,v in ipairs(self.Children)do v:Destroy()end end
 return n
end
local Creator={Font='test'}
function Creator.New(class,p,children)
 local n=node(class);for k,v in pairs(p or {})do n[k]=v end
 if n.Parent and n.Parent.Children then table.insert(n.Parent.Children,n)end
 for _,v in ipairs(children or {})do v.Parent=n;table.insert(n.Children,v)end
 return n
end
function Creator.NewRoundFrame(_,shape,p,children,isButton)local n=Creator.New(isButton and 'ImageButton' or 'ImageLabel',p,children);n.Shape=shape;return n end
function Creator.Icon()return {'asset',{}}end
function Creator.Image()local n=node('Frame');n.ImageLabel=Creator.New('ImageLabel',{Parent=n});return n end
function Creator.Tween(target,_,props)
 local t={Completed=signal()}
 function t:Play()for k,v in pairs(props)do target[k]=v end end
 function t:Cancel()self.Cancelled=true;self.Completed:Fire()end
 tweens[#tweens+1]=t;return t
end
local env=setmetatable({
 Enum=setmetatable({},{__index=function()return setmetatable({},{__index=function(_,k)return k end})end}),
 UDim2={new=function(...)return {...}end},UDim={new=function(...)return {...}end},Vector2={new=function(...)return {...}end},Font={new=function()return {}end},
 task={delay=function(_,fn)timers[#timers+1]=fn end},
},{__index=_G})
local loaded={}
env.require=function(id)
 if id=='../modules/Creator'then return Creator end
 local name=id:match('([^/]+)$');if not loaded[name]then local f=assert(loadfile('src/components/'..name..'.lua'));setfenv(f,env);loaded[name]=f()end
 return loaded[name]
end
local Glass=env.require('./GlassButton')
local calls=0
local glass=Glass.New({Parent=node('Frame'),Mode='Segment',Title='Block',Callback=function()calls=calls+1 end})
assert(glass.Fill.ImageTransparency==1)
glass:SetSelected(true);assert(glass.Fill.ImageTransparency==0.9)
glass.Button.InputBegan:Fire({UserInputType='Touch'});local press=glass.Motion.Active.press.Tween
glass.Button.InputEnded:Fire({UserInputType='Touch'});assert(press.Cancelled and glass.Scale.Scale==1)
glass.Button.Activated:Fire();assert(calls==1)
glass:Destroy();glass.Button.Activated:Fire();assert(calls==1 and active==0,'glass lifecycle leaked '..active)
local old=#tweens
local reduced=Glass.New({Parent=node('Frame'),ReducedMotion=true});assert(#tweens==old);reduced:Destroy();assert(active==0)
local window={Topbar={Height=44},UIElements={Main={Main=node('Frame')}},TabModule={Tabs={[1]={Icon='house'},[3]={Icon='eye'},[7]={Icon='music',Locked=true}},SelectedTab=1}}
function window.TabModule:SelectTab(index)self.SelectedTab=index;window.IconRail:Refresh()end
env.require('./SidebarRail').Attach(window)
local rail=window.IconRail
assert(rail.Buttons[1] and rail.Buttons[3] and rail.Buttons[7],'sparse tab dropped')
assert(rail.Entries[3].IconName=='eye','eye icon missing')
rail.Buttons[3].Activated:Fire();assert(window.TabModule.SelectedTab==3)
rail.Buttons[7].Activated:Fire();assert(window.TabModule.SelectedTab==3,'locked tab selected')
old=#tweens;for _=1,10 do rail:Sync()end;assert(#tweens==old,'unchanged rail sync starts tweens')
rail:SetCollapsed(true);rail:SetCollapsed(false);rail:SetCollapsed(true)
for _,fn in ipairs(timers)do fn()end;assert(rail.Frame.Visible,'stale hide beat reopened rail')
window.TabModule.Tabs[3]=nil;rail:Sync();assert(rail.Buttons[3]==nil)
rail.Frame:Destroy();for _,fn in ipairs(timers)do fn()end
assert(active==0,'rail lifecycle leaked '..active)
print('Glass/rail: cancellation, activation, reduced motion, sparse/eye icons, locked tabs, rapid collapse and cleanup passed')
