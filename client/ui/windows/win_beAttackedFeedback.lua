
function M:init()
    WinBase.init(self, "BeAttackedFeedback.json")
    self.fb_image = self:child("BeAttackFeedback-Image")
end

local function hideFeedbackImage(self)
    if self.alphaTimer then
        self.alphaTimer()
    end
    local cfg = Me:cfg().beAttackedFeedback
    local totalTime = cfg.hideTime or 10
    self.timeLeft = totalTime
    self.alphaTimer = World.Timer(1, function()
        self.timeLeft = self.timeLeft - 1
        if self.timeLeft > 0 then
            if cfg.hideSmooth ~= false then
                self.fb_image:SetAlpha(self.timeLeft/totalTime)
            end
            return true
        else
            self.fb_image:SetAlpha(0)
            self.fb_image:SetVisible(false)
            UI:closeWnd(self)
            return false
        end
    end)
end

function M:updateAttackerDirection(packet)
    local from = World.CurWorld:getEntity(packet.fromId)
    if not from then
        return
    end
    local cfg = Me:cfg().beAttackedFeedback
    if not cfg then
        return
    end
    if cfg.fromPlayer == false and from:isControl() then
        return
    end
    if cfg.fromNpc == false and not from:isControl() then
        return
    end
    local fromPos = from:getPosition()
    local myPos = Me:getPosition()
    local offX = myPos.x - fromPos.x
    local offZ = myPos.z - fromPos.z
    local angle = math.atan(offZ , offX) * 180 / math.pi
    self.fb_image:SetImage(cfg.image or "set:attack_effect.json image:hurt.png")
    self.fb_image:SetVisible(true)
    self.fb_image:SetAlpha(1)
    self.fb_image:SetRotate(angle - Me:getRotationYaw() + 180)
    hideFeedbackImage(self)
end

return M