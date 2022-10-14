local Def = require "we.def"
local Signal = require "we.signal"
local Input = require "we.view.scene.input"
local IScene = require "we.engine.engine_scene"
local TreeSet = require "we.gamedata.vtree"
local IInstance = require "we.engine.engine_instance"
local Base = require "we.view.scene.selector.selector_base"

local M = Lib.derive(Base)

function M:init()
	self._tree_id = nil
	self._path = nil
end

function M:on_bind()

end

function M:on_unbind()

end

function M:select(data)
	local datas = Lib.splitString(data,"|")
	self._tree_id = datas[1]
	self._path = datas[2]
end

function M:on_mouse_press(x, y, button)
	if button ~= Input.MOUSE_BUTTON_TYPE.BUTTON_LEFT then
		return
	end
	
	local instance = IScene:pick_point({ x = x, y = y }, Def.SCENE_NODE_TYPE.PART)
	if not instance then
		return
	end

	local tree = TreeSet:tree(self._tree_id)
	assert(tree, self._tree_id)
	local node = tree:node(self._path)
	assert(node, self._path)
	node["rawval"] = tostring(IInstance:id(instance))
	Signal:publish(self, self.SIGNAL.SELECT_FINISH)
end

return M