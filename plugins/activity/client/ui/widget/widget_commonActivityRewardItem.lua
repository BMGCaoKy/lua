---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Administrator.
--- DateTime: 2020/11/18 14:19
---
local LuaTimer = T(Lib, "LuaTimer") ---@type LuaTimer

local widget_base = require "ui.widget.widget_base"
local M = Lib.derive(widget_base)

function M:init(parent)
    widget_base.init(self, "CommonActivityRewardItem.json")
    self.parent = parent
    self:initWnd()
    self:initEvent()
end

function M:initWnd()
    self.llRoot = self:root()
    self.ivIcon = self:child("CommonActivityRewardItem-Icon")
    self.ivBg = self:child("CommonActivityRewardItem-Bg")
    self.ivMask = self:child("CommonActivityRewardItem-Mask")
    self.ivSelect = self:child("CommonActivityRewardItem-Select")
    self.llEffectClip = self:child("CommonActivityRewardItem-Effect-Clip")
    self.ivEffect = self:child("CommonActivityRewardItem-Effect")
    self.ivEffectMask = self:child("CommonActivityRewardItem-Effect-Mask")
    self.tvNum = self:child("CommonActivityRewardItem-Num")
    self.tvName = self:child("CommonActivityRewardItem-Name")

    self.ivMask:SetVisible(false)
    self.ivSelect:SetVisible(false)
    self.ivEffect:SetVisible(false)
end

function M:initEvent()
    self:subscribe(self.llRoot, UIEvent.EventWindowClick, function()
        if self.parent then
            self.parent:clickItem(self)
        end
    end)
end

function M:setRewardData(data,anim)
    self:SetIcon(data)
    if data.needMask then
        self.ivMask:SetImage("set:common_activity.json image:img_iconboard_" .. data.quality .. "_mask")
        self.ivMask:SetVisible(true)
    end
    self.reward = data
    if data.numLang ~= "#" then
        self.tvNum:SetText(Lang:getMessage(data.numLang))
    end

    if data.effect ~= "#" then
        self.ivEffect:SetEffectName(data.effect)
        self.ivEffect:SetVisible(true)
    end
    self.ivBg:SetImage("set:common_activity.json image:img_iconboard_" .. data.quality)
    if anim then
        self:showAnim(data)
    end
end

function M:showAnim(data)
    local scale = 0
    self.ivIcon:SetArea({ 0, 0 }, { 0, 0 }, { scale, 0 }, { scale, 0 })
    self.ivBg:SetArea({ 0, 0 }, { 0, 0 }, { scale, 0 }, { scale, 0 })
    self.ivMask:SetArea({ 0, 0 }, { 0, 0 }, { scale, 0 }, { scale, 0 })
    self.llEffectClip:SetArea({ 0, 0 }, { 0, 0 }, { scale, 0 }, { scale, 0 })
    self:addTimer(LuaTimer:scheduleTimer(function()
        scale = scale + 0.05
        self.ivIcon:SetArea({ 0, 0 }, { 0, 0 }, { math.min(scale, 0.89), 0 }, { math.min(scale, 0.89), 0 })
        self.ivBg:SetArea({ 0, 0 }, { 0, 0 }, { scale, 0 }, { scale, 0 })
        self.ivMask:SetArea({ 0, 0 }, { 0, 0 }, { scale + 0.1, 0 }, { scale + 0.1, 0 })
        self.llEffectClip:SetArea({ 0, 0 }, { 0, 0 }, { scale, 0 }, { scale, 0 })
        self:SetIcon(data)
    end, 8, 20))
end

---播放显示动画并显示特效
function M:setLotteryResult(data)
    if data.effect ~= "#" then
        self.ivEffect:SetEffectName(data.effect)
    end
    if data.needMask then
        self.ivMask:SetImage("set:common_activity.json image:img_iconboard_" .. data.quality .. "_mask")
        self.ivMask:SetVisible(true)
    end
    self.ivEffect:SetVisible(true)
    self:showAnim(data)
    if data.numLang ~= "#" then
        self.tvNum:SetText(Lang:getMessage(data.numLang))
    end
    self.ivBg:SetImage("set:common_activity.json image:img_iconboard_" .. data.quality)
end

---显示幸运值
function M:setLuckyValue(data)
    local scale = 0

    self.tvName:SetText(Lang:getMessage("lucky.lottery.ui.luckyValue"))
    self.tvName:SetArea({ 0, 0 }, { -0.35, 0 }, { 0, 0 }, { 0, 0 })
    self.tvName:SetTextColor({ 255 / 255, 217 / 255, 77 / 255, 1 })
    self.ivBg:SetArea({ 0, 0 }, { 0, 0 }, { scale, 0 }, { scale, 0 })
    self.ivEffect:SetArea({ 0, 0 }, { -(scale / 2), 0 }, { scale, 0 }, { scale, 0 })

    self:addTimer(LuaTimer:scheduleTimer(function()
        self.ivIcon:SetArea({ 0, 0 }, { 0, 0 }, { math.min(scale, 0.9), 0 }, { math.min(scale, 0.9), 0 })
        self.ivBg:SetArea({ 0, 0 }, { 0, 0 }, { scale, 0 }, { scale, 0 })
        self.ivEffectMask:SetArea({ 0, 0 }, { 0, 0 }, { scale, 0 }, { scale, 0 })
        self.ivEffect:SetArea({ 0, 0 }, { -(scale / 2), 0 }, { scale, 0 }, { scale, 0 })
        scale = scale + 0.05
        self:SetIcon(data)
    end, 8, 20))

    if data.numLang ~= "#" then
        self.tvNum:SetText(Lang:getMessage(data.numLang))
    end

    self.ivBg:SetImage("set:common_activity.json image:img_iconboard_" .. data.quality)
end

function M:onSelect(isSelect)
    self.ivSelect:SetVisible(isSelect)
end

function M:SetIcon(data)
    if data.imageScale and data.imageScale ~= "#" then
        UILib:setImageAdjustSize(self.ivIcon, data.image, self.ivIcon:GetPixelSize().x, self.ivIcon:GetPixelSize().y, data.imageScale)
    else
        UILib:setImageAdjustSize(self.ivIcon, data.image)
    end
    if data.imageXOffset ~= "#" then
        self.ivIcon:SetXPosition({ 0, data.imageXOffset })
    end
    if data.imageYOffset ~= "#" then
        self.ivIcon:SetYPosition({ 0, data.imageYOffset })
    end
end

function M:SetEffectMask(image)
    self.ivEffectMask:SetImage(image)
end

return M