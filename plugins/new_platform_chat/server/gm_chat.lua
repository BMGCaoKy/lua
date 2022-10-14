local path = Root.Instance():getGamePath():gsub("\\", "/") .. "lua/gm_server.lua"
local file, err = io.open(path, "r")
local GMItem
local PlayerSpInfoManager = T(Lib, "PlayerSpInfoManager")
if file then
    GMItem = require("gm_server")
    file:close()
end
if not GMItem then
    GMItem = GM:createGMItem()
end

GMItem["聊天插件s/储存玩家特殊信息"] = function(self)
    PlayerSpInfoManager:savePlayerSpInfoById(self.platformUserId)
end

GMItem["聊天插件/增加语音次数10"] = function(self)
    local num = self:getValue("soundTimes")
    self:setValue("soundTimes", num + 10)
end

GMItem["聊天插件/增加语音次数1"] = function(self)
    local num = self:getValue("soundTimes")
    self:setValue("soundTimes", num + 1)
end

GMItem["聊天插件s/战斗标签"] = function(self)
    Plugins.CallTargetPluginFunc("platform_chat", "addConditionAutoCounts", self, 4, 1)
end

GMItem["聊天插件s/金魔方标签"] = function(self)
    Plugins.CallTargetPluginFunc("platform_chat", "addConditionAutoCounts", self, 5, 100)
end

GMItem["聊天插件s/点击系统消息"] = function(self)
    local content = "测试消息啊"
    local msgPack = {
        event = "testSystemEvent",
        args = os.time()
    }
    Plugins.CallTargetPluginFunc("platform_chat", "sendOneSystemMsg", content, msgPack)
end

GMItem["聊天插件s/清空标签计数"] = function(self)
    self:setConditionAutoTagsCounts({})
end