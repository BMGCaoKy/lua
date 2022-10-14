local cmd = require "editor.cmd"
local entity_obj = require "editor.entity_obj"

function M:init()
    WinBase.init(self, "entitySetting_tips_edit.json")

    self.sureBtn = self:child("Entity-Tips-Frame-Sure")
   
    self:child("Entity-Tips-Frame-Context1"):SetVisible(false)
    self:child("Entity-Tips-Frame-Sure-Text"):SetText(Lang:toText("win.map.edit.entity.setting.fetch.delete"))
    self:child("Entity-Tips-Frame-Cancel-Text"):SetText(Lang:toText("gui_menu_exit_game_cancel"))
    self:child("Entity-Tips-Frame-Title"):SetText(Lang:toText("composition.replenish.title"))
    self.sureBtn:SetNormalImage("set:map_edit_BuildingTool.json image:but_red_pop_nor")
    self.sureBtn:SetPushedImage("set:map_edit_BuildingTool.json image:but_red_pop_act")
    self:child("Entity-Tips-Frame-Bg"):SetImage("set:map_edit_BuildingTool.json image:delete_tips_bg")


    self:subscribe(self.sureBtn, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
		cmd:del_entity(self._entityId)
        UI:closeWnd("mapEditEntitySetting")  --todo
    end)
    self:child("Entity-Tips-Frame-Cancel"):setBelongWhitelist(true)
    self:subscribe(self:child("Entity-Tips-Frame-Cancel"), UIEvent.EventButtonClick, function()
        self:closeTipsWnd()
    end)

    self:subscribe(self:child("Entity-Tips-Bg"), UIEvent.EventWindowClick, function()
       self:closeTipsWnd()
    end)

end

function M:closeTipsWnd()
    UI:closeWnd(self)
	local pos = entity_obj:getPosById(self._entityId)
    Lib.emitEvent(Event.EVENT_ENTITY_SETTING, self._entityId, pos)
end

function M:onOpen(id)
	self._entityId = id
	local entityType = entity_obj:Cmd("getType", id)
	local tips = "win.map.edit.entity.setting.delete"
	self:child("Entity-Tips-Frame-Context"):SetText(Lang:toText(tips))
end

function M:onClose()

end

function M:onReload(reloadArg)

end
function M:onReload(reloadArg)

end

return M