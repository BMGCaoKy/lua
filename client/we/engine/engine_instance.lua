local M = {}

M.INSTANCECOLOR = {
	HOVER	= {255 / 255, 216 / 255, 22 / 255, 1.0},
	SELECT	= {245 / 255, 173 / 255, 50 / 255, 1.0},
	HOVER_LOCK={255/255.0,168/255.0,172/255.0,1.0},
	HOVER_LOCK2={204/255.0,204/255.0,204/255.0,1.0},
}

function M:set(inst, name, val)
	return inst:setProperty(name, val)
end

function M:get(inst, name)
	return inst:getProperty(name)
end

function M:id(inst)
	return inst:getInstanceID()
end

function M:set_hover(inst, flag)
	if self:get(inst, "isSelectInEditor") == "true" then
		return
	end
	local isLock=self:get(inst,"isLockedInEditor")
	if isLock=="true" then
		inst:setRenderBoxColor(M.INSTANCECOLOR.HOVER_LOCK)
		inst:setIsRenderBox(flag)	
		return
	end

	assert(inst.setIsRenderBox, inst:getTypeName())
	if flag then
		inst:setRenderBoxColor(M.INSTANCECOLOR.HOVER)
		inst:setIsRenderBox(true)
	else
		inst:setIsRenderBox(false)
	end
end

function M:set_selectable(inst, flag)
	if not inst.setSelectable then
		return
	end
	return inst:setSelectable(flag)
end

function M:set_select(inst, is_render_box, is_select_in_editor)
	if is_select_in_editor == nil then
		is_select_in_editor = is_render_box
	end

	if inst:isA("Force") then
		inst:setDebugGraphShow(is_render_box)
	elseif inst:isA("Torque") then
		inst:setDebugGraphShow(is_render_box)
	elseif inst:isA("ConstraintBase") then
		inst:setDebugGraphShow(is_render_box)
	elseif inst:isA("BasePart") then
		inst:setRenderBoxColor(M.INSTANCECOLOR.SELECT)
		inst:setIsRenderBox(is_render_box)
		self:set(inst, "isSelectInEditor", tostring(is_select_in_editor))
	elseif inst:isA("Entity") then
		if is_render_box then
			inst:setEdge(true, { 1.0, 209.0 / 255, 26.0 / 255, 1.0 })
		else
			inst:setEdge(false, {1.0, 0, 0, 1.0})
		end
	elseif inst:isA("DropItem") then
		inst:setIsRenderBox(is_render_box)
	elseif inst:isA("Model") then
		inst:setIsRenderBox(is_render_box)
		self:set(inst, "isSelectInEditor", tostring(is_select_in_editor))
	elseif inst:isA("RegionPart") then
		self:set(inst, "isSelectInEditor", tostring(is_select_in_editor))
	elseif inst:isA("AudioNode") then
		inst:setIsRenderBox(is_render_box)
		self:set(inst, "isSelectInEditor", tostring(is_select_in_editor))
	elseif inst:isA("EmptyNode") then
		inst:setRenderBoxColor(M.INSTANCECOLOR.SELECT)
		inst:setIsRenderBox(is_render_box)
		self:set(inst, "isSelectInEditor", tostring(is_select_in_editor))
	elseif inst:isA("EffectPart") then
		self:set(inst,"isSelectInEditor",tostring(is_select_in_editor))
		inst:setIsRenderBox(is_select_in_editor)
	elseif inst:isA("MovableNode") then
		if inst.setRenderBoxColor then
			inst:setRenderBoxColor(M.INSTANCECOLOR.SELECT)
		end
		if inst.setEdge then
			if is_render_box then
				inst:setEdge(true, { 1.0, 209.0 / 255, 26.0 / 255, 1.0 })
			else
				inst:setEdge(false, {1.0, 0, 0, 1.0})
			end
		end
		self:set(inst,"isSelectInEditor",tostring(is_select_in_editor))
		inst:setIsRenderBox(is_select_in_editor)
	end
end

function M:set_world_pos(inst, pos)
	return inst:setWorldPos(pos)
end

function M:position(inst)
	return inst:getPosition()
end

function M:rotation(inst)
	return inst:getRotation()
end

function M:transform(inst)
	return inst:getWorldTransform()
end

function M:get_volume(inst)
	return inst:getVolume()
end

function M:set_shape(part, shape)
	return part:setShape(shape)
end

function M:set_parent(part, parent)
	return part:setParent(parent)
end

function M:get_parent(inst)
	return inst:getParent()
end

function M:set_size_x(part, len)
	part:setSizeX(len)
end

function M:set_size_y(part, len)
	part:setSizeY(len)
end

function M:set_size_z(part, len)
	part:setSizeZ(len)
end

function M:size(part)
	return part:getSize()
end

function M:set_scale_x(ins,val)
	if ins.setScaleX == nil then
		return
	end
	ins:setScaleX(val)
end

function M:set_scale_y(ins,val)
	if ins.setScaleY == nil then
		return
	end
	ins:setScaleY(val)
end

function M:set_scale_z(ins,val)
	if ins.setScaleZ == nil then
		return
	end
	ins:setScaleZ(val)
end

function M:destory(inst)
	inst:destroy()
end

function M:set_batch_type(inst,batch_type)
	-- if inst.batchType == nil then
	-- 	return
	-- end
	-- inst:batchType(batch_type)
	self:set(inst, "batchType", tostring(batch_type))
end


return M
