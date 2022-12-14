---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by 10184.
--- DateTime: 2020/11/16 11:09
---
local BlindBoxRewardConfig = T(Config, "BlindBoxRewardConfig") ---@type BlindBoxRewardConfig

function M:init()
    WinBase.init(self, "BlindBoxRewardList.json")
    self:initWnd()
    self:initEvent()
end

function M:initWnd()
    self.tvTitle = self:child("BlindBoxRewardList-Title")
    self.ivClose = self:child("BlindBoxRewardList-Close")
    local llRewards = self:child("BlindBoxRewardList-Rewards")
    self.lvGroupList = UIMgr:new_widget("list_view", llRewards)
    self.lvGroupList:invoke("ITEM_SPACE", 12)
    self.btnBackClose = self:child("BlindBoxRewardList-Back-Close")
    self.wFloatReward = UIMgr:new_widget("commonActivityRewardFloat"):invoke("get")
    self:root():AddChildWindow(self.wFloatReward:root())
end

function M:initEvent()
    self:subscribe(self.ivClose, UIEvent.EventWindowClick, function()
        UI:closeWnd("blindBoxRewardList")
    end)
    self:subscribe(self.btnBackClose, UIEvent.EventButtonClick, function()
        UI:closeWnd("blindBoxRewardList")
    end)
end

function M:isShowAnim()
    return false
end

function M:showBlindBoxRewards(boxId)
    self.lvGroupList:invoke("CLEAN")
    local list = BlindBoxRewardConfig:getRewardListByBlindBoxId(boxId)
    local delay = 0
    local lotteryCount = 0
    for _, group in pairs(list) do
        if group.rewardGroup then
            lotteryCount = lotteryCount + group.lotteryCount
            local item = UIMgr:new_widget("blindBoxRewardGroup")
            item:invoke("setWidth",{ 1, 0 })
            item:invoke("onDataChanged", group, delay)
            self.lvGroupList:invoke("ITEM", item)
            delay = delay + #group.rewardGroup * 50
        end
    end
    self.tvTitle:SetText(string.format(Lang:getMessage("blind.box.reward.list.title"), tostring(lotteryCount)))
    UI:openWnd("blindBoxRewardList")
end

function M:onClose()
    self.lvGroupList:invoke("CLEAN")
    self.wFloatReward:hide()
end

function M:clickItem(item)
    self.wFloatReward:showReward(item.reward, item:root())
end
