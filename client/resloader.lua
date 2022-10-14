require "common.resloader"

local lfs = require "lfs"
local setting = require "common.setting"
local gameName = L("gameName")
local models = L("models", {})
local dealType = L("dealType", {})

local function path_combine(...)
	local tmp = {}
	for _, path in ipairs({...}) do
		if (path ~= "") then
			table.insert(tmp, path)
		end
	end
	local ret = string.gsub(string.gsub(table.concat(tmp, "/"), "\\", "/"), "(/+)", "/")
	return ret
end

local function registerBlockTexture()

end

local function registerItemTexture()

end

function ResLoader:getGameRootDir()
	return CGame.Instance():getGameRootDir()
end


function ResLoader:setModelMatItem(id , mat, view)
	local rotateX = mat.rotateX and math.rad(mat.rotateX) or 0
	local rotateY = mat.rotateY and math.rad(mat.rotateY) or 0
	local rotateZ = mat.rotateZ and math.rad(mat.rotateZ) or 0
	local scale = mat.scale or 1
	local translate = mat.translate or { x = 0, y = 0, z = 0 }
	if view == 1 then
		ModelManager.Instance():setModelMatItemFirst(id, scale, translate, rotateX, rotateY, rotateZ)
	elseif view == 3 then
		ModelManager.Instance():setModelMatItemThird(id, scale, translate, rotateX, rotateY, rotateZ)
	end
end

function ResLoader:loadCoreResources()
	local defaultTextureFolder = path_combine(Root.Instance():getRootPath(), "Media/Textures/defaultBlocks")
	TextureAtlasRegister.instance:addMemTextureFolder("DefaultBlocks", defaultTextureFolder)
end

function ResLoader:loadGameResources()
	registerBlockTexture()
	registerItemTexture()
end

function ResLoader:loadSetting()
	local path = World.GameName .. "/"
	local resGroupMgr = ResourceGroupManager:Instance()
	local gameRoot = self:getGameRootDir()
	resGroupMgr:addResourceList(gameRoot, path, {} ,"FileSystemIndexByPath")
end

function ResLoader:reload(changed, hasChangeImage)
	if hasChangeImage then
		self:addGame(gameName)
	end

	--World.CurMap:bakeLightAndSave(false, true)

    for _, name in ipairs(changed) do
        if name:sub(1,6)=="block:" then
			Blockman.instance:refreshBlocks()
			break
		end
    end
end

function ResLoader:filePathJoint(cfg, file)
	local path
	if file:sub(1,1)=="/" then
		path = "plugin/" .. cfg.plugin .. file
	elseif file:sub(1,1)=="@" then
		path = file:sub(2)
	else
		path = "plugin/" .. cfg.plugin .. "/" .. cfg.modName .. "/" .. cfg._name .. "/" .. file
	end
	return path 
end

function ResLoader:loadImage(cfg, image)
	if image and (image:find("set:") or image:find("http:") or image:find("https:")) then
		return image
	end
	local path = ResLoader:filePathJoint(cfg,image)
	TextureAtlasRegister.instance:addMemTextureAtlas(cfg.modName, path)
	if GUIManager:Instance():isEnabled() then
		GUILib.loadImageFromResLoader(image, path)
	end
	return path
end

function ResLoader:addTextureAtlas(cfg, image)
	if image and (image:find("set:") or image:find("http:") or image:find("https:")) then
		return image
	end
	local path = ResLoader:filePathJoint(cfg,image)
	TextureAtlasRegister.instance:addMemTextureAtlas(cfg.modName, path)
	return path
end

function ResLoader:loadModel(cfg, model)
	local modId
	if type(model)=="table" then
		modId = model.mesh and models[model.mesh] or (model.icon and models[model.icon])
	else
		modId = models[model]
	end
	if modId then
	  return modId
	end
	local m_cfg = type(model) == "table" and model
	local mesh = m_cfg and m_cfg.mesh
	local icon = m_cfg and m_cfg.icon

	if mesh then
		modId = ModelManager.Instance():createModelFromMesh(mesh)
		models[mesh] = modId
	elseif icon then
		modId = ModelManager.Instance():createModelFromPicture(ResLoader:loadImage(cfg, icon), {1, 1, 1, 1})
		models[icon] = modId
	end
	if not modId then
		return false
	end
	local mat_f = m_cfg and m_cfg.matItem_first or cfg.matItem_first
	local mat_t = m_cfg and m_cfg.matItem_third or cfg.matItem_third
	local isSwings = m_cfg and m_cfg.isSwings or cfg.isSwings
	if mat_f then
	  ResLoader:setModelMatItem(modId, mat_f,1 )
	end
	if mat_t then
	  ResLoader:setModelMatItem(modId, mat_t,3)
	end
	if isSwings ~= nil then
	  ModelManager.Instance():setSwing(modId, isSwings)
	end
	return modId
end

function ResLoader:rewardContent(reward, cfg)
	local ret = {}
	local _cfg = cfg
	local icons = {}
	if not reward then
		return ret, _cfg, icons
	end
	if type(reward) == "table" then
		ret = reward
		_cfg = cfg
	elseif not string.find(reward, "/") then
		ret = Lib.readGameJson(ResLoader:filePathJoint(cfg, reward .. ".json"))
        _cfg = cfg
	elseif setting:fetch("reward", reward) then
		ret = setting:fetch("reward", reward)
		_cfg = ret
	end
	for i, arr in ipairs(ret) do
		if arr.array then
			for _, a in ipairs(arr.array or {}) do
				local func = assert(dealType[a.type], a.type)
				local icon = func(dealType, a.name)
				table.insert(icons, { icon = a.icon or icon, count = not a.countRange and (a.count or 1), countRange = a.countRange, reDeal = a.icon })
			end
		else
			local func = assert(dealType[arr.type], arr.type)
			local icon = func(dealType, arr.name)
			table.insert(icons, { icon = arr.icon or icon, count = not arr.countRange and (arr.count or 1), countRange = arr.countRange, reDeal = arr.icon })
		end
	end
	return ret, _cfg, icons
end

function ResLoader:getIcon(type, name)
	local func = assert(dealType[type], type)
	return func(dealType, name)
end

function dealType:Item(itemName)
	local icon
	local item = Item.CreateItem(itemName, 1)
	icon = item:icon()
	return icon
end

function dealType:Block(itemName)
	local icon
	local item = Item.CreateItem("/block", 1, function(_item)
		_item:set_block(itemName)
	end)
	icon = item:icon()
	return icon
end

function dealType:Coin(coinName)
	return Coin:iconByCoinName(coinName)
end

function dealType:Exp()
	return World.cfg.expIcon or "set:gui_task.json image:EXP.png"
end

function dealType:Event()
	return "set:new_gui_material.json image:chat_icon_nor"
end