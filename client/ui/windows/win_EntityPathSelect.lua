local entity_obj = require "editor.entity_obj"
local global_setting = require "editor.setting.global_setting"
local entitySetting = require "editor.setting.entity_setting"

local bm = Blockman.Instance()
local manorRadius = 5
local isShop

function M:init()
    WinBase.init(self, "setEntityPath_edit.json")

    self.gridView = self:child("Path-Layout-GridView")
    self.gridView:InitConfig(0, 1, 1)
    self.gridView:SetAutoColumnCount(false)
    self.gridView:HasItemHidden(false)
    self.item = GUIWindowManager.instance:LoadWindowFromJSON("setEntityPathItem_edit.json")
    self.gridView:AddItem(self.item)
   
    self.manorMode = self.item:child("Path-Layout-Up-Sel")
    self.fixedMode = self.item:child("Path-Layout-Mid-Sel")
    self.staticMode = self.item:child("Path-Layout-Down-Sel")
    self.manorFram = self.item:child("Path-Layout-Up-Fram1")
    self.fixedFram = self.item:child("Path-Layout-Mid-Frame1")
    self.staticFram = self.item:child("Path-Layout-Down-Frame1")
    self.setPathBtn = self.item:child("Path-Layout-Mid-Btn")
    self.back = self:child("Path-Layout-Back")
    self.back:setBelongWhitelist(true)
    self.slider = self.item:child("Path-Layout-Up-Slider")
    self.showSliderNum = self.item:child("Path-Layout-Up-SliderNum")
    self.setPathBtnText = self.item:child("Path-Layout-Mid-Btn-Text")
    self.title = self:child("Path-Title")
    self.upDepict = self.item:child("Path-Layout-Up-Depict")
    self.upShow = self.item:child("Path-Layout-Up-Show")
    self.upManor = self.item:child("Path-Layout-Up-Manor")
    self.upExplain = self.item:child("Path-Layout-Up-Explain")
    self.midDepict = self.item:child("Path-Layout-Mid-Depict")
    self.midShow = self.item:child("Path-Layout-Mid-Show")
    self.midLine = self.item:child("Path-Layout-Mid-Line")
    self.downDepict = self.item:child("Path-Layout-Down-Depict")
    self.downShow = self.item:child("Path-Layout-Down-Show")
    self.downLine = self.item:child("Path-Layout-Down-Line")

    self:initUI()

    self:subscribe(self.setPathBtn, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
        UI:openWnd("aiControl", self._entityId)
    end)

    self:subscribe(self.manorFram, UIEvent.EventWindowTouchUp, function()
         self:setMode(0, manorRadius)
    end)
    self:subscribe(self.fixedFram, UIEvent.EventWindowTouchUp, function()
         self:setMode(1, manorRadius)
    end)
    self:subscribe(self.staticFram, UIEvent.EventWindowTouchUp, function()
         self:setMode(2, manorRadius)
    end)

    self:subscribe(self.back, UIEvent.EventButtonClick, function()
        self:closePathWnd()
    end)

    self:subscribe(self:child("Path-Bg"), UIEvent.EventWindowClick, function()
        self:closePathWnd()
    end)

    self:subscribe(self.slider, UIEvent.EventWindowTouchDown, function()
    end)

	self:subscribe(self.slider, UIEvent.EventWindowTouchMove, function()
        self:setAiRadiusNum()
    end)

	self:subscribe(self.slider, UIEvent.EventWindowTouchUp, function()
       self:setAiRadiusNum()
    end)

	self:subscribe(self.slider, UIEvent.EventMotionRelease, function()
        self:setAiRadiusNum()
    end)
end


function M:initUI()
    self.title:SetText(Lang:toText("win.entity.path.select.title"))
    self.upDepict:SetText(Lang:toText("win.entity.path.select.up.depict"))
    self.upShow:SetText(Lang:toText("win.entity.path.select.up.show"))
    self.upManor:SetText(Lang:toText("win.entity.path.select.up.explain"))
    self.upExplain:SetText(Lang:toText("win.entity.path.select.up.manor"))
    self.midDepict:SetText(Lang:toText("win.entity.path.select.down.depict"))
    self.midShow:SetText(Lang:toText("win.entity.path.select.down.show"))

    
    self.downDepict:SetText(Lang:toText("win.entity.path.select.stand"))
    self.downShow:SetText(Lang:toText("win.entity.path.select.still"))

    if World.LangPrefix ~= "zh" then
        self.slider:SetArea({0, 136}, {0, 125}, {0, 352}, {0, 30})
        self.showSliderNum:SetArea({0, 512}, {0, 125}, {0, 50}, {0, 22})
        self.upExplain:SetArea({0, 75}, {0, 167}, {0, 223}, {0, 22})
        self.midLine:SetArea({0, 62}, {0, 20}, {0, 642}, {0, 3})
    end
end

function M:setAiRadiusNum()
    local value = math.modf(self.slider:GetProgress()/0.1)
    manorRadius = value
    self.showSliderNum:SetText(value)
    entity_obj:Cmd("saveAiRadius", self._entityId, manorRadius)
end

function M:setMode(aiMode, manorRadius, isSavePath)
    assert(aiMode)
    self.manorMode:SetSelected(aiMode == 0 and not isShop)
    self.fixedMode:SetSelected(aiMode == 1 and not isShop)
    self.staticMode:SetSelected(aiMode == 2 or isShop)
    self.setPathBtn:SetEnabled(aiMode == 1 and not isShop)
	self.slider:SetEnabled(aiMode == 0 and not isShop)
    self.slider:SetProgress(manorRadius / 10)
    self.showSliderNum:SetText(manorRadius)
    if aiMode == 0 and not isShop then
        entity_obj:Cmd("setRouteModle", self._entityId, "patrolRadius", manorRadius)
        self.setPathBtn:SetNormalImage("set:map_edit_setEntityPath.json image:button_unable")
        self.setPathBtn:SetPushedImage("set:map_edit_setEntityPath.json image:button_unable")
        self.slider:SetHeaderImage("set:map_edit_setEntityPath.json image:install_Slider1")
        self.slider:SetBackImage("set:map_edit_setEntityPath.json image:install_Slider_bg")
        self.slider:SetProgressImage("set:map_edit_setEntityPath.json image:install_Slider_level")
        self.setPathBtn:SetArea({0, 136}, {0, 120}, {0, 200}, {0, 48})
        self.setPathBtnText:SetText(Lang:toText("win.entity.path.select.route.setting"))
        self.setPathBtnText:SetArea({0, 0}, {0, -2}, {1, 0}, {1, 0})
    elseif aiMode == 1 and not isShop then
        self.setPathBtn:SetNormalImage("set:map_edit_setEntityPath.json image:button_nor")
        self.setPathBtn:SetPushedImage("set:map_edit_setEntityPath.json image:button_act")
        self.slider:SetHeaderImage("set:map_edit_setEntityPath.json image:install_Slider1_unable")
        self.slider:SetBackImage("set:map_edit_setEntityPath.json image:install_Slider_bg_unable")
        self.slider:SetProgressImage("set:map_edit_setEntityPath.json image:install_Slider_level_unable")
		self.setPathBtnText:SetArea({0, 0}, {0, -2}, {1, 0}, {1, 0})

        local tmpDerive = Lib.copy(entity_obj:getDataById(self._entityId))
        local route = tmpDerive and tmpDerive.tmpAiData and tmpDerive.tmpAiData.route or {}
        entity_obj:Cmd("setRouteModle", self._entityId, "fixedRoute")
        if isSavePath==1 then
            self.setPathBtnText:SetText(Lang:toText("win.entity.path.select.adjustment.route"))
            self.setPathBtn:SetNormalImage("set:map_edit_setEntityPath.json image:button_nor")
            self.setPathBtn:SetPushedImage("set:map_edit_setEntityPath.json image:button_act")
            if World.Lang == "zh_CN" then
                self.setPathBtn:SetArea({0, 136}, {0, 120}, {0, 166}, {0, 48})
            else
                self.setPathBtn:SetArea({0, 136}, {0, 120}, {0, 250}, {0, 48})
            end
        end
    elseif aiMode == 2 or isShop then
        self.setPathBtn:SetNormalImage("set:map_edit_setEntityPath.json image:button_unable")
        self.setPathBtn:SetPushedImage("set:map_edit_setEntityPath.json image:button_unable")
        self.setPathBtn:SetArea({0, 136}, {0, 120}, {0, 200}, {0, 48})
        self.setPathBtnText:SetText(Lang:toText("win.entity.path.select.route.setting"))
        self.setPathBtnText:SetArea({0, 0}, {0, -2}, {1, 0}, {1, 0})
        self.slider:SetHeaderImage("set:map_edit_setEntityPath.json image:install_Slider1_unable")
        self.slider:SetBackImage("set:map_edit_setEntityPath.json image:install_Slider_bg_unable")
        self.slider:SetProgressImage("set:map_edit_setEntityPath.json image:install_Slider_level_unable")
        entity_obj:Cmd("setRouteModle", self._entityId, "stand")
    end
end

function M:closePathWnd()
    UI:closeWnd(self)
	local pos = entity_obj:getPosById(self._entityId)
    Lib.emitEvent(Event.EVENT_ENTITY_SETTING, self._entityId, pos)
end

function M:onOpen(id)
    self._entityId = id
    local aiMode = entity_obj:Cmd("getPathMode", self._entityId)
    local fullName = entity_obj:getCfgById(id)
    local merchantGroup = global_setting:getMerchantGroup()
    local groupName = entitySetting:getCfg(fullName).shopGroupName
    if merchantGroup[groupName] then
        aiMode = 2
        isShop = true
    else
        if isShop then
            aiMode = 0
        end
        isShop = false
    end
    manorRadius = entity_obj:Cmd("getAiRadius", self._entityId)
    self:setMode(aiMode, manorRadius, aiMode)
    Lib.emitEvent(Event. EVENT_OPEN_INVENTORY, false)
end

function M:onClose()
    Lib.emitEvent(Event. EVENT_OPEN_INVENTORY, true)
end

function M:onReload(reloadArg)

end
