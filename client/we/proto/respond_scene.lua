local Input = require "we.view.scene.input"
local Operator = require "we.view.scene.operator.operator"
local Receptor = require "we.view.scene.receptor.receptor"
local Recorder = require "we.gamedata.recorder"
local Placer = require "we.view.scene.placer.placer"
local State = require "we.view.scene.state"
local Map = require "we.view.scene.map"
local Scene = require "we.view.scene.scene"
local PartOperation = require "we.view.scene.logic.part_operation"

local IWorld = require "we.engine.engine_world"
local CameraIndicator = require "we.view.scene.camera_indicator"

local Def = require "we.def"
local IScene = require "we.engine.engine_scene"
local IInstance = require "we.engine.engine_instance"
local Module = require "we.gamedata.module.module"
local VN = require "we.gamedata.vnode"
local Material=require "we.view.scene.material"

local last_tick = 0

local Bake = nil
local function get_bake()
	if Bake == nil then
		Bake = require "we.view.scene.logic.bake"
	end
	return Bake
end

return {
	KEY_EVENT = function(event, key)
		if event == "Press" then
			Input:on_key_press(key)
		elseif event == "Release" then
			Input:on_key_release(key)
		else
			assert(false, tostring(event))
		end
	end,

	MOUSE_EVENT = function(event, x, y, button)
		if event == "Press" then
			Input:on_mouse_press(x, y, button)
		elseif event == "Release" then
			Input:on_mouse_release(x, y, button)
		elseif event == "Move" then
			local curr_tick = World.CurWorld:getTickCount()
			if last_tick ~= curr_tick then
				Input:on_mouse_move(x, y)
				last_tick = curr_tick
			end
		else
			assert(false, tostring(event))
		end
	end,

	HOVER_REMAIN = function(event, x, y, button)
		local ret,result=Input:on_hover_remain(x,y)
		local tab={ret,result=result}
		return tab
	end,
	
	HOVER_UNLOCK = function(event, x, y, button)
		Input:on_hover_unlock(x,y)
	end,

	MOUSE_WHEEL = function(wheelValue)
		Input:on_mouse_wheel(wheelValue)
	end,

	LOST_FOCUS = function()
		Input:on_lost_focus()
	end,

	OPERATOR = function(code, is_scene)
		Recorder:start()
		local op = assert(Operator:operator(code), tostring(code))
		local receptor = Receptor:binding()
		assert(op:check(receptor))
		op:exec(receptor, is_scene)
		Recorder:stop()
	end,
	
	DRAG_INSTANCE_TO_SCENE = function(x, y)
		local isEdittingCollosion,id=State:get_custom_collision_editing()
		if isEdittingCollosion then
			return
		end
		Recorder:start()
		Placer:binding():place(x, y)
		State:placer()["mode"] = ""
		Recorder:stop()
	end,
	CHECK_ITEM_IN_USE = function(module, item)
		local in_use = Map:check_use_cfg(module, item)
		return { ok = true, data = in_use}
	end,

	UNBIND_RECEPTOR = function()
		Receptor:unbind()
	end,

	SCENE_RESET = function()
		Scene:reset()
	end,

	CREATE_FOLDER = function(isDataSet)
		Recorder:start()
		Map:create_folder(isDataSet)
		Recorder:stop()
	end,

	CREATE_SCENEUI = function()
		Recorder:start()
		Map:create_sceneui()
		Recorder:stop()
	end,

	CREATE_EFFECT_PART = function(...)
		Recorder:start()
		Map:create_effect_part({...})
		Recorder:stop()
	end,
	
	CREATE_AUDIO_NODE = function(...)
		Recorder:start()
		Map:create_audio_node({...})
		Recorder:stop()
	end,

	CREATE_EMPTY_NODE = function(...)
		Recorder:start()
		Map:create_empty_node({...})
		Recorder:stop()
	end,

	CREATE_FOG_NODE = function(...)
		Recorder:start()
		Map:create_fog_node({...})
		Recorder:stop()
	end,

	CREATE_POST_PROCESS = function(...)
		Recorder:start()
		Map:create_post_process({...})
		Recorder:stop()
	end,

	ADD_FOLDER = function(id, isDataSet)
		Recorder:start()
		Map:add_folder(id, isDataSet)
		Recorder:stop()
	end,

	TIER_CHANGED = function(...)
		Recorder:start()
		Map:tier_changed(...) 
		Recorder:stop()
	end,

	ADD_ITEM_CHILD = function(...)
		Recorder:start()
		Map:add_obj_child({...})
		Recorder:stop()
	end,

	ADD_LIGHT_CHILD = function(data)
		Recorder:start()
		Map:add_light_child(data)
		Recorder:stop()
	end,

	CREATE_CUSTOM_COLLISION = function(nodeId)	
		Recorder:start()
		local isEditing,id=State:get_custom_collision_editing()
		if isEditing then
			local oldCollision=Map:query_instance(id)
			assert(oldCollision)
			local oldInst=oldCollision:parent()
			oldInst._node:setProperty("collisionFidelity","6")
			assert(oldInst)
			oldInst:saveCollision(tostring(id))
			oldInst._vnode["customCollision"]["isEditing"]=false
		end
		local inst=Map:query_instance(tostring(nodeId))
		if not inst then
			Recorder:stop()
			return
		end
		inst._node:setProperty("collisionFidelity",tostring("0"))
		local collision=inst._vnode["customCollision"]
		if not collision then
			Recorder:stop()
			return 
		end
		local collisionid=collision["id"]
		local obj
		if collisionid =="" then
			obj=Map:add_collision_child(nodeId)
			collisionid=obj._vnode["id"]
			inst._vnode["customCollision"]["id"]=collisionid
			inst._vnode["customCollision"]["isEditing"]=true
		else 
			obj=Map:add_collision_child(nodeId,collisionid)
			obj._vnode["id"]=collisionid
			inst._vnode["customCollision"]["isEditing"]=true
			inst:loadCollision(collisionid)
		end
		State:set_custom_collision_editing(true,collisionid)
		Recorder:stop()
	end,

	FINISH_CUSTOM_COLLISION=function(nodeId)	
		local editting,collision_id=State:get_custom_collision_editing()
		if editting~=true or collision_id=="" then
			return
		end
		local collision=Map:query_instance(collision_id)
		if not collision then
			return
		end
		Recorder:start()
		local inst=collision:parent()
		inst._node:setProperty("collisionFidelity",tostring("6"))
		inst._vnode["customCollision"]["isEditing"]=false
		inst:saveCollision(collision_id)
		State:set_custom_collision_editing(false,"")
		Recorder:stop()
	end,

	DROP_ITEM_EFFECT = function(...)
	    Recorder:start()
		Map:drop_obj_effect({...})
		Recorder:stop()
	end,

	DRAG_ITEM_EFFECT = function(...)
	    local table = {...}
		local instance= IScene:pick_point({x = table[1], y = table[2]}, Def.SCENE_NODE_TYPE.PART) 
		if not instance then
			return {ok = true, data = ""}
		end
		local id = IInstance:get(instance,"id")
		return {ok = true, data = id or ""}
	end,
	
	CHECK_SCENEUI_IN_RECEPTOR = function()
		local receptor = Receptor:binding()
		local list = receptor:list(function(obj)
			local child = obj:children()
			for _,v in ipairs(child) do
				if v:class() == "SceneUI" then
					return true
				end
			end
			return false
		end)
		return { results = #list ~= 0}
	end,
	
	CHANGE_EDIT_FOLDER = function(id)
		Map:change_edit_folder(id)
	end,

	CLEAR_EDIT_FOLDER = function()
		Map:clear_edit_folder()
	end,

	SET_REGION_PART = function(id)
		local placer = Placer:bind("region")
		placer:set_parent(Map:query_instance(id))
	end,
	
	CHANGE_EDIT_FOLDER = function(id)
		Map:change_edit_folder(id)
	end,

    btskey2name = function(btsKey)
        local module = Module:module("map")
        local name = ""

        for _, item in pairs(module:list()) do
            local root = item:obj()
            VN.iter(root,
                function(node)
                    local meta = VN.meta(node)
                    if meta:name() ~= "Instance_Part" and meta:name() ~= "Instance_PartOperation" then
                        return
                    end
                    return node["btsKey"] == btsKey
                end,
                function(node)
                   name = node["name"]
                end
             )
             if name ~= "" then
                break
             end
        end

        return {name = name}
    end,

	SAVE_MATERIAL_AS_TEMPLATE=function(id,fileName)
		local inst=Map:query_instance(id)
		inst:save_material_as_template(fileName)
	end,

	SHOW_CAMERA_INDICATOR = function(show)
		CameraIndicator:show_camera_indicator(show)
    end,

	BAKE_CONFIG = function(operation)
		local func = get_bake()[operation]
		if _G.type(func) == "function" then
			func(get_bake())
		end
	end,

	CREATE_MATERIAL_TREE=function(fileName)
		Material:init(fileName)	
	end,

	MESH_TEXTURE_MD5 = function ()
		local inst = MeshResourceManager.Instance()
		inst:CacheMeshTextureMd5()
		inst.Release()
	end
}
