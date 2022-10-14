---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Anybook.
--- DateTime: 2022/6/28 15:53
---
local reportController = require "common.report.controller"
local gameName = World.GameName
local tostring = tostring

function reportController:init()
    World.Timer(1, self.requestEventTrackingList, self)
end

function reportController:requestEventTrackingList()
    -- 请求埋点列表，下发各个客户端
    local params = {
        { "game", tostring(gameName) }
    }
    self.lastTime = World.Now()
    AsyncProcess.HttpRequestByKey("GET", "GetEventTrackingList", {}, params, function(response)
        if response.status_code then
            Lib.logWarning("Request EventTracking list failed.", Lib.v2s(response))
            return
        end
        local eventList = response.events
        reportController:receiveEventTrackingList(eventList)
        reportController:notifyClientEventTrackingList(eventList)
    end)
end

function reportController:notifyClientEventTrackingList(list)
    local packet = {
        pid = "EventTrackingList",
        list = list
    }
    WorldServer.BroadcastPacket(packet)
end

function reportController:requestListByClient()
    self:tryRequestList()
end

Event:GetEvent("OnPlayerLogin"):Bind(function(player)
    local list = {}
    for eventName in pairs(reportController:getEventTrackingList()) do
        table.insert(list, eventName)
    end
    player:sendPacket({ pid = "EventTrackingList", list = list })
end)

reportController:init()
return reportController