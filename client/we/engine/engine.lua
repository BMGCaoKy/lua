local Core = require "editor.core"
local cjson = require "cjson"

local M = {}

function M:make_chunk(min, max, hollow_out)
	assert(min.x <= max.x)
	assert(min.y <= max.y)
	assert(min.z <= max.z)

	local obj = Core.make_chunk(min, max, not hollow_out)
	assert(obj)

	local prop = {
		lx = max.x - min.x + 1,
		ly = max.y - min.y + 1,
		lz = max.z - min.z + 1
	}

	return debug.setmetatable(obj, {
		__index = function(obj, key)
			assert(prop[key], string.format("invalid prop %s", key))
			return prop[key]
		end
	})
end

function M:set_chunk(min, chunk)
	return Core.set_chunk(min, chunk)
end

function M:clr_chunk(min, chunk)
	return Core.clr_chunk(min, chunk)
end

--打开进度条窗口
function M:open_progress_window(_type)
	local paramsjson = cjson.encode({
		type = "OPEN_PROGRESS_WINDOW",
		params = {
			_type = _type,
			params = {}
		}
	})
	return Core.notify(paramsjson)
end

function M:get_block(pos)
	return World.CurMap:getBlockConfigId(pos)
end

-- block
function M:set_block(pos, id)
	if pos.y < 0 or pos.y > 255 then
		return
	end
	return World.CurMap:setBlockConfigId(pos, id)
end

--分析选中方块进度
function M:update_req_count(fin,rmn,tot)
	local paramsjson = cjson.encode({
		type = "UPDATE_REQ_COUNT",
		params = {
			fin = fin,
			rmn = rmn,
			tot = tot
		}
	})
	return Core.notify(paramsjson)
end

function M:iterate_block(pos_min, pos_max, func, step)
	step = step or 1
	assert(step > 0)

	local total = (pos_max.x - pos_min.x + 1) * (pos_max.y - pos_min.y + 1) * (pos_max.z - pos_min.z + 1)
	assert(total > 0)
	local remain = total

	local co = coroutine.create(function()
		local count = step
		for x = pos_min.x, pos_max.x do
			for y = pos_min.y, pos_max.y do
				for z = pos_min.z, pos_max.z do
					local ret, errmsg = xpcall(func, traceback, {x = x, y = y, z = z})
					assert(ret, errmsg)
					count = count - 1
					remain = remain - 1
					if remain <= 0 then
						goto FINISH
					elseif count <= 0 then
						coroutine.yield(false, remain, total)
						count = step
					end
				end
			end
		end

		::FINISH::
		assert(remain == 0)
		return true, remain, total
	end)

	return function()
		local rets = {coroutine.resume(co)}
		if not rets[1] then
			assert(false, rets[2])
		end

		return table.unpack(rets, 2)
	end
end

function M:open_menu(focus_class)
	local paramsjson = cjson.encode(
			{
				type = "OPEN_MENU",
				params = {
					focus_class = focus_class
				}
			}
	)
	return Core.notify(paramsjson)
end

function M:detect_collision(min,max)
	return Core.detect_collision(min,max)
end


function M:make_chunk_bytable(obj,solid)
	local chunk = Core.make_chunk_bytable(obj.lx, obj.ly, obj.lz, solid, obj.model)
	assert(chunk)

	local prop = {lx = obj.lx,ly = obj.ly,lz = obj.lz}

	return debug.setmetatable(chunk, {
		__index = function(chunk, key)
			assert(prop[key], string.format("invalid prop %s", key))
			return prop[key]
		end
	})
end


return M
