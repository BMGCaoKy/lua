local setting = require "common.setting"
local globalSetting = require "editor.setting.global_setting"

local MODE_TYPE = {
    GAME_TIME_RANK = "GAME_TIME_RANK",    
    WAR_INFOMATION = "WAR_INFOMATION",    
}

function M:init()
    WinBase.init(self, "victoryShowSetting.json")
    self.gameInfoCheck = self:child("Setting-EndLayout-Check")
    self.gameTimeRank = self:child("Setting-EndLayout-Check_4")
    self:child("Setting-title"):SetText(Lang:toText("lang_game_info"))
    self:child("Setting-EndLayout-Title_3"):SetText(Lang:toText("lang_show_enable"))
    self:child("Setting-EndLayout-Title_3_6"):SetText(Lang:toText("lang_this_game_info"))
    self:child("Setting-EndLayout-Title_3_6_7"):SetText(Lang:toText("lang_game_time_rank"))
    self:subscribe(self:child("Setting-EndLayout-CheckLayout"), UIEvent.EventWindowTouchUp, function()
        self:selectCheck(MODE_TYPE.WAR_INFOMATION)
    end)

    self:subscribe(self:child("Setting-EndLayout-CheckLayout_4"), UIEvent.EventWindowTouchUp, function()
        self:selectCheck(MODE_TYPE.GAME_TIME_RANK)
    end)
end

function M:selectCheck(mode)
    self.gameInfoCheck:SetChecked(mode == MODE_TYPE.WAR_INFOMATION)
    self.gameTimeRank:SetChecked(mode == MODE_TYPE.GAME_TIME_RANK)
    globalSetting:setShowScoreInfoMode(mode)
end

function M:onOpen()
    self.mode = globalSetting:getShowScoreInfoMode() or MODE_TYPE.WAR_INFOMATION
    self:selectCheck(self.mode)
end

return M