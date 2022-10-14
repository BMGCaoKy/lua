require "common.event.event"
require "event.event_pool_window"
require "event.bindable_event_window"
require "event.event_pool_object"

local ClientEvents =
{
    "OnClientInitDone",
    "OnLoadMapDone",
    "OnTrayItemChanged",
    "OnTouchScreenBegin",
    "OnTouchScreenMove",
    "OnTouchScreenEnd"
}

Event:RegisterEvents(ClientEvents, Define.EVENT_SPACE.GLOBAL)