
function M:init()
    WinBase.init(self, "Reload.json")

    Lib.lightSubscribeEvent("error!!!!! script_client win_reload Lib event : EVENT_SHOW_RELOAD_PROGRESS",Event.EVENT_SHOW_RELOAD_PROGRESS, function(packet)
        if not self.image then
            self.image = self:child("Reload-Image")
            self.image:setProgram("CLOCK")
        end
        local cfg = packet.cfg
        local size = self.image:GetPixelSize()
        local function finish()
            self.image:SetVisible(false)
            self.image:setSectorBar(0, 0.5 * size.x, 0.5 * size.y)
            if self.reloadTimer then
                self.reloadTimer()
                self.reloadTimer = nil
            end
        end
        finish()
        local reloadTime = cfg.reloadTime or 20
        if reloadTime <= 0 then
            return
        end
        if packet.method ~= "Cancel" then
            self.image:SetVisible(true)
            local pro = cfg.progress or {}
            self.image:SetImage(pro.image or "")
            local w = pro.size and pro.size[1] or 50
            local h = pro.size and pro.size[2] or 50
            self.image:SetWidth({0, w})
            self.image:SetHeight({0, h})
            local progress = 0
            local update = 1 / reloadTime
            self.reloadTimer = World.Timer(1, function()
                progress = progress + update
                self.image:setSectorBar(progress, 0.5 * size.x, 0.5 * size.y)
                if progress >= 1 then
                    finish()
                end
                return progress < 1
            end)
        end
    end)

end

return M