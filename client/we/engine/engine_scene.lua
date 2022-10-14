local Def = require "we.def"

local BM = Blockman.Instance()
local CW = World.CurWorld
local GAME = CGame.instance
local IInstance = require "we.engine.engine_instance"

local M = {
	on_drag = false,
}

local function get_scene()
	local manager = CW:getSceneManager()
	return manager:getOrCreateScene(CW.CurMap.obj)
end

function M:point2scene(point)
	local result = BM:getRayTraceResult(point, 150, false, false, false, {})
	return result.hitPos
end

function M:pick_scene_point(point, filter, reject)
	local function get_object(result)
		if result.type == "BLOCK" then
			return {pos = result.blockPos, side = result.sideNormal}
		elseif result.type == "TERRAIN" then
			return { pos = result.hitPos }
		elseif result.type == "PART" then
			return { pos = result.hitPos }
		else
			print("hit ???", Lib.v2s(result))
		end
	end

	local result = BM:getRayTraceResultAtInstance(point, 150, false, false, false, {}, "", reject or {}, {})
	local type = Def.SCENE_NODE_TYPE_NAME[result.type]
	if not type then
		return
	end

	if (type & filter) ~= 0 then
		return get_object(result), type
	end
end

function M:pick_point(point, filter, reject)
	local function get_object(result)
		if result.type == "BLOCK" then
			return {pos = result.blockPos, side = result.sideNormal}
		elseif result.type == "ENTITY" then
			return World.CurWorld:getEntity(result.objID)
		elseif result.type == "DROPITEM" then
			return World.CurWorld:getDropItem(result.objID)
		elseif result.type == "PART" then
			return Instance.getByInstanceId(result.partId)
		elseif result.type == "INSTANCE" then
			return Instance.getByInstanceId(result.instanceId)
		else
			print("hit ???", Lib.v2s(result))
		end
	end

	local result = BM:getRayTraceResultAtInstance(point, 150, false, false, false, {}, "", reject or {}, {})
	local type = Def.SCENE_NODE_TYPE_NAME[result.type]
	if not type then
		return
	end

	if (type & filter) ~= 0 then
		return get_object(result), type
	end
end

function M:pick_rect(rect, is_filter_children)
	local manager = CW:getSceneManager()
	local scene = manager:getOrCreateScene(CW.CurMap.obj)

	local screen_size = GAME:getWndSize()
	local l, t, r, b = rect.left/screen_size.x, rect.top/screen_size.y, rect.right/screen_size.x, rect.bottom/screen_size.y
	return scene:getRenderablesInScreenArea(l, t, r, b, true, is_filter_children == false)
end

function M:move_parts(parts, displacement)
	local manager = CW:getSceneManager()
	local scene = manager:getOrCreateScene(CW.CurMap.obj)
	scene.move(parts, displacement, true)
end

function M:move_parts_to(parts, pos_d)
	local pos_s = self:parts_center(parts)
	self:move_parts(parts, {x = pos_d.x - pos_s.x, y = pos_d.y - pos_s.y, z = pos_d.z - pos_s.z}, true)
end

function M:start_drag_parts(parts)
	local manager = CW:getSceneManager()
	self.on_drag = true
	manager:startMoveParts(parts)
end

function M:end_drag_parts()
	local manager = CW:getSceneManager()
	manager:endMoveParts()
	self.on_drag = false
end

function M:drag_parts(parts, x, y)
	local manager = CW:getSceneManager()
	manager:rayMoveParts(parts, {x = x, y = y}, 1000)
end

function M:scale_parts(parts, scale)
	local manager = CW:getSceneManager()
	local scene = manager:getOrCreateScene(CW.CurMap.obj)
	scene.scale(parts, scale)
end

function M:rotate_parts(parts, aix, degress)
	local manager = CW:getSceneManager()
	local scene = manager:getOrCreateScene(CW.CurMap.obj)
	scene.rotateAround(parts, aix, degress)
end

function M:rotate_parts_around_point(parts,axis,point,angle)
	get_scene().rotateAroundPoint(parts,axis,point,angle)
end

function M:scale_parts_base_point(parts,scale,point)
	get_scene().scaleBasePoint(parts,scale,point)
end

function M:parts_center(parts)
	local manager = CW:getSceneManager()
	local scene = manager:getOrCreateScene(CW.CurMap.obj)
	local box = scene.getWorldAABB(parts, true)
	if box then
		return {
			x = box[2].x + (box[3].x - box[2].x) / 2,
			y = box[2].y + (box[3].y - box[2].y) / 2,
			z = box[2].z + (box[3].z - box[2].z) / 2,
		}
	else
		return {
			x = math.maxinteger,
			y = math.maxinteger,
			z = math.maxinteger
		}
	end
end

function M:parts_center_exlude_children(parts)
	local box = get_scene().getWorldAABB(parts, false)
	if box then
		return {
			x = box[2].x + (box[3].x - box[2].x) / 2,
			y = box[2].y + (box[3].y - box[2].y) / 2,
			z = box[2].z + (box[3].z - box[2].z) / 2,
		}
	end
	return nil
end

function M:parts_aabb(parts)
	local manager = CW:getSceneManager()
	local scene = manager:getOrCreateScene(CW.CurMap.obj)
	local box = scene.getWorldAABB(parts, true)

	return box
end

function M:parts_bound(parts)
	local box = self:parts_aabb(parts)
	if box then
		return {
			min = {
				x = box[2].x,
				y = box[2].y,
				z = box[2].z
			},
			max = {
				x = box[3].x,
				y = box[3].y,
				z = box[3].z
			}
		}
	end
end

function M:parts_bound_exclude_children(parts)
	local manager = CW:getSceneManager()
	local scene = manager:getOrCreateScene(CW.CurMap.obj)
	local box = scene.getWorldAABB(parts, false)
	if box then
		return {
			min = {
				x = box[2].x,
				y = box[2].y,
				z = box[2].z
			},
			max = {
				x = box[3].x,
				y = box[3].y,
				z = box[3].z
			}
		}
	end
end

function M:parts_obb(parts, act_part, unionChildren)
	local manager = CW:getSceneManager()
	local scene = manager:getOrCreateScene(CW.CurMap.obj)
	local box = scene.getWorldOBB(parts, act_part, unionChildren)

	return box
end

function M:parts_obb_bound(parts, act_part)
	local box = self:parts_obb(parts, act_part, true)
	if box then
		return {
			min = {
				x = box[2].x,
				y = box[2].y,
				z = box[2].z
			},
			max = {
				x = box[3].x,
				y = box[3].y,
				z = box[3].z
			}
		}
	end
end

function M:parts_obb_center(parts)
	local box = self:parts_obb(parts)
	return {
		x = box[4].x,
		y = box[4].y,
		z = box[4].z
	}
end

function M:parts_gizmo_center(parts)
	if #parts == 1 then 
		local name=IInstance:get(parts[1],"name")
		if name~="Model" then
			return parts[1]:getAnchorPoint()
		end
	end

	if #parts == 0 then 
		return { x=0, y=0, z=0}
	end

	return self:parts_obb_center(parts)
end

return M
