require "common.instance"

function Instance.createEntity(params)
	return EntityClient.CreateClientEntity(params)
end

function Instance.createDropItem(params)	-- TODO
	local objID = params.objID or World.CurWorld:nextLocalID()
	local ret = DropItemClient.Create(objID, params.pos, params.item, params.moveSpeed, params.moveTime, params.guardTime)
	if params.fixRotation ~= nil then
		ret:setFixRotation(params.fixRotation)
	end
	return ret
end
