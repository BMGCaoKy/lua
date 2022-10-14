local M = {}

function M.focus_target(pos,distance)
	local bm = Blockman.Instance()
	if not bm then
		return
	end
	local player_pos = bm:getViewerPos()
	local dis_x = pos.x - player_pos.x
	local dis_y = pos.y - player_pos.y
	local dis_z = pos.z - player_pos.z

	--计算pitch y z
	--[[
			  -90
			   Y
			   |
		0 -Z-------Z 0
			   |
			  -Y
			   90
	]]
	local pitch = 0
	local sqrt_xz = math.sqrt(dis_x ^ 2 + dis_z ^ 2)
	if dis_y == 0 and sqrt_xz == 0 then
		pitch = 45
	elseif sqrt_xz == 0 and dis_y > 0 then
		pitch = -90
	elseif sqrt_xz == 0 and dis_y < 0 then
		pitch = 90
	else
		pitch = -math.deg(math.atan(dis_y/sqrt_xz))
	end

	--计算raw x z
	--[[
			     0
			     Z
			     |
		-90 X<------->-X 90
			     |
		        -Z
			 -180/180
	]]
	local yaw = 0
	if dis_x == 0 and dis_z >= 0 then
		yaw = 0
	elseif dis_x == 0 and dis_z < 0 then
		yaw = 180
	elseif dis_x < 0 then
		yaw = math.deg(math.atan(dis_z/dis_x)) + 90
	elseif dis_x > 0 then
		yaw = math.deg(math.atan(dis_z/dis_x)) - 90
	end

	--计算坐标点
	--取单位向量 * 固定距离distance
	local player_new_pos = {
		x = 0,
		y = 0,
		z = 0
	}
	local vector_quantity_x = player_pos.x - pos.x
	local vector_quantity_y = player_pos.y - pos.y
	local vector_quantity_z = player_pos.z - pos.z
	local vector_quantity_mod = math.sqrt(vector_quantity_x ^ 2 + 
						  vector_quantity_y ^ 2 + 
						  vector_quantity_z ^ 2)

	player_new_pos.x = vector_quantity_x / vector_quantity_mod * distance + pos.x
	player_new_pos.y = vector_quantity_y / vector_quantity_mod * distance + pos.y
	player_new_pos.z = vector_quantity_z / vector_quantity_mod * distance + pos.z

	if player_new_pos.y <= 0 then
		player_new_pos.y = 0
	end

	player_new_pos.y = math.max(player_new_pos.y,0)
	player_new_pos.y = math.min(player_new_pos.y,255)

	bm:setViewerPos(player_new_pos, yaw, pitch, 1)
end

function M.floor_pos(pos)
	return {
		x = math.floor(pos.x),
		y = math.floor(pos.y),
		z = math.floor(pos.z),
	}
end

return M
