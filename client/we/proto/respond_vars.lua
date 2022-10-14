local Var = require "we.gamedata.var"

return {
	VAR_KEY = function(page)
		local key = Var:get_vars(page)
		return {ok = true, data = key}
	end
}
