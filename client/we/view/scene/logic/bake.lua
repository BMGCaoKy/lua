local State = require "we.view.scene.state"
local Def = require "we.def"
local VN = require "we.gamedata.vnode"
local Lfs = require "lfs"
local Map = require "we.view.scene.map"

local M = {}

local map_cfg_vnode = nil
local is_weight_visible_str = "is_bake_weight_visible"
local is_light_effect_visible_str = "is_bake_light_effect_visible"
local is_bake_light_str = "is_bake_light"
local is_bake_parallel_light_shadow_str = "is_bake_parallel_light_shadow"

local state_cfg_node = State:get_root()["bake_config"]
local bake_mgr_inst = LightBakeManager.Instance();
local scene_mgr = EngineSceneManager.Instance()

local function get_map_cfg(prop_name)
    return map_cfg_vnode[prop_name]
end

local function set_map_cfg(prop_name, val)
    VN.assign(map_cfg_vnode, prop_name, val, VN.CTRL_BIT.NOTIFY|VN.CTRL_BIT.SYNC)
end

local function set_state_val(prop_name, val)
    VN.assign(state_cfg_node, prop_name, val, VN.CTRL_BIT.NOTIFY|VN.CTRL_BIT.SYNC)
end

function M:set_bake_weight_visible()
    local is_visible = state_cfg_node[is_weight_visible_str]
    bake_mgr_inst:showBakeTargetWeight(is_visible)
end

function M:start_bake()
    bake_mgr_inst:bakeScene();
end

function M:set_bake_light_effect_visible()
    local is_visible = state_cfg_node[is_light_effect_visible_str]
    bake_mgr_inst:showBakePreview(is_visible)
    set_map_cfg(is_light_effect_visible_str, is_visible)
end

function M:del_bake_result()
    bake_mgr_inst:deleteBakeScene()
    self:get_result_dir()
    local bake_dir = state_cfg_node["result_dir_path"]
    for fn in Lfs.dir(bake_dir) do
        if fn ~= "." and fn ~= ".." then
            local path = Lib.combinePath(bake_dir, fn)
			local attr = Lfs.attributes(path)
			if attr.mode == "file" then
				os.remove(path)
			end
        end
    end
end

function M:init()
    local curMap = assert(Map:curr())
    map_cfg_vnode = curMap:get_node()

    local is_light_effect_visible = get_map_cfg(is_light_effect_visible_str)
    if is_light_effect_visible == nil then
        is_light_effect_visible = false
    end
    set_state_val(is_light_effect_visible_str,is_light_effect_visible)
    self:set_bake_light_effect_visible()

    set_state_val(is_weight_visible_str, false)
    --self:set_bake_weight_visible()

    local is_bake_light = get_map_cfg(is_bake_light_str)
    if is_bake_light == nil then
        is_bake_light = false
    end
    set_state_val(is_bake_light_str,is_bake_light)
    self:set_is_bake_light()

    local is_bake_parallel_light_shadow = get_map_cfg(is_bake_parallel_light_shadow_str)
    if is_bake_parallel_light_shadow == nil then
        is_bake_parallel_light_shadow = false
    end
    set_state_val(is_bake_parallel_light_shadow_str,is_bake_parallel_light_shadow)
    self:set_is_bake_parallel_light_shadow()
end

function M:get_is_baking()
    set_state_val("is_baking", bake_mgr_inst:getIsBaking())
end

function M:get_result_dir()
    set_state_val("result_dir_path", bake_mgr_inst:GetBakeMapFullDir())
end

function M:set_is_bake_light()
    local val = state_cfg_node[is_bake_light_str]
    -- scene_mgr:setEnableBakeLight(val)
    bake_mgr_inst:setEnableBakeLightClient(val)
    set_map_cfg(is_bake_light_str, val)
end

function M:set_is_bake_parallel_light_shadow()
    local val = state_cfg_node[is_bake_parallel_light_shadow_str]
    scene_mgr:setEnableBakeDirLightShadow(val)
    set_map_cfg(is_bake_parallel_light_shadow_str, val)
end

return M