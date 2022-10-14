local M = {}

---------------------------------------------
-- block
function M:set_block(pos, id)
	return World.CurMap:setBlockConfigId(pos, id)
end

function M:get_block(pos)
	return World.CurMap:getBlockConfigId(pos)
end

return M
