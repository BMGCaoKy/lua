﻿---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by 10184.
--- DateTime: 2020/12/17 20:02
---
local misc = require "misc"
local seri = require "seri"
local DBHandler = require "dbhandler" ---@type DBHandler
local PlayerDBMgr = T(Lib, "PlayerDBMgr") ---@class PlayerDBMgr
local LoginDBRequestFunc = {}

function PlayerDBMgr:init()
    PlayerDBMgr.registerLoginDBDataRequestFunc(Define.DBSubKey.PlayerData, Player.onGetPlayerDBData, Player.saveDBData)
end

function PlayerDBMgr.registerLoginDBDataRequestFunc(subKey, onGetDBFunc, onSaveDBFunc)
    for _, requestFunc in pairs(LoginDBRequestFunc) do
        if requestFunc.subKey == subKey then
            if type(onGetDBFunc) == "function" then
                requestFunc.onGetDBFunc = onGetDBFunc
            end
            if type(onSaveDBFunc) == "function" then
                requestFunc.onSaveDBFunc = onSaveDBFunc
            end
            return
        end
    end
    table.insert(LoginDBRequestFunc, { subKey = subKey, onGetDBFunc = onGetDBFunc, onSaveDBFunc = onSaveDBFunc })
end

local function deserializeData(text)
    local data
    if text and text ~= "" then
        data = seri.deseristring_string(misc.base64_decode(text))
    end
    return data or {}
end

function PlayerDBMgr.getPlayerLoginData(userId, callback)
    if type(callback) ~= "function" then
        return
    end
    local records = {}
    if DBHandler.enable then
        local function checkAllDataGet()
            for _, requestFunc in pairs(LoginDBRequestFunc) do
                if not records[requestFunc.subKey] then
                    return false
                end
            end
            return true
        end
        for _, requestFunc in pairs(LoginDBRequestFunc) do
            DBHandler:getDataByUserId(userId, requestFunc.subKey, function(_, data)
                local ok, result = xpcall(deserializeData, traceback, data)
                if not ok then
                    return
                end
                records[requestFunc.subKey] = result
                if not checkAllDataGet() then
                    return
                end
                callback(userId, records)
            end, function (_, init)
                if init then
                    records[requestFunc.subKey] = {}
                    if not checkAllDataGet() then
                        return
                    end
                    callback(userId, records)
                end
            end)
        end
    else
        for _, requestFunc in pairs(LoginDBRequestFunc) do
            records[requestFunc.subKey] = {}
        end
        callback(userId, records)
    end
end

function PlayerDBMgr.onGetLoginDBData(player)
    if not World.gameCfg.disableSave and World.cfg.needSave and DBHandler.enable and not player:isWatch() then
        ---使用数据存储功能，先获取数据
        local records = {}
        local function checkAllDataGet()
            for _, requestFunc in pairs(LoginDBRequestFunc) do
                if not records[requestFunc.subKey] then
                    return false
                end
            end
            return true
        end
        for _, requestFunc in pairs(LoginDBRequestFunc) do
            DBHandler:getData(player, requestFunc.subKey, function(subKey, data)
                if not player:isValid() then
                    return
                end
                local ok, result = xpcall(deserializeData, traceback, data)
                if not ok then
                    perror("player load db data failed", player.platformUserId, player.name, type(data) == "string" and data:len(), result)
                    Game.KickOutPlayer(player, "game.loaddb.failed")
                    return
                end
                records[subKey] = result
                if not checkAllDataGet() then
                    return
                end
                for _, callBackRequest in pairs(LoginDBRequestFunc) do
                    local _subKey = callBackRequest.subKey
                    callBackRequest.onGetDBFunc(player, _subKey, records[_subKey])
                end
            end)
        end
    else
        ---不适用数据存储功能，直接初始化成空数据
        player:timer(1, function()
            for _, requestFunc in pairs(LoginDBRequestFunc) do
                requestFunc.onGetDBFunc(player, requestFunc.subKey, {})
            end
        end)
    end
end

-- 旧接口，立即存盘
function PlayerDBMgr.onSaveLoginDBData(player, callback)
    PlayerDBMgr.SaveImmediate(player, callback)
end

-- 存盘（实时）
function PlayerDBMgr.SaveImmediate(player, callback)
    if not player then
        return false
    end

    if not DBHandler.enable or player:isWatch() or not player.dataLoaded then
        return false
    end
    local records = {}
    local function checkAllDataSave()
        for _, requestFunc in pairs(LoginDBRequestFunc) do
            if not records[requestFunc.subKey] then
                return false
            end
        end
        return true
    end
    for _, requestFunc in pairs(LoginDBRequestFunc) do
        local data = requestFunc.onSaveDBFunc(player)
        if type(data) == "table" then
            DBHandler:setData(player.platformUserId, requestFunc.subKey, misc.base64_encode(seri.serialize_string(data)), true, function()
                records[requestFunc.subKey] = true
                if not checkAllDataSave() then
                    return false
                end
                if callback then
                    callback()
                end
                if player:isValid() and player.Logouting then
                    player.Logouting = false
                    Game.RemoveLogoutPlayer(player)
                end
            end)
        end
    end
    if player.map then
        MapChunkMgr.saveMapChunkToDB(player.map)
    end
    return true
end

RETURN(PlayerDBMgr)