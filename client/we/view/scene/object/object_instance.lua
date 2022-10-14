local Def = require "we.def"
local Signal = require "we.signal"

local Meta = require "we.gamedata.meta.meta"
local VN = require "we.gamedata.vnode"
local Recorder = require "we.gamedata.recorder"

local Bunch = require "we.view.scene.bunch"
local Utils = require "we.view.scene.utils"

local Object = require "we.view.scene.object.object"
local Receptor = require "we.view.scene.receptor.receptor"

local IWorld = require "we.engine.engine_world"
local IScene = require "we.engine.engine_scene"
local IInstance = require "we.engine.engine_instance"
local State = require "we.view.scene.state"
local BindObject = require "we.view.scene.bind.bind_object"
local Base = require "we.view.scene.object.object_base"
local CW = World.CurWorld
local M = Lib.derive(Base)



M.SIGNAL = {
	DESTROY				= "DESTROY",
	GEOMETRIC_CHANGED	= "GEOMETRIC_CHANGED",
	NAME_CHANGED		= "NAME_CHANGED",
	SELECTED_CHANGED	= "SELECTED_CHANGED"
}

M.ABILITY = {
	MOVE				= 1 << 1,
	SCALE				= 1 << 2,
	ROTATE				= 1 << 3,
	TRANSFORM			= 1 << 1 | 1 << 2 | 1 << 3,
	AABB				= 1 << 4,
	HAVELENGTH			= 1 << 5,
	ANCHORSPACE			= 1 << 6,
	FOCUS 				= 1 << 7,
	FORCE_UPRIGHT		= 1 << 8,
	SELECTABLE			= 1 << 9,
}

local CLASS_ABILITY = {
	["Part"] = M.ABILITY.TRANSFORM | M.ABILITY.AABB | M.ABILITY.FOCUS | M.ABILITY.SELECTABLE,
	["PartOperation"] = M.ABILITY.TRANSFORM | M.ABILITY.AABB | M.ABILITY.FOCUS | M.ABILITY.SELECTABLE,
	["Model"] = M.ABILITY.TRANSFORM | M.ABILITY.AABB | M.ABILITY.FOCUS | M.ABILITY.SELECTABLE,
	["MeshPart"] = M.ABILITY.TRANSFORM | M.ABILITY.AABB | M.ABILITY.FOCUS | M.ABILITY.SELECTABLE,
	["AudioNode"] = M.ABILITY.MOVE | M.ABILITY.AABB | M.ABILITY.FOCUS | M.ABILITY.SELECTABLE,
	["RodConstraint"] = M.ABILITY.HAVELENGTH | M.ABILITY.ANCHORSPACE,
	["SpringConstraint"] = M.ABILITY.HAVELENGTH | M.ABILITY.ANCHORSPACE,
	["RopeConstraint"] = M.ABILITY.HAVELENGTH | M.ABILITY.ANCHORSPACE,
	["SliderConstraint"] = M.ABILITY.ANCHORSPACE,
	["Entity"] = M.ABILITY.TRANSFORM | M.ABILITY.AABB | M.ABILITY.FOCUS | M.ABILITY.FORCE_UPRIGHT | M.ABILITY.SELECTABLE,
	["DropItem"] = M.ABILITY.AABB | M.ABILITY.MOVE | M.ABILITY.FOCUS | M.ABILITY.SELECTABLE,
	["RegionPart"] = M.ABILITY.MOVE | M.ABILITY.SCALE | M.ABILITY.AABB | M.ABILITY.FOCUS | M.ABILITY.SELECTABLE,
	["VoxelTerrain"] = M.ABILITY.FOCUS,
	["Light"] = M.ABILITY.MOVE | M.ABILITY.ROTATE | M.ABILITY.AABB | M.ABILITY.FOCUS | M.ABILITY.SELECTABLE,
	["EmptyNode"] = M.ABILITY.MOVE | M.ABILITY.ROTATE | M.ABILITY.SCALE | M.ABILITY.AABB | M.ABILITY.FOCUS | M.ABILITY.SELECTABLE,
	["PostProcess"] = M.ABILITY.FOCUS,
	["EffectPart"]= M.ABILITY.MOVE | M.ABILITY.ROTATE | M.ABILITY.AABB | M.ABILITY.FOCUS | M.ABILITY.SELECTABLE,
	["ActorNode"] = M.ABILITY.MOVE | M.ABILITY.ROTATE | M.ABILITY.SCALE | M.ABILITY.AABB | M.ABILITY.FOCUS | M.ABILITY.SELECTABLE,
	["MountPoint"] = M.ABILITY.MOVE | M.ABILITY.ROTATE | M.ABILITY.SCALE | M.ABILITY.AABB | M.ABILITY.FOCUS | M.ABILITY.SELECTABLE,
	["FogNode"] = M.ABILITY.FOCUS
}


local PRECISION = 0.01

local function on_transform(self)
	Signal:publish(self, M.SIGNAL.GEOMETRIC_CHANGED)

	if self._parent then
		on_transform(self._parent)
	end
end

-- 可以由引擎主动修改的属性(通常是场景操作，可以批量操作)，为了效率需要做以下考虑
-- 因为是被动属性所以不需要 RECORDE，撤销主属性，它也会调用到这里跟着变
-- 因为属性面板是由 Bunch 统一管理，所以也不需要 SYNC
-- 它们不会再触发其它的属性关联所以也不需要 NOTIFY
-- 特殊对待 SYNC 标记， 目前有 position、rotation、size
local function on_position_changed(self)
	local meta = VN.meta(self._vnode)
	if meta:is("Instance_CSGShape") then
		VN.assign(self._vnode, "massCenter", self._vnode["position"], VN.CTRL_BIT.NONE)
		if meta:is("Instance_MeshPart") then
			--更新编辑器世界锚点
			local pos = self._node:getAnchorPoint()
			VN.assign(self._vnode, "anchorPoint", pos, VN.CTRL_BIT.NONE)
		end
	end

	-- 基于效率考虑拖动过程中统一设置而不是单个 obj 设置
	if not self._on_drag then
		on_transform(self)
	end
end

local function on_rotation_changed(self)
	if not self._on_drag then
		on_transform(self)
	end
end

local function check_effect_part_transform(self)
	VN.assign(
		self._vnode,
		"position", 
		Utils.deseri_prop("Vector3", IInstance:get(self._node, "position")),
		VN.CTRL_BIT.NONE
	)

	VN.assign(
		self._vnode,
		"rotation", 
		Utils.deseri_prop("Vector3", IInstance:get(self._node, "rotation")),
		VN.CTRL_BIT.NONE
	)
end

local function on_size_changed(self)
	if not self._vnode["scale"] then
		return
	end

	VN.assign(
		self._vnode,
		"scale", 
		Utils.deseri_prop("Vector3", IInstance:get(self._node, "scale")),
		VN.CTRL_BIT.NONE
	)

	local meta = VN.meta(self._vnode)
	if meta:is("Instance_CSGShape") then
		local volume = IInstance:get_volume(self._node)
		VN.assign(
			self._vnode, 
			"volume",
			volume,
			VN.CTRL_BIT.NONE
		)
		VN.assign(
			self._vnode,
			"mass",
			volume * self._vnode["density"],
			VN.CTRL_BIT.NONE
		)
	end

	if not self._on_drag then
		on_transform(self)
	end
end

-- 引擎有些计算会延迟，所以在某些属性改变的时候需要主动刷新
local function update_node(self)
	if self._node:isA("PartOperation") then
		-- self._node:updateShape()
		VN.assign(
			self._vnode, 
			"size", 
			Utils.deseri_prop("Vector3", IInstance:get(self._node, "size")),
			VN.CTRL_BIT.NOTIFY
		)
	end
end

-- thoes property can changed by engine
local property_monitor = {
	["position"] = function(self, value)
		local curr = self._vnode["position"]
		if math.abs(curr.x - value.x) < PRECISION and
		   math.abs(curr.y - value.y) < PRECISION and
		   math.abs(curr.z - value.z) < PRECISION then
		   -- 非引擎主动修改
		   return
		end

		if self._on_drag then
			self._record["position"] = self._record["position"] or {}
			self._record["position"].from = self._record["position"].from or VN.value(curr)
			self._record["position"].to = value
			VN.assign(self._vnode, "position", value, VN.CTRL_BIT.NONE)

			-- gitmoz移动3D音效时，更新相对坐标
			if self._vnode["is_relative"] and self._vnode["relative_pos"] then
				local pos = self._node:getLocalPosition()
				VN.assign(self._vnode, "relative_pos", pos, VN.CTRL_BIT.NONE)
			end
			--特效gizmo
			if self._vnode["transform"] then
				if self._vnode["transform"]["pos"] then
					local pos=self._node:getLocalPosition()
					VN.assign(self._vnode.transform,"pos",pos,VN.CTRL_BIT.NONE)
				end
			end
			on_position_changed(self)
		else
			self._vnode["position"] = value
		end
	end,

	["rotation"] = function(self, value)
		local curr = self._vnode["rotation"]
		if math.abs(curr.x - value.x) < PRECISION and
		   math.abs(curr.y - value.y) < PRECISION and
		   math.abs(curr.z - value.z) < PRECISION then
		   -- 非引擎主动修改
		   return
		end

		if self:check_ability(M.ABILITY.FORCE_UPRIGHT) then
			value.x = 0
			value.z = 0
		end

		if self._on_drag then
			self._record["rotation"] = self._record["rotation"] or {}
			self._record["rotation"].from = self._record["rotation"].from or VN.value(curr)
			self._record["rotation"].to = value

			VN.assign(self._vnode, "rotation", value, VN.CTRL_BIT.NONE)
			on_rotation_changed(self)
		else
			self._vnode["rotation"] = value
		end
		--特效gizmo
		if self._vnode["transform"] then
			if self._vnode["transform"]["rotate"] then
				VN.assign(self._vnode.transform,"rotate",value,VN.CTRL_BIT.NONE)
				on_rotation_changed(self)
			end
		end
	end,

	["size"] = function(self, value)
		local curr = self._vnode["size"]
		if math.abs(curr.x - value.x) < PRECISION and
		   math.abs(curr.y - value.y) < PRECISION and
			math.abs(curr.z - value.z) < PRECISION then
			-- 非引擎主动修改
			return
		end

		if self._on_drag then
			self._record["size"] = self._record["size"] or {}
			self._record["size"].from = self._record["size"].from or VN.value(curr)
			self._record["size"].to = value

			VN.assign(self._vnode, "size", value, VN.CTRL_BIT.NONE)
			on_size_changed(self)
		else
			self._vnode["size"] = value
		end
			--特效gizmo
		if self._vnode["transform"] then
			if self._vnode["transform"]["scale"] then
				on_size_changed(self)
			end
		end
	end,

	["scale"] = function(self, value)
		local curr = self._vnode["scale"]
		if math.abs(curr.x - value.x) < PRECISION and
		   math.abs(curr.y - value.y) < PRECISION and
			math.abs(curr.z - value.z) < PRECISION then
			-- 非引擎主动修改
			return
		end

		if self._on_drag then
			self._record["scale"] = self._record["scale"] or {}
			self._record["scale"].from = self._record["scale"].from or VN.value(curr)
			self._record["scale"].to = value

			VN.assign(self._vnode, "scale", value, VN.CTRL_BIT.NONE)
			on_size_changed(self)
		else
			self._vnode["scale"] = value
		end
	end,

	["originSize"] = function(self, value)
		local curr = self._vnode["originSize"]
		if not curr then
			return
		end
		if math.abs(curr.x - value.x) < PRECISION and
		   math.abs(curr.y - value.y) < PRECISION and
			math.abs(curr.z - value.z) < PRECISION then
			-- 非引擎主动修改
			return
		end

		if self._on_drag then
			self._record["originSize"] = self._record["originSize"] or {}
			self._record["originSize"].from = self._record["originSize"].from or VN.value(curr)
			self._record["originSize"].to = value

			VN.assign(self._vnode, "originSize", value, VN.CTRL_BIT.NONE)
			on_size_changed(self)
		else
			self._vnode["originSize"] = value
		end
	end,

	["volume_changed"] = function(self, value)
		if value <= 0.0 then
			return
		end

		local meta = VN.meta(self._vnode)
		if meta:is("Instance_CSGShape") then
			local mass = self._vnode["density"] * value
			VN.assign(self._vnode, "volume", value, VN.CTRL_BIT.NONE)
			VN.assign(self._vnode, "mass", mass, VN.CTRL_BIT.NONE)
		end
	end,

	["light_actived"] = function(self)
		local actived = self._vnode["lightActived"]
		if not actived then
			return
		end
		--引擎调用，不存在复亮的情况
		VN.assign(self._vnode, "lightActived", false, VN.CTRL_BIT.NONE)
	end,

	["local_anchor"] = function(self, value)
		local curr = self._vnode["localAnchorPoint"]
		if math.abs(curr.x - value.x) < PRECISION and
		   math.abs(curr.y - value.y) < PRECISION and
			math.abs(curr.z - value.z) < PRECISION then
			-- 非引擎主动修改
			return
		end

		if self._on_drag then
			self._record["localAnchorPoint"] = self._record["localAnchorPoint"] or {}
			self._record["localAnchorPoint"].from = self._record["localAnchorPoint"].from or VN.value(curr)
			self._record["localAnchorPoint"].to = value

			VN.assign(self._vnode, "localAnchorPoint", value, VN.CTRL_BIT.NONE)
		else
			self._vnode["localAnchorPoint"] = value
		end
	end
}

--在router中调用才能递归
local function model_propagate_to_children(tgt_obj, property_name, filter)
	local cls = tgt_obj:class()
	local function func(obj, val)
		for idx,child in ipairs(obj:children()) do
			if filter==nil or filter(child) then
				child.propagating_tb = child.propagating_tb or {}
				child.propagating_tb[property_name] = true
				VN.assign(child._vnode,property_name,val,VN.CTRL_BIT.NOTIFY | VN.CTRL_BIT.SYNC)
				child.propagating_tb[property_name] = nil
			end
		end
	end

	local nval = tgt_obj._vnode[property_name]
	if cls == "Model" then
		func(tgt_obj, nval)
	else
		if tgt_obj.propagating_tb and tgt_obj.propagating_tb[property_name] then
			func(tgt_obj, nval)
		end
	end
end

local router = {
	["^name"] = function(self, event, oval)
		IInstance:set(self._node,"name",self._vnode["name"])
		if self._node:isA("Entity") then
			self._node:setName(self._vnode["name"])
			self._node:updateShowName()
		end
		Signal:publish(self, M.SIGNAL.NAME_CHANGED, self._vnode["name"])
	end,

	["^edit_custom_collider"]=function(self,event,oval)
	IInstance:set(self._node,"name",self._vnode["name"])
		if self._node:isA("Entity") then
			self._node:setName(self._vnode["name"])
			self._node:updateShowName()
		end
		Signal:publish(self, M.SIGNAL.NAME_CHANGED, self._vnode["name"])
	end,

	["^selected_count"] = function(self,event,oval)
		if not self._selected_inc then
			if self._vnode["selected"] then
				self._vnode["selected"] =  false --is_select
			end
			self._vnode["selected"] = true
		end
	end,

	["^selected$"] = function(self,event,oval)
		self:on_selected(self._vnode["selected"])
		Signal:publish(self, M.SIGNAL.SELECTED_CHANGED,self._vnode["selected"])
	end,

	["^isLockedInEditor"] = function(self, event, oval)
		IInstance:set(self._node,"isLockedInEditor",tostring(self:locked()))
	end,

	["^isVisibleInEditor"] = function(self,event,oval)
		IInstance:set(self._node,"isVisibleInEditor",tostring(self:enabled()))
		IInstance:set_selectable(self._node, self:enabled())
	end,

	["^children$"] = function(self, event, index, oval)
		if event == Def.NODE_EVENT.ON_INSERT then
			local vnode = self._vnode["children"][index]
			local child = Object:create("instance", vnode, self)
			if not self._node then
				return
			end
			IInstance:set_parent(child:node(), self:node())
			table.insert(self._children, index, child)
			local child_trans = child._vnode["transform"]
			local parent_trans = self._vnode["transform"]
			if child_trans and parent_trans then
				local pos = self:node():getPosition()
				local rotate = self:node():getRotation()
				child:node():setPosition({x = pos.x, y = pos.y, z = pos.z})
				child:node():setRotation({x = rotate.x, y = rotate.y, z = rotate.z})
			end
			if child._vnode["useForCollision"] then
				local cls=self:class()
				if cls=="Folder" then
					self:parent():add_primitive(child)
				end
			end
		elseif event == Def.NODE_EVENT.ON_REMOVE then
			local child = table.remove(self._children, index)
			child:dtor()
			if child._vnode["useForCollision"] then
				if self:class()=="Folder" then
					self:parent():remove_primitive(child)
				end
			end
		end

		-- update_node(self)
	end,

	["^position"] = function(self, event, oval)
		IInstance:set(self._node, "position", Utils.seri_prop("Vector3", self._vnode["position"]))
		on_position_changed(self)
	end,

	["^rotation"] = function(self, event, oval)
		IInstance:set(self._node, "rotation", Utils.seri_prop("Vector3", self._vnode["rotation"]))
		on_rotation_changed(self)
	end,

	["^scale$"] = function(self, event, oval)
		IInstance:set(self._node, "scale", Utils.seri_prop("Vector3", self._vnode["scale"]))
	end,

	["^scale/x"] = function(self, event, oval)
		IInstance:set_scale_x(self._node, self._vnode["scale"]["x"])
	end,

	["^scale/y"] = function(self, event, oval)
		IInstance:set_scale_y(self._node, self._vnode["scale"]["y"])
	end,

	["^scale/z"] = function(self, event, oval)
		IInstance:set_scale_z(self._node, self._vnode["scale"]["z"])
	end,

	["^size$"] = function(self, event, oval)
		IInstance:set(self._node, "size", Utils.seri_prop("Vector3", self._vnode["size"]))
		on_size_changed(self)
	end,

	["^size/x"] = function(self, event, oval)
		IInstance:set_size_x(self._node, self._vnode["size"]["x"])
		on_size_changed(self)
	end,
	
	["^size/y"] = function(self, event, oval)
		IInstance:set_size_y(self._node, self._vnode["size"]["y"])
		on_size_changed(self)
	end,
	
	["^size/z"] = function(self, event, oval)
		IInstance:set_size_z(self._node, self._vnode["size"]["z"])
		on_size_changed(self)
	end,
	
	["^mass$"] = function(self, event, oval)
		IInstance:set(self._node, "mass", tostring(self._vnode["mass"]))
	end,

	["^restitution"] = function(self, event, oval)
		IInstance:set(self._node, "restitution", tostring(self._vnode["restitution"]))
	end,

	["^friction"] = function(self, event, oval)
		IInstance:set(self._node, "friction", tostring(self._vnode["friction"]))
	end,

	["^lineVelocity"] = function(self, event, oval)
		IInstance:set(self._node, "lineVelocity", Utils.seri_prop("Vector3", self._vnode["lineVelocity"]))
	end,

	["^angleVelocity"] = function(self, event, oval)
		IInstance:set(self._node, "angleVelocity", Utils.seri_prop("Vector3", self._vnode["angleVelocity"]))
	end,

	["^useAnchor"] = function(self, event, oval)
		IInstance:set(self._node, "useAnchor", tostring(self._vnode["useAnchor"]))
	end,
	["^cameraCollideEnable"] = function(self, event, oval)
		IInstance:set(self._node, "cameraCollideEnable", tostring(self._vnode["cameraCollideEnable"]))
	end,

	["^partNavMeshType"] = function(self, event, oval)
		IInstance:set(self._node, "partNavMeshType", tostring(self._vnode["partNavMeshType"]))
	end,

	
	["^staticObject"] = function(self, event, oval)
		IInstance:set(self._node, "staticObject", tostring(self._vnode["staticObject"]))
	end,

	["^selectable"] = function(self, event, oval)
		IInstance:set(self._node, "selectable", tostring(self._vnode["selectable"]))
	end,
	["^needSync"] = function(self, event, oval)
		IInstance:set(self._node, "needSync", tostring(self._vnode["needSync"]))
	end,

	["^bloom"] = function(self, event, oval)
		IInstance:set(self._node, "bloom", tostring(self._vnode["bloom"]))
	end,

	["^useGravity"] = function(self, event, oval)
		IInstance:set(self._node, "useGravity", tostring(self._vnode["useGravity"]))
	end,

	["^density"] = function(self, event, oval)
		self._vnode["mass"] = self._vnode["density"] * self._vnode["volume"]
		IInstance:set(self._node, "density", tostring(self._vnode["density"]))
	end,

	["^collisionGroup"] = function(self, event, oval)
		IInstance:set(self._node, "collisionGroup", tostring(self._vnode["collisionGroup"]))
	end,

	["^collisionUniqueKey"] = function(self, event, oval)
		IInstance:set(self._node, "collisionUniqueKey", tostring(self._vnode["collisionUniqueKey"]))
	end,

	["^material/color"] = function(self, event, oval)
		IInstance:set(self._node, "materialColor", Utils.seri_prop("Color", self._vnode["material"]["color"]))
	end,

	["^material/texture"] = function(self, event, oval)
		IInstance:set(self._node, "materialTexture", Utils.seri_prop("PartTexture", self._vnode["material"]["texture"]))
	end,

	["^material/offset"] = function(self, event, oval)
		IInstance:set(self._node, "materialOffset", Utils.seri_prop("Vector3", self._vnode["material"]["offset"]))
	end,

	["^material/alpha"] = function(self, event, oval)
		IInstance:set(self._node, "materialAlpha", tostring(self._vnode["material"]["alpha"]))
	end,

	["^material/useTextureAlpha"] = function(self, event, oval)
		IInstance:set(self._node, "useTextureAlpha", tostring(self._vnode["material"]["useTextureAlpha"]))
	end,

	["^material/discardAlpha"] = function(self, event, oval)
		IInstance:set(self._node, "discardAlpha", tostring(self._vnode["material"]["discardAlpha"]))
	end,

	["^csgShapeVisible"] = function(self, event, oval)
		IInstance:set(self._node, "visible", tostring(self._vnode["csgShapeVisible"]))
	end,

	["^csgShapeEffect/asset"] = function(self, event, oval)
		IInstance:set(self._node, "effectFilePath", tostring(self._vnode["csgShapeEffect"]["asset"]))
	end,

	["^actorObject/asset"] = function(self, event, oval)
		IInstance:set(self._node, "actorTemplate", tostring(self._vnode["actorObject"]["asset"]))
	end,

	["^transform/pos"] = function(self, event, oval)
		local pos = {x = 0, y = 0, z = 0}
		pos.x = self._vnode["transform"]["pos"]["x"]
		pos.y = self._vnode["transform"]["pos"]["y"]
		pos.z = self._vnode["transform"]["pos"]["z"]
	    self._node:setLocalPosition(pos)
		check_effect_part_transform(self)
	end,

	["^transform/rotate"] = function(self, event, oval)
		local rotate = {x = 0, y = 0, z = 0}
		rotate.x = self._vnode["transform"]["rotate"]["x"]
		rotate.y = self._vnode["transform"]["rotate"]["y"]
		rotate.z = self._vnode["transform"]["rotate"]["z"]
		self._node:setLocalRotation(rotate)
		check_effect_part_transform(self)
	end,

	["^transform/scale"] = function(self, event, oval)
		IInstance:set(self._node, "scale", Utils.seri_prop("Vector3", self._vnode["transform"]["scale"]))
	end,

	["^xform/pos"] = function(self, event, oval)
		IInstance:set(self._node, "pos", Utils.seri_prop("Vector3", self._vnode["xform"]["pos"]))
	end,

	["^xform/rotate"] = function(self, event, oval)
		IInstance:set(self._node, "scale", Utils.seri_prop("Vector3", self._vnode["xform"]["rotate"]))
	end,

	["^xform/scale"] = function(self, event, oval)
		IInstance:set(self._node, "scale", Utils.seri_prop("Vector3", self._vnode["xform"]["scale"]))
	end,

	["^relative_pos"] = function(self, event, oval)
		local pos = {x = 0, y = 0, z = 0}
		pos.x = self._vnode["relative_pos"]["x"]
		pos.y = self._vnode["relative_pos"]["y"]
		pos.z = self._vnode["relative_pos"]["z"]
	    self._node:setLocalPosition(pos)
		VN.assign(
			self._vnode,
			"position", 
			Utils.deseri_prop("Vector3", IInstance:get(self._node, "position")),
			VN.CTRL_BIT.NONE
		)
	end,

	["^loop/enable"] = function(self, event, oval)
		if self._vnode["loop"]["enable"]  then
			IInstance:set(self._node, "loopCount", tostring(-self._vnode["loop"]["play_times"]))
		else
			IInstance:set(self._node, "loopCount", tostring(self._vnode["loop"]["play_times"]))
		end
	end,

	["^loop/play_times"] = function(self, event, oval)
		if self._vnode["loop"]["enable"] then
			IInstance:set(self._node, "loopCount", tostring(-self._vnode["loop"]["play_times"]))
		else
			IInstance:set(self._node, "loopCount", tostring(self._vnode["loop"]["play_times"]))
		end
	end,

	["^loop/interval"] = function(self, event, oval)
		IInstance:set(self._node, "loopInterval", tostring(self._vnode["loop"]["interval"]))
	end,

	["^loop/reset"] = function(self, event, oval)
		IInstance:set(self._node, "loopReset", tostring(self._vnode["loop"]["reset"]))
	end,

	["^shape"] = function(self, event, oval)
		IInstance:set_shape(self._node, tostring(self._vnode["shape"]))
	end,

	["^slavePartID"] = function(self, event, oval)
		IInstance:set(self._node, "slavePartID", tostring(self._vnode["slavePartID"]))
	end,

	["^masterLocalPos"] = function(self, event, oval)
		local master_pivot = IWorld:get_instance(self._node:getMasterPivotID())
		local instance = IInstance:get_parent(self._node)
		local pos = instance:toWorldPosition(self._vnode["masterLocalPos"])
		IInstance:set_world_pos(master_pivot,pos)
	end,

	["^masterWorldPos"] = function(self, event, oval)
		local master_pivot = IWorld:get_instance(self._node:getMasterPivotID())
		IInstance:set_world_pos(master_pivot,self._vnode["masterWorldPos"])
	end,

	["^slaveLocalPos"] = function(self, event, oval)
		local slave_pivot = IWorld:get_instance(self._node:getSlavePivotID())
		local instance = IWorld:get_instance(self._node:getSlavePartID())
		if instance then
			local pos = instance:toWorldPosition(self._vnode["slaveLocalPos"])
			IInstance:set_world_pos(slave_pivot,pos)
		end
	end,

	["^slaveWorldPos"] = function(self, event, oval)
		local slave_pivot = IWorld:get_instance(self._node:getSlavePivotID())
		IInstance:set_world_pos(slave_pivot,self._vnode["slaveWorldPos"])
	end,

	["^collision$"] = function(self, event, oval)
		IInstance:set(self._node, "collision", tostring(self._vnode["collision"]))
	end,

	["^useSpring"] = function(self, event, oval)
		IInstance:set(self._node, "useSpring", tostring(self._vnode["useSpring"]))
	end,

	["^stiffness"] = function(self, event, oval)
		IInstance:set(self._node, "stiffness", tostring(self._vnode["stiffness"]))
	end,

	["^damping"] = function(self, event, oval)
		IInstance:set(self._node, "damping", tostring(self._vnode["damping"]))
	end,

	["^springTargetAngle"] = function(self, event, oval)
		IInstance:set(self._node, "springTargetAngle", tostring(self._vnode["springTargetAngle"]))
	end,

	["^angleUpperLimit"] = function(self, event, oval)
		IInstance:set(self._node, "angleUpperLimit", tostring(self._vnode["angleUpperLimit"]))
	end,

	["^angleLowerLimit"] = function(self, event, oval)
		IInstance:set(self._node, "angleLowerLimit", tostring(self._vnode["angleLowerLimit"]))
	end,

	["^useMotor"] = function(self, event, oval)
		IInstance:set(self._node, "useMotor", tostring(self._vnode["useMotor"]))
	end,

	["^motorTargetAngleVelocity"] = function(self, event, oval)
		IInstance:set(self._node, "motorTargetAngleVelocity", tostring(self._vnode["motorTargetAngleVelocity"]))
	end,

	["^useAngleLimit"] = function(self, event, oval)
		IInstance:set(self._node, "useAngleLimit", tostring(self._vnode["useAngleLimit"]))
	end,

	["^angleUpperLimit"] = function(self, event, oval)
		IInstance:set(self._node, "angleUpperLimit", tostring(self._vnode["angleUpperLimit"]))
	end,

	["^angleLowerLimit"] = function(self, event, oval)
		IInstance:set(self._node, "angleLowerLimit", tostring(self._vnode["angleLowerLimit"]))
	end,

	["^motorForce"] = function(self, event, oval)
		IInstance:set(self._node, "motorForce", tostring(self._vnode["motorForce"]))
	end,

	["^radius"] = function(self, event, oval)
		IInstance:set(self._node, "radius", tostring(self._vnode["radius"]))
	end,

	["^length"] = function(self, event, oval)
		IInstance:set(self._node, "length", tostring(self._vnode["length"]))
	end,

	["^visible"] = function(self, event, oval)
		IInstance:set(self._node, "visible", tostring(self._vnode["visible"]))
	end,

	["^fixedJustify"] = function(self, event, oval)
		IInstance:set(self._node, "fixedJustify", tostring(self._vnode["fixedJustify"]))
	end,

	["^thickness"] = function(self, event, oval)
		IInstance:set(self._node, "thickness", tostring(self._vnode["thickness"]))
	end,

	["^coil"] = function(self, event, oval)
		IInstance:set(self._node, "coil", tostring(self._vnode["coil"]))
	end,

	["^color"] = function(self, event, oval)
		IInstance:set(self._node, "color", Utils.seri_prop("Color", self._vnode["color"]))
	end,

	["^upperLimit"] = function(self, event, oval)
		IInstance:set(self._node, "upperLimit", tostring(self._vnode["upperLimit"]))
	end,

	["^lowerLimit"] = function(self, event, oval)
		IInstance:set(self._node, "lowerLimit", tostring(self._vnode["lowerLimit"]))
	end,
	
	["^booleanOperation"] = function(self, event, oval)
		IInstance:set(self._node, "booleanOperation", tostring(self._vnode["booleanOperation"]))
	end,

	["^decalOffset"] = function(self, event, oval)
		local val = { x = self._vnode["decalOffset"].x, y = self._vnode["decalOffset"].y, z = 0 }
		IInstance:set(self._node, "decalOffset", Utils.seri_prop("Vector3", val))
	end,

	["^decalColor"] = function(self, event, oval)
		IInstance:set(self._node, "decalColor", Utils.seri_prop("Color", self._vnode["decalColor"]))
	end,

	["^decalAlpha"] = function(self, event, oval)
		IInstance:set(self._node, "decalAlpha", tostring(self._vnode["decalAlpha"]))
	end,

	["^decalSurface"] = function(self, event, oval)
		IInstance:set(self._node, "decalSurface", tostring(self._vnode["decalSurface"]))
	end,

	["^decalImageType"] = function(self, event, oval)
		IInstance:set(self._node, "decalImageType", tostring(self._vnode["decalImageType"]))
	end,

	["^decalTiling"] = function(self, event, oval)
		local val = { x = self._vnode["decalTiling"].x, y = self._vnode["decalTiling"].y, z = 0 }
		IInstance:set(self._node, "decalTiling", Utils.seri_prop("Vector3", val))
	end,

	["^decalTexture/asset"] = function(self, event, oval)
		IInstance:set(self._node, "decalTexture", self._vnode["decalTexture"]["asset"])
	end,

	["^force"] = function(self, event, oval)
		IInstance:set(self._node,"force",Utils.seri_prop("Vector3",self._vnode["force"]))
	end,

	["^useRelativeForce"] = function(self, event, oval)
		IInstance:set(self._node,"useRelativeForce",tostring(self._vnode["useRelativeForce"]))
	end,

	["^torque"] = function(self, event, oval)
		IInstance:set(self._node,"torque",Utils.seri_prop("Vector3",self._vnode["torque"]))
	end,

	["^useRelativeTorque"] = function(self, event, oval)
		IInstance:set(self._node,"useRelativeTorque",tostring(self._vnode["useRelativeTorque"]))
	end,

	["^customThreshold"] = function(self, event, oval)
		IInstance:set(self._node,"customThreshold",tostring(self._vnode["customThreshold"]))
	end,

	["^mesh"] = function(self, event, oval)
		IInstance:set(self._node,"mesh",tostring(self._vnode["mesh"]))
	end,

	["^roughness"] = function(self, event, oval)
		IInstance:set(self._node,"roughness",tostring(self._vnode["roughness"]))
	end,

	["^metalness"] = function(self, event, oval)
		IInstance:set(self._node,"metalness",tostring(self._vnode["metalness"]))
	end,
	
	["^fixRotation"] = function(self, event, oval)
		IInstance:set(self._node,"fixRotation",tostring(not self._vnode["fixRotation"]))
	end,

	["^originAnchor"] = function(self, event, oval)
		IInstance:set(self._node,"originAnchor",tostring(self._vnode["originAnchor"]))
		
		if Receptor:binding() then 
			Signal:publish(Receptor:binding(), Receptor.SIGNAL.ANCHOR_CHANGE)
		end
		--更新编辑器世界锚点
		local pos = self._node:getAnchorPoint()
		VN.assign(self._vnode, "anchorPoint", pos, VN.CTRL_BIT.NONE)
	end,
	["^anchorPoint"] = function(self, event, oval)
		IInstance:set(self._node, "anchorPoint", Utils.seri_prop("Vector3", self._vnode["anchorPoint"]))
		
		if Receptor:binding() then 
			Signal:publish(Receptor:binding(), Receptor.SIGNAL.ANCHOR_CHANGE)
		end
	end,

	["^isTop"] = function(self, event, oval)
		IInstance:set(self._node,"isTop",tostring(self._vnode["isTop"]))
	end,

	["^isFaceCamera"] = function(self, event, oval)
		IInstance:set(self._node,"isFaceCamera",tostring(self._vnode["isFaceCamera"]))
	end,

	["^rangeDistance"] = function(self, event, oval)
		IInstance:set(self._node, "rangeDistance", tostring(self._vnode["rangeDistance"]))
	end,

	["^layoutFile/asset"] = function(self, event, oval)
		local path = self._vnode["layoutFile"]["asset"]
		local asset_path = string.sub(path,7,string.len(path))
		IInstance:set(self._node, "layoutFile", asset_path)
	end,

	["^uiScaleMode"] = function(self, event, oval)
		IInstance:set(self._node, "uiScaleMode", self._vnode["uiScaleMode"] and "0" or "1")
	end,

	["^stretch"] = function(self, event, oval)
		IInstance:set(self._node, "stretch", tostring(self._vnode["stretch"]))
	end,

	["^isLock$"] = function(self, event, oval)
		IInstance:set(self._node, "isLock", tostring(self._vnode["isLock"]))
	end,

	["^staticBatchNo"] = function(self, event, oval)
		if self:class() == "MeshPart" then
			return
		end

		IInstance:set(self._node, "staticBatchNo", tostring(self._vnode["staticBatchNo"]))
	end,

	["^batchType$"] = function(self, event, oval)
		model_propagate_to_children(self,"batchType", function(obj)
			return Def.PROP_SUPPORT_TYPE.batchType[obj:class()] ~= nil
		end)
		IInstance:set(self._node, "batchType", tostring(self._vnode["batchType"]))
	end,

	["^collisionFidelity$"] = function(self, event, oval)
		local isEditting,id=State:get_custom_collision_editing()
		if isEditting and id~="" and self._vnode["collisionFidelity"]~="6"  then
			if self._vnode["customCollision"]["isEditing"] then
				self:saveCollision(id)
				State:set_custom_collision_editing(false,"")
				self._vnode["customCollision"]["isEditing"]=false
			end
		end
		IInstance:set(self._node, "collisionFidelity", self._vnode["collisionFidelity"])
	end,

	["^lightType"] = function(self, event, oval)
		IInstance:set(self._node, "lightType", tostring(self._vnode["lightType"]))
	end,

	["^skyColor"] = function(self, event, oval)
		IInstance:set(self._node, "skyColor", Utils.seri_prop("Color", self._vnode["skyColor"]))
	end,

	["^skyLineColor"] = function(self, event, oval)
		IInstance:set(self._node, "skyLineColor", Utils.seri_prop("Color", self._vnode["skyLineColor"]))
	end,

	["^lightColor"] = function(self, event, oval)
		IInstance:set(self._node, "lightColor", Utils.seri_prop("Color", self._vnode["lightColor"]))
	end,

	["^lightBrightness"] = function(self, event, oval)
		IInstance:set(self._node, "lightBrightness", tostring(self._vnode["lightBrightness"]))
	end,

	["^lightRange"] = function(self, event, oval)
		IInstance:set(self._node, "lightRange", tostring(self._vnode["lightRange"]))
	end,

	["^lightAngle"] = function(self, event, oval)
		IInstance:set(self._node, "lightAngle", tostring(self._vnode["lightAngle"]))
	end,

	["^lightLength"] = function(self, event, oval)
		IInstance:set(self._node, "lightLength", tostring(self._vnode["lightLength"]))
	end,

	["^lightWidth"] = function(self, event, oval)
		IInstance:set(self._node, "lightWidth", tostring(self._vnode["lightWidth"]))
	end,

	["^lightActived"] = function(self, event, oval)
		IInstance:set(self._node, "lightActived", tostring(self._vnode["lightActived"]))
	end,

	["^shadows/shadowsType"] = function(self, event, oval)
		IInstance:set(self._node, "shadowsType", tostring(self._vnode["shadows"]["shadowsType"]))
	end,

	["^shadows/shadowsIntensity"] = function(self, event, oval)
		IInstance:set(self._node, "shadowsIntensity", tostring(self._vnode["shadows"]["shadowsIntensity"]))
	end,

	["^shadows/shadowsOffset"] = function(self, event, oval)
		IInstance:set(self._node, "shadowsOffset", tostring(self._vnode["shadows"]["shadowsOffset"]))
	end,

	["^shadows/shadowsPresicion"] = function(self, event, oval)
		IInstance:set(self._node, "shadowsPresicion", tostring(self._vnode["shadows"]["shadowsPresicion"]))
	end,

	["^shadows/shadowsDistance"] = function(self, event, oval)
		IInstance:set(self._node, "shadowsDistance", tostring(self._vnode["shadows"]["shadowsDistance"]))
	end,

	["^lodData/lodModelItem$"]=function(self,event,oval)
		if event==4 then
			self._node:removeLodData(oval-1)
		end
		local lodData=self._vnode["lodData"]
		for k,v in pairs(lodData.lodModelItem) do
			v["id"]=k-1
		end

	end,
	["^replaceLodModel$"]=function(self,event,oval,path)
		IInstance:set(self._node,"useLodModel",tostring(self._vnode.replaceLodModel))
	end,

	["^lodData/lodModelItem/[0-9]+/"]=function(self,event,oval,path)
		local func=function(indexstr)
			local index=tonumber(indexstr)
			print(index)
			print(oval)
			local lodModelItem=self._vnode["lodData"]["lodModelItem"][indexstr]
			self._node:updateLodData(lodModelItem.id,lodModelItem.distance,lodModelItem.meshName)
		end
		string.gsub(path,"[0-9]+",func)
	end,
	["^materialData/customMaterialData/renderFace$"]=function(self,event,oval,path)
		local val=self:get_custom_material().renderFace
		local modelEntity=self:get_model_entity()
		local material=self:get_material()
		material:setCullMode(tonumber(val))
		self:on_material_changed()
	end,

	["^materialData/materialSelector/asset$"]=function(self,event,oval,path)
		local val=self._vnode.materialData.materialSelector.asset	
		self._vnode.materialData.materialPath=val
		self:init_material_vnode(val)
		self:on_material_changed()
	end,

	["^materialData/customMaterialData/alpha$"]=function(self,event,oval,path)
		local val=self:get_custom_material().alpha
		local modelEntity=self:get_model_entity()
		local color=self:get_custom_material().baseMap.color
		modelEntity:setCustomColor({color.r/255,color.g/255,color.b/255,val})
		self:on_material_changed()
	end,

	["^materialData/customMaterialData/alphaClippingThreshold$"]=function(self,event,oval,path)
		local modelEntity=self:get_model_entity()
		local val=	self._vnode.materialData.customMaterialData.alphaClippingThreshold
		modelEntity:setCustomThreshold(val)
		-- self._node:refreshMaterial()
		self:on_material_changed()
	end,
	["^materialData/customMaterialData/baseMap/mapPath$"]=function(self,event,oval,path)	
		local material=self:get_material()	
		-- local material = self._node:getMaterialForClient();
		local val=self:get_custom_material().baseMap.mapPath	
		material:activeTexture(0,val)
		material:setDiffuseTexture(val)
		material:setEnableDiffuseTexture(true)
		self._node:setMaterialForClient(material)
		self:get_model_entity():setMaterial(material)
		--self._node:refreshMaterial()
		self:on_material_changed()
	end,

	["^materialData/customMaterialData/baseMap/color"]=function(self,event,oval,path)
		local val=self:get_custom_material().baseMap.color
		local modelEntity=self:get_model_entity()
		modelEntity:setCustomColor({val.r/255,val.g/255,val.b/255,self:get_custom_material().alpha})
		local material = self:get_material()
		material:setCustomColor({val.r/255,val.g/255,val.b/255,self:get_custom_material().alpha})
		self._node:setMaterialForClient(material)
		--self._node:refreshMaterial()
		self:on_material_changed()
	end,
	["^materialData/customMaterialData/baseMap/tiling"]=function(self,event,oval,path)
		local val=self:get_custom_material().baseMap.tiling
		local modelEntity=self:get_model_entity()
		modelEntity:setTill(val.x)
		--local material = self._node:getMaterial()
		--material:setTill(val.x)
		--self._node:setMaterialForClient(till)
		self:on_material_changed()
	end,
	["^materialData/customMaterialData/baseMap/offset"]=function(self,event,oval,path)
		local val=self:get_custom_material().baseMap.offset
		local modelEntity=self:get_model_entity()
		modelEntity:setPartUVOffset({x=val.x,y=val.y})
		self:on_material_changed()
	end,
	["^materialData/customMaterialData/specularMap/roughness$"]=function(self,event,oval,path)
		local material=self:get_material()
		material:setDefineWithBool("SPECULAR", true)
		local val=self:get_custom_material().specularMap.roughness
		local modelEntity=self:get_model_entity()
		self:on_material_changed()
	end,

	["^materialData/customMaterialData/specularMap/mapPath$"]=function(self,event,oval,path)
		local val=self:get_custom_material().specularMap.mapPath
		if val=="" then 
			self:get_material():removeDefine("SPECULAR")
		else
			self:get_material():setDefineWithBool("SPECULAR",true)
		end
		local modelEntity=self:get_model_entity()
		modelEntity:setSpecularSampler(Def.SPECULAR_SLOT,val)
		local material=self:get_material()
		material:setSpecularSampler(Def.SPECULAR_SLOT, val)
		--self._node:refreshMaterial()
		self._node:setMaterialForClient(material)
		self:on_material_changed()
	end,

	["^materialData/customMaterialData/normalMap/mapPath$"]=function(self,event,oval,path)
		local val=self:get_custom_material().normalMap.mapPath	
		local material=self:get_material()
		if val=="" then 
			material:removeDefine("BUMP")
		else
			material:setDefineWithBool("BUMP",true)
		end
		material:rebuild()
		local modelEntity=self:get_model_entity()
		modelEntity:setBumpSampler(Def.BUMP_SLOT,val)
		material:setBumpSampler(Def.BUMP_SLOT, val)
		--self._node:refreshMaterial()
		self._node:setMaterialForClient(material)
		self:on_material_changed()
	end,

	["^materialData/customMaterialData/normalMap/bumpScale$"]=function(self,event,oval,path)
	    local val=self:get_custom_material().normalMap.bumpScale
		local modelEntity=self:get_model_entity()
		local material=self:get_material()
		local vec3=modelEntity:getBumpInfos()
		vec3.y=val
		self._vnode.materialData.customMaterialData.normalMap.bumpScaleVec=vec3
		material:setBumpInfos(vec3)
		modelEntity:setBumpInfos(vec3)
		self._node:setMaterial(material)
		self._node:setMaterialForClient(material)
		self:on_material_changed()
	end,

	["^materialData/customMaterialData/emissionData/color"]=function(self,event,oval,path)
		local modelEntity=self:get_model_entity()
		local material=self:get_material()
		local val=self:get_custom_material().emissionData.color
		modelEntity:setEmissionColor({x=val.r/255,y=val.g/255,z=val.b/255})
		material:setEmissionColor({x=val.r/255,y=val.g/255,z=val.b/255})
		self._node:setMaterialForClient(material)
		--self._node:refreshMaterial()
		self:on_material_changed()
	end,

	["^materialData/customMaterialData/emissionData/mapPath$"]=function(self,event,oval,path)
		local modelEntity=self:get_model_entity()
		local material=self:get_material()
		local val=	self:get_custom_material().emissionData.mapPath
		if val=="" then 
			self:get_material():removeDefine("EMISSION")
		else
			material:setDefineWithBool("EMISSION", true)
		end	
		modelEntity:setEmissionSampler(Def.EMISSION_SLOT,val)
		material:setEmissionSampler(Def.EMISSION_SLOT, val)
		self._node:setMaterialForClient(material)
		--self._node:refreshMaterial()
		self:on_material_changed()
	end,

	["^materialData/customMaterialData/matarialOption/castShadows$"]=function(self,event,oval,path)
		local val=self:get_custom_material().matarialOption.castShadows
		IInstance:set(self._node,"castShadow",tostring(val))
		self:on_material_changed()
	end,

	["^materialData/customMaterialData/matarialOption/ReceiveShadows$"]=function(self,event,oval,path)
		local val=self:get_custom_material().matarialOption.ReceiveShadows
		IInstance:set(self._node,"receiveShadow",tostring(val))
		self:on_material_changed()
	end,

	["^postProcessBloom/enableBloom$"] = function(self, event, oval)
		IInstance:set(self._node, "enableBloom", tostring(self._vnode["postProcessBloom"]["enableBloom"]))
	end,

	["^postProcessBloom/fullScreenBloom$"] = function(self, event, oval)
		IInstance:set(self._node, "fullScreenBloom", tostring(self._vnode["postProcessBloom"]["fullScreenBloom"]))
	end,

	["^postProcessBloom/ignoreMainLight$"] = function(self, event, oval)
		IInstance:set(self._node, "ignoreMainLight", tostring(self._vnode["postProcessBloom"]["ignoreMainLight"]))
	end,

	["^postProcessBloom/bloomIsAttenuation$"] = function(self, event, oval)
		IInstance:set(self._node, "bloomIsAttenuation", tostring(self._vnode["postProcessBloom"]["bloomIsAttenuation"]))
	end,

	["^postProcessBloom/intensity$"] = function(self, event, oval)
		IInstance:set(self._node, "intensity", tostring(self._vnode["postProcessBloom"]["intensity"]))
	end,

	["^postProcessBloom/threshold$"] = function(self, event, oval)
		IInstance:set(self._node, "threshold", tostring(self._vnode["postProcessBloom"]["threshold"]))
	end,

	["^postProcessBloom/saturation$"] = function(self, event, oval)
		IInstance:set(self._node, "saturation", tostring(self._vnode["postProcessBloom"]["saturation"]))
	end,

	["^postProcessBloom/blurType$"] = function(self, event, oval)
		IInstance:set(self._node, "blurType", tostring(self._vnode["postProcessBloom"]["blurType"]))
	end,

	["^postProcessBloom/gaussianBlurDeviation$"] = function(self, event, oval)
		IInstance:set(self._node, "gaussianBlurDeviation", tostring(self._vnode["postProcessBloom"]["gaussianBlurDeviation"]))
	end,

	["^postProcessBloom/gaussianBlurMultiplier$"] = function(self, event, oval)
		IInstance:set(self._node, "gaussianBlurMultiplier", tostring(self._vnode["postProcessBloom"]["gaussianBlurMultiplier"]))
	end,

	["^postProcessBloom/gaussianBlurSampler$"] = function(self, event, oval)
		IInstance:set(self._node, "gaussianBlurSampler", tostring(self._vnode["postProcessBloom"]["gaussianBlurSampler"]))
	end,

	["^postProcessBloom/iterations$"] = function(self, event, oval)
		IInstance:set(self._node, "iterations", tostring(self._vnode["postProcessBloom"]["iterations"]))
	end,

	["^postProcessBloom/offset$"] = function(self, event, oval)
		IInstance:set(self._node, "offset", tostring(self._vnode["postProcessBloom"]["offset"]))
	end,

	["^canAcceptShadow$"] = function(self,event,oval,path)
		model_propagate_to_children(self,"canAcceptShadow", function(obj)
			return Def.PROP_SUPPORT_TYPE.bake_enable[obj:class()] ~= nil
		end)
		IInstance:set(self._node, "canAcceptShadow", tostring(self._vnode["canAcceptShadow"]))
	end,

	["^canGenerateShadow$"] = function(self,event,oval,path)
		model_propagate_to_children(self,"canGenerateShadow", function(obj)
			return Def.PROP_SUPPORT_TYPE.bake_enable[obj:class()] ~= nil
		end)
		IInstance:set(self._node, "canGenerateShadow", tostring(self._vnode["canGenerateShadow"]))
	end,

	["^bakeTextureWeight$"] = function(self,event,oval,path)
		model_propagate_to_children(self,"bakeTextureWeight", function(obj)
			return Def.PROP_SUPPORT_TYPE.bake_enable[obj:class()] ~= nil
		end)
		IInstance:set(self._node, "bakeTextureWeight", tostring(self._vnode["bakeTextureWeight"]))
	end,

	-- 文字贴花
	["^textDecalRotationZ"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalRotationZ", tostring(self._vnode["textDecalRotationZ"]))
	end,

	["^textDecalText$"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalText", tostring(self._vnode["textDecalText"]))
	end,

	["^textDecalFontStyle"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalFontStyle", tostring(self._vnode["textDecalFontStyle"]))
	end,

	["^textDecalPosition"] = function(self, event, oval)
		local val = { x = self._vnode["textDecalPosition"].x, y = self._vnode["textDecalPosition"].y, z = self._vnode["textDecalPosition"].z }
		IInstance:set(self._node, "textDecalPosition", Utils.seri_prop("Vector3", val))
	end,

	["^textDecalSize"] = function(self, event, oval)
		local val = { x = self._vnode["textDecalSize"].x, y = self._vnode["textDecalSize"].y, z = self._vnode["textDecalSize"].z }
		IInstance:set(self._node, "textDecalSize", Utils.seri_prop("Vector3", val))
	end,

	["^textDecalFontSize"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalFontSize", tostring(self._vnode["textDecalFontSize"]))
	end,

	["^textDecalAutoScale"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalAutoScale", tostring(self._vnode["textDecalAutoScale"]))
	end,

	["^textDecalAutoTextScale"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalAutoTextScale", tostring(self._vnode["textDecalAutoTextScale"]))
	end,

	["^textDecalMinAutoTextScale"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalMinAutoTextScale", tostring(self._vnode["textDecalMinAutoTextScale"]))
	end,

	["^textDecalTextBoldWeight"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalTextBoldWeight", tostring(self._vnode["textDecalTextBoldWeight"]))
	end,

	["^textDecalTextColor"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalTextColor", Utils.seri_prop("Color", self._vnode["textDecalTextColor"]))
	end,

	["^textDecalBackgroundEnabled"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalBackgroundEnabled", tostring(self._vnode["textDecalBackgroundEnabled"]))
	end,

	["^textDecalBackgroundColor"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalBackgroundColor", Utils.seri_prop("Color", self._vnode["textDecalBackgroundColor"]))
	end,

	["^textDecalFrameEnabled"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalFrameEnabled", tostring(self._vnode["textDecalFrameEnabled"]))
	end,

	["^textDecalFrameColor"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalFrameColor", Utils.seri_prop("Color", self._vnode["textDecalFrameColor"]))
	end,

	["^textDecalWordWrapped"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalWordWrapped", tostring(self._vnode["textDecalWordWrapped"]))
	end,

	["^textDecalTextWordBreak"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalTextWordBreak", tostring(self._vnode["textDecalTextWordBreak"]))
	end,

	["^textDecalHorzFormatting"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalHorzFormatting", tostring(self._vnode["textDecalHorzFormatting"]))
	end,

	["^textDecalVertFormatting"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalVertFormatting", tostring(self._vnode["textDecalVertFormatting"]))
	end,

	["^textDecalBorderEnabled"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalBorderEnabled", tostring(self._vnode["textDecalBorderEnabled"]))
	end,

	["^textDecalBorderWidth"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalBorderWidth", tostring(self._vnode["textDecalBorderWidth"]))
	end,

	["^textDecalBorderColor"] = function(self, event, oval)
		IInstance:set(self._node, "textDecalBorderColor", Utils.seri_prop("Color", self._vnode["textDecalBorderColor"]))
	end,

	["^fogType"] = function(self, event, oval)
		IInstance:set(self._node, "fogType", tostring(self._vnode["fogType"]))
	end,

	["^fogColor"] = function(self, event, oval)
		IInstance:set(self._node, "fogColor", Utils.seri_prop("Color", self._vnode["fogColor"]))
	end,

	["^fogDensity"] = function(self, event, oval)
		IInstance:set(self._node, "density", tostring(self._vnode["fogDensity"]))
	end,

	["^fogAlpha"] = function(self, event, oval)
		IInstance:set(self._node, "fogAlpha", tostring(self._vnode["fogAlpha"]))
	end,

	["^fogStart"] = function(self, event, oval)
		IInstance:set(self._node, "fogStart", tostring(self._vnode["fogStart"]))
	end,

	["^fogEnd"] = function(self, event, oval)
		IInstance:set(self._node, "fogEnd", tostring(self._vnode["fogEnd"]))
	end,

	["^showFog"] = function(self, event, oval)
		IInstance:set(self._node, "showFog", tostring(self._vnode["showFog"]))
	end,

	["^maxViewDistance"]=function(self,event,oval)
		IInstance:set(self._node,"maxViewDistance",tostring(self._vnode["maxViewDistance"]))
	end
}

function M:on_material_changed()
	--local materialJson=IInstance:get(self._node,"pastmaterial")
	local  materialJson = self._node:getMaterial()
	self._vnode.materialData.materialJson=materialJson
	Bunch:mark_dirty("materialData", "materialJson")
end

function M:get_material()
	--local modelEntity=self._node:getModelEntity()
	--local material=modelEntity:getMaterial()
	local material = self._node:getMaterialForClient();
	return material
end

function M:get_model_entity()
	local modelEntity=self._node:getPartModelModelEntity()
	return modelEntity
end

function M:get_custom_material()
    local customMaterialData=self._vnode.materialData.customMaterialData
	return customMaterialData
end

function M:get_material_map_slot(path)
	local slot=self:get_custom_material()[path].slot	
	slot=self:get_material():findSlotByTextureStageUsed(slot)
	VN.assign(self._vnode.materialData.customMaterialData[path],
		"slot",
		slot,
		VN.CTRL_BIT.NONE)
	return slot
end

function M:save_material_as_template(filePath)
	print(filePath)
	local material=self:get_material()
	material:saveToFile(filePath)
	VN.assign(
		self._vnode.materialData,
		"materialPath",
		filePath,
		VN.CTRL_BIT.NONE
	)
	VN.assign(
		self._vnode.materialData.materialSelector,
		"asset",
		filePath,
		VN.CTRL_BIT.NONE
	)
	VN.assign(
		self._vnode.materialData,
		"editCustomMaterial",
		false,
		VN.CTRL_BIT.NONE
	)
	Bunch:mark_dirty("materialData","materialPath")
	Bunch:mark_dirty("materialData/materialSelector","asset")
end

function M:set_material_by_drag(filePath)
	VN.assign(
		self._vnode.materialData.materialSelector,
		"asset",
		filePath,
		VN.CTRL_BIT.NOTIFY
	)
	Bunch:mark_dirty("materialData", "materialSelector")
end

function M:init_material_vnode(filePath)
	VN.assign(
		self._vnode.materialData.customMaterialData,
		"enableSpecular",
		false,
		VN.CTRL_BIT.NOTIFY
	)
	VN.assign(
		self._vnode.materialData.customMaterialData,
		"enableNormal",
		false,
		VN.CTRL_BIT.NOTIFY
		)
	VN.assign(
		self._vnode.materialData.customMaterialData,
		"enableEmission",
		false,
		VN.CTRL_BIT.NOTIFY
		)

	VN.assign(self._vnode.materialData,
		"editCustomMaterial",
		false,
		VN.CTRL_BIT.NOTIFY
	)

	Bunch:mark_dirty("materialData", "customMaterialData")
	Bunch:mark_dirty("materialData", "editCustomMaterial")
	
	self._vnode.materialData.customMaterialData = Meta:meta("CustomMaterialData"):ctor()
	if not filePath or filePath=="" then
		return
	end
	local name=string.match(filePath,"[A-z0-9]+.mtl")
	name=string.match(name,"[A-z]+")
	local modelEntity=self:get_model_entity()
	local material = PartMaterial.CreateFromFile(name)
	material:setTemplateName(name)
	modelEntity:setMaterial(material)
	self._node:setMaterialForClient(material)
	--self._node:refreshMaterial()
	local Bunch = require "we.view.scene.bunch"
	self:on_material_changed()
	local renderFace=material:getRasterizerState():getDesc().cullMode

	VN.assign(
		self._vnode.materialData,
		"materialPath",
		filePath,
		VN.CTRL_BIT.NONE
	)
	VN.assign(
		self._vnode.materialData.materialSelector,
		"asset",
		filePath,
		VN.CTRL_BIT.NONE
	)
	VN.assign(
		self._vnode.materialData.customMaterialData,
		"renderFace",
		tostring(math.tointeger(renderFace)),
		VN.CTRL_BIT.NONE
	)

	local alpha=modelEntity:getCustomColor()
	VN.assign(
		self._vnode.materialData.customMaterialData,
		"alphaClippint", 
		true,
		VN.CTRL_BIT.NONE
	)

	VN.assign(
		self._vnode.materialData.customMaterialData,
		"alphaClippingThreshold", 
		modelEntity:getCustomThreshold(),
		VN.CTRL_BIT.NONE
	)
 
	local color=modelEntity:getCustomColor()
	VN.assign(
		self._vnode.materialData.customMaterialData,
		"alpha", 
		color[4],
		VN.CTRL_BIT.NONE
	)
	VN.assign(
		self._vnode.materialData.customMaterialData.baseMap,
		"color", 
		{r=color[1]*255,g=color[2]*255,b=color[3]*255,a=color[4]*255},
		VN.CTRL_BIT.NONE
	)

	local till=modelEntity:getTill()
	VN.assign(
		self._vnode.materialData.customMaterialData.baseMap,
		"tiling",
		{x=till,y=till},
		VN.CTRL_BIT.NONE
	)

	local offset=modelEntity:getPartUVOffset()
	VN.assign(
		self._vnode.materialData.customMaterialData.baseMap,
		"offset", 
		{x=offset.x,y=offset.y},
		VN.CTRL_BIT.NONE
	)

	local mtl = require "we.view.scene.mtl"
	local m = mtl.template(filePath)
	local enableSpecular=false
	local enableNormal=false
	local enableEmission=false
	if m.Defines.SPECULAR~=nil then
		enableSpecular= m.Defines.SPECULAR	
	end
	if m.Defines.EMISSION~=nil then
		enableEmission=m.Defines.EMISSION
	end
	if m.Defines.NORMAL~=nil then
		enableNormal=m.Defines.NORMAL
	end

	local textures= m.Properties.Textures
	if textures then
		if textures.texSampler then
			VN.assign(
				self._vnode.materialData.customMaterialData.baseMap,
				"mapPath",
				textures.texSampler.Path,
				VN.CTRL_BIT.NONE
			)
			VN.assign(
				self._vnode.materialData.customMaterialData.baseMap.mapSelector,
				"asset",
				textures.texSampler.Path,
				VN.CTRL_BIT.NONE
			)
		end	
	end

	Bunch:mark_dirty("materialData", "customMaterialData")
	Bunch:mark_dirty("materialData/customMaterialData", "enableSpecular")
	Bunch:mark_dirty("materialData/customMaterialData", "enableNormal")
	Bunch:mark_dirty("materialData/customMaterialData", "enableEmission")
	Bunch:mark_dirty("materialData","editCustomMaterial")
end

local collisionRouter={
	["^position"]=function(primitive,transform)
		primitive:setPosition(transform:getPosition())	
	end,

	["^scale"]=function(primitive,transform)
		primitive:setScale(transform:getScale())
	end,

	["^rotation"]=function(primitive,transform)
		primitive:setRotation(transform:getRotation())
	end,

	["^size"]=function(primitive,transform)
		primitive:setScale(transform:getScale())
	end
}

function M.inject(name, updater)
	router["^"..name] = updater
end

function M:setBindNotify(notify_func)
	self._bind_notify = notify_func
end

--获取引擎的size给编辑器
local function get_engine_size(self)
	local size = self._node:getSize()
	local curr = self._vnode["size"]
	if math.abs(curr.x - size.x) >= PRECISION
	or math.abs(curr.y - size.y) >= PRECISION
	or math.abs(curr.z - size.z) >= PRECISION then -- 浮点型处理
		VN.assign(self._vnode, "size", size, VN.CTRL_BIT.NONE)
		on_size_changed(self)
	end
end

function M:init(vnode, parent)
	assert(VN.check_type(vnode, "Instance"))

	Base.init(self, "instance", vnode)
	-- self._transform = Transform.build()
	self._raw_ctor = true
	self._node = nil
	self._parent = parent
	self._children = {}
	self._invalid = false
	self._lightGizmo = nil

	self._record = {}
	self._on_drag = false
	local cls = vnode["class"]
	local is_part_op = (cls == "PartOperation")

	if vnode["id"] == "" then
		self._vnode["id"] = tostring(IWorld:gen_instance_id())
	end
	
	self._node =assert(IWorld:create_instance(
		Utils.export_inst(
			VN.value(vnode), 
			true
		), true,
		{not_only_engine = true}
	))
	local parent_node = (parent or {})._node or IWorld:get_scene_root_node()
	--model要在插入children之前set_parent，否则model再model会飞到天边
	if not is_part_op then
		IInstance:set_parent(self._node, parent_node)
	end

	--volume、mass不存盘，直接从引擎获取
	if vnode["volume"] == 0 then
		-- self._node:updateShape()
		self._vnode["volume"] = IInstance:get_volume(self._node)
		self._vnode["mass"] = self._vnode["density"] * self._vnode["volume"]
	end

	if self:check_ability(M.ABILITY.SELECTABLE) then
		IInstance:set_selectable(self._node, self:enabled())
	end

	for _, v in ipairs(vnode["children"]) do
		local child = Object:create("instance", v, self)
		table.insert(self._children, child)
	end

	-- 创建PartOperation组成部件的引擎节点
	local childs = {}
	if cls == "PartOperation" then
		local valid_component = 
		{
			Part = true,
			PartOperation = true
		}
		for _, v in ipairs(vnode["componentList"]) do
			if valid_component[v.class] then
				local child_node = assert(IWorld:create_instance(
					Utils.export_inst(
						VN.value(v), 
						true
					), true,
					{not_only_engine = true}
				))
				table.insert(childs,child_node)
			end

		end
		self._node:setCSGChildren(childs)
	end
	
	--在set_parent中会调用到CSGShape:mergeShapes，才会重新计算PartOperation
	if is_part_op then
		IInstance:set_parent(self._node, parent_node)
	end

	for idx, child in ipairs(childs) do
		IWorld:remove_instance(child)
	end

	self._bind_notify = function(...)
	end
	self._router = Signal:subscribe(self._vnode, Def.NODE_EVENT.ON_MODIFY, function(path, event, index, ...)
		path = table.concat(path, "/")
		if event == Def.NODE_EVENT.ON_ASSIGN then
			path = path == "" and index or path .. "/" .. index
		end

		local captures = nil
		for pattern, processor in pairs(router) do
			captures = table.pack(string.find(path, pattern))
			if #captures > 0 then
				local args = {}
				for i = 3, #captures do
					table.insert(args, math.tointeger(captures[i]) or captures[i])
				end
				for _, arg in ipairs({...}) do
					table.insert(args, arg)
				end
				if event == Def.NODE_EVENT.ON_ASSIGN then
					processor(self, event, table.unpack(args),path)
				else
					processor(self, event, index, table.unpack(args),path)
				end
				
				break
			end
		end
		if self._vnode["useForCollision"] then	
			for pattern, processor in pairs(collisionRouter) do
				local ret=string.find(path,pattern)
				if ret then
					local parentTrans=self:parent():parent()._node:getWorldTransform()
					local relativeTrans=parentTrans:toLocalTransform(self._node:getWorldTransform())
					local customShape=self:parent():parent()._node.customShape
					local primitive=customShape:getPrimitive(self._vnode["primitive_id"])
					processor(primitive,relativeTrans)
				end
			end
		end
		self._bind_notify(self._vnode,path,event,index,table.unpack{...})
	end)

	self._cancel = {}
	for name in pairs(property_monitor) do
		local cancel = self._node:listenPropertyChange(name, function(inst, old, new)
			local processor = assert(property_monitor[name], name)
			if processor then
				processor(self, new)
			end
			
		end)

		table.insert(self._cancel, cancel)
	end

	if cls == "MeshPart" then
		--anchorPoint不存盘，直接从引擎获取
		local pos = self._node:getAnchorPoint()
		VN.assign(self._vnode, "anchorPoint", pos, VN.CTRL_BIT.NONE)
		get_engine_size(self)
	elseif cls == "EffectPart" then
		get_engine_size(self)
	end
	if cls=="MeshPart" or cls=="Part" then
	--	self:on_material_changed()
	end

	self._raw_ctor = nil
end

function M:add_primitive(obj)
	local customShape=self._node.customShape
	local objTrans=obj._node:getWorldTransform()
	local relativeTrans=self._node:getWorldTransform():toLocalTransform(objTrans)
	local shape=obj._vnode["shape"]
	local primitive=customShape:addPrimitive(shape,relativeTrans:getPosition(),relativeTrans:getRotation(),relativeTrans:getScale())
	obj._vnode["primitive_id"]=primitive:getId()
end

function M:remove_primitive(obj)
    local customShape=self._node.customShape
	customShape:removePrimitive(obj._vnode["primitive_id"])
end

function M:child_dtor(isSetParent)
	local manager = CW:getSceneManager()
	local scene = manager:getOrCreateScene(CW.CurMap.obj)

	if isSetParent then
		IInstance:set_parent(self._node, scene:getRoot())
	end

	for _,child in ipairs(self:children()) do
		if child:check_base("Instance_CSGShape") then
			child:dtor()
		end
	end
end


function M:dtor()
	for _, child in ipairs(self._children) do
		child:dtor()
	end

	self._invalid = true
	Signal:publish(self, M.SIGNAL.DESTROY)

	for _, cancel in ipairs(self._cancel) do
		cancel()
	end
	self._cancel = {}

	if self._node then
		-- TODO author:rcz split() need file name is content self:getMergeShapesDataKey()!
		-- if  self._node:isA("PartOperation") then
		-- 	self._node:onRemovedByEditor()
		-- end
		IWorld:remove_instance(self._node)
		self._node = nil
	end

	if self._lightGizmo then
		self._lightGizmo:destroy()
		self._lightGizmo = nil
	end

	Base.dtor(self)
	if self._router then
		self._router()
	end
end
---------------------------------------
-- parent & children
function M:parent()
	return self._parent
end

function M:children()
	return self._children
end

function M:new_child(val)
	if not val.id or val.id == "" then
		val.id = tostring(IWorld:gen_instance_id())
	end
	VN.insert(self._vnode["children"], nil, val)
	return assert(self:query_child(val.id), tostring(val.id))
end

function M:remove_child(obj)
	for idx, child in ipairs(self._children) do
		if child == obj then
			local val = VN.remove(self._vnode["children"], idx)
			return val
		end
	end

	assert(false, "can 't find child")
end

function M:query_child(id)
	for _, child in ipairs(self._children) do
		if child:check(id) then
			return child
		else
			local cc = child:query_child(id)
			if cc then
				return cc
			end
		end
	end
end

function M:root()
	if self._parent then
		return self._parent:root()
	else
		return self
	end
end

--------------------------------------------------------------
-- setter/getter vnode

function M:id()
	return self._vnode["id"]
end

function M:class()
	return self._vnode["class"]
end

function M:name()
	return self._vnode["name"]
end

function M:locked()
	return self._vnode["isLockedInEditor"]
end

function M:enabled()
	return self._vnode["isVisibleInEditor"]
end

function M:btskey()
	return self._vnode["btsKey"]
end

function M:module()
	local map = {
		["Entity"] = "entity",
		["DropItem"] = "item"
	}
	local class = self:class()
	return map[class]
end

function M:config()
	return self._vnode["config"]
end

function M:size()
	return Lib.copy(self._vnode["size"])
end

function M:selected()
	return self._vnode["selected"]
end

function M:set_select(flag, on)
	if self._invalid then
		return
	end

	if self._vnode["is_null_object"] then
		if flag or on then
			BindObject:create_bind_object(self)
			self._vnode["selected"] = true
		else
			BindObject:remove(self)
			self._vnode["selected"] = false
		end
		return 
	end
	local show = on and true or flag
	local selected_ancestor = self
	
	local is_anc_selected = false
	self.selected_ancestor_tb = self.selected_ancestor_tb or {}
	local tmp_k, tmp_v = next(self.selected_ancestor_tb)
	if tmp_k then is_anc_selected = true end

	local is_render = show or is_anc_selected

	IInstance:set_select(self._node, is_render)
	self._vnode["selected"] = flag
end

function M:set_select_inc(flag, on)
	self:set_select(flag,on)
	local c = self._vnode["selected_count"] or 0
	self._selected_inc =  true
	self._vnode["selected_count"] = c + 1
	self._selected_inc = nil
end

function M:set_boolean_operation(operation)
	self._vnode["booleanOperation"] = operation
end

function M:set_master_local_pos(pos)
	self._vnode["masterLocalPos"] = pos
end

function M:master_local_pos()
	return self._vnode["masterLocalPos"]
end

function M:set_master_world_pos(pos)
	self._vnode["masterWorldPos"] = pos
end

function M:master_world_pos()
	return self._vnode["masterWorldPos"]
end

function M:set_slave_local_pos(pos)
	self._vnode["slaveLocalPos"] = pos
end

function M:slave_local_pos()
	return self._vnode["slaveLocalPos"]
end

function M:set_slave_world_pos(pos)
	self._vnode["slaveWorldPos"] = pos
end

function M:slave_world_pos()
	return self._vnode["slaveWorldPos"]
end

function M:set_length(length)
	self._vnode["length"] = length
end

function M:set_anchor_space(space)
	self._vnode["anchorSpace"] = tostring(space)
end

function M:set_slave_part_name(name)
	self._vnode["slavePartName"] = name
end

function M:set_slave_part_id(id)
	self._vnode["slavePartID"] = id
end

function M:slave_part_id()
	return self._vnode["slavePartID"]
end

function M:set_master_part_name(name)
	self._vnode["masterPartName"] = name
end

function M:set_translucence()
	local alpha = self._vnode["material"]["alpha"]
	alpha = (alpha > 0.5) and 0.5 or alpha
	IInstance:set(self._node,"materialAlpha",tostring(alpha))
end

function M:recover_translucence()
	local alpha = self._vnode["material"]["alpha"]
	IInstance:set(self._node,"materialAlpha",tostring(alpha))
end

-------------------------------------------------------------
-- common utils

function M:transform()
	return self._transform
end

function M:local_position()
	if self._parent	then
		local parent_position = self._parent:val()["position"]
		local position = self:val()["position"]
		local local_pos = Lib.v3cut(parent_position, position)
		return local_pos
	end
	return {x = 0, y = 0, z = 0}
end

function M:transform_set_position(position)
	assert(self._transform)
	self._transform:setPosition(position)
end

function M:transform_set_rotation(rotation)
	assert(self._transform)
	self._transform:setRotation(rotation)
end

function M:transform_set_scale(scale)
	assert(self._transform)
	self._transform:setScale(scale)
end

function M:set_selectable(flag)
	assert(self._node)
	IInstance:set_selectable(self._node, flag)
end

function M:setLocked(lockedstate)
    if self._invalid then
		return
	end
	self._vnode["isLockedInEditor"] = lockedstate
end

function M:rotation()
	assert(self._node)
	return IInstance:rotation(self._node)
end

function M:check(id)
	--assert(self._node)
	if not self._node then
		return false
	end
	if not math.tointeger(id) then
		return IInstance:id(self._node) == IInstance:id(id)	-- id is node
	end
	return IInstance:id(self._node) == math.tointeger(id)	-- id maybe string
end

function M:on_selected(selected)
	local receptor
	if self:check_base("Instance_ConstraintBase") then
		receptor = Receptor:bind("constraint")
	else
		receptor = Receptor:bind("instance")
	end

	if selected then
		receptor:attach(self:node())
		local manager = CW:getSceneManager()
		if self._vnode["class"] == "Light" then
			self._lightGizmo = GizmoLight:create()
			self._lightGizmo:setSelect(self._node)
			manager:addLightGizmo(self._lightGizmo)
		end
	else
		receptor:detach(self:node())
		if self._lightGizmo then
			self._lightGizmo:destroy()
			self._lightGizmo = nil
		end
	end
end

function M:check_ability(type)
	local class = self._vnode["class"]
	local ability = CLASS_ABILITY[class]
	return ability and (ability & type > 0) or false
end

function M:check_base(type)
	local meta = Meta:meta(self._vnode.__OBJ_TYPE)
	return meta:inherit(type)
end

function M:value()
	return VN.value(self._vnode)
end

function M:on_drag()
	for _, child in ipairs(self._children) do
		child:on_drag()
	end
	self._on_drag = true
end

function M:on_drop()
	for _, child in ipairs(self._children) do
		child:on_drop()
	end

	if self._record.position then
		VN.assign(self._vnode, "position", self._record.position.from, VN.CTRL_BIT.NONE)
		VN.assign(self._vnode, "position", self._record.position.to, VN.CTRL_BIT.NOTIFY | VN.CTRL_BIT.RECORDE)
	end

	if self._record.rotation then
		VN.assign(self._vnode, "rotation", self._record.rotation.from, VN.CTRL_BIT.NONE)
		VN.assign(self._vnode, "rotation", self._record.rotation.to, VN.CTRL_BIT.NOTIFY | VN.CTRL_BIT.RECORDE)
	end

	if self._record.size then
		VN.assign(self._vnode, "size", self._record.size.from, VN.CTRL_BIT.NONE)
		VN.assign(self._vnode, "size", self._record.size.to, VN.CTRL_BIT.NOTIFY | VN.CTRL_BIT.RECORDE)
	end

	self._record = {}
	self._on_drag = false
end

--零件操作检查
function M:check_part_mix(obj,operation)
	local type_table = operation == "MODEL" and Def.SCENE_MODEL_TYPE or Def.SCENE_UNION_TYPE
	local type  = obj:class()
	if type_table[type] then
		return true
	end
	return false
end

--祖先节点中类型为Model的最顶层节点，若无Model祖先，返回nil
function M:find_toppest_model_ancestor()
	if self._vnode["useForCollision"] then
		return self
	end
	local parent = self:parent()
	local ret = nil
	while parent do
		if parent:class() == "Model" then
			ret = parent
		end
		parent = parent:parent()
	end
	return ret
end

function M:traverse_children(func, before)
	if _G.type(func) ~= "function" then
		return
	end

	if before then
		func(self)
	end

	for idx, child in ipairs(self:children()) do
		child:traverse_children(func)
	end

	if not before then
		func(self)
	end
end

function M:isGlobalLight()
	return self:node().lightType == "GlobalLight"
end

function M:get_light_gizmo()
	return self._lightGizmo
end

function M:isShareFolder()
	local isDataset = self:value().isDataSet
	return self:class() == "Folder"and isDataset
end 

function M:saveCollision(collision_id)
	local dir=Lib.combinePath(Def.PATH_GAME_META_DIR,"module","collision",collision_id)
	Lib.mkPath(dir)
	local path=Lib.combinePath(dir,"setting.json")
	os.remove(path)
	local file, errmsg = io.open(path, "w+b")
	assert(file, errmsg)
	local inst=self:query_child(collision_id)
	if not inst then
		return
	end
	local parts=inst:children()
	local exportInfo={}
	for k,v in pairs(parts) do
		if string.find(v:class(),"Part") then
			local temp=Utils.export_inst(VN.value(v._vnode),true)
			table.insert(exportInfo,temp)
		end
	end
	local json=Lib.toJson(exportInfo)
	file:write(json)
	file:close()
	self:remove_child(inst)
	self._vnode["customShapeData"]=IInstance:get(self._node,"customShapeData")
end

function M:loadCollision(collision_id)
	local path=Lib.combinePath(Def.PATH_GAME_META_DIR,"module","collision",collision_id,"setting.json")	
	local file,errmsg=io.open(path,"r")
	assert(file,errmsg)
	local exportInfo=file:read("a")
	print(exportInfo)
	local json = require("cjson")
    local success, parts = pcall(json.decode, exportInfo)
    if not success then
        return
    end
	local collision=self:query_child(collision_id)
	local customShape=self._node.customShape
	customShape:reset()
	for k,v in pairs(parts) do
		if v.class=="Part"then
			local properties=v.properties
			local cfg=Meta:meta("Instance_Part"):ctor({
				id=tostring(properties.id),
				position=Utils.deseri_prop("Vector3",properties.position),
				rotation=Utils.deseri_prop("Vector3",properties.rotation),
				scale=Utils.deseri_prop("Vector3",properties.scale),
				useForCollision=true,
				shape=properties.shape
			})
			collision:new_child(cfg)

		end
	end
end 

--祖先节点中类型为Model的最顶层节点，若无Model祖先，返回nil
function M:find_toppest_model_ancestor()
	local parent = self:parent()
	local ret = nil
	while parent do
		if parent:class() == "Model" then
			ret = parent
		end
		parent = parent:parent()
	end
	return ret
end

function M:traverse_children(func, before)
	if _G.type(func) ~= "function" then
		return
	end

	if before then
		func(self)
	end

	for idx, child in ipairs(self:children()) do
		child:traverse_children(func)
	end

	if not before then
		func(self)
	end
end



return M
