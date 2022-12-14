---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by 10184.
--- DateTime: 2021/1/4 20:46
---
---@class FlyTipsHelper
local FlyTipsHelper = T(Lib, "FlyTipsHelper")
local cjson = require("cjson")

function FlyTipsHelper:init()
    self.tipsItemWait = {}       -- item等待队列
    self.tipsItemMsg = {}       -- item当前显示队列
    self.tipsItemCache = {}     -- item节点缓存
    self.sameTipsCDList = {}     -- 同一条tips的提示CD
    self:stopUpdateItemList()
end

function FlyTipsHelper:stopUpdateItemList()
    if self.updateTimer then
        self.updateTimer()
        self.updateTimer = nil
    end
    self.curTimeCounts = 0
end

function FlyTipsHelper:pushOneFlyTipsItem(itemInfo)
    local codeStr = cjson.encode(itemInfo)
    if self.sameTipsCDList[codeStr] then
        local flyTipsSetting = World.cfg.fly_tipsSetting or {}
        if os.time() - self.sameTipsCDList[codeStr] < (flyTipsSetting.sameTipsCDTime or 0) then
            return
        end
    end
    self.sameTipsCDList[codeStr] = os.time()
    table.insert(self.tipsItemWait, itemInfo)

    if not self.updateTimer then
        self:startUpdateItemList()
    end
end

function FlyTipsHelper:startUpdateItemList()
    if not self.updateTimer then
        local flyTipsSetting = World.cfg.fly_tipsSetting or {}
        local ticks = flyTipsSetting.tipsFresh or 2
        self.updateTimer = World.LightTimer("FlyTipsHelper:startUpdateItemList", ticks, function()
            self:updateItemListShow()
            return true
        end)
    end
end

function FlyTipsHelper:updateItemListShow()
    local flyTipsSetting = World.cfg.fly_tipsSetting or {}
    self.curTimeCounts = self.curTimeCounts + 1
    for k, val in pairs(self.tipsItemMsg)  do
        if k == 1 then
            local lastPosY = self.tipsItemMsg[k]:invoke("getItemYPosition")
            if lastPosY > flyTipsSetting.minPosY then
                local newPosY = lastPosY - flyTipsSetting.oneTimeDistance
                self.tipsItemMsg[k]:invoke("setItemYPosition", newPosY)
                local startActionTime = self.tipsItemMsg[k]:invoke("getStartActionTime")
                if startActionTime <= 0 then
                    self.tipsItemMsg[k]:invoke("setStartActionTime", self.curTimeCounts)
                end
            end
        elseif k > 1 then
            local lastPosY = self.tipsItemMsg[k]:invoke("getItemYPosition")
            local prePosY = self.tipsItemMsg[k-1]:invoke("getItemYPosition")
            if lastPosY -  flyTipsSetting.oneTimeDistance - flyTipsSetting.minDistance > prePosY then
                local newPosY = lastPosY - flyTipsSetting.oneTimeDistance
                self.tipsItemMsg[k]:invoke("setItemYPosition", newPosY)
                local startActionTime = self.tipsItemMsg[k]:invoke("getStartActionTime")
                if startActionTime <= 0 then
                    self.tipsItemMsg[k]:invoke("setStartActionTime", self.curTimeCounts)
                end
            end
        end
        local startActionTime = self.tipsItemMsg[k]:invoke("getStartActionTime")
        if startActionTime > 0 then
            local passTime = self.curTimeCounts - startActionTime
            if passTime > flyTipsSetting.oneShowTime + flyTipsSetting.oneHideTime then
                self.tipsItemMsg[k]:invoke("updateAllNodeAlpha", 0)
                self:deleteOneTipsItem(k)
            elseif passTime > flyTipsSetting.oneShowTime then
                local alpha = (1-((passTime-flyTipsSetting.oneShowTime)/flyTipsSetting.oneHideTime))
                self.tipsItemMsg[k]:invoke("updateAllNodeAlpha", alpha)
            else
                self.tipsItemMsg[k]:invoke("updateAllNodeAlpha", 1)
            end
        end
    end

    -- 创建一条新的tips
    if #self.tipsItemWait > 0 then
        local curNum = #self.tipsItemMsg
        if curNum > 0 and curNum < flyTipsSetting.maxCount then
            local prePosY = self.tipsItemMsg[curNum]:invoke("getItemYPosition")
            if flyTipsSetting.initPosY - flyTipsSetting.minDistance > prePosY then
                self:addOneTipsItemShow(self.tipsItemWait[1])
                table.remove(self.tipsItemWait, 1)
            end
        elseif curNum == 0 then
            self:addOneTipsItemShow(self.tipsItemWait[1])
            table.remove(self.tipsItemWait, 1)
        end
    end

    if #self.tipsItemWait <= 0 and #self.tipsItemMsg <=0 then
        self:stopUpdateItemList()
        return
    end
end

function FlyTipsHelper:addOneTipsItemShow(itemInfo)
    local newTipItem
    if #self.tipsItemCache > 0 then
        newTipItem = table.remove(self.tipsItemCache, 1)
        table.insert(self.tipsItemMsg, newTipItem)
    else
        newTipItem = UIMgr:new_widget("flyTips")
        table.insert(self.tipsItemMsg, newTipItem)

        local desktop = GUISystem.instance:GetRootWindow()
        desktop:AddChildWindow(newTipItem)
        newTipItem:SetLevel(2)
    end
    newTipItem:invoke("initItemData", itemInfo)
    newTipItem:invoke("setCreateTime", self.curTimeCounts)
    newTipItem:invoke("setStartActionTime", 0)
end

function FlyTipsHelper:deleteOneTipsItem(deleteKey)
    if #self.tipsItemWait > 0 then
        local cacheTipItem = table.remove(self.tipsItemMsg, deleteKey)
        table.insert(self.tipsItemCache, cacheTipItem)
    else
        local cacheTipItem = table.remove(self.tipsItemMsg, deleteKey)
        GUIWindowManager.instance:DestroyGUIWindow(cacheTipItem)
    end
end

FlyTipsHelper:init()