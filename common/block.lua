---@type setting
local setting = require "common.setting"
---@type setting
local CfgMod = setting:mod("block")

local IdCfg = {}
local blockMap = T(Block, "blockMap")

local world = World.CurWorld

function Block.registerBlockMap(k, v)
	blockMap[k] = v
end

function Block.getBlockFace(sideNormal)
	if sideNormal == Lib.v3(0, 1, 0) then
		return Define.BLOCK_FACE.UP
	elseif sideNormal == Lib.v3(0, -1, 0) then
		return Define.BLOCK_FACE.DOWN
	elseif sideNormal == Lib.v3(1, 0, 0) then
		return Define.BLOCK_FACE.LEFT
	elseif sideNormal == Lib.v3(-1, 0, 0) then
		return Define.BLOCK_FACE.RIGHT
	elseif sideNormal == Lib.v3(0, 0, -1) then
		return Define.BLOCK_FACE.FRONT
	elseif sideNormal == Lib.v3(0, 0, 1) then
		return Define.BLOCK_FACE.BEHIND
	end
	return Define.BLOCK_FACE.INVALID
end

function Block.GetIdCfg(id, no_error)
	Block.registerBlock(id)
	local cfg = IdCfg[id]
	if not cfg then
		if not no_error then
			Lib.logError("Block.GetIdCfg", id)
		end
		return nil
	end
	return assert(cfg, id)
end

function Block.GetNameCfgId(name)
	return assert(CfgMod.name2id[name], name)
end

function Block.GetNameCfg(name)
	return assert(CfgMod:get(name), name)
end

local function rotate(vec, yaw, pitch, roll)
	yaw = yaw % 360
	pitch = pitch % 360
	roll = roll % 360

	Lib.rotate(vec, {
		x = pitch,
		y = yaw,
		z = roll
	})
end

local function rotatePosInBlock(vec, yaw, pitch, roll)
	vec.x = vec.x - 0.5
	vec.y = vec.y - 0.5
	vec.z = vec.z - 0.5
	rotate(vec, yaw, pitch, roll)
	vec.x = vec.x + 0.5
	vec.y = vec.y + 0.5
	vec.z = vec.z + 0.5
end

local function translationPosInBlock(vec, xoffset, yoffset, zoffset)
	if xoffset == 1 or xoffset == -1 then
		vec.x = 1 - vec.x
	else
		vec.x = vec.x + xoffset
	end

	if yoffset == 1 or yoffset == -1 then
		vec.y = 1 - vec.y
	else
		vec.y = vec.y + yoffset
	end

	if zoffset == 1 or zoffset == -1 then
		vec.z = 1 - vec.z
	else
		vec.z = vec.z + zoffset
	end

end

local function hasValidRotation(cfg)
	local rotation = cfg.rotation
	if type(rotation) ~= "table" then
		return false
	end
	return true
end

local function hasValidTranslation(cfg)
	local translation = cfg.translation
	if type(translation) ~= "table" then
		return false
	end
	return true
end

local function hasValidTranslation(cfg)
	local translation = cfg.translation
	if type(translation) ~= "table" then
		return false
	end
	return true
end

local function rotateBoundingVolume(cfg, yaw, pitch, roll)
	for _, box in pairs(cfg._collisionBoxes) do
		local max, min = box.max, box.min
		rotatePosInBlock(max, yaw, pitch, roll)
		rotatePosInBlock(min, yaw, pitch, roll)
		if max.x < min.x then
			max.x, min.x = min.x, max.x
		end
		if max.y < min.y then
			max.y, min.y = min.y, max.y
		end
		if max.z < min.z then
			max.z, min.z = min.z, max.z
		end
	end
end

local function translationBoundingVolume(cfg, xoffset, yoffset, zoffset)
	for _, box in pairs(cfg._collisionBoxes) do
		local max, min = box.max, box.min
		translationPosInBlock(max, xoffset, yoffset, zoffset)
		translationPosInBlock(min, xoffset, yoffset, zoffset)
		if max.x < min.x then
			max.x, min.x = min.x, max.x
		end
		if max.y < min.y then
			max.y, min.y = min.y, max.y
		end
		if max.z < min.z then
			max.z, min.z = min.z, max.z
		end
	end
end

local function rotateQuadConfig(cfg, yaw, pitch, roll)
	for _, quad in pairs(cfg._quads) do
		if quad.pos then
			for _, pos in pairs(quad.pos) do
				rotatePosInBlock(pos, yaw, pitch, roll)
			end
		end
		if quad.vertices then
			for _, vertex in pairs(quad.vertices) do
				rotatePosInBlock(vertex.position, yaw, pitch, roll)
				if vertex.normal then
					rotate(vertex.normal, yaw, pitch, roll)
				end
			end
		end
	end
end

local function translationQuadConfig(cfg, xoffset, yoffset, zoffset)
	for _, quad in pairs(cfg._quads) do
		if quad.pos then
			for _, pos in pairs(quad.pos) do
				translationPosInBlock(pos, xoffset, yoffset, zoffset)
			end
		end
		if quad.vertices then
			for _, vertex in pairs(quad.vertices) do
				translationPosInBlock(vertex.position, xoffset, yoffset, zoffset)
				if vertex.normal then
					rotate(vertex.normal, xoffset, yoffset, zoffset)
				end
			end
		end
	end
end

local function rotateStandardBlockTextureConfig(cfg, yaw, pitch, roll)
	-- if cfg.texture then
	-- 	print("cannot rotate standard block", cfg.fullName)
	-- end
	-- yaw = yaw % 360
	-- pitch = pitch % 360
	-- roll = roll % 360

	-- local textures = cfg.texture
	-- local posX = textures[5]
	-- local negX = textures[4]
	-- local posY = textures[1]
	-- local negY = textures[0]
	-- local posZ = textures[3]
	-- local negZ = textures[2]

	-- if roll == 90 then
	-- 	posX, posY, negX, negY = negY, posX, posY, negX
	-- elseif roll == 180 then
	-- 	posX, negX = negX, posX
	-- 	posY, negY = negY, posY
	-- elseif roll == 270 then
	-- 	posX, posY, negX, negY = posY, negX, negY, posX
	-- end

	-- if pitch == 90 then
	-- 	posY, posZ, negY, negZ = negZ, posY, posZ, negY
	-- elseif roll == 180 then
	-- 	posY, negY = 
	-- elseif roll == 270 then
	-- 	vec.y, vec.z = vec.z, -vec.y
	-- end

	-- if yaw == 90 then
	-- 	vec.x, vec.z = vec.z, -vec.x
	-- elseif roll == 180 then
	-- 	vec.x, vec.z = -vec.x, -vec.z
	-- elseif roll == 270 then
	-- 	vec.x, vec.z = -vec.z, vec.x
	-- end
end

local function rotateColliderConfig(cfg, yaw, pitch, roll)
	local colliderConfig = cfg._collider
	local rotate = Quaternion.fromEulerAngle(pitch, yaw, roll)
	if colliderConfig.rotation == nil then
		colliderConfig.rotation = { x=pitch, y=yaw, z=roll }
	else
		local quat = Quaternion.fromEulerAngleVector(colliderConfig.rotation)
		quat = rotate * quat
		colliderConfig.rotation = Vector3.new(quat:toEulerAngle())
	end
	local offset = Vector3.fromTable(colliderConfig.offset or { x=0, y=0, z=0 })
	offset.y = offset.y - 0.5
	offset = rotate * offset
	offset.y = offset.y + 0.5
	colliderConfig.offset = offset
end

local function rotateBlockConfig(cfg)
	local rotation = cfg.rotation
	local yaw = rotation.y
	local pitch = rotation.x
	local roll = rotation.z
	assert(cfg._collisionBoxes or cfg._collider, 
		'block config must contain "collisionBoxes" or "collider" to calculate rotation')
	assert(cfg.quads, 
		'block config must contain "quads" to calculate rotation')
	if cfg.collisionBoxes == cfg._collisionBoxes then
		cfg._collisionBoxes = Lib.copy(cfg.collisionBoxes)
	end
	if cfg.quads == cfg._quads then
		cfg._quads = Lib.copy(cfg.quads)
	end
	if cfg.collider == cfg._collider then
		cfg._collider = Lib.copy(cfg.collider)
	end

	if cfg._collisionBoxes then
		rotateBoundingVolume(cfg, yaw, pitch, roll)
	end
	if cfg._collider then
		rotateColliderConfig(cfg, yaw, pitch, roll)
	end
	rotateQuadConfig(cfg, yaw, pitch, roll)
	rotateStandardBlockTextureConfig(cfg, yaw, pitch, roll)
end

local function translationBlockConfig(cfg)
	local translation = cfg.translation
	local xoffset = translation.x
	local yoffset = translation.y
	local zoffset = translation.z

	if cfg.collisionBoxes == cfg._collisionBoxes then
		cfg._collisionBoxes = Lib.copy(cfg.collisionBoxes)
	end
	if cfg.quads == cfg._quads then
		cfg._quads = Lib.copy(cfg.quads)
	end

	translationBoundingVolume(cfg, xoffset, yoffset, zoffset)
	translationQuadConfig(cfg, xoffset, yoffset, zoffset)
end

local function convertTexturePath(cfg, path)
	if path:sub(1,7)=="plugin/" or  path == "" or path == nil then
		return path
	elseif path:sub(1,1)=="/" then
		return "plugin/" .. cfg.plugin .. path
	elseif path:sub(1,1)=="@" then
		return path:sub(2)
	else
		return "plugin/" .. cfg.plugin .. "/block/" .. cfg._name .. "/" .. path
	end
end

local function isShowTexture(notShowTexture)
	if not notShowTexture then
		return
	end
	-- 只有手机编辑器的编辑场景才判断是否显示贴图，其他环境均不显示
	local localEditroEnvironment = World.isClient and CGame.instance:getIsEditor()
	return not localEditroEnvironment
end

local function showIcon(cfg)
	if not cfg.icon then
		return 
	end
	if not cfg.notShowTexture then
		return cfg.icon
	end
	return isShowTexture(cfg.notShowTexture) and cfg.icon
end

function CfgMod:onLoad(cfg, reload)
	cfg.baseName = cfg.fullName

	if cfg.isOpaqueFullCube ~= nil and not cfg.renderPass then
		cfg.renderPass = 4
	end
	
	if World.cfg.defaultBlockRenderPass ~= nil then
		cfg.renderPass = World.cfg.defaultBlockRenderPass
	end

	if cfg.texture then
		local texture = {}
		cfg._texture = cfg._texture or cfg.texture
		for i, path in ipairs(cfg._texture) do
			texture[i] = convertTexturePath(cfg, path)
		end
		cfg.texture = isShowTexture(cfg.notShowTexture) and {} or texture
		cfg.icon = showIcon(cfg)
	end

	--贴图路径转换
	if cfg.quads then
		if not cfg.quads_ then
			cfg.quads_ = Lib.copy(cfg.quads)
		end
		for i, quad in ipairs(cfg.quads) do
			if quad.texture then
				quad.texture = convertTexturePath(cfg, quad.texture)
			end
		end
	end

	if cfg.defaultTexture then
		cfg._defaultTexture = cfg._defaultTexture or cfg.defaultTexture
		cfg.defaultTexture = convertTexturePath(cfg, cfg._defaultTexture or cfg.defaultTexture)
	end

	if not cfg._collisionBoxes then
		cfg._collisionBoxes = cfg.collisionBoxes
	end

	if not cfg._collider then
		cfg._collider = cfg.collider
	end

	if not cfg._quads then
		cfg._quads = cfg.quads
	end

	local defaultTexture = cfg.defaultTexture
	if defaultTexture and cfg.quads then
		if cfg._quads == cfg.quads then
			cfg._quads = Lib.copy(cfg.quads)
		end
		for _, quad in pairs(cfg._quads) do
			quad.texture = quad.texture or defaultTexture
		end
	end

	IdCfg[cfg.id] = cfg

	if hasValidRotation(cfg) then
		if not pcall(rotateBlockConfig, cfg) then
			print("Failed to rotate block config, please check the config format: ", cfg.fullName)
		end
	end

	if hasValidTranslation(cfg) then
		if not pcall(translationBlockConfig, cfg) then
			print("Failed to translation block config, please check the config format: ", cfg.fullName)
		end
	end

	if not World.isClient then 
		WaterMgr.AddWaterCfg(cfg)
		LavaMgr.AddLavaCfg(cfg)
	end
	world:loadBlockConfig(cfg.id, cfg, reload or not World.isClient)
end

local airFullName = "/air"
function Block.GetAirBlockName()
	return airFullName
end

local function init()
	local airBlock = {
		id = 0,
		fullName = "/air",
		lightOpacity = 0,
		lightValue = 0,
		renderable = false,
		emitLightInMaxLightMode = true,
		blockObjectOnCollision = false,
		blockCameraOnCollision = false,
		isOpaqueFullCube = false,
		focusable = false,
		collisionBoxes = {},
		collisionShape = {},
		clickPenetrate = true,
	}

	local newAirBlock = world.cfg.newAirBlock
	if newAirBlock then
		airBlock = assert(CfgMod:get(newAirBlock), "reset air block error!!!! in block InitCfg.")
		airBlock.fullName = "/air"
	end
	local airBlockProp = world.cfg.airBlockProp or {}
	for prop, value in pairs(airBlockProp) do
		airBlock[prop] = value
	end
	airBlock.id = 0
	airFullName = airBlock.fullName

	CfgMod:set(airBlock)

	if World.isClient then
		local ids = {}
		for _, v in pairs(CfgMod.name2id or {})  do
			table.insert(ids, v)
		end
		world:registerBlockIds(ids)
	else
		for name in pairs(CfgMod.name2id) do
			CfgMod:get(name)
		end
	end
end

function Block.registerBlock(id)
	if not IdCfg[id]  then
		local name = CfgMod.id2name[id]
		if name then
			CfgMod:get(name)
		end
	end
end

function block_event(event, id)
	local func = Block[event]
	if func then
		func(id)
	end
end

init()


