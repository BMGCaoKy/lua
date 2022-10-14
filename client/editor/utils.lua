local M = {}
local cjson = require("cjson")
local globalSetting = require "editor.setting.global_setting"
local editorSetting = require "editor.setting"
local commonSetting = require "common.setting"

function M.focus_target(pos,distance)
	local bm = Blockman.Instance()
	if not bm then
		return
	end
	local player_pos = bm:getViewerPos()
	local dis_x = pos.x - player_pos.x
	local dis_y = pos.y - player_pos.y
	local dis_z = pos.z - player_pos.z

	--����pitch y z
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

	--����raw x z
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

	--���������
	--ȡ��λ���� * �̶�����distance
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

local screenShotDirPath = Root.Instance():getGamePath() .. "screenShot/"
function M:screenShot(func)
    local screenShotImgPath = {
        square = screenShotDirPath .. "icon_upload_square_" .. os.time() .. ".png",
        rectangle = screenShotDirPath .. "icon_upload_rec_" .. os.time() .. ".png",
    }

    Lib.mkPath(screenShotDirPath)
    self:removeScreenShot()

    Root.Instance():pushScreenShotInfo(screenShotImgPath.square, 326, 330)
    Root.Instance():pushScreenShotInfo(screenShotImgPath.rectangle, 590, 330)
    World.Timer(2, function()
        if Root.Instance():getScreenShotInfoSize() == 0 then
            if func then
                globalSetting:saveIsUseNewScreenShot(false, true)
                func(screenShotImgPath)
            end
            return false
        end
        return true
    end)
end

function M:removeScreenShot()
	for file in lfs.dir(screenShotDirPath) do
		if file:find("icon_upload_") then
			os.remove(screenShotDirPath .. file)
		end
	end
end

function M:getCertainScreenShotInfo()
	local info = CGame.instance:getShellInterface():getCertainInfo("uploadCoverInfo")
	return info and cjson.decode(info) or {}
end

function M:saveGameGlobalField(path, field, value)
	local oldCfg = Lib.readGameJson(path)
	if not oldCfg then
		print("saveGameGlobalField oldCfg is nil---------------")
		return
	end
	oldCfg[field] = value
	Lib.saveGameJson(path, oldCfg)
end

local endPoint_fullName = "myplugin/endPoint"
function M:checkIsExistEndPoint(entity_obj, placeItemFullName)
	local isExistEndPoint = entity_obj:getEntityByFullName(endPoint_fullName)
	if not isExistEndPoint or placeItemFullName ~= endPoint_fullName then
		return
	end
	entity_obj:delEntityByFullName(endPoint_fullName)
end

local endPointCondition
function M:checkEndPointIsPlace(entity_obj, entity_id, opType)
	local entity = entity_obj:getEntityById(entity_id)
	if not entity then
		return
	end
	local fullName = entity:cfg().fullName
	if fullName ~= endPoint_fullName then
		return
	end
	endPointCondition = {}
	if opType == "set_entity_undo" or opType == "del_entity_redo" then
		endPointCondition.enable = false
		endPointCondition.pos = nil
	else
		local entityPos = entity_obj:getPosById(entity_id)
		endPointCondition.enable = true
		endPointCondition.pos = entityPos
	end
end

function M:setEndPointPos(pos)
	endPointCondition = endPointCondition or {}
	endPointCondition.pos = pos
	endPointCondition.enable = pos and true or false
end

function M:isPlaceEndPoint()
	return endPointCondition and endPointCondition.pos or nil
end

function M:getEndPointOnMap()
	local map =  World.CurMap
	local entitys = map.keyEntitys
	if not endPointCondition then
		endPointCondition = {}
		endPointCondition.enable = false
		for _, entityCfg in pairs(entitys) do
			if entityCfg.data.cfg == endPoint_fullName then
				endPointCondition.enable = true
				endPointCondition.pos = entityCfg.data.pos
				break
			end
		end
	end
	return endPointCondition
end

local allObj
local function getObjPlaceCount(mod, fullName, isRemove)
	if not allObj then
		allObj = {
			entity = {},
			item = {}
		}
		local mapCfg = World.CurMap.cfg

		for key, data in pairs(allObj) do
			local objs = mapCfg[key] or {}
			for index = 1, #objs do
				local full_name = objs[index].cfg
				data[full_name] = data[full_name] or {}
				local obj = data[full_name]
				obj.count = (obj.count or 0) + 1
			end
		end
	end
	allObj[mod][fullName] = allObj[mod][fullName] or {}
	local result = allObj[mod][fullName]
	local opCount = isRemove and -1 or 1
	result.count = (result.count or 0) + opCount
	return result.count <= 0
end

function M:setPlaceObjChange(mod, cfg, isRemove)
	if not cfg then
		return
	end
	if mod == "block" and type(cfg) == "number" then
		cfg = Block.GetNameCfg(commonSetting:id2name("block", cfg))
	end
	local fullName = cfg.fullName or cfg
	if mod == "entity" or mod == "item" then
		isRemove = getObjPlaceCount(mod, fullName, isRemove)
	end
	fullName = fullName:match("myplugin/(.+)")
	editorSetting:setPlaceObjChange(mod, fullName, not isRemove)
end

return M
