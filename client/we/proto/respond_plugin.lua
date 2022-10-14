local Plugin = require "we.plugin.plugin"

return {
	ON_EVENT = function(id, event, params)
		Plugin:on_event(id, event, params)
	end,
}
