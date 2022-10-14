-- 基于游戏root目录的文件辅助模块
local GAME_PATH = Root.Instance():getGamePath()

local btsFolderPaths = { -- 蓝图BTS
"events/", -- default
"part_storage/events/",

}

local mergeShapeDataFolderPaths = { -- PartOperation顶点数据
"scene_asset/mergeShapesData/", -- default
"part_storage/mergeShapesData/",

}

-- local meshPartCollisonDataFolderPaths = { -- 未凸化的顶点数据（MeshPart才会存档）
-- "meshpart_collision/", -- default

-- }

local collisionDataFolderPaths = { -- 凸化后的顶点数据（Meshpart和Partoperation才会存档）
    "part_collision/", -- default
    "part_storage/part_collision/",
}


local fileConfigMap = {

["BTS"] = {
    ["folders"] = btsFolderPaths,
    ["fileSuffix"] = ".bts", },

["MergeShapesData"] = {
    ["folders"] = mergeShapeDataFolderPaths,
    ["fileSuffix"] = ".json", },

-- ["MeshPartCollision"] = {
--         ["folders"] = meshPartCollisonDataFolderPaths,
--         ["fileSuffix"] = ""
-- },

["Collision"] = {
    ["folders"] = collisionDataFolderPaths,
    ["fileSuffix"] = "", },

}

-- 根据文件夹路径，文件名和文件后缀 构建文件路径：
-- 返回 文件基于游戏root目录的相对路径 和 文件在系统中的绝对路径
function FileUtil.buildFilePathsByFolderAndName(folderPath, fileName, fileSuffix)
    local relativeFilePath = folderPath .. fileName .. fileSuffix
    local fullFilePath = GAME_PATH .. relativeFilePath
    return relativeFilePath, fullFilePath
end

local function getFilePathsByKey(key, keyType)
    local suffix = fileConfigMap[keyType]["fileSuffix"]
    for _, folderPath in ipairs(fileConfigMap[keyType]["folders"]) do
        local relativeFilePath, fullFilePath = FileUtil.buildFilePathsByFolderAndName(folderPath, key, suffix)
        if Lib.fileExists(fullFilePath) then
            --Lib.logInfo("Successfully find:", fullFilePath)
            return relativeFilePath, fullFilePath
        end
    end
    --Lib.logInfo(string.format("Failed find: type = %s, key = %s", keyType, key))
end

-- 根据btsKey去找到对应bts文件：
-- 找到文件 返回文件基于游戏root目录的相对路径 和 文件在系统中的绝对路径
-- 否则返回nil
function FileUtil.getBTSFilePathsByKey(btsKey)
    return getFilePathsByKey(btsKey, "BTS")
end

-- 根据mergeShapesDataKey去找到对应Union的顶点数据文件：
-- 找到文件 返回文件基于游戏root目录的相对路径 和 文件在系统中的绝对路径
-- 否则返回nil
function FileUtil.getMergeShapesDataFilePathsByKey(mergeShapesDataKey)
    return getFilePathsByKey(mergeShapesDataKey, "MergeShapesData")
end

-- 根据collisionUniqueKey去找到对应凸化数据文件：
-- 找到文件 返回文件基于游戏root目录的相对路径 和 文件在系统中的绝对路径
-- 否则返回nil
function FileUtil.getCollisionDataFilePathsByKey(collisionUniqueKey)
    return getFilePathsByKey(collisionUniqueKey, "Collision")
end


-- function FileUtil.getMeshPartCollisionDataPathsByMeshPath(meshPath)
--     local key = meshPath:gsub("/", "_")
--     local relativeFilePath, fullFilePath = getFilePathsByKey(key, "MeshPartCollision")
--     return relativeFilePath, fullFilePath
-- end

get_collision_data_path_by_key = function (collisionUniqueKey, data)
    local _, fullFilePath = FileUtil.getCollisionDataFilePathsByKey(collisionUniqueKey)
    if not fullFilePath then -- 配置文件夹中没找到，可能在zip中，暂时交由c++那边处理
        local defaultFolderPath = collisionDataFolderPaths[1]
        local _, tempFullPath = FileUtil.buildFilePathsByFolderAndName(defaultFolderPath, collisionUniqueKey, "")
        fullFilePath = tempFullPath
    end
    table.insert(data, fullFilePath)
end