---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by wangpq.
--- DateTime: 2020/5/27 17:16
---
---@class UISubAnimationTextAlpha : UISubAnimation
local UISubAnimationTextAlpha = Lib.class("UISubAnimationTextAlpha", require "ui.ui_animation.ui_subAnimation")

function UISubAnimationTextAlpha:onPlay()
    self.alphaStart = tonumber(self.config.alphaStart)
    self.alphaEnd = tonumber(self.config.alphaEnd)
    self.alpha = self.alphaStart
    self.alphaDelta = (self.alphaEnd - self.alphaStart) / self.ticks
end

function UISubAnimationTextAlpha:onUpdate()
    if self.tick == self.ticks then
        self.alpha = self.alphaEnd
    else
        self.alpha = self.alpha + self.alphaDelta
    end

    self.window:SetAlpha(self.alpha)

    --Lib.logDebug("UISubAnimationTextAlpha:onUpdate ", self.alpha)
end

function UISubAnimationTextAlpha:onDestroy()
    --TODO
end

return UISubAnimationTextAlpha