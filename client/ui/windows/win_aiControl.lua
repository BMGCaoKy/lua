local cmd = require "editor.cmd"
local entity_obj = require "editor.entity_obj"
local data_state = require "editor.dataState"
local network_mgr = require "network_mgr"
local bm = Blockman.Instance()
local player_pos = nil
local player_yaw = nil
local player_pitch = nil

local tipWin = nil

local function backToEditor()
    local mainPlayer = bm:getEditorPlayer()
    Player.CurPlayer = mainPlayer
    bm:setMainPlayer(mainPlayer)
    Player.CurPlayer:setPosition(player_pos)
    Player.CurPlayer:setRotationYaw(player_yaw)
    Player.CurPlayer:setRotationPitch(player_pitch)
end

function M:changeCamera()
	local bm = Blockman.instance
	local cameraInfo = bm:getCameraInfo(4)
	local saveCameraData = {
		curInfo = cameraInfo.curInfo,
		viewCfg = cameraInfo.viewCfg,
	}
	local viewCfg = {
		enable = true,
		distance =  10,
		lockBodyRotation = false
	}
	bm:setPersonView(4)
	if viewCfg then
		bm:changeCameraCfg(viewCfg, 4)
	end

	return function()
		local personView = bm:getCurrPersonView()
		bm:changeCameraCfg(saveCameraData.viewCfg, personView)
		bm:setPersonView(saveCameraData.curInfo.curPersonView)
	end
end

function M:registerUiEvent()
    self:subscribe(self.btnClose, UIEvent.EventButtonClick, function()
        --CGame.instance:onEditorDataReport("click_route_close", "")
		--UI:closeWnd(self)
--        self.tips:SetVisible(true)
    end)

    self:subscribe(self.tipsExitBtn, UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
    end)

    self:subscribe(self.tipsCancelBtn, UIEvent.EventButtonClick, function()
        self.tips:SetVisible(false)
    end)

    
    self:subscribe(self:child("aiControl-ExitTips-Mask"), UIEvent.EventWindowClick, function()
        self.tips:SetVisible(false)
    end)

    self:subscribe(self.btnSet, UIEvent.EventButtonClick, function()
        CGame.instance:onEditorDataReport("click_route_sure", "")
        CGame.instance:onEditorDataReport("click_route_save", "")
        self:setRoute()
        
    end)
    self:subscribe(self.btnBack, UIEvent.EventButtonClick, function()
        CGame.instance:onEditorDataReport("click_route_back", "")
        self:backRoute()
    end)

    self:subscribe(self.btnExit, UIEvent.EventButtonClick, function()
        --UI:closeWnd(self)
        self.tips:SetVisible(true)
    end)

end

function M:transferControl(entity)
    Lib.emitEvent(Event.EVENT_ENTITY_CONTROL, entity)    
end

function M:registerLibEvent()
    if not self.allLibEvent then
        self.allLibEvent = {}
    end
    self.allLibEvent[#self.allLibEvent + 1] = Lib.subscribeEvent(Event.EVENT_CREATE_ROUNTE, function(pos)
        pos.y = pos.y + 1
        local entity = self:drawOneRoute(pos)
        self:setCreateRounteStatus(false)
        self:transferControl(entity)
    end)
    
end

function M:initUiName()
    self.btnClose = self:child("aiControl-btnclose")
    self.controlGroup = self:child("aiControl-control")
    self.btnBack = self:child("aiControl-back")
    self.btnSet = self:child("aiControl-set")
    self.btnExit = self:child("aiControl-Exit")
    self.text = self:child("aiControl-text")
    self.textBG = self:child("aiControl-Iconbg")
    self.tips = self:child("aiControl-ExitTips")
    self.tipsExitBtn = self:child("aiControl-ExitTips-Sure")
    self.tipsCancelBtn = self:child("aiControl-ExitTips-Cancel")
end

function M:init()
    WinBase.init(self, "aiControl_edit.json")
    self:root():setBelongWhitelist(true)
    self:initUiName()
    self:registerUiEvent()
    self.text:SetText(Lang:toText("Win_AiControl_tips"))
    local width =  self.text:GetFont():GetTextExtent(Lang:toText("Win_AiControl_tips"),1.0)
    self.text:SetWidth({0 , width})
    self.textBG:SetWidth({0 , width + 150})
    self:child("aiControl-ExitTips-Title"):SetText(Lang:toText("composition.replenish.title"))
    self:child("aiControl-ExitTips-Context"):SetText(Lang:toText("Edit_EntitySetting_tip_exit_context"))
    self:child("aiControl-ExitTips-Context_0"):SetText(Lang:toText("Edit_EntitySetting_tip_exit_secondLevelText"))
    self:child("aiControl-ExitTips-Sure-Text"):SetText(Lang:toText("stage_exit"))
    self:child("aiControl-ExitTips-Cancel-Text"):SetText(Lang:toText("gui_menu_exit_game_cancel"))
end

function M:pushRoute(route)
    self.routes[#self.routes + 1] = route
end

function M:popRoute()
    return table.remove(self.routes)
end

function M:getRoute(index)
    return self.routes[index]
end

function M:getLastRoute()
    return self.routes[#self.routes]
end

function M:getRouteCount()
    return #self.routes
end

function M:getAllRoutePos()
    local result = {}
    for _, route in pairs(self.routes or {}) do
        table.insert(result, route:getPosition())
    end
    return result
end

function M:drawOneRoute(pos, fristFlag, lastFlag)
    local fullName = entity_obj:getCfgById(self.entityId)
    local newPos = Lib.copy(pos)
    newPos.y = 255
    local route = EntityClient.CreateClientEntity({
        cfgName = fristFlag and "myplugin/door_entity" or fullName,
        pos = newPos
    })
    
    local data = self.deriveData.fillBlock
    if data and not fristFlag then
        route:SetEntityToBlock(data)
    end
    if self.last_route then
        self.last_route:setRenderBox(false)
    end
    if not fristFlag then
        route:setRenderBox(true)
        self.last_route = route
    end
    World.Timer(1, function()
        route:setPosition(pos)
    end)
    self:pushRoute(route)
    if #self.routes > 1 then
        local fromRoute = self.routes[#self.routes - 1]
        fromRoute:setGuide2Target(route)
        fromRoute:setGuide2LineSpeed(0.002)
        fromRoute:setGuideLineTexture("guide_arrow1.png")
        self.routes[#self.routes - 1]:setDrawGuide(true)
    end
    self:updateRouteTexture()
    return route
end

function M:updateRouteTexture()
    local routeCount = #self.routes 
    for i = 1, routeCount - 2 do
        local fromRoute = self.routes[i]
        fromRoute:setGuideLineTexture("guide_arrow1.png")
    end
    if routeCount >= 2 then
        local fromRoute = self.routes[routeCount - 1]
        fromRoute:setGuideLineTexture("guide_arrow.png")
    end
end

function M:drawAllRoute()
    local entity = entity_obj:getEntityById(self.entityId)
    local fristPos = entity:getPosition()
    local aiData = self.deriveData.tmpAiData
    if not aiData then
        aiData = {}
        self.deriveData.tmpAiData = aiData 
    end
    if not aiData.route  then
        aiData.route = {}
    end

    if #aiData.route < 1 then
        self:drawOneRoute(fristPos, true)
        Lib.emitEvent(Event.EVENT_CREATE_ROUNTE, {
            x = fristPos.x + 1,
            y = fristPos.y - 1,
            z = fristPos.z
        })
    end
    for index, point in ipairs(aiData.route) do
        self:drawOneRoute(point, index == 1)
    end
end

function M:setCreateRounteStatus(flag)
    data_state.setAiRoute = flag --设置路点状态
    self.btnClose:SetVisible(flag)
    self.controlGroup:SetVisible(not flag)
end

function M:checkCanClickCreateRoute(isBack)
    -- 点击屏幕可以创建一个路点的情况
    if self:getRouteCount() <= 1 then
        self:setCreateRounteStatus(true)
        return
    end
    self:setCreateRounteStatus(false)
    -- 按照上一个路点的位置创建出下一个路点出来
    if isBack then
        self.btnBack:SetVisible(self:getRouteCount() > 2)
        return
    end
    local routeArray = self.deriveData.tmpAiData.route
    if #routeArray <= 1 then
        self.btnBack:SetVisible(false)
        return
    end
    if isBack then
        return
    end
    local routeCount = self:getRouteCount()
    local disV = Lib.v3cut(routeArray[routeCount], routeArray[routeCount - 1])
    local dir = Lib.v3normalize(disV)
    local newTargetPos = Lib.v3add(routeArray[routeCount], Lib.v3multip(dir, 3))
    local entity = self:drawOneRoute(newTargetPos)
    World.Timer(2, function()
        self:transferControl(entity)
    end)
    self.btnBack:SetVisible(true)
end

function M:backRoute()
    if self:getRouteCount() <= 1 then
        return
    end
    local route = self:popRoute()
    if self:getRouteCount() > 1 then
        self:transferControl(self:getLastRoute())
        self.routes[#self.routes]:setDrawGuide(false)
        self.routes[#self.routes]:setRenderBox(true)
        self.last_route = nil
    else
        backToEditor()
        self:saveRoute()
    end

    World.Timer(1, function()
        route:destroy()
        return false
    end)
    local routeData = self.deriveData.tmpAiData.route
    table.remove(routeData)
    self:checkCanClickCreateRoute(true)
    self:saveRoute()
    self:updateRouteTexture()
end
   
function M:setRoute()
    local data = self.deriveData.tmpAiData
    local allRoutePos = self:getAllRoutePos()
    data.route = allRoutePos
    local routeCount = self:getRouteCount()
    self.routes[#self.routes]:setRenderBox(false)
    self:checkCanClickCreateRoute()
    self:saveRoute()
end

function M:saveRoute()
    local route = self.deriveData.tmpAiData.route
    if #route <= 1 then
        route = nil
    end
    entity_obj:deriveSetData(self.entityId, "aiData", {
        route = route 
    })
    local tmpAiData =  self.deriveData.tmpAiData
    if tmpAiData and tmpAiData.route and #tmpAiData.route <= 1 then
        tmpAiData.route = nil
    end
    entity_obj:deriveSetData(self.entityId, "tmpAiData", self.deriveData.tmpAiData)
    -- UI:closeWnd(self)
end

function M:openPathRemind()
    if not tipWin then
            tipWin = GUIWindowManager.instance:LoadWindowFromJSON("entitySettingCrlTip_edit.json")

            local function CloseTipsWnd()
                if not Clientsetting.isKeyGuide("isPathRemind") then
                    local retry = 1
                    World.Timer(5, function() 
                        local respone = network_mgr:set_client_cache("isPathRemind", "1")
                        if respone.ok or retry > 2 then
							if respone.ok then
								Clientsetting.setGuideInfo("isPathRemind", false)
							end
                            return false
                        end
                        retry = retry + 1
                        return true
                    end)
                end
                self:root():RemoveChildWindow1(tipWin)
            end

            local title = tipWin:child("Entity-Ctr-Frame-Title")
            local context =  tipWin:child("Entity-Ctr-Frame-Context")
            local image = tipWin:child("Entity-Ctr-Tips-Frame-Demo")
            local warning = tipWin:child("Entity-Ctr-Tips-Frame-Warning")
            local click = tipWin:child("Entity-Ctr-Tips-Frame-Click")

            warning:SetText(Lang:toText("EntitySetting_crl_tip_choiceText"))
            context:SetFontSize("HT18")
            context:SetText(Lang:toText("win.ai.control.remind.text"))
            title:SetText(Lang:toText("win.ai.control.remind.title"))
            image:SetImage("set:map_edit_aiControlImageTips.json image:set_path_image_tips")
            image:SetArea({0, 0}, {0.41, 0}, {0, 641}, {0, 169})
            if World.LangPrefix ~= "zh" then
                warning:SetArea({0.7, 0}, {0.857778, 0}, {0, 76}, {0, 24})
                click:SetArea({0.64, 0}, {0.83, 0}, {0, 270}, {0, 50})
            end

            local isPathRemind = false
            self:subscribe(click, UIEvent.EventWindowClick, function()
                if isPathRemind == false then
                    tipWin:child("Entity-Ctr-Tips-Frame-Select"):SetChecked(true)
                    isPathRemind = true
                else
                    tipWin:child("Entity-Ctr-Tips-Frame-Select"):SetChecked(false)
                    isPathRemind = false
                end
				Clientsetting.setlocalGuideInfo("isPathRemind", not isPathRemind)
            end)

            self:subscribe(tipWin:child("Entity-Ctr-Close"), UIEvent.EventButtonClick, function()
                CloseTipsWnd()
            end)

            self:subscribe(tipWin:child("Entity-Ctr-BG"), UIEvent.EventWindowClick, function()
                CloseTipsWnd()
            end)
        end
        self:root():AddChildWindow(tipWin)
end

function M:setPlayerYPos(yIncrement)
	local player = Player.CurPlayer
	local pos = player:getPosition()
	pos.y = pos.y + (yIncrement)
	player:setPosition(pos)
end

function M:onOpen(id)
    EditorModule:emitEvent("enterEntityPosSetting")
	-- Blockman.instance.gameSettings.cameraYaw = Blockman.instance:viewerRenderYaw()
	-- Blockman.instance.gameSettings.cameraPitch = Blockman.instance:viewerRenderPitch() + Blockman.instance.gameSettings.cameraPitchCompensate
	-- Blockman.instance:setPersonView(World.cfg.viewMode)
	self.recoCamera = self:changeCamera()
	self:setPlayerYPos(-6)
    player_pos = Player.CurPlayer:getPosition()
    player_yaw = Player.CurPlayer:getRotationYaw()
    player_pitch = Player.CurPlayer:getRotationPitch() 
    self.last_can_place = data_state.is_can_place 
    data_state.is_can_place = false
    self.routes = {}
    self:registerLibEvent()
    self.entityId = id
    self.aiMode = entity_obj:Cmd("getPathMode", self.entityId)
    self.last_route = nil
    self.deriveData = Lib.copy(entity_obj:getDataById(id))
    self.aiData = nil
    self:drawAllRoute()
    self:checkCanClickCreateRoute()
    Lib.emitEvent(Event.EVENT_OPEN_INVENTORY, false)
    UI:closeWnd("mapEditToolbar")
    
    if Clientsetting.isKeyGuide("isPathRemind") then
        self:openPathRemind()
    else
        tipWin = nil
    end
    self.tips:SetVisible(false)
end

function M:onClose()
    entity_obj:Cmd("setRouteModle", self.entityId, self.aiMode)
    data_state.is_can_place = self.last_can_place
    Lib.emitEvent(Event.EVENT_OPEN_EDIT_MAIN)
    data_state.setAiRoute = false
    for _, event in pairs(self.allLibEvent or {}) do
        event()
    end
    backToEditor()
    self:clearRoutes()
	local pos = entity_obj:getPosById(self.entityId)
	-- Blockman.instance:setPersonView(World.cfg.editrovViewMode or World.cfg.viewMode)
	self:setPlayerYPos(6)
	Lib.emitEvent(Event.EVENT_ENTITY_SETTING, self.entityId, pos)
    self.recoCamera()
    EditorModule:emitEvent("leaveEntityPosSetting")
end

function M:clearRoutes()
    for _, route in pairs(self.routes) do
        route:destroy()
    end
end

function M:onReload(reloadArg)

end
