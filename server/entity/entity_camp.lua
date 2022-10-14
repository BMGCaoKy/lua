local M = L("M", {})
local campsTbl = T(M, "campsTbl")

--- return [entity1, ...]
function M.getAllEntitys(campFilterFn)
	local tblRet = {}
	local curWorld = World.CurWorld
	for camp, tblIds in pairs(campsTbl) do
		if (not campFilterFn) or campFilterFn(camp) then
			for id, _ in pairs(tblIds) do
				local entity = curWorld:getObject(id)
				if entity then
					table.insert(tblRet, entity)
				else
					tblIds[id] = nil -- 遍历中可以set nil，不能添加
				end
			end
		end
	end
	return tblRet
end

function M.addAIEntity(camp, entity)
	local tbl = campsTbl[camp]
	if not tbl then
		tbl = {}
		campsTbl[camp] = tbl
	end
	tbl[entity.objID] = true
end

function M.delAIEntity(camp, entity)
	local tbl = campsTbl[camp]
	if tbl then		
		tbl[entity.objID] = nil
	end
end

return M
