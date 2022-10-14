local Def = require "we.def"
local Core = require "editor.core"
local BM = Blockman.Instance()
local CW = World.CurWorld
local GAME = CGame.instance

local scene_root_node = nil

local M = {}

--------------------------------------------------------------
-- map
function M:enter_map(name, id, pos)
	CW:loadCurMap({
		id = id,
		name = name,
		static = true
	}, pos)

	local manager = CW:getSceneManager()
	local scene = manager:getOrCreateScene(CW.CurMap.obj)
	manager:setCurScene(scene)
end

function M:leave_map()
	
end

function M:close_map(name)
	local map = CW:getOrCreateStaticMap(name)
	if map then
		map:close()
	end
end

---------------------------------------------------------------
-- instance
function M:create_instance(cfg, beyond, flags)
	local manager = CW:getSceneManager()
	local scene = manager:getOrCreateScene(CW.CurMap.obj)
	cfg.scene = scene
	local inst = Instance.newInstance(cfg, CW.CurMap)
	if inst and not beyond then
		inst:setParent(scene:getRoot())
	end

	--支持合批的零件类型
	local batch_enable_types = {
		Part = true, 
		PartOperation = true, 
		MeshPart = true
	}

	local function get_children(tb, result_tb)
		local has_id = tb.properties and tb.properties.id
		local is_valid_type = tb.class and batch_enable_types[tb.class]
		if has_id and is_valid_type then
			result_tb[tb.properties.id] = true
		end
		if tb.children then
			for idx,child in ipairs(tb.children) do
				get_children(child,result_tb)
			end
		end
	end

	--只有引擎节点（比如复制的时候那个还没有放到场景中去的）
	local only_engine = not(flags and flags.not_only_engine)
	if only_engine then
		local results_tb = {}
		get_children(cfg, results_tb)

		--如果为空node为新建类型，不是复制类型
		local first_k = next(results_tb)
		if first_k == nil then
			local is_batch_enable = cfg.class and batch_enable_types[cfg.class]
			local id = inst:getInstanceID()

			if is_batch_enable and id and cfg.class == "Part" then
				AutoStaticBatch.addEditorPart(id)
			end
		else
			for node_id in pairs(results_tb) do
				AutoStaticBatch.addEditorPart(node_id)
			end
		end
	end

	return inst
end

function M:remove_instance(inst)
	if inst then
		return inst:destroy()
	end
end

function M:get_instance(id)
	return Instance.getByInstanceId(id)
end


function M:gen_instance_id()
	return Core.gen_instance_id()
end

---------------------------------------------------------------
-- block
function M:create_block_widget(id, pos)
	pos = pos or {x = 0, y = 0, z = 0}
    local obj = Core.new_widget_block(pos, id)
    return debug.setmetatable(obj, {
        __index = Core.block_lib
    })
end

function M:remove_block_widget(obj)
	Core.del_widget_block(obj)
end

---------------------------------------------------------------
-- chunk
function M:create_chunk_widget(chunk, pos)
	pos = pos or {x = 0, y = 0, z = 0}
	local obj = Core.new_widget_chunk(pos, chunk)
	assert(obj)

	return debug.setmetatable(obj, {
		__index = Core.chunk_lib
	})
end

function M:remove_chunk_widget(obj)
	Core.del_widget_chunk(obj)
end

---------------------------------------------------------------
-- box
function M:create_box_widget(min, max)
	local obj = Core.new_widget_frame(min, max)
	assert(obj)

	return debug.setmetatable(obj, {
		__index = Core.frame_lib
	})
end

function M:remove_box_widget(obj)
	Core.del_widget_frame(obj)
end

function M:get_scene_root_node()
	if scene_root_node then
		return scene_root_node
	end
	local manager = CW:getSceneManager()
	local scene = manager:getOrCreateScene(CW.CurMap.obj)
	return scene:getRoot()
end


return M
