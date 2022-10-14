local Def = require "we.def"
local Signal = require "we.signal"
local Input = require "we.view.scene.input"

local IScene = require "we.engine.engine_scene"
local IInstance = require "we.engine.engine_instance"
local IWorld = require "we.engine.engine_world"

local M = {}

M.SIGNAL = {
	ON_BIND_CHANGED	= "ON_BIND_CHANGED",
	ANCHOR_CHANGE	= "ANCHOR_CHANGE",
}

function M:init()
	self._receptor = nil
	self._list = {}

	self._hover_id = nil
end

function M:update()
	if self._receptor then
		self._receptor:update()
	end
end

function M:bind(type)
	if not self._list[type] then
		local class = require(string.format("%s.receptor_%s", "we.view.scene.receptor", string.lower(type)))
		assert(class, string.format("class %s is not exist", type))

		local obj = Lib.derive(class)
		obj:init()

		self._list[type] = obj
	end

	local receptor = assert(self._list[type])
	if self._receptor == receptor then
		return self._receptor
	end

	if self._receptor then
		self._receptor:on_unbind()
		self._receptor = nil
	end


	self._receptor = receptor
	self._receptor:on_bind()

	Signal:publish(self, M.SIGNAL.ON_BIND_CHANGED, self._receptor)
	return self._receptor
end

function M:unbind()
	if not self._receptor then
		return
	end

	self._receptor:on_unbind()
	self._receptor = nil

	Signal:publish(self, M.SIGNAL.ON_BIND_CHANGED, nil)
end

function M:binding()
	return self._receptor
end

local function clear_hover_effects(self, node)
	if not node then
		return
	end
	IInstance:set_hover(node, false)
	self._hover_id = nil
end

local function set_hover_effects(self, node)
	if not node then
		return
	end
	
	local Map = require "we.view.scene.map"
	local obj = Map:query_instance(node)
	local tgt_obj = obj:find_toppest_model_ancestor() or obj
	local hover_node = nil
	if tgt_obj then
		hover_node = tgt_obj:node()
	end
	local node_id = IInstance:get(hover_node,"id")
	if node_id == self._hover_id then
		return
	end
	self._hover_id = node_id
	IInstance:set_hover(hover_node, true)
end

local function hover(self, x, y)
	local now_node = IScene:pick_point({x = x, y = y}, Def.SCENE_NODE_TYPE.PART)
	local old_node = self._hover_id and IWorld:get_instance(self._hover_id)
	if now_node == old_node then 
		return
	end
	if old_node then
		local Map = require "we.view.scene.map"
		local obj = Map:query_instance(old_node)
		if obj and obj:selected() then 
			obj:node():setRenderBoxColor(IInstance.INSTANCECOLOR.SELECT)
		else
			clear_hover_effects(self, old_node)
		end
	end
	if now_node then
		set_hover_effects(self, now_node)
	end
end

local function process_event(self, event, ...)
	if not self._receptor then
		return false
	end

	local proc = assert(self._receptor[event], string.format("%s", event))
	return proc(self._receptor, ...)
end

function M:on_mouse_move(x, y)
	if not IScene.on_drag then
		hover(self, x, y)
	end
	if process_event(self, "on_mouse_move", x, y) then
		return true
	end
end

function M:on_hover_remain(x,y)
	if not IScene.on_drag then
		local inst=IScene:pick_point({x=x,y=y},Def.SCENE_NODE_TYPE.PART)
		if inst then
			local isLock=IInstance:get(inst, "isLockedInEditor")
			local id=IInstance:get(inst,"id")
			local result={isLocked=isLock,id=id};
			return result;
		end
	end
	return "false"
end

function M:on_mouse_press(x, y, button)
	if process_event(self, "on_mouse_press", x, y, button) then
		return true
	end
end

function M:on_mouse_release(x, y, button, is_click)
	if process_event(self, "on_mouse_release", x, y, button, is_click) then
		return true
	end
end  

function M:on_key_press(key)
	if process_event(self, "on_key_press", key) then
		return true
	end
end

function M:on_key_release(key)
	if not self._receptor then
		return false
	end

	if process_event(self, "on_key_release", key) then
		return true
	end
	
	if key == Input.KEY_CODE.Key_Esc then
		self:unbind()
		return true
	end
end

function M:create(name)
	local class = require(string.format("%s.receptor_%s", "we.view.scene.receptor", string.lower(name)))
	assert(class, string.format("class %s is not exist", name))

	local obj = Lib.derive(class)
	obj:init()

	return obj
end

function M:select(type, list)
	local receptor = self:bind(type)
	receptor:clear()
	for _, obj in pairs(list) do
		receptor:attach(obj)
	end
end

return M
