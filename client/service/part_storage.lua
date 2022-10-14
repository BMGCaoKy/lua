local PartStorage = L("PartStorage", {})
local DEFAULT_FOLDER_PATH = "part_storage/"
local SETTING_PATH = DEFAULT_FOLDER_PATH .. "setting.json"

local function save(serializeInstances)
    local savePath = Root.Instance():getGamePath() .. DEFAULT_FOLDER_PATH
    if not Lib.dirExist(savePath) then
        Lib.mkPath(savePath)
    end
    Lib.saveGameJson(SETTING_PATH, serializeInstances)
end

function PartStorage:save()
    local manager = World.CurWorld:getSceneManager()
    local partStroageIns = manager:getPartStorage()
    local serializeInstances = {}
    partStroageIns:getAllChildrenAsTable(serializeInstances)
    save(serializeInstances)
end

RETURN(PartStorage)
