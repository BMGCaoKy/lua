function M:init()
    WinBase.init(self, "General_Pop_up.json", true)
    self.settittletext = self:child("General_Pop_up_tittle")
    self.settiptext = self:child("General_Pop_up-text")
    self.settext = self:child("General_Pop_up_textname")
    self.adduibase = self:child("General_Pop_up-inform_window")
end

function M:setArg(text1, text2, cfg)
    local path1 = string.sub(cfg,1,9)
    local path2 = string.sub(cfg,10,string.len(cfg))
    local itemcfg =  Lib.readGameJson("plugin/"..path1.."item/"..path2.."/setting.json")
    local widget = UIMgr:new_widget("cell")
    widget:invoke("ITEM_FULLNAME", cfg)
    self.adduibase:AddChildWindow(widget)
    widget:SetArea({ 0.42, 0 }, { 0.4, 0 }, { 0, 80  }, { 0, 80 })
    local langtext1 = Lang:toText(text1)
    local langtext2 = Lang:toText(text2)
    local langtext3 = Lang:toText(itemcfg.itemname)

    self._root:SetVisible(true)
    self.settittletext:SetText(langtext1)
    self.settiptext:SetText(langtext2)
    self.settext:SetText(langtext3)

    self:tick(text1, text2, cfg)

end

function M:tick(text1, text2, cfg)
    local time = 40
	if self.closeTimer then
		self.closeTimer()
		self.closeTimer = nil
	end
    local function tick()
       time = time - 1
       if time <= 0 then
            UI:closeWnd(self)
            return false
       end
       return true
    end
    self.closeTimer = World.Timer(1, tick)
	self.reloadArg = table.pack(self.closeTimer, text1, text2, cfg)
end

function M:onReload(reloadArg)
	local closeTimer, text1, text2, cfg = table.unpack(reloadArg or {}, 1, reloadArg and reloadArg.n)
	if closeTimer then
		closeTimer()
		closeTimer = nil
	end
	self:setArg(text1, text2, cfg)
end

return M