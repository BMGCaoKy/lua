---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by wangpq.
--- DateTime: 2020/5/27 17:51
---
---@class UISubAnimationTextScale : UISubAnimation
local UISubAnimationTextScale = Lib.class("UISubAnimationTextScale", require "ui.ui_animation.ui_subAnimation")

function UISubAnimationTextScale:onPlay()
    self.scaleStart = tonumber(self.config.scaleStart)
    self.scaleEnd = tonumber(self.config.scaleEnd)
    self.scale = self.scaleStart
    self.scaleDelta = (self.scaleEnd - self.scaleStart) / self.ticks
end

function UISubAnimationTextScale:onUpdate()
    if self.tick == self.ticks then
        self.scale = self.scaleEnd
    else
        self.scale = self.scale + self.scaleDelta
    end

    self.window:SetScale({ x = self.scale, y = self.scale, z = self.scale })

    --Lib.logDebug("UISubAnimationTextScale:onUpdate ", self.scale)
end

function UISubAnimationTextScale:onDestroy()
    --TODO
end

return UISubAnimationTextScale