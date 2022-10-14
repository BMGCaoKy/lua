---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by hlm.
--- DateTime: 2021/3/18 11:07
--- 这里是玩家特殊数据的管理类
--- @class PlayerSpInfoManager
local PlayerSpInfoManager = T(Lib, "PlayerSpInfoManager")
local Player = Player
local handles = T(Player, "PackageHandlers")
--local SYNC_INTERVAL = 40
function PlayerSpInfoManager:init()
    self.dirtyPlayer = {}
    self.playerSpInfoDic = {}
end
function PlayerSpInfoManager:playerInit(gameFriend,player)
    if not player or not player:isValid() then
        return
    end
    if not self.playerSpInfoDic then
        self.playerSpInfoDic = {}
    end
    local userIds = {}
    --加入自己
    if not self.playerSpInfoDic[tostring(player.platformUserId)] then
        table.insert(userIds,tonumber(player.platformUserId))
    end
    --加入自己的同玩好友
    for _,user in pairs(gameFriend) do
        if not self.playerSpInfoDic[tostring(user.userId)] then
            table.insert(userIds,tonumber(user.userId))
        end
    end
    if #userIds>0 then
        self:getPlayerSpDataByIdList(userIds,function()
            local list = {}
            for _,uid in pairs(userIds) do
                --同步标脏
                list[tostring(uid)] = self.playerSpInfoDic[tostring(uid)]
            end
            --player:sendPacket({
            --    pid = "PlayerSpInfoSync",
            --    list = list
            --})
        end)
    end

end

function PlayerSpInfoManager:getPlayerSpDataByIdList(userIds,cb)
    if #userIds >0 then
        AsyncProcess.GetPlayerGameSpecialData(userIds, function(list)
            for _,info in pairs(list) do
                if not self.playerSpInfoDic[tostring(info.userId)] then
                    self.playerSpInfoDic[tostring(info.userId)] = info.data or {}
                end
            end
            if cb then
                cb(list)
            end
        end)
    end
end
---@param userId string
---@param callback function
function PlayerSpInfoManager:savePlayerSpInfoById(userId,callback)
    userId = tostring(userId)
    Lib.logDebug("PlayerSpInfoManager:savePlayerSpInfoById: start ",self.dirtyPlayer[userId], Lib.v2s(self.playerSpInfoDic[userId]))
    if self.playerSpInfoDic[userId] and self.dirtyPlayer[userId] then
        AsyncProcess.SavePlayerGameSpecialData(tonumber(userId), self.playerSpInfoDic[userId], function(ret)
            Lib.logInfo("PlayerSpInfoManager:savePlayerSpInfoById success",Lib.v2s(self.playerSpInfoDic[userId]))
            if callback then
                callback(ret)
            end
            if ret then
                self.dirtyPlayer[userId] = false
            end

        end)
    end

end

---@param userId string
---@param cb function
function PlayerSpInfoManager:getPlayerSpDataById(userId,cb)
    userId=tostring(userId)
    if not cb or type(cb) ~= "function" then
        Lib.logInfo("PlayerSpInfoManager:getPlayerSpDataByIdList need a callback!")
        return
    end
    if self.playerSpInfoDic[userId] then
        cb(Lib.copy(self.playerSpInfoDic[userId]))
    else
        self:getPlayerSpDataByIdList({[1] = tonumber(userId)},function()
            cb(Lib.copy(self.playerSpInfoDic[userId]))
        end)
    end
end

--设置特殊消息的key
---@param userId string
---@param key string
---@param userId any
function PlayerSpInfoManager:setPlayerSpKeyValueById(userId,key,val,cb)
    userId=tostring(userId)
    if not self.playerSpInfoDic[userId] then
        self:getPlayerSpDataById(userId,function(data)
            if not self.playerSpInfoDic[userId] then
                self.playerSpInfoDic[userId] = {}
            end
            if type(val) == "table" then
                self.playerSpInfoDic[userId][key] = Lib.copy(val)
                self.dirtyPlayer[userId] = true
            else
                if self.playerSpInfoDic[userId][key] ~= val then
                    self.playerSpInfoDic[userId][key] = val
                    self.dirtyPlayer[userId] = true
                end
            end
            Lib.logDebug("PlayerSpInfoManager:setPlayerSpKeyValueById:",userId, self.dirtyPlayer[userId], Lib.v2s(self.playerSpInfoDic[userId] or {}))
            if cb then
                cb()
            end
        end)
    else
        if type(val) == "table" then
            self.playerSpInfoDic[userId][key] = Lib.copy(val)
            self.dirtyPlayer[userId] = true
        else
            if self.playerSpInfoDic[userId][key] ~= val then
                self.playerSpInfoDic[userId][key] = val
                self.dirtyPlayer[userId] = true
            end
        end
        Lib.logDebug("PlayerSpInfoManager:setPlayerSpKeyValueById:",userId, self.dirtyPlayer[userId], Lib.v2s(self.playerSpInfoDic[userId] or {}))
        if cb then
            cb()
        end
    end
end

function handles:GetPlayerSpDataById(packet)

    local userId = tostring(packet.userId)
    if userId then
        if PlayerSpInfoManager.playerSpInfoDic[userId] then
            return PlayerSpInfoManager.playerSpInfoDic[userId]
        else
            PlayerSpInfoManager:getPlayerSpDataByIdList({tonumber(packet.userId)},function()
                self:pushClientUpdateSpInfo(userId)
            end)
            return false
        end
    end
end
function handles:GetPlayerSpDataListById(packet)
    PlayerSpInfoManager:getPlayerSpDataByIdList(packet.userIds,function(list)
        self:sendPacket({
            pid = "PushPlayerSpInfoListSync",
            list = list
        })
    end)
end

-- 通知客户端同步玩家数据
function Player:pushClientUpdateSpInfo(userId)
    self:sendPacket({
        pid = "PlayerSpInfoSync",
        list = {[tostring(userId)] = PlayerSpInfoManager.playerSpInfoDic[tostring(userId)]}
    })
end

--- 服务端调用增加亲密度
function PlayerSpInfoManager:addSpDataIntimacyValById(userId1, userId2, addIntimacyVal)
    -- 增加亲密度
    local callFunc1 = function(data)
        local intimacyData = Lib.copy(data[Define.PLAYER_SP_INFO_KEY.intimacyVal])
        local targetId = tostring(userId2)
        if addIntimacyVal >= 0 then
            if intimacyData then
                if intimacyData[targetId] then
                    intimacyData[targetId] = intimacyData[targetId] + addIntimacyVal
                else
                    intimacyData[targetId] = addIntimacyVal
                end
            else
                intimacyData = {}
                intimacyData[targetId] = addIntimacyVal
            end
        else  -- 不是好友的，送礼的时候检查更新一次亲密度
            if intimacyData then
                intimacyData[targetId] = 0
            else
                intimacyData = {}
                intimacyData[targetId] = 0
            end
        end
        -- 送礼的都需要保存
        self.dirtyPlayer[tostring(userId1)] = true
        self.dirtyPlayer[tostring(userId2)] = true
        self:setPlayerSpKeyValueById(userId1, Define.PLAYER_SP_INFO_KEY.intimacyVal, intimacyData)
    end
    self:getPlayerSpDataById(userId1, callFunc1)
end

--- 服务端调用设置亲密度
function PlayerSpInfoManager:setSpDataIntimacyValById(userId1, userId2, val)
    local callFunc1 = function(data)
        local intimacyData = data[Define.PLAYER_SP_INFO_KEY.intimacyVal]
        local targetId = tostring(userId2)
        if intimacyData then
            intimacyData[targetId] = val
        end
        self:setPlayerSpKeyValueById(userId1, Define.PLAYER_SP_INFO_KEY.intimacyVal, intimacyData)
    end
    self:getPlayerSpDataById(userId1, callFunc1)
end

PlayerSpInfoManager:init()