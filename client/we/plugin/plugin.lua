local Signal = require "we.signal"
local Request = require "we.proto.request_plugin"

local M = {}

function M:init()
	self._plugins = {}
end

function M:on_event(id, event, params)
	local plugin = assert(self._plugins[id])
	plugin:on_event(event, params)
end

-----------------------------------------------------------
-- base
local base_class = {}
base_class.SIGNAL = {
	ON_TRIGGERED = "triggered"
}

function base_class:init(type, params)
	self._type = type
	self._id = Request.request_insert(type, params)
end

function base_class:dtor()
	Request.request_remove(self._id)
end

function base_class:id()
	return self._id
end

function base_class:on_event(event, params)
	Signal:publish(self, event, table.unpack(params))
end

-----------------------------------------------------------
-- action
local action_class = Lib.derive(base_class)
function action_class:init(text)
	base_class.init(self, "Action", {text = text})
end

-----------------------------------------------------------
function M:create_action(text)
	local action = Lib.derive(action_class)
	action:init(text)

	local id = action:id()
	assert(not self._plugins[id])
	self._plugins[id] = action

	return action
end

function M:remove_action(action)
	local id = action:id()
	assert(self._plugins[id])
	self._plugins[id]:dtor()
	self._plugins[id] = nil
end

M:init()

return M
