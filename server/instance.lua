require "common.instance"

function Instance.createEntity(params)
	local entity = EntityServer.Create(params)
	if entity and params.map then
		entity:setMapPos(params.map, entity:getPosition())
	end
	return entity
end

function Instance.createDropItem(params)
	return DropItemServer.Create(params)
end
