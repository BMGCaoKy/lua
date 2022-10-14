
function M:init()
	WinBase.init(self, "BGMList.json", true)

	self.curMusicIndex = 0
	self.curMusicText = self:child("BGMList-CurMusic")

	local titleText = self:child("BGMList-Title")
	titleText:SetText(Lang:toText("gui.text.bgmlist.title"))
	
	local sureBtn = self:child("BGMList-Sure")
	sureBtn:SetText(Lang:toText("gui.text.sure"))
	self:subscribe(sureBtn, UIEvent.EventButtonClick, function()
		local index = self.selectedBgmIndex
		--self:onAuditionBgmChanged(nil)
		if index then
			Me:sendPacket({ pid = "StartPlayBGM", index = index })
		else
			UI:closeWnd(self)
		end
	end)

	local cancelBtn = self:child("BGMList-Cancel")
	cancelBtn:SetText(Lang:toText("gui.text.cancel"))
	self:subscribe(cancelBtn, UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
	end)

	Lib.subscribeEvent(Event.EVENT_PLAYING_BGM_CHANGED, function(index)
		self:onPlayingBgmChanged(index)
	end)

	self:initBgmList()
end

function M:getBgmListSize()
	local list = self.bgmItemList
	if not list then
		return 0
	end
	local wnd = list:getContainerWindow()
	return wnd and wnd:GetChildCount() or 0
end

function M:getBgmListItem(index)
	if not index or index < 1 or index > self:getBgmListSize() then
		return nil
	end
	return self.bgmItemList:getContainerWindow():GetChildByIndex(index - 1)
end

function M:isBgmNeedPrivilege(index)
	local list = self.bgmCfgList or {}
	if not index or index < 1 or index > #list then
		return nil
	end
	return list[index].needPrivilege == "TRUE"
end


function M:initBgmList()
	local bgmList = self:child("BGMList-List")
	bgmList:SetInterval(10)
	bgmList:ClearAllItem()
	self.bgmCfgList = Lib.readGameCsv("bgm.csv") or {}
	local windowMgr = GUIWindowManager.instance
	for i, cfg in pairs(self.bgmCfgList) do
		local item = windowMgr:LoadWindowFromJSON("BGMListItem.json")
		item:child("BGMListItem-MusicName"):SetText(Lang:toText(cfg.name or ""))
		if self:isBgmNeedPrivilege(i) then
			item:SetBackImage("set:gui_bgm_list.json image:vip_background_normal.png")
		else
			item:SetBackImage("set:gui_bgm_list.json image:background_normal.png")
		end
		self:subscribe(item, UIEvent.EventWindowClick, function()
			self:onSelectedBgmChanged(i)
		end)

		local playBtn = item:child("BGMListItem-PlayMusic")
		self:subscribe(playBtn, UIEvent.EventButtonClick, function()
			self:onAuditionBgmChanged(i)
		end)
		bgmList:AddItem(item)
	end
	self.bgmItemList = bgmList
end

function M:onOpen()
	WinBase.onOpen(self)
	if self.playingBgmIndex then
		self:onPlayingBgmChanged(self.playingBgmIndex)
	end
end

function M:onClose()
	self:onAuditionBgmChanged(nil)
	self:onSelectedBgmChanged(nil)
	WinBase.onClose(self)
end

function M:onPlayingBgmChanged(newIndex)
	self.playingBgmIndex = newIndex

	if not UI:isOpen(self) then
		return
	end

	local oldIndex = self.lastPlayingIndex
	local item = self:getBgmListItem(oldIndex)
	if item then
		local needPrivilege = self:isBgmNeedPrivilege(oldIndex)
		local backImg = needPrivilege and "set:gui_bgm_list.json image:vip_background_normal.png" or "set:gui_bgm_list.json image:background_normal.png"
		if oldIndex == self.selectedBgmIndex then
			backImg = needPrivilege and "set:gui_bgm_list.json image:vip_background_crrent.png" or "set:gui_bgm_list.json image:background_crrent.png"
		end
		item:SetBackImage(backImg)
	end	

	if newIndex ~= self.selectedBgmIndex then
		local item = self:getBgmListItem(newIndex)
		if item then
			local needPrivilege = self:isBgmNeedPrivilege(newIndex)
			local backImg = needPrivilege and "set:gui_bgm_list.json image:vip_background_playing.png" or "set:gui_bgm_list.json image:background_playing.png"
			item:SetBackImage(backImg)
			self.lastPlayingIndex = newIndex
		end
	end

	local cfg = self.bgmCfgList[newIndex]
	if cfg then
		self.curMusicText:SetText(Lang:formatMessage("gui.text.bgmlist.playing", {Lang:toText(cfg.name or "")}))
	else
		self.curMusicText:SetText("")
	end
end

function M:onSelectedBgmChanged(newIndex)
	local oldIndex = self.selectedBgmIndex
	if oldIndex == newIndex then
		return
	end

	local item = self:getBgmListItem(oldIndex)
	if item then
		local needPrivilege = self:isBgmNeedPrivilege(oldIndex)
		local backImg = needPrivilege and "set:gui_bgm_list.json image:vip_background_normal.png" or "set:gui_bgm_list.json image:background_normal.png"
		if oldIndex == self.playingBgmIndex then
			backImg = needPrivilege and "set:gui_bgm_list.json image:vip_background_playing.png" or "set:gui_bgm_list.json image:background_playing.png"
		end
		item:SetBackImage(backImg)
	end
	self.selectedBgmIndex = nil

	local item = self:getBgmListItem(newIndex)
	if item then
		local needPrivilege = self:isBgmNeedPrivilege(newIndex)
		local backImg = needPrivilege and "set:gui_bgm_list.json image:vip_background_crrent.png" or "set:gui_bgm_list.json image:background_crrent.png"
		item:SetBackImage(backImg)
		self.selectedBgmIndex = newIndex
	end
end

function M:onAuditionBgmChanged(newIndex)
	local mainData = Me:data("main")
	local oldIndex = mainData.auditionBgmIndex
	if oldIndex == newIndex then
		return
	end

	local buff = mainData.auditionBgmBuff
	if buff then
		if buff.soundId then
			TdAudioEngine.Instance():setSoundsVolume(buff.soundId, 1.0)
		end
		Me:removeClientBuff(buff)
		mainData.auditionBgmBuff = nil
		TdAudioEngine.Instance():setGlobalVolume(1.0)
	end
	local oldIndex = mainData.auditionBgmIndex
	local item = self:getBgmListItem(oldIndex)
	if item then
		local button = item:child("BGMListItem-PlayMusic")
		button:SetNormalImage("set:gui_bgm_list.json image:button_play.png")
		button:SetPushedImage("set:gui_bgm_list.json image:button_play.png")
		self:unsubscribe(button, UIEvent.EventButtonClick)
		self:subscribe(button, UIEvent.EventButtonClick, function()
			self:onAuditionBgmChanged(oldIndex)
		end)
	end

	local cfg = self.bgmCfgList[newIndex]
	if not cfg then
		mainData.auditionBgmIndex = nil
		return
	end
	local item = self:getBgmListItem(newIndex)
	if item then
		local button = item:child("BGMListItem-PlayMusic")
		button:SetNormalImage("set:gui_bgm_list.json image:button_pause.png")
		button:SetPushedImage("set:gui_bgm_list.json image:button_pause.png")
		self:unsubscribe(button, UIEvent.EventButtonClick)
		self:subscribe(button, UIEvent.EventButtonClick, function()
			self:onAuditionBgmChanged(nil)
		end)
		self:onSelectedBgmChanged(newIndex)
	end
	mainData.auditionBgmBuff = Me:addClientBuff(cfg.buff)
	local soundId = mainData.auditionBgmBuff.soundId
	if soundId then
		local globalVolume = 0.001
		TdAudioEngine.Instance():setGlobalVolume(globalVolume)
		TdAudioEngine.Instance():setSoundsVolume(soundId, 1 / globalVolume)
	end
	mainData.auditionBgmIndex = newIndex
end
