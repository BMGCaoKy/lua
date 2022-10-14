---@class TagsConfig
local TagsConfig = T(Config, "TagsConfig")
local items = {}

function TagsConfig:init()
    local csvData = Lib.read_csv_file(Root.Instance():getGamePath() .. "lua/plugins/platform_chat/csv/tags.csv", 2)
    if not csvData then
        csvData = Lib.read_csv_file(Root.Instance():getRootPath() .. "lua/plugins/platform_chat/csv/tags.csv", 2) or {}
    end
    for _, config in pairs(csvData) do
        local data = {
            tagId = tonumber(config.tag_id),
            name = config.name or "",
            relation = config.relation or "",
            tagType = tonumber(config.tag_type) or 0,
            sort_id = tonumber(config.sort_id) or 0,
            is_guide_tag = tonumber(config.is_guide_tag) or 0,
        }
        data.relationList = {}
        local relationStr =  Lib.splitString(data.relation, "#")
        for _, tId in pairs(relationStr) do
            table.insert(data.relationList, tId)
        end
        table.insert(items, data)
    end

    table.sort(items, function(a, b )
        return a.sort_id < b.sort_id
    end)
end

-- 所有标签
function TagsConfig:getItems()
    return items or {}
end

-- 根据tagId获取某个标签信息
function TagsConfig:getItemByTagId(tagId)
    for i, v in pairs(items) do
        if v.tagId == tagId then
            return v
        end
    end
    return nil
end

-- 根据tagId获取关联标签
function TagsConfig:getRelationItems(tagId)
    for i, v in pairs(items) do
        if v.tagId == tagId then
            return v.relationList
        end
    end
    return {}
end

-- 两个标签是否关联
function TagsConfig:isRelationItem(tagId1, tagId2)
    local items1 = self:getRelationItems(tagId1)
    for i, v in pairs(items1) do
        if tonumber(v.tagId) == tonumber(tagId2) then
            return true
        end
    end

    local items2 = self:getRelationItems(tagId2)
    for i, v in pairs(items2) do
        if tonumber(v.tagId) == tonumber(tagId1) then
            return true
        end
    end
    return false
end

-- 获取标签种类列表
function TagsConfig:getItemsTagTypeList()
    local itemData = {}
    local typeList = {}
    for i, v in pairs(items) do
        if not itemData[v.tagType] then
            itemData[v.tagType] = true
            table.insert(typeList, v.tagType)
        end
    end
    table.sort(typeList, function(a, b)
        return a < b
    end)
    return typeList
end

-- 获取某种类型的标签
function TagsConfig:getItemsByTagType(tagType)
    local itemData = {}
    for i, v in pairs(items) do
        if v.tagType == tagType then
            table.insert(itemData, v)
        end
    end
    return itemData
end

-- 获取引导标签
function TagsConfig:getAllGuideTags()
    local itemData = {}
    for i, v in pairs(items) do
        if v.is_guide_tag == 1 then
            table.insert(itemData, v)
        end
    end
    return itemData
end

TagsConfig:init()
return TagsConfig