local Cjson = require "cjson"
local Core = require "editor.core"

local M = {}


local dialog_base = {
	init = function(self, id, options, cancel)
		self._id = id
		self._options = options
		self._cancel = cancel
	end,

	show = function(self)
	end,

	exec = function(self)
	end,

	respond = function(self, select)
		local option = self._options[select or 0]
		if not option then
			if self._cancel then
				self._cancel()
			end
		else
			if option.func then
				option.func()
			end
		end
	end
}

local dialog_confirm = Lib.derive(dialog_base, {
	init = function(self, id, options, cancel)
		dialog_base.init(self, id, options, cancel)
	end,

	show = function(self)
		Core.notify(Cjson.encode{
			type = "DIALOG_CONFIRM",
			params = {
				id = self._id
			}
		})
	end
})

local dialog_enum = Lib.derive(dialog_base, {
	init = function(self, id, options)
		dialog_base.init(self, id, options)
	end,

	show = function(self)

	end
})

-------------------------------------------------------------------
function M:init()
	self._set = {}
end

function M:confirm(ok, cancel)
	local id = #self._set + 1
	local dialog = Lib.derive(dialog_confirm)
	dialog:init(id,	{{func = ok}}, cancel)
	self._set[id] = dialog
	dialog:show()
end

function M:signal(options)
	Core.notify(Cjson.encode{
		type = options,
	})
end

function M:respond(id, ...)
	local dialog = assert(self._set[id], id)
	if dialog:respond(...) then
		self._set[id] = nil
	end
end

return M
