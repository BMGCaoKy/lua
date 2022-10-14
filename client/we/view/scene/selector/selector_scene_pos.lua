local Def = require "we.def"
local Signal = require "we.signal"
local Map = require "we.view.scene.map"
local IScene = require "we.engine.engine_scene"
local Base = require "we.view.scene.selector.selector_base"
local TreeSet = require "we.gamedata.vtree"
local VN = require "we.gamedata.vnode"
local Input = require "we.view.scene.input"

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
	local result, type = IScene:pick_scene_point({ x = x, y = y }, Def.SCENE_NODE_TYPE.BLOCK | Def.SCENE_NODE_TYPE.TERRAIN | Def.SCENE_NODE_TYPE.PART)
	if not result then
		return
	end
	local pos
	if type == Def.SCENE_NODE_TYPE.BLOCK then
		pos = Lib.v3add(result.pos, result.side or { x = 0, y = 1, z = 0 })
	elseif type == Def.SCENE_NODE_TYPE.TERRAIN or type == Def.SCENE_NODE_TYPE.PART then
		pos = 
		{ 
			x = result.pos.x, 
			y = result.pos.y + 0.04, 
			z = result.pos.z
		}
	end
	local tree = TreeSet:tree(self._tree_id)
	assert(tree, self._tree_id)
	local node = tree:node(self._path)
	assert(node, self._path)
	node["pos"]["x"] = pos["x"]
	node["pos"]["y"] = pos["y"]
	node["pos"]["z"] = pos["z"]
	if node["map"] then
		node["map"] = Map:curr():name()
	end

	Signal:publish(self, self.SIGNAL.SELECT_FINISH)
end

return M