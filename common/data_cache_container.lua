
local next = next
local ipairs = ipairs
local pairs = pairs
local huge = math.huge
local traceback = traceback

local typeId = 0
local function accumulator(segment)
	typeId = segment or (typeId + 1)
	return typeId
end
local _dataCacheContainerMaxDataCount = 10240 -- it can't be Infinity !
local _checkDataCacheValidTimer = nil
local _dataCacheContainers = {}

DataCacheContainer.ContainerType = 
{
	TYPE_OVERRIVE = "TYPE_OVERRIVE",
	TYPE_APPEND = "TYPE_APPEND",
}
local _ContainerTypeAccu = 
{
	TYPE_OVERRIVE = accumulator(),
	TYPE_APPEND = accumulator(),
}
DataCacheContainer.DefaultDataLifeTime = 20 * 60 * 2 -- 默认每个数据包的维持/存活时间是两分钟，超时就丢弃。
DataCacheContainer.DefaultContainerTypeAccu = _ContainerTypeAccu.TYPE_OVERRIVE -- 默认覆盖模式

-- when the event emit/subxxx,the World may not init!
--[[
	_dataCacheContainers = {
		name = {
			containerTypeAccu = accu,
			dataLifeTime = time,
			argsDatas = {
				[index] = {
					argsPack = a pack data,
					pushDataTime = pushTime
				}
			}
		}
	}

	_containerDataHandler = {
		[accu] = data handler func, func params: old argsDatas, continer data life time, push argsData pack
	}

	argsDatas must be a array.
	argsData must have pushDataTime.
]]
local function filterLegitimateArgsDatas(oldArgsDatas, dataLifeTime, World_Now)
	local firstData = oldArgsDatas[1]
	local lastData = oldArgsDatas[#oldArgsDatas]
	if (not firstData) or (not lastData) then
		return {}
	elseif (firstData.pushDataTime + dataLifeTime) > World_Now then
		return oldArgsDatas
	elseif (lastData.pushDataTime + dataLifeTime) < World_Now then
		return {}
	else
		local ret = {}
		local getNotTimeout = false
		for _, data in ipairs(oldArgsDatas) do
			if getNotTimeout or (data.pushDataTime + dataLifeTime) > World_Now then
				getNotTimeout = true
				ret[#ret + 1] = data
			end
		end
		return ret
	end
end

local _containerDataHandler = {
	[_ContainerTypeAccu.TYPE_OVERRIVE] = function(oldArgsDatas, dataLifeTime, argsPack)
		return {
            [1] = {
                argsPack = argsPack,
                pushDataTime = World.Now and World.Now() or huge
            }
		}
	end,
	[_ContainerTypeAccu.TYPE_APPEND] = function(oldArgsDatas, dataLifeTime, argsPack)
		if #oldArgsDatas >= _dataCacheContainerMaxDataCount then
			Lib.logWarning(" error !!! DataCacheContainer is too big !!! please clean or pop the data !!!", traceback())
			return oldArgsDatas
		end
		local World_Now = World.Now and World.Now() or huge
		local ret = filterLegitimateArgsDatas(oldArgsDatas, dataLifeTime, World_Now)
		ret[#ret + 1] = {
			argsPack = argsPack,
			pushDataTime = World_Now
		}
		return ret
	end,
}

-----------------------------------------------------------------------------------
function DataCacheContainer.registerContainerType(containerType, dataHandleFunc) -- handleFunc return data must be a array
    if not containerType or containerType == "" then
		Lib.logWarning(" error !!! try register a containerType but containerType was nil or \"\" !!!")
        return false
	end
	local accu = accumulator()
    _ContainerTypeAccu[containerType] = accu
    _containerDataHandler[accu] = dataHandleFunc or function () return {} end
end

function DataCacheContainer.getContainerTypeAccu(containerType)
    if not containerType or containerType == "" then
        return false
    end
    for typ, accu in pairs(_ContainerTypeAccu) do
        if containerType == typ then
            return accu
        end
    end
    return false
end

function DataCacheContainer.checkHasRegister(name) -- just check is data cache, not return data!
	return not not (name and _dataCacheContainers[name])
end
-----------------------------------------------------------------------------------
local function reg2Continer(name, containerType, dataLifeTime, argsDatas)
	local accu = DataCacheContainer.getContainerTypeAccu(containerType) or DataCacheContainer.DefaultContainerTypeAccu
	local lifeTime = dataLifeTime and (dataLifeTime > 0) and dataLifeTime or DataCacheContainer.DefaultDataLifeTime
	_dataCacheContainers[name] = {
		containerTypeAccu = accu,
		dataLifeTime = lifeTime,
		argsDatas = argsDatas
	}
end

function DataCacheContainer.registerContainer(name, containerType, dataLifeTime)
	if name == nil then
		Lib.logWarning(" error !!! try register a DataCacheContainer but not name !!!")
		return false
	end

	if _dataCacheContainers[name] then
		Lib.logWarning(" error !!! repeat register a DataCacheContainer !!! name : ", name)
		return false
	end
	reg2Continer(name, containerType, dataLifeTime, {})
	return true
end

function DataCacheContainer.changeContainerType(name, containerType, dataLifeTime)
	if not name or not containerType then
		Lib.logWarning(" error !!! try change a DataCacheContainer type but not name or not containerType!!!", name, containerType)
		return false
	end

	local dataCache = _dataCacheContainers[name]
	if not dataCache then
		Lib.logWarning(" error !!! try change a DataCacheContainer type but not dataCacheContainer. name : ", name)
		return false
	end
	reg2Continer(name, containerType, dataLifeTime or dataCache.dataLifeTime, dataCache.argsDatas)
	return true
end

function DataCacheContainer.removeContainer(name)
	if name == nil then
		Lib.logWarning(" error !!! try remove a DataCacheContainer but not name !!!")
		return false
	end
	_dataCacheContainers[name] = nil
end
-----------------------------------------------------------------------------------
local function startDataCacheCheckTimer()
	if _checkDataCacheValidTimer then
		return
	end
	if not World.LightTimer then
		return
	end
	_checkDataCacheValidTimer = World.LightTimer("_checkDataCacheValidTimer!!!!!", 20*60, function()
		local World_Now = World.Now and World.Now() or huge
		local clearNames = {}
		for name, dataCache in pairs(_dataCacheContainers or {}) do
			local tempArgsDatas = filterLegitimateArgsDatas(dataCache.argsDatas or {}, dataCache.dataLifeTime, World_Now)
			if not next(tempArgsDatas) then
				clearNames[name] = true
			else
				dataCache.argsDatas = tempArgsDatas
			end
		end
		for name in pairs(clearNames) do
			_dataCacheContainers[name] = nil
		end
		if not next(_dataCacheContainers) then
			_checkDataCacheValidTimer = nil
			return false
		end
		return true
	end)
end

function DataCacheContainer.pushDataCache(name, ...)
	if name == nil then
		Lib.logWarning(" error !!! try push data to DataCacheContainer but not name !!!")
		return false
	end

	local dataCache = _dataCacheContainers[name]
	if not dataCache then
		dataCache = {
			containerTypeAccu = DataCacheContainer.DefaultContainerTypeAccu,
			dataLifeTime = DataCacheContainer.DefaultDataLifeTime,
			argsDatas = {}
		}
		_dataCacheContainers[name] = dataCache
	end

	dataCache.argsDatas = _containerDataHandler[dataCache.containerTypeAccu](dataCache.argsDatas, dataCache.dataLifeTime, table.pack(...))
	startDataCacheCheckTimer()
	return true
end

function DataCacheContainer.popDataCache(name)
	if name == nil then
		Lib.logWarning(" error !!! try pop data in DataCacheContainer but not name !!!")
		return {}
	end

	local dataCache = _dataCacheContainers[name]
	if not dataCache then
		Lib.logWarning(" error !!! try pop data in DataCacheContainer but not register DataCacheContainer !!! name : ", name)
		return {}
	end
	local World_Now = World.Now and World.Now() or huge
	local dataLifeTime = dataCache.dataLifeTime
	local ret = {}
	for _, data in ipairs(dataCache.argsDatas) do
		if (data.pushDataTime + dataLifeTime) > World_Now then
			ret[#ret + 1] = data.argsPack
		end
	end
	dataCache.argsDatas = {}
	return ret
end

function DataCacheContainer.cleanDataCache(name)
	if name == nil then
		Lib.logWarning(" error !!! try clean data in DataCacheContainer but not name !!!")
		return false
	end

	local dataCache = _dataCacheContainers[name]
	if not dataCache then
		Lib.logWarning(" error !!! try clean data in DataCacheContainer but not register DataCacheContainer !!! name : ", name)
		return false
	end
	dataCache.argsDatas = {}
	return true
end
----------------------------------------------------------------------------------- Test code
function DataCacheContainer.changeMax()
	_dataCacheContainerMaxDataCount = 5
end
function DataCacheContainer.resetMax()
	_dataCacheContainerMaxDataCount = 10240
end
