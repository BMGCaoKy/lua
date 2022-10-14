if not GUIManager:Instance():isEnabled() then
	return
end

local self = GUILib

local guiMgr = L("guiMgr", GUIManager:Instance())
local imgMgr = L("imgMgr", CEGUIImageManager:getSingleton())
local winMgr = L("winMgr", CEGUIWindowManager:getSingleton())

local imagesetResourceGroupMap = {
	imagesets = true,
	_imagesets_ = true,
}

local function filePathJoint(cfg, image)
	local path, resourceGroup, isEditorPath
	if image:sub(1,1)=="/" and cfg then
		--"/icon.png"
		path = "plugin/" .. cfg.plugin .. image
		resourceGroup = "gameres"
	elseif image:sub(1,1)=="@" then
		--"@icon.png"
		path = image:sub(2)
		resourceGroup = string.sub(path, 1, 5) == "asset" and "gameres" or "asset"
		isEditorPath = true
	elseif image:sub(1,1)=="#" then
		--"#icon.png"
		path = image:sub(2)
		resourceGroup = "_textures_"
	elseif image:find("plugin") then
		path = image
		resourceGroup = "gameres"
	elseif not cfg then
		return false
	else
		path = "plugin/" .. cfg.plugin .. "/" .. cfg.modName .. "/" .. cfg._name .. "/" .. image
		resourceGroup = "gameres"
	end
	return path, resourceGroup, isEditorPath
end

function GUILib.getImagePath(image, cfg)
	if not image or image == "" then
		return
	end

	if image:find("set:") or image:find("http:") or image:find("https:") then
		return image
	end

	if image:find("block:") then
		--cpp will auto build image
		local resourceGroup = "gameres"
		local blockName = string.match(image, "block:(.+)")
		local block_id = Block.GetNameCfgId(blockName)
		local blockCfg = Block.GetNameCfg(blockName)
		if block_id == 36 then
			-- 透明方块需要特殊处理，游戏中是不会显示透明方块，所以直接正常加载这张透明图片即可
			return filePathJoint(blockCfg, blockCfg.icon)
		else
			image = ObjectPicture.Instance():buildBlockPicture(block_id)
		end
		return image, resourceGroup
	end

	return filePathJoint(cfg, image)
end

function GUILib.getImagesetFile(imageName)
	if imageName:find("set:") and imageName:sub(1, 4) == "set:" then
		local _, _, imageset, name = imageName:find("set:(.+)%.json%s+image:(.+)")
		local pngIndex = name:find(".png")
		name = pngIndex and name:sub(1, pngIndex - 1) or name
		return imageset .. ".imageset", imageset .. "/" .. name
	else 
		local _, count = string.gsub(imageName, "/", "/")
		local _, _, imageset, name = imageName:find("(.+)/(.+)") 
		if name and not name:find("/") and count and count==1 then
			return imageset .. ".imageset", imageset .. "/" .. name
		end
	end
	return nil, imageName
end

function GUILib.loadImageset(imageset, resourceGroup)
	if lfs.attributes(guiMgr:getResGroupDir("_imagesets_") .. "/" .. imageset) then 
		imgMgr:loadImageset(imageset, "_imagesets_")
	elseif lfs.attributes(guiMgr:getResGroupDir("imagesets") .. "/" .. imageset) then 
		imgMgr:loadImageset(imageset, "imagesets")
	else
		Lib.logError("can not find define imageset resourceGroup :", resourceGroup, imageset)
	end
end

function GUILib.loadImage(imageName, cfg)
	if not imageName then
		Lib.logWarning("load image empty", imageName)
		return
	end

	local isdef = imgMgr:isDefined(imageName)
	if isdef then
		return imageName
	end

	if imageName:find("set:") then
		return imageName
	end

	local filePath, resourceGroup, isEditorPath = GUILib.getImagePath(imageName, cfg)
	if not filePath then
		Lib.logError("can not find image:", imageName)
		return
	end

	local imageKey = resourceGroup and GUILib.getImageKey(filePath, resourceGroup) or filePath
	imageKey = isEditorPath and filePath or imageKey
	local isdef = imgMgr:isDefined(imageKey)
	if not isdef and resourceGroup then
		imgMgr:addFromImageFile(imageKey, filePath, resourceGroup)
	end
	return imageKey, filePath
end

function GUILib.unloadImage(imageKey)
	imgMgr:destroy(imageKey)
end

function GUILib.loadImageFromResLoader(oldImageName, newImageName)
	if not newImageName or not oldImageName then
		return
	end
	local isdef = imgMgr:isDefined(newImageName)
	if isdef then
		return
	end
	if oldImageName:find("set:") or oldImageName:find("block:") or oldImageName:find("http:") or oldImageName:find("https:")then
		return
	end
	local resourceGroup = "gameres"
	if oldImageName:sub(1,1)=="@" then
		resourceGroup = string.sub(newImageName, 1, 5) == "asset" and "gameres" or "asset"
	elseif oldImageName:sub(1,1)=="#" then
		resourceGroup = "_textures_"
	end
	imgMgr:addFromImageFile(newImageName, newImageName, resourceGroup)
end

function GUILib.getImageKey(filePath, resGroup)
	return resGroup .. "|" .. filePath
end

function GUILib.loadSingleImage(filePath, resGroup)
  local imageKey = GUILib.getImageKey(filePath, resGroup)
  local isdef = imgMgr:isDefined(imageKey)
  if not isdef and resGroup then
    imgMgr:addFromImageFile(imageKey, filePath, resGroup)
  end
  return imageKey
end

function GUILib.deg2QuaternionStr(x, y, z)
	local atan = math.atan
	local cos = math.cos
	local sin = math.sin
	local d2r = 4 * atan (1, 1) / 180
	
	local sin_x_2 = sin(0.5 * x * d2r)
	local sin_y_2 = sin(0.5 * y * d2r)
	local sin_z_2 = sin(0.5 * z * d2r)
	
	local cos_x_2 = cos(0.5 * x * d2r)
	local cos_y_2 = cos(0.5 * y * d2r)
	local cos_z_2 = cos(0.5 * z * d2r)
	
	local r_w = cos_z_2 * cos_y_2 * cos_x_2 + sin_z_2 * sin_y_2 * sin_x_2
	local r_x = cos_z_2 * cos_y_2 * sin_x_2 - sin_z_2 * sin_y_2 * cos_x_2
	local r_y = cos_z_2 * sin_y_2 * cos_x_2 + sin_z_2 * cos_y_2 * sin_x_2
	local r_z = sin_z_2 * cos_y_2 * cos_x_2 - cos_z_2 * sin_y_2 * sin_x_2
	return "w:"..r_w.." x:"..r_x.." y:"..r_y.." z:"..r_z
end

function GUILib.quaternion2Deg(w, x, y, z)
	local atan = math.atan
	local asin = math.asin
	local PI = math.pi

	local epsilon = 0.0009765625
	local threshold = 0.5 - epsilon;
	local test = w * y - x * z;
	local r2a = 180 / PI

	local r_x,r_y,r_z
	if test < -threshold or test >threshold then
		local sign = test > 0 and 1 or -1
		r_z = -2 * sign * atan(x, w)* r2a
		r_y = sign * (PI / 2)* r2a
		r_x = 0
	else
		r_x = atan(2 * (y * z + w * x), w * w - x * x - y * y + z * z) * r2a
		r_y = asin(-2 * (x * z - w * y))* r2a
		r_z = atan(2 * (x * y + w * z), w * w + x * x - y * y - z * z) * r2a
	end
	return {r_x, r_y, r_z}
end