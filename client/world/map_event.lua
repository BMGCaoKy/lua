
local events = {}
local similarity
if CGame.instance:getEditorType() == 1 then
    similarity = require "editor.edit_record.similarity"
end

function events:blockChange(params)
    if similarity then
        similarity:addChangedBlock(self, params.pos, params.oldId, params.newId)
    end
end

function map_event(mapId, event, ...)
	-- client not need do anything

end
