---@class TagsAutoConfig
local TagsAutoConfig = T(Config, "TagsAutoConfig")

local settings = {}

function TagsAutoConfig:init()
    local csvData = Lib.read_csv_file(Root.Instance():getGamePath() .. "lua/plugins/platform_chat/csv/tags_auto.csv", 2)
    if not csvData then
        csvData = Lib.read_csv_file(Root.Instance():getRootPath() .. "lua/plugins/platform_chat/csv/tags_auto.csv", 2) or {}
    end
    for _, vConfig in pairs(csvData) do
        local data = {
            tagId = tonumber(vConfig.n_tag_id) or 0,
            conditionType = tonumber(vConfig.n_condition_type) or 0,
            conditionPriority = tonumber(vConfig.n_condition_priority) or 0,
            conditions = vConfig.s_conditions or "",
            timeLimit = tonumber(vConfig.n_time_limit) or 0,
            exclusion = vConfig.s_exclusion or "",
        }

        data.exclusionList = {}
        local exclusionStr =  Lib.splitString(data.exclusion, "#")
        for _, tId in pairs(exclusionStr) do
            table.insert(data.exclusionList, tonumber(tId))
        end

        data.conditionsNum = {}
        local conditionsStr =  Lib.splitString(data.conditions, "#")
        -- >=min, <max
        if conditionsStr[1] then
            data.conditionsNum.min =  tonumber(conditionsStr[1] )
        end
        if conditionsStr[2] then
            data.conditionsNum.max =  tonumber(conditionsStr[2] )
        end

        settings[data.tagId] = data
    end
end

function TagsAutoConfig:getCfgByTagId(tagId)
    if not settings[tagId] then
        return nil
    end
    return settings[tagId]
end

function TagsAutoConfig:getAllCfgs()
    return settings
end

-- 获取某种分配条件的标签
function TagsAutoConfig:getItemsByConditionType(conditionType)
    local items = {}
    for i, v in pairs(settings) do
        if v.conditionType == conditionType then
            table.insert(items, v)
        end
    end

    table.sort(items, function(a, b )
        return a.conditionPriority > b.conditionPriority
    end)
    return items
end

-- 获取某种分配条件,并达到条件的最优标签
function TagsAutoConfig:getCompleteItemsByConditionType(conditionType, counts, playTime)
    local items = {}
    for i, v in pairs(settings) do
        if v.conditionType == conditionType then
            if counts <= 0 then
                if v.timeLimit < playTime then -- 超过时限，还没获得过次数的，也可以得到标签
                    if v.conditionsNum.min and v.conditionsNum.max then
                        if counts >= v.conditionsNum.min and v.conditionsNum.min < v.conditionsNum.max then
                            table.insert(items, v)
                        end
                    elseif v.conditionsNum.min then
                        if counts >= v.conditionsNum.min then
                            table.insert(items, v)
                        end
                    end
                end
            else
                if v.timeLimit >= playTime then
                    if v.conditionsNum.min and v.conditionsNum.max then
                        if counts >= v.conditionsNum.min and v.conditionsNum.min < v.conditionsNum.max then
                            table.insert(items, v)
                        end
                    elseif v.conditionsNum.min then
                        if counts >= v.conditionsNum.min then
                            table.insert(items, v)
                        end
                    end
                end
            end
        end
    end

    table.sort(items, function(a, b )
        return a.conditionPriority > b.conditionPriority
    end)
    return items[1]
end

-- 根据tagId获取互斥的标签
function TagsAutoConfig:getExclusionItems(tagId)
    for i, v in pairs(settings) do
        if v.tagId == tagId then
            return v.exclusionList
        end
    end
    return nil
end

-- 两个标签是否互斥
function TagsAutoConfig:isExclusionItem(tagId1, tagId2)
    local items1 = self:getExclusionItems(tagId1)
    for i, v in pairs(items1) do
        if v.tagId == tagId2 then
            return true
        end
    end

    local items2 = self:getExclusionItems(tagId2)
    for i, v in pairs(items2) do
        if v.tagId == tagId1 then
            return true
        end
    end
    return false
end
TagsAutoConfig:init()
return TagsAutoConfig


