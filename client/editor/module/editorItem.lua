local editorItem = L("editorItem", Lib.derive(EditorModule.baseDerive))
local itemSetting = require "editor.setting.item_setting"
local blockSetting = require "editor.setting.block_setting"
local entitySetting = require "editor.setting.entity_setting"

function editorItem:new(mod, fullName, otherArgs)
    local data = {
        mod = mod or "block",
        fullName = fullName,
        args = {}
    }
    for k, v in pairs(otherArgs or {}) do
        data.args[k] = v
    end
    if mod == "block" then
        local item =  Item.CreateItem("/block", 1, function(_item)
			_item:set_block(fullName)
        end)
        return setmetatable({}, {
            __index = function(t, key)
                if key == "cfg" or key == "full_name" then
                    return editorItem[key]
                end
                return item[key] or editorItem[key] or data[key]
            end
        })
    else
        return setmetatable(data, {__index = editorItem})
    end
end

function editorItem:getArgs(key)
    local args = self.args
    return args[key]
end

function editorItem:icon()
    local args = self.args
    if args.icon then
        return args.icon
    end
    local cfg = self:cfg()
    if cfg.icon then
        return ResLoader:loadImage(cfg, cfg.icon)
    else
        local block_id = Block.GetNameCfgId(self.fullName)
        if block_id then
            function editorItem:block_id()
                return block_id
            end
            return ObjectPicture.Instance():buildBlockPicture(block_id)
        end
    end
end

function editorItem:type()
    local args = self.args
    return args.type or self.mod
end

function editorItem:full_name()
    return self.fullName
end

function editorItem:cfg()
    return EditorModule:getCfg(self.mod, self.fullName)
end

local function judgeCapacity(desc)
    local hasCapacity = string.find(desc, "false")
    if not string.find(desc, "gunCapacity") or not hasCapacity then
        desc = string.gsub(desc, "gunCapacity", "openCapacity")
        return desc
    end
    local descList = Lib.splitString(desc, "\n")
    local resultDesc = descList[1] .. "\n" .. "{infiniteCapacity}\n"
    for i = 2, #descList do
        if string.find(descList[i], "props_attack") then
            resultDesc = resultDesc .. descList[i] .. "\n"
            break
        end
    end
    return resultDesc
end

function editorItem:getDescText(isCreate)
    local args = self.args
    local descTipInfo = args.descTipInfo
	local cfg = self:cfg()
	if not isCreate then
	    if descTipInfo then
			return judgeCapacity(descTipInfo)
		end
		local desc = cfg.desc
		if desc then
			return judgeCapacity(desc)
		end
	
		local baseDesc = cfg.baseDesc
		if baseDesc then
			return judgeCapacity(baseDesc)
		end
	end

    -- this is a bad func
    local function getPropData()
        local getEditBaseFunc = cfg.editBaseFunc
        local func = Clientsetting[getEditBaseFunc]
        if not func then
            local data = Clientsetting.getData(getEditBaseFunc)
            if data then
                return data
            end
        else
            return func() 
        end
    end

    local function createDesc(propData)
        local base = propData and propData.base or {}
        local typeSetting = entitySetting
        local typeSettingMap = {
            block = blockSetting,
            item = itemSetting,
            entity = entitySetting
        }
        typeSetting = typeSettingMap[self.mod]
        for _, propItem in pairs(base) do
            local pos = propItem.pos
            local value
            if self.mod == "block" or self.mod == "item" then
                typeSetting = self.mod == "block" and blockSetting or itemSetting
                value = UI:getWnd("mapEditBaseProp"):getBasePropByPos(pos, self.fullName, typeSetting)
            else
                typeSetting = entitySetting
                value = UI:getWnd("mapEditBaseProp2"):getBasePropByPos(pos, self.fullName)
            end
            if value then
                typeSetting:setBasePropDescValue(self.fullName, propItem, value)
            end
        end
		typeSetting:save(self.fullName)
        --typeSetting:createDesc(self.fullName)
    end

    local propData = getPropData()
    createDesc(propData)
    if cfg.desc then
        return judgeCapacity(cfg.desc)
    end

    -- if self:isBlock() then
    --     return "{base_block_desc}\n"
    -- end
    return "base_block_desc"
end

function editorItem:isBlock()
    return self.mod == "block"
end

function editorItem:getNameText()
    local args = self.args
    if args.nameTipInfo then
        return args.nameTipInfo
    end

    local cfg = self:cfg()
    local itemname = cfg.itemname
    if itemname then
        return itemname
    end
    return cfg._name
end

function editorItem:container()
    return
end

function editorItem:stack_count()
    return 1
end

function editorItem:setShowCount(visible)
    local args = self.args
    args.showCount = visible
end

function editorItem:isShowCount()
    local args = self.args
    return args.showCount or false
end

RETURN(editorItem)
