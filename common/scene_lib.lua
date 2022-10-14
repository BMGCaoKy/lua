local MERGE_SHAPES_DATA_DEFAULT_FOLDER_PATH = "scene_asset/mergeShapesData/"
local GAME_PATH = Root.Instance():getGamePath()

function part_operation_event(event, ...)
	local func = SceneLib[event]
	if not func then
		print("no part_operation_event! ", event)
		return
	end
	func(...)
end

local function saveSceneAsset(relativeFolderPath, fileName, content)
	local fullFolderPath = GAME_PATH .. relativeFolderPath
	if not Lib.dirExist(fullFolderPath) then
		Lib.mkPath(fullFolderPath)
	end
	local relativeFilePath, _ = FileUtil.buildFilePathsByFolderAndName(relativeFolderPath, fileName, ".json")
	Lib.saveGameJson(relativeFilePath, content)
end

local function deleteSceneAsset(relativeFolderPath, fileName)
	local _, fullFilePath = FileUtil.buildFilePathsByFolderAndName(relativeFolderPath, fileName, ".json")
	if Lib.fileExists(fullFilePath) then
		os.remove(fullFilePath)
	end
end

function SceneLib.saveMergeShapesData(mergeShapesDataKey, mergeShapesData)
	local relativeFolderPath = MERGE_SHAPES_DATA_DEFAULT_FOLDER_PATH
	saveSceneAsset(relativeFolderPath, mergeShapesDataKey, mergeShapesData)
end

local function loadMergeShapesData(mergeShapesDataKey)
	local relativeFilePath, _ = FileUtil.getMergeShapesDataFilePathsByKey(mergeShapesDataKey)
	local mergeShapesData = {}
	if relativeFilePath then
		mergeShapesData = Lib.readGameJson(relativeFilePath)
	end
	return mergeShapesData
end

function SceneLib.loadBasicShapes(mergeShapesDataKey, data)
	local mergeShapesData = loadMergeShapesData(mergeShapesDataKey)
	local temp = mergeShapesData.basicShapesData
	if temp then
		for key, value in pairs(temp) do
			data[key] = value
		end
	end
end

function SceneLib.loadBrushData(mergeShapesDataKey, brushData, additionalData)
	local mergeShapesData = loadMergeShapesData(mergeShapesDataKey)
	local temp = mergeShapesData.brushData
	if temp then
		for key, value in pairs(temp) do
			brushData[key] = value
		end
	end
	temp = mergeShapesData.additionalData
	if temp then
		for key, value in pairs(temp) do
			additionalData[key] = value
		end
	end
end

function SceneLib.addAdditionalMaterial(path)
	if not SceneLib.pathsTb then
		SceneLib.pathsTb = {}
	end
	for _, v in pairs(SceneLib.pathsTb) do
		if v == path then
			return
		end
	end

	table.insert(SceneLib.pathsTb, path)
end

function SceneLib.loadAdditionalMaterial(pathsTb)
	for _, v in pairs(SceneLib.pathsTb or {}) do
		pathsTb[#pathsTb + 1] = v
	end

	--SceneLib.pathsTb = nil
end

local function unionPart(target, parts)
	local scene = assert(target:getScene())
	local op = Instance.Create("PartOperation")
	op:setPosition(target:getPosition())
	table.insert(parts, 1, target)
	op:mergeShapes(parts)
	op:setPosition(op:getFixedPosition())
	op:setParent(scene:getRoot())
	return op
end

function PartOperation:splitPart()
	local childs = {}
	local content = {}
	SceneLib.loadBasicShapes(self:getMergeShapesDataKey(), content)
	local scene = self:getScene()
	if not scene then
		return
	end
	
	local map = scene:getMap()
	for _, cfg in ipairs(content) do
		cfg.scene = scene
		local subPart = Instance.newInstance(cfg, map)
		if subPart then
			childs[#childs + 1] = subPart
		end
	end
	self:splitShapes(childs)
	return childs
end

function CSGShape:unionPart(parts)
	self:setBooleanOperation(0)
	assert(parts and next(parts))
	for _, part in ipairs(parts) do
		part:setBooleanOperation(0)
	end
	return unionPart(self, parts)
end

function CSGShape:intersectPart(parts)
	assert(parts and next(parts))
	self:setBooleanOperation(0)
	for _, part in ipairs(parts) do
		part:setBooleanOperation(1)
	end
	return unionPart(self, parts)
end

function CSGShape:reversePart(parts)
	assert(parts and next(parts))
	self:setBooleanOperation(0)
	for _, part in ipairs(parts) do
		part:setBooleanOperation(2)
	end
	return unionPart(self, parts)
end

function PartOperation:onRemovedByEditor()
	local relativeFolderPath = MERGE_SHAPES_DATA_DEFAULT_FOLDER_PATH
	deleteSceneAsset(relativeFolderPath, self:getMergeShapesDataKey())
end