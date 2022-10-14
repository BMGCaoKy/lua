---@class NPCDialogueContentConfig
local NPCDialogueContentConfig = T(Config, "NPCDialogueContentConfig")

local settings = {}

function NPCDialogueContentConfig:init()
    local config = Lib.read_csv_file(Root.Instance():getGamePath() .. "config/npc_dialogue_content.csv", 2)
    for _, vConfig in pairs(config) do
        local data = {}

        data.id = tonumber(vConfig.id) or 0
        data.name = vConfig.name
        data.content = vConfig.content
        settings[data.id] = data
        
    end
end

function NPCDialogueContentConfig:getContentById(id)
    local data = settings[id]
    if data then
        return data
    else
        perror("NPCDialogueContentConfig:getContentById fail,id is:",id)
        return nil
    end
end

NPCDialogueContentConfig:init()

return NPCDialogueContentConfig