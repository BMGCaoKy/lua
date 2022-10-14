require "common.event.event"
require "event.event_pool_object"

local ServerEvents =
{
    "OnPlayerLogin",
    "OnPlayerLogout",
    "OnPlayerReconnect",
}

Event:RegisterEvents(ServerEvents, Define.EVENT_SPACE.GLOBAL)