local buffItem = L("buffItem", {})
local data_state = require "editor.dataState"
local map_setting = require "editor.map_setting"

function buffItem.add(entity_obj, id, derive, pos, _table)
    local entity = entity_obj:getEntityById(id)	
    World.Timer(1, function()
        entity:updateUpperAction("freeze", 110000, true)
    end)
end

function buffItem.load(entity_obj, id, pos)
    local entity = entity_obj:getEntityById(id)	
    entity:updateUpperAction("freeze", 110000)
end

RETURN(buffItem)
