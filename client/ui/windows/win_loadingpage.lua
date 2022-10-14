---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by work.
--- DateTime: 2018/8/29 17:15
---
function M:init()
    WinBase.init(self, "LoadingPage.json", true)
    self:child("LoadingPage-Loading"):SetVisible(true)
    self:child("LoadingPage-LoadingTip"):SetVisible(true)
    self:child("LoadingPage-Loading-Failure"):SetVisible(false)
    self.m_button_close = self:child("LoadingPage-Button-close")
    self.m_button_close:SetText(Lang:toText("gui.exit.game"))
    self:subscribe(self.m_button_close, UIEvent.EventButtonClick, function()
        self:exitGame()
    end)
end

function M:sendgameover(msg)
    if msg then
        return
    end
    self:child("LoadingPage-Loading"):SetVisible(false)
    self:child("LoadingPage-LoadingTip"):SetVisible(false)
    self:child("LoadingPage-Loading-Failure"):SetVisible(true)
    self:child("LoadingPage-Msg-Failure"):SetText(tostring(msg))
	self.reloadArg = table.pack(msg)
end

function M:exitGame()
    CGame.instance:exitGame("offline")
end

function M:onReload(reloadArg)
	local msg = table.unpack(reloadArg or {}, 1, reloadArg and reloadArg.n)
	self:sendgameover(msg)
end

return M