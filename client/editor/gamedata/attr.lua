local M = {}

function M.to_bool(val, def)
	if not val then
		return not not def
	end

	if val == "true" then
		return true
	end

	return false
end

return M
