local editorSetting = require "editor.setting"
local itemSetting = L("itemSetting", {})
local modName = "item"

local buffMap = {
	"hp",
	"mp"
}
local buffTemple = Clientsetting.getBuffTemple()
local break_block_temp =  buffTemple and buffTemple["pressing"].breakEfficient
local getPropFunc = {}
local setPropFunc = {}

function getPropFunc.breakEfficient(name, pos)
	local breakEff = editorSetting:getValueByKey(pos.mod, name, pos.propKey) or break_block_temp
    if type(breakEff) == "number" then
        return breakEff
    end
	for k, v in pairs(breakEff or {}) do
		for blockName, value in pairs(v) do
			return value * 10000
		end 
	end
end

function setPropFunc.breakEfficient(name, pos, value)
	local breakEff = editorSetting:getValueByKey(pos.mod, name, pos.propKey) or break_block_temp
    if type(breakEff) == "number" then
        editorSetting:saveValueByKey(pos.mod, name, pos.propKey, value)
        return
    end
	for k, v in pairs(breakEff or {}) do
		for blockName, _ in pairs(v) do
			breakEff[k][blockName] = value / 10000
		end 
	end

	editorSetting:saveValueByKey(pos.mod, name, pos.propKey, breakEff)
end	

local function getNameByFullName(fullName)
	assert(type(fullName) == "string", fullName)
	local splitRet = Lib.splitString(fullName, "/")
	local len = #splitRet
	local name = len > 0 and splitRet[len]
	return name
end

function itemSetting:createBuffName(itemFullName, buffTypeName)
	local name = getNameByFullName(itemFullName)
	return "myplugin/item_buff_" .. name .. "[" .. buffTypeName  
end

function itemSetting:getCfgByKey(fullName, key)
	local name = getNameByFullName(fullName)
    return editorSetting:getValueByKey(modName, name, key)
end

function itemSetting:saveCfgByKey(fullName, key, value, isSave)
	local name = getNameByFullName(fullName)
	return editorSetting:saveValueByKey(modName, name, key, value, isSave)
end

function itemSetting:getCfg(fullName)
    local data = editorSetting:fetch(modName, fullName)
	return Lib.copy(data and data.cfg)
end

function itemSetting:getBuff(buffName)
	local retCfg
	local name
	if buffName then
		name = getNameByFullName(buffName)
	end
	if name then
		return editorSetting:fetch("buff", name, true)
	end
end

function itemSetting:setBuffProp(buffName, prop, value)
	local buff = self:getBuff(buffName)
	local buffCfg = buff and buff.cfg
	if buffCfg then
		buffCfg[prop] = value
		buff.isChange = true
	end
end

function itemSetting:getBuffProp(buffName, prop)
	local buff = self:getBuff(buffName)
	local buffCfg = buff and buff.cfg
	return buffCfg and buffCfg[prop]
end

function itemSetting:getBuffByKey(fullName, key)
	local buffName = self:getCfgByKey(fullName, key)
	if not buffName then
		buffName = self:createBuffName(fullName, key)
		self:saveCfgByKey(fullName, key, buffName)
	end
	local data =  self:getBuff(buffName)
	return data
end

function itemSetting:getPropByBuffType(fullName, prop, buffType)
	local buff = self:getBuffByKey(fullName, buffType)
	local buffCfg = buff and buff.cfg
	if buffCfg then
		return buffCfg[prop]
	end
end

function itemSetting:setPropByBuffType(fullName, prop, buffType, value)
	local buff = self:getBuffByKey(fullName, buffType)
	local buffCfg = buff and buff.cfg
	if buffCfg then
		buffCfg[prop] = value
		buff.isChange = true
	end
end

function itemSetting:getTypeBuffList(fullName)
	local buffNameList = self:getCfgByKey(fullName, "attachInit")
	return buffNameList
end

function itemSetting:setTypeBuffList(fullName, value)
	self:saveCfgByKey(fullName, "attachInit", value)
end

function itemSetting:getUseBuffList(fullName)
	local buffNameList = self:getCfgByKey(fullName, "useAddBuffList")
	return buffNameList
end

function itemSetting:setUseBuffList(fullName, value)
	self:saveCfgByKey(fullName, "useAddBuffList", value)
end

function itemSetting:getBaseBuffName(fullName, buffType)
	local buffName = self:getCfgByKey(fullName, buffType)
	if buffName then
		return getNameByFullName(buffName)
	end
end

function itemSetting:save(fullName)
	local name = getNameByFullName(fullName)
	self:createDesc(fullName)
	editorSetting:saveCache(modName, fullName)
	-- editorSetting:save(modName, name)
	local equip_buff = self:getBaseBuffName(fullName, "equip_buff")
	local hand_buff = self:getBaseBuffName(fullName, "handBuff")
	local food_buff = self:getBaseBuffName(fullName, "food_buff")
	if equip_buff then
		editorSetting:saveCache("buff", equip_buff)
		-- editorSetting:save("buff", equip_buff)
	end
	if hand_buff then
		self:setBuffProp(hand_buff, "type", "HandBuff")
		editorSetting:saveCache("buff", hand_buff)
		-- editorSetting:save("buff", hand_buff)
	end
	if food_buff then
		self:setBuffProp(food_buff, "type", "FoodBuff")
		editorSetting:saveCache("buff", food_buff)
	end

	-- 处理批量特殊操作的东西
	local changeGroup = self:getCfgByKey(fullName, "changeGroup")
	local ignoreList = {"icon", "changeGroup"}
	local cfg = self:getCfg(fullName)
	local function canChange(key2)
		for _, key1 in pairs(ignoreList) do
			if key1 == key2 then
				return false
			end
		end
		return true
	end
	for _, name in pairs(changeGroup or {}) do
		for key, value in pairs(cfg) do
			if canChange(key) then
				self:saveCfgByKey(name, key, value)
			end
		end
		self:save(name)
	end
end

function itemSetting:cancel(fullName)
	local name = getNameByFullName(fullName)
	editorSetting:clearData(modName, name)
	local equip_buff = self:getBaseBuffName(fullName, "equip_buff")
	local hand_buff = self:getBaseBuffName(fullName, "handBuff")
	local food_buff = self:getBaseBuffName(fullName, "food_buff")
	if equip_buff then
		editorSetting:clearData("buff", self:getBaseBuffName(fullName, "equip_buff"))
	end
	if hand_buff then
		editorSetting:clearData("buff", self:getBaseBuffName(fullName, "handBuff"))
	end
	if food_buff then
		editorSetting:clearData("buff", self:getBaseBuffName(fullName, "food_buff"))
	end
end

function itemSetting:getItemType(fullName)
	return self:getCfgByKey(fullName, "itemType")
end

function itemSetting:createItemDesc(fullName)

end

function itemSetting:parsePath(fullName, pos)
	local name = pos.name
	local path = pos.path
	if path and path:sub(1, 1) == "$" then
		local index = path:find("/")
		if index then
			name = self:getCfgByKey(fullName, path:sub(2, index - 1))
			if name and type(name) == "table" then
				local key, value = next(name)
				name = value
			end
		end
	end
	name = getNameByFullName(name)
	return name
end

function itemSetting:getBasePropByPos(fullName, pos)
	if not pos.mod then
		pos.mod = modName
	end
	if pos.isEquipBuff then
		return self:getPropByBuffType(fullName, pos.propKey, "equip_buff")
	elseif pos.isHandBuff then
		return self:getPropByBuffType(fullName, pos.propKey, "handBuff")
	elseif pos.isSelf then
		return self:getCfgByKey(fullName, pos.propKey)
	elseif pos.isFoodBuff then
		return self:getPropByBuffType(fullName, pos.propKey, "food_buff")
	else
		local name = self:parsePath(fullName, pos)
		if getPropFunc[pos.propKey] then
			return getPropFunc[pos.propKey](name, pos)
		end
		return editorSetting:getValueByKey(pos.mod, name, pos.propKey)
	end
end

function itemSetting:setBasePropByPos(fullName, pos, value)
	if not pos.mod then
		pos.mod = modName
		return
	end
	if pos.isEquipBuff then
		self:setPropByBuffType(fullName, pos.propKey, "equip_buff", value)
	elseif pos.isHandBuff then
		self:setPropByBuffType(fullName, pos.propKey, "handBuff", value)
	elseif pos.isSelf then
		self:saveCfgByKey(fullName, pos.propKey, value)
	elseif pos.isFoodBuff then
		self:setPropByBuffType(fullName, pos.propKey, "food_buff", value)
	else
		local name = self:parsePath(fullName, pos)
		if setPropFunc[pos.propKey] then
			setPropFunc[pos.propKey](name, pos, value)
		else
			editorSetting:saveValueByKey(pos.mod, name, pos.propKey, value)
		end
		return pos.mod, name
	end
end

function itemSetting:delBuffItem(fullName)
	local name = getNameByFullName(fullName)
	local function delFile(mod, oName)
		local path = Root.Instance():getGamePath() .. "plugin/myplugin/" .. mod .. "/"
		local oPath = path .. oName
		CGame.instance:deleteDir(oPath)
	end

	local function delItemFile()
		local dName = delFile("item", name)
		return dName
	end

	local function delBuffFile()
		local buffKeyList = {
			"itembuff", "attachBuff"
		}
		for _, buffkey in pairs(buffKeyList) do
			local itembuff = self:getCfgByKey(name, buffkey)
			if itembuff then
				local itemBuffName = getNameByFullName(itembuff)
				delFile("buff", itemBuffName)  
			end
		end
	end
	delBuffFile()
	delItemFile()
end

function itemSetting:copyBuffItem(fullName)
	local time = os.time()
	local name = getNameByFullName(fullName)
	local function copyFile(mod, oName)
		local dName = oName .. "_" .. time
		local path = Root.Instance():getGamePath() .. "plugin/myplugin/" .. mod .. "/"
		local oPath = path .. oName
		local dstPath = path .. dName
		Lib.full_copy_folder(oPath, dstPath)
		return dName
	end

	local function copyItemFile()
		local dName = copyFile("item", name)
		return dName
	end

	local function copyBuffFile()
		local result = {}
		local buffKeyList = {
			"itembuff", "attachBuff"
		}
		for _, buffkey in pairs(buffKeyList) do
			local itembuff = self:getCfgByKey(name, buffkey)
			if itembuff then
				local itemBuffName = getNameByFullName(itembuff)
				result[buffkey] = "myplugin/" .. copyFile("buff", itemBuffName)  
			end
		end
		return result
	end

	local function modifyBuffValue(itemName, buffMap)
		for buffKey, value in pairs(buffMap) do
			self:saveCfgByKey(itemName, buffKey, value, true)
		end
	end

	local newItemName = copyItemFile()
	local buffNameMap = copyBuffFile()
	modifyBuffValue(newItemName, buffNameMap)
	--ResLoader:loadSetting()
	return "myplugin/" .. newItemName
end


function itemSetting:createDesc(fullName)
	local function getBuffType(buffName)
		local splitRet = Lib.splitString(buffName, "/")
		local len = #splitRet
		local name = len > 0 and splitRet[len]
		splitRet = Lib.splitString(buffName, "[")
		len = #splitRet
		local type = len > 0 and splitRet[len]
		return type
	end

	local cfg = self:getCfg(fullName)
	local baseDesc = cfg.baseDesc
	local resultDesc = ""
	if baseDesc then
		resultDesc = resultDesc .. "{" .. baseDesc .. "}" .. "\n" 
	end
	local basePropDesc = cfg and cfg.basePropDesc
	for lang, valueItem in pairs(basePropDesc or {}) do
		local valueDescRes = ""
		for _, valueDesc in pairs(valueItem) do
			if type(valueDesc) == "string" then
				valueDescRes = valueDescRes .. "{" .. valueDesc .."}"
			else
				valueDescRes = valueDescRes  .. tostring(valueDesc == true and "" or valueDesc)
			end
		end
		if tonumber( valueDescRes ) ~= 0 then
			local propDesc = "{" .. lang .. "}" .. "" .. valueDescRes
			resultDesc = resultDesc .. propDesc .. "\n"
		end
	end
	local buffList = self:getTypeBuffList(fullName) or self:getUseBuffList(fullName) or {}
	local buffDesc = "" 
	for index, v in pairs(buffList) do
		local buffName = getBuffType(v)
		if buffDesc == "" then
			buffDesc = "{attach_buff_desc}"
		end
		if index ~= 1 then
			buffDesc = buffDesc .. ",{" .. buffName .."}"
		else
			buffDesc = buffDesc .. "{" ..  buffName .."}"
		end
	end
	resultDesc = resultDesc .. buffDesc
	self:saveCfgByKey(fullName, "desc", resultDesc)
end

function itemSetting:setBasePropDescValue(fullName, propItem, value)
	local cfg = self:getCfg(fullName)
	local basePropDesc = cfg and cfg.basePropDesc
	if not basePropDesc then
		basePropDesc = {}
	end
	local descIndex = propItem.descIndex
	local descDataItem = Clientsetting.getUIDescCsvData(descIndex)
	local descTitleLangKey = descDataItem.title
	local descTaildLangKey = descDataItem.tailText
	local sysConvert = propItem.SysConvert
	if  sysConvert  and sysConvert ~=0 then
		value = value / sysConvert
	end
	basePropDesc[descTitleLangKey] = {
		value, descTaildLangKey
	}
	self:saveCfgByKey(fullName, "basePropDesc", basePropDesc)
end

RETURN(itemSetting)
