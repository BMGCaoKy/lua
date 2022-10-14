local entity_obj = require "editor.entity_obj"

local function resetPosition(id)
    if not id then
        return
    end
    local pos = entity_obj:getPosById(id)
    local yaw = entity_obj:getYawById(id)
    local pitch = entity_obj:getPitchById(id)
    Player.CurPlayer:setPosition(pos)
    Player.CurPlayer:setRotationYaw(yaw)
    Player.CurPlayer:setRotationPitch(pitch)
	Player.CurPlayer:setBodyYaw(yaw)
end

function M:init()
    WinBase.init(self, "entitySetting_tips_edit.json")

    self.sureBtn = self:child("Entity-Tips-Frame-Sure")
    self.context1 = self:child("Entity-Tips-Frame-Context1")

    self.context1:SetVisible(false)
    self.sureBtn:setBelongWhitelist(true)
    self:child("Entity-Tips-Frame-Sure-Text"):SetText(Lang:toText("win.map.edit.entity.setting.yes"))
    self:child("Entity-Tips-Frame-Cancel-Text"):SetText(Lang:toText("composition.replenish.no.btn"))
    self:child("Entity-Tips-Frame-Title"):SetText(Lang:toText("composition.replenish.title"))

	self:subscribe(self.sureBtn, UIEvent.EventButtonClick, function()
        resetPosition(self._entityId)
        UI:closeWnd(self)
        if self.state == 1 then
           UI:closeWnd("mapEditEntitySettingPos") 
        end
    end)

	self:subscribe(self:child("Entity-Tips-Frame-Cancel"), UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
    end)

    self:subscribe(self:child("Entity-Tips-Bg"), UIEvent.EventWindowClick, function()
        UI:closeWnd(self)
    end)

end

function M:onOpen(id, msg, state,isVisible,secondLevelText)
	self._entityId = id
    self:child("Entity-Tips-Frame-Context"):SetText(msg)
    if msg == Lang:toText("Edit_EntitySetting_tip_back_context") then
        self:child("Entity-Tips-Frame-Sure-Text"):SetText(Lang:toText("win.map.edit.entity.setting.yes"))
        self:child("Entity-Tips-Frame-Bg"):SetImage("set:map_edit_entitySettingTips.json image:popbg_save_edit")
        self.sureBtn:SetNormalImage("set:map_edit_main.json image:but_green_pop_nor")
        self.sureBtn:SetPushedImage("set:map_edit_main.json image:but_green_pop_act")
    end
    if isVisible == false then
        self:child("Entity-Tips-Frame-Context"):SetArea({0, 0}, {0.37, 0}, {0.8, 0}, {0.163934, 0})
    else
        self.sureBtn:SetNormalImage("set:map_edit_BuildingTool.json image:but_red_pop_nor")
        self.sureBtn:SetPushedImage("set:map_edit_BuildingTool.json image:but_red_pop_act")
        self:child("Entity-Tips-Frame-Bg"):SetImage("set:map_edit_BuildingTool.json image:delete_tips_bg")
        self:child("Entity-Tips-Frame-Sure-Text"):SetText(Lang:toText("gui.exit"))
    end
    self.state = state
    self.context1:SetVisible(isVisible)
    self.context1:SetText(secondLevelText)
end

function M:onReload(reloadArg)

end

return M