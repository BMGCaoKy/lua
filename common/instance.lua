local type = type
---@class Instance
---@field getByInstanceId fun(id : number) : Instance
---@field getByRuntimeId fun(id : number) : Instance
---@field getInstanceID fun(self : Instance) : number
---@field getRuntimeID fun(self : Instance) : number
---@field setParent fun(self : Instance, parent : Instance) : void
---@field getParent fun(self : Instance) : Instance
---@field addChild fun(self : Instance, child : Instance) : void
---@field removeChild fun(self : Instance, child : Instance) : void
---@field removeAllChildren fun(self : Instance) : void
---@field getChildrenCount fun(self : Instance) : number
---@field getChildAt fun(self : Instance, index : number) : Instance
---@field setProperty fun(self : Instance, name    : string, value : string) : void
---@field setPropertyByLuaTable fun(self : Instance, properties : table<string, string>) : void
---@field getProperty fun(self : Instance, name	: string) : string
---@field getAllChild fun(self : Instance) : Instance[]
---@field delAllChild fun(self : Instance) : void
---@field addToGroup fun(self : Instance, name : string, persistent : boolean) : void
---@field removeFromGroup fun(self : Instance, name : string) : void
---@field isInGroup fun(self : Instance, name : string) : boolean
---@field isA fun(self : Instance, class : string) : boolean
---@field isValid fun(self : Instance) : boolean
---@field destroy fun(self : Instance) : void
local Instance = Instance

local InstanceList = L("InstanceList", {})
Instance.InstanceList = InstanceList

local VarGet, VarSet
local propertyIndicator = {}
local fastTableInitialized = false

local _getByInstanceId = L("_getByInstanceId", Instance.getByInstanceId)
function Instance.getByInstanceId(id)
    if not id or not tonumber(id) or tonumber(id) <= 0 then
        return nil
    end
    return _getByInstanceId(tonumber(id))
end

function Instance:initData()
	-- do nothing
end

local RootDir = Root.Instance():getGamePath()
local triggerParser = require "common.trigger_parser"

local function loadTrigger(cfg, btsPath)
	if World.isClient then
		return
	end
	cfg._btsTime = {}

	local path = btsPath
	if not path then
		assert(cfg.btsKey, "must have btsKey!!!")
		local _, fullFilePath = FileUtil.getBTSFilePathsByKey(cfg.btsKey)
		path = fullFilePath
	end

	if path and Lib.fileExists(path) then
		local triggers, msg = triggerParser.parse(path)
		if not triggers then
			--error(string.format("triggerParser parse file: '%s' error: %s", path, msg))
			return
		else
			cfg.triggers = triggers
		end
	--else
	--	print(string.format("triggerParser parse file error, bts file not found, btsKey = %s", cfg.btsKey))
	end

	Trigger.LoadTriggers(cfg)
end

local needConnect = {--注意：c++触发的事件需要先connect
	enter_scene = function(self)
		Trigger.CheckTriggers(self._cfg, "ENTER_SCENE", {part1 = self})
	end,
	ready = function(self)
		Trigger.CheckTriggers(self._cfg, "READY", {part1 = self})
	end,
	part_touch_part_begin = function(self, target)
		Trigger.CheckTriggers(self._cfg, "PART_TOUCH_PART_BEGIN", {part1 = self, part2 = target})
	end,
	part_touch_entity_begin = function(self, target)
		Trigger.CheckTriggers(self._cfg, "PART_TOUCH_ENTITY_BEGIN", {part1 = self, obj2 = target})
	end,
	part_touch_part_end = function(self, target)
		Trigger.CheckTriggers(self._cfg, "PART_TOUCH_PART_END", {part1 = self, part2 = target})
	end,
	part_touch_entity_end = function(self, target)
		Trigger.CheckTriggers(self._cfg, "PART_TOUCH_ENTITY_END", {part1 = self, obj2 = target})
	end,
}

function Instance.checkNeedConnectEvent(instance, triggerSet)
	if not instance or not triggerSet or not triggerSet[trigger_exec_type.NORMAL] then
		return
	end
	for key in pairs(triggerSet[trigger_exec_type.NORMAL]) do
		key = key:lower()
		if needConnect[key] then
			instance:connect(key, needConnect[key])
		end
	end
end

function Instance:loadTriggerByExtendCfg(extendCfg)
	if not extendCfg or not extendCfg.triggers then
		return
	end

	local cfg = self._cfg
	if not cfg then
		cfg = {}
		self._cfg = cfg
	end

	cfg._btsTime = {}
	cfg.triggers = {}
	for _, trigger in pairs(extendCfg.triggers) do
		table.insert(cfg.triggers,{type = trigger, actions = {}})
	end
	Trigger.LoadTriggers(cfg)
	cfg.instance = self
	return cfg.triggers and true or false
end

function Instance:loadTrigger(path, isKey)
	if World.isClient then
		return
	end

	if not path or path == "" then
		return
	end

	local cfg = self._cfg
	if not cfg then
		cfg = {}
		self._cfg = cfg
	end

	local btsPath
	
	if isKey then
		cfg.btsKey = path
	else
		btsPath = path
	end

	loadTrigger(cfg, btsPath)
	cfg.instance = self

	return cfg.triggers and true or false
end

function Instance:loadTriggerOnCreate(extendCfg, properties)
	if extendCfg.triggers then
		return self:loadTriggerByExtendCfg(extendCfg)
	end
	return self:loadTrigger(properties.btsKey, true)
end

function Instance:onCreated(params, map)
end

local EMPTY = setmetatable({}, { __newindex = error })
function Instance.newInstance(params, map)
	if not next(params) then
		return
	end
	Profiler:begin("Instance.newInstance")
	---@type Instance
	local instance
	local class = params.class
	local properties = params.properties or EMPTY
	local extendCfg = params.extendCfg or EMPTY
	local attributes = params.attributes or { }
	if class == "Entity" then
		instance = Instance.createEntity({
			cfgName = params.config,
			name = params.name or properties.name or "",
			map = params.map or map,
			pos = params.pos or Lib.deserializerStrV3(properties.position),
			scale = params.scale or properties.scale or nil --[["x:1 y:1 z:1"]],
			ry = params.ry,
			rp = params.rp,
		})
	elseif class == "DropItem" then
		local item = Item.CreateItem(params.config, params.count or 1, function(dropItem)
			if params.fullName == "/block" then
				dropItem:set_block_id(params.block_id or 0)
			end
		end)
		local fixRotation
		if properties.fixRotation ~= nil then
			fixRotation = properties.fixRotation
			properties.fixRotation = nil -- 使用完不再需要，防止在后面的setPropertyByLuaTable中设置脏属性
		elseif params.fixRotation ~= nil then
			fixRotation = params.fixRotation
		end
		instance = Instance.createDropItem({
			item = item,
			map = params.map or (map and map.name ),
			pos = params.pos,
			pitch = params.pitch or 0,
			yaw = params.yaw or 0,
			lifeTime = params.lifeTime,
			moveSpeed = params.moveSpeed, -- { x = 0, y = 0, z = 0 }
			moveTime = params.moveTime,
			guardTime = params.guardTime or 0,
			fixRotation = fixRotation,
		})
	elseif class == "Missile" then	-- TODO
		assert(false, "create Missile instance")
		-- instance = Missile.Create(params.config, { map = params.map, fromID = 0, targetID = 0, targetDir = 0 })
	elseif class == "VoxelTerrain" then
		assert(params.scene, "terrain needs scene!")
		instance = params.scene:getTerrain(true) -- params: isCreate
	else
		instance = Instance.Create(class)
		if instance then
			local ok = instance:loadTriggerOnCreate(extendCfg, properties)
			if ok and instance._cfg.triggerSet then
				Instance.checkNeedConnectEvent(instance, instance._cfg.triggerSet)
			end
			
		end
	end

    if not instance then
        Lib.logError("can not create instance: ", class)
        Profiler:finish("Instance.newInstance")
        return
    end
    local propertiesList={}
	for k,v in pairs(properties) do
		if k ~= "customColor" and k~="lodData" then
			propertiesList[#propertiesList + 1] =k
			propertiesList[#propertiesList + 1] = v
		end
	end
    instance:setPropertyByLuaTable(propertiesList, false) 
	for key, value in pairs(attributes) do
		instance:setAttribute(key, value)
	end
	
	local cusPropertiesList = {}
	for key, value in pairs(params.customProperties  or EMPTY) do
		cusPropertiesList[#cusPropertiesList + 1] = key
		cusPropertiesList[#cusPropertiesList + 1] = value
	end
	if #cusPropertiesList > 1 then 
		instance:setCustomPropertyByLuaTable(cusPropertiesList, "Instance")
	end

	instance.properties = Lib.copy(properties)
	instance.isInsteance = true
	instance.extendCfg = Lib.copy(extendCfg)
	instance.attributes = attributes

	if not IS_EDITOR then
		--进入游戏加载Folder DataSet数据
		if params.class=="Folder" and (properties.isDataSet or "false") =="true" then
			params.children = Lib.read_json_file(RootDir..map.dir.."DataSet/"..properties.id..".json") or EMPTY
		end
	end

	local children = params.children or EMPTY
	for _, params in ipairs(children) do
		local child = Instance.newInstance(params, map)
		if child then
			child:setParent(instance)
		end
	end
	instance:onCreated(params, map)
	
    if map then
        if class == "Part" or class == "MeshPart" then
            Trigger.CheckTriggers(instance._cfg, "PART_ENTER", { obj1 = instance, key = instance:getRuntimeID(), map = map })
        end
    end
	Trigger.CheckTriggers(instance._cfg, "PART_CREATED", {part = instance})
    Profiler:finish("Instance.newInstance")
    return instance
end

function Instance:clearData()
	Trigger.CheckTriggers(self._cfg, "PART_DESTORY", {part = self})
    InstanceList[self.runtimeId] = nil
end

function Instance:onDestroy()
	self:DestroySelfEvent()
end

local PropertyTypeCacheList = {}
local function getPropertyValueByType(self, key)
	local data = self:getProperty(key)
	local dataType
	if not PropertyTypeCacheList[key] then
		PropertyTypeCacheList[key] = self:getPropertyDataTypeString(key)
	end
	dataType = PropertyTypeCacheList[key]
	if data == "" or dataType == "" then
		return
	end

	local function toVector3(data)
		local vec3 = Lib.splitString(data, ": ", true)
		return Vector3.new(vec3[1], vec3[2], vec3[3])
	end

	local function toQuaternion(data)
		local quaternion = Lib.splitString(data, ": ", true)
		return Quaternion.new(quaternion[1], quaternion[2], quaternion[3], quaternion[4])
	end

	if dataType:find("Vector3") then
		return toVector3(data)
	elseif dataType:find("Quaternion") then
		return toQuaternion(data)
	elseif dataType:find("float") or dataType:find("int") then
		return tonumber(data)
	elseif dataType:find("bool") then
		return data:find("true") and true or false
	else
		return data
	end
end

local function changeValueByPropertyType(self, key, value)
	if not PropertyTypeCacheList[key] then
		PropertyTypeCacheList[key] = self:getPropertyDataTypeString(key)
	end
	local valueType = PropertyTypeCacheList[key]
	local function vectorToString(data)
		return string.format("x: %s y: %s z: %s", tostring(data.x), tostring(data.y), tostring(data.z))
	end

	local function quaterniontoString(data)
		return string.format("x: %s y: %s z: %s w: %s", tostring(data.x), tostring(data.y), tostring(data.z), tostring(data.w))
	end

	local function colorToString(data)
		return string.format("r: %s g: %s b: %s a: %s", tostring(data.r), tostring(data.g), tostring(data.b), tostring(data.a))
	end

	if valueType:find("Vector3") then
		return vectorToString(value)
	elseif valueType:find("Quaternion") then
		return quaterniontoString(value)
	elseif valueType:find("Color") then
		return colorToString(value)
	else
		return tostring(value)
	end
end

local PropertyFuncMap = APIProxy.getPropertyFuncMap()

local InstanceMT = L("InstanceMT", {})
function InstanceMT:__index(key)
	local proxyInfo = PropertyFuncMap[key]
	if proxyInfo then
		if self:isA("SceneUI") then
			if key == "LocalPosition" then
				return self:getPosition()
			elseif key == "LocalRotation" then
				return self:getRotation()
			end
		end
		if proxyInfo.getTypeFunc then
			return proxyInfo.getTypeFunc(self[proxyInfo.get](self))
		end
		if proxyInfo.func then
			return self[proxyInfo.func]
		end
		return self[proxyInfo.get](self)
	end
    if self.removed then
        if World.cfg.enableInstanceValidityCheck then
            error("Tried to read property \"" .. key .. "\" of an instance, but the instance is already destroyed");
        end
        
        if fastTableInitialized then
            local field = self.fastTable[key]
            if type(field) ~= "userdata" and field ~= propertyIndicator then
                return field
            end
        else
            for _, classTable in ipairs(self.parentTableList) do
                local field = classTable[key]
                if type(field) ~= "userdata" then
                    return field
                end
            end
        end

        return nil
    end

    if fastTableInitialized then
        local field = self.fastTable[key]
        if type(field) == "userdata" then
            return VarGet(self, field)
        elseif field == propertyIndicator then
            return getPropertyValueByType(self, key)
        elseif field ~= nil then
            return field
        end
    else
        for _, classTable in ipairs(self.parentTableList) do
            local field = classTable[key]
            if field ~= nil then
                if type(field) == "userdata" then
                    return VarGet(self, field)
                else
                    return field
                end
            end
        end
    end

    -- 有可能是自定义属性。有哪些自定义属性是加载场景后才知道
    if self:hasProperty(key) then
        return getPropertyValueByType(self, key)
    end

    if not key then
        Lib.logError("Invalid instance index: " .. tostring(key))
        return nil
    end

    return self:findFirstChild(key)
end

function InstanceMT:__newindex(key, value)
	local proxyInfo = PropertyFuncMap[key]
	if proxyInfo then
		if self:isA("SceneUI") then
			if key == "LocalPosition" then
				return self:setPosition(value)
			elseif key == "LocalRotation" then
				return self:setRotation(value)
			end
		end
		if not proxyInfo.set then
			Lib.logError(string.format("Set %s failed. Property [%s] is read only.", key, key))
			return
		end
		if proxyInfo.setTypeFunc then
			value = proxyInfo.setTypeFunc(value)
		end
		return self[proxyInfo.set](self, value)
	end
    if self.removed then
        if World.cfg.enableInstanceValidityCheck then
            error("Tried to write property \"" .. key .. "\" of an instance, but the instance is already destroyed");
        end
        rawset(self, key, value)
        return
    end
    if fastTableInitialized then
        local field = self.fastTable[key]
        if type(field) == "userdata" then
            return VarSet(self, field, value)
        elseif field == propertyIndicator then
            local changeValue = changeValueByPropertyType(self, key, value)
            self:setProperty(key, changeValue)
            return
        end
    else
        for _, classTable in ipairs(self.parentTableList) do
            local field = classTable[key]
            if type(field) == "userdata" then
                return VarSet(self, field, value)
            end
        end
        if self:hasProperty(key) then
            local changeValue = changeValueByPropertyType(self, key, value)
            self:setProperty(key, changeValue)
            return
        end
    end

    rawset(self, key, value)
end

function InstanceMT:__tostring()
    return string.format("%s[%d]", self.className, self.runtimeId)
end

local nameToFastTable = {}
local nameToClassTable = { PropertySet = PropertySet }
local nameToParentList = {}

local function getInheritanceChain(list, name)
    local classTable = nameToClassTable[name]
    if not classTable then
        return false
    end
    list[#list + 1] = name
    for i = 0, 99 do
        local parentName = classTable["__parent" .. i]
        if not parentName then
            break
        end
        if not getInheritanceChain(list, parentName) then
            break
        end
    end
    return true
end

local function updateFastTable()
    nameToFastTable = {}
    for name, _ in pairs(nameToClassTable) do
        local fastTable = {}
        local inheritanceChain = {}
        getInheritanceChain(inheritanceChain, name)
        for i = #inheritanceChain, 1, -1 do
            local className = inheritanceChain[i]
            local propNames = ClassDB.getClassSelfPropertyNames(className)
            for _, propName in ipairs(propNames) do
                fastTable[propName] = propertyIndicator
            end
            for k, v in pairs(nameToClassTable[className]) do
                fastTable[k] = v
            end
        end
        if not next(fastTable) then
            Lib.logError("Unknown instance type:", name)
        end
        for k, v in pairs(fastTable) do
            if k:sub(1,2) == "__" then
                fastTable[k] = nil
            end
        end
        nameToFastTable[name] = fastTable
    end
    for _, instance in pairs(InstanceList) do
        instance.fastTable = nameToFastTable[instance.className]
    end
end

local function initializeNameToClassTable()
    for className, _ in pairs(Instance.getInstanceClasses()) do
        nameToClassTable[className] = rawget(_G, className)
    end
end

local function initializeNameToParentList()
    for className, _ in pairs(nameToClassTable) do
        local parentNameList = {}
        getInheritanceChain(parentNameList, className)
        local parentList = {}
        for _, parentName in ipairs(parentNameList) do
            parentList[#parentList + 1] = nameToClassTable[parentName]
        end
        nameToParentList[className] = parentList
    end
end

local function watchClassTableModification()
    for className, classTable in pairs(nameToClassTable) do
        local proxyTable = setmetatable({}, {
            __index = classTable,
            __newindex = function(obj, key, value)
                if key:sub(1, 2) == "__" then
                    rawset(obj, key, value)
                    rawset(classTable, key, value)
                else
                    rawset(classTable, key, value)
                    -- TODO: 只更新需要更新的表
                    if fastTableInitialized then
                        updateFastTable()
                    end
                end
            end
        })
        for k, v in pairs(classTable) do
            if k:sub(1, 2) == "__" then
                rawset(proxyTable, k, v)
            end
        end
        rawset(_G, className, proxyTable)
    end
end

-- 要在初始化代码都执行完毕后调用这个函数。初始化阶段会频繁修改classTable，这个时候先不使用fastTable，避免频繁调用updateFastTable()
function initializeFastTable()
    updateFastTable()
    fastTableInitialized = true
end

local function InstanceWriter(runtimeId, className, isRemoved)
    local instance = InstanceList[runtimeId]
    if instance then
        return instance
    end
    instance = {
        runtimeId = runtimeId,
        className = className,
        parentTableList = assert(nameToParentList[className], className),
        fastTable = nameToFastTable[className],
        removed = isRemoved,
        isValid = function(self)
            return not self.removed
        end,
    }
    InstanceList[runtimeId] = setmetatable(instance, InstanceMT)
    if isRemoved then
        return instance
    end
    instance:initData()
    return instance
end

local tb = { writer = InstanceWriter, idKey = "runtimeId" }
World.CurWorld:regInstanceWriter(tb)
VarGet = tb.var_get
VarSet = tb.var_set

initializeNameToClassTable()
initializeNameToParentList()
watchClassTableModification()

RETURN()
