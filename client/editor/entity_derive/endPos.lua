local endPos = L("endPos", {})
local data_state = require "editor.dataState"

function endPos.add(entity_obj, id, derive_obj)
	
end

function endPos.del(entity_obj, id)

end 

function endPos.load(entity_obj, id, pos)
	local name = entity_obj:getCfgById(id)
	entity_obj:rulerArithmeticAdd(name, pos, id)
end

RETURN(endPos)
