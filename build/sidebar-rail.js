module.exports = function(bundle) {
 function replace(from,to) { if(bundle.split(from).length!==2) throw Error('Rail integration changed: '+from.slice(0,70));bundle=bundle.replace(from,to); }
 replace('Window.SideBarVisible and Window.SideBarWidth or 0','Window.SideBarVisible and Window.SideBarWidth or 52');
 replace('Window.UIElements.SideBarContainer.Visible = visible','Window.UIElements.SideBarContainer.Visible = visible\n\t\t\tif Window.IconRail then Window.IconRail.Frame.Visible = not visible; Window.IconRail:Sync() end');
 replace('visible and -Window.SideBarWidth or 0','visible and -Window.SideBarWidth or -52');
 const start=bundle.indexOf('__modules["src/components/window/Init.lua"]'); const end=bundle.indexOf('\n__modules[',start+20); let win=bundle.slice(start,end); if(win.split('\treturn Window\nend').length!==2) throw Error('Window return changed'); win=win.replace('\treturn Window\nend','\trequire("src/components/SidebarRail.lua").Attach(Window)\n\treturn Window\nend'); bundle=bundle.slice(0,start)+win+bundle.slice(end);
 replace('\treturn Tab\nend\n\nfunction TabModule:OnChange','\tif Window.IconRail then Window.IconRail:Sync() end\n\treturn Tab\nend\n\nfunction TabModule:OnChange');
 replace('\t\tTabModule.OnChangeFunc(TabIndex)','\t\tif Window.IconRail then Window.IconRail:Refresh() end\n\t\tTabModule.OnChangeFunc(TabIndex)');
 return bundle;
};
