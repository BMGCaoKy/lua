local engine = require "editor.engine"
local myGamePath = CGame.instance:getMyGamePath()
function M:init()
    WinBase.init(self, "mainTip_edit.json")

    self:child("Edit-Main-Tip-Dlg-Tips"):SetText(Lang:toText("win.map.edit.main.tip.tips"))
    self:child("Edit-Main-Tip-Dlg-Save-Text"):SetText(Lang:toText("win.map.edit.main.tip.tips.save"))
    self:child("Edit-Main-Tip-Dlg-Cancel-Text"):SetText(Lang:toText("win.map.main.tips.cancel.btn"))
    self:child("Edit-Main-Tip-Dlg-Title"):SetText(Lang:toText("composition.replenish.title"))
   
	self:subscribe(self:child("Edit-Main-Tip-Close"), UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
    end)

    self:subscribe(self:child("Edit-Main-Tip-Bg"), UIEvent.EventWindowClick, function()
        UI:closeWnd(self)
    end)

	self:subscribe(self:child("Edit-Main-Tip-Dlg-Save"), UIEvent.EventButtonClick, function()
        handle_mp_editor_command("save_MpMap", {path = ""})
        Lib.emitEvent(Event.EVENT_EDIT_MAP_MAKING)
        local count = 0
        World.Timer(1, function()
             if count > 5 then
                CGame.instance:getShellInterface():killAppProcess()
                return false
             end
             count = count + 1
             return true
        end)	
    end)

	self:subscribe(self:child("Edit-Main-Tip-Dlg-Cancel"), UIEvent.EventButtonClick, function()
		--Lib.emitEvent(Event.EVENT_OPEN_HOME)
        Lib.emitEvent(Event.EVENT_EDIT_MAP_MAKING)
        local count = 0
        World.Timer(1, function()
             if count > 5 then
                CGame.instance:getShellInterface():killAppProcess()
                return false
             end
             count = count + 1
             return true
        end)
    end)

end

function M:onReload(reloadArg)

end

return M