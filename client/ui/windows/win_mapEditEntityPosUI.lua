local cmd = require "editor.cmd"
local entity_obj = require "editor.entity_obj"
local data_state = require "editor.dataState"
local engine = require "editor.engine"
local global_setting = require "editor.setting.global_setting"

local hight = 0
local uiCount = 0
local function fetchBtn(self, info, backFunc)
    local btn = GUIWindowManager.instance:LoadWindowFromJSON("btn_edit.json")
    btn:SetArea({0, 0}, {hight / 314, 0 }, { 1, 0}, { 58 / 314, 0})
    btn:child("Btn-Item-Icon"):SetImage(info.icon)--todo
    btn:child("Btn-Item-ImageTextLayout-TextImage"):SetImage(info.image)
    btn:child("Btn-Item-ImageTextLayout-TextImage"):SetArea({0, 0}, {0,  0}, {info.size[1] / 72 * 0.75, 0 }, {info.size[2] / 72 * 1.2, 0})
	self:subscribe(btn:child("Btn-Item"), UIEvent.EventButtonClick, function()
		if backFunc then
			backFunc(self.argc)
		end
        UI:closeWnd(self)
    end)
    self.menu_1:AddChildWindow(btn)
    btn:SetAutoSize(true)
	hight = hight + 58 + 6
	uiCount = uiCount + 1
    return btn
end

function M:initData()
    if World.Lang == "zh_CN" then
        self.itemNameImageList = { 
			changMonsterModle 	= 
			{
				icon = "set:map_edit_objectset.json image:icon_refresh_setting",
				image = "image/cn_Change.png", 		
				size = {71,18  }	
			},
			setPosition 	= 
			{
				icon = "set:map_edit_objectset.json image:icon_pos_setting",
				image = "image/cn_Position.png", 		
				size = {71,18}	
			},
			delete 	= 
			{
				icon = "set:map_edit_objectset.json image:icon_del_setting",
				image = "image/cn_Delete.png", 		
				size = {37,18}	
			},
			setting 	= 
			{
				icon = "image/icon_quality_setting.png",
				image = "image/cn_setting.png", 		
				size = {37,18}	
			},
		}
			
	else
		self.itemNameImageList = {
			changMonsterModle 	= 
			{
				icon = "set:map_edit_objectset.json image:icon_refresh_setting",
				image = "image/en_Change.png", 		
				size = {65,21}	
			},
			setPosition 	= 
			{
				icon = "set:map_edit_objectset.json image:icon_pos_setting",
				image = "image/en_Position.png", 		
				size = {67,15}	
			},
			delete 	= 
			{
				icon = "set:map_edit_objectset.json image:icon_del_setting",
				image = "image/en_Delete.png", 		
				size = {54,16}	
			},
			setting 	= 
			{
				icon = "image/icon_quality_setting.png",
				image = "image/en_setting.png", 		
				size = {58,21}	
			},
		}
	end
	local wShowFollowImageData = World.cfg.showFollowImageData 
	for k, v in pairs(wShowFollowImageData or {}) do
		self.itemNameImageList[k] = v
	end
end

function M:init()
    WinBase.init(self, "entitySetting_edit.json")
    self.menu = self:child("Edit-Entity-Menu")
    self.menu:SetInterval(6)
    self.menu_1 = self:child("Edit-Entity-Menu_1")
    self.close = self:child("Edit-Entity-Close")
	self._root:SetArea({0, 0}, {0, 0 }, { 0, 180}, { 0, 439})
	self:initData()
    self.close:SetVisible(false)
	self:subscribe(self.close, UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
    end)

    Lib.subscribeEvent(Event.EVENT_CLOSE_POP_WIN, function()
        if not self.isRespondPopWindow then
            return
        end
        UI:closeWnd(self)
    end)
    self:root():setBelongWhitelist(true)
end

function M:showSettingUi()
	local uiShowList = self.uiShowList
	for k, uiItem in pairs(uiShowList or {}) do
		local info = self.itemNameImageList[uiItem.uiName]
		if info then
			local btn = fetchBtn(self, info, uiItem.backFunc)   
            if uiItem.uiName == "changMonsterModle" then
                btn:setBelongWhitelist(true)
            end
		end
	end
end

function M:followEntity()
	local objID = self.objID
	if self.timer then
		self.timer()
		self.timer = nil
	end
	if not objID then
		return
	end
	self.timer = UILib.uiFollowObject(self:root(), objID, {
		anchor = {
			x = -0.4,
			y = 0.2 + uiCount * 0.1
		},
		minScale = 0.7,
		maxScale = 1.2,
		autoScale = true,
		canAroundYaw = false
	})
end

function M:onOpen(params)
	self.objID = params and params.objID
	self.uiShowList = params.uiShowList
    self.argc = params.argc
	self.menu_1:CleanupChildren()
	if not self.objID then
		return
	end
	hight = 0
	uiCount = 0
	self:showSettingUi()
	self:followEntity()
    self.isRespondPopWindow = true
    Blockman.instance.gameSettings.isPopWindow = true
end

function M:onClose()
	-- if self.widget_obj then
	-- 	engine:del_widget_frame(self.widget_obj)
	-- end
    self.isRespondPopWindow = false
    Blockman.instance.gameSettings.isPopWindow = false
end

function M:onReload(reloadArg)

end

return M