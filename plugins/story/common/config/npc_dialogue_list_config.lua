---@class NPCDialogueListConfig
local NPCDialogueListConfig = T(Config, "NPCDialogueListConfig")

local settings = {}

function NPCDialogueListConfig:init()
    print("NPCDialogueListConfig:init")
    local config = Lib.read_csv_file(Root.Instance():getGamePath() .. "config/npc_dialogue_list.csv", 2)
    for _, vConfig in pairs(config) do
        local data = {}

        data.dialogue_id = tonumber(vConfig.dialogue_id) or 0
        data.npc_name = vConfig.npc_name
        data.npc_id = tonumber(vConfig.npc_id) or 0
        data.action_id = tonumber(vConfig.action_id) or 0
        data.reason_id = tonumber(vConfig.reason_id) or 1 

        data.dialogue_list = {}
        local dialogue_list = Lib.split(vConfig.dialogue_list, ",")
        for _, dialogue in pairs(dialogue_list) do
            table.insert(data.dialogue_list, tonumber(dialogue))
        end

        settings[data.dialogue_id] = data

    end
end

function NPCDialogueListConfig:getDialogueById(id)
    local data = settings[id]
    if data then
        return data
    else
        perror("NPCDialogueListConfig:getDialogueById fail,id is:",id)
        return nil
    end
end

function NPCDialogueListConfig:getDialogue(npc_id, action_id, reason_id)
    for _, data in pairs(settings) do
        
        if data.npc_id == npc_id and data.action_id == action_id and data.reason_id == reason_id then
            return data
        end
    end

    print("===========can not find cfg by this npcId:",npc_id," and actionId:",action_id)

    return nil
end

NPCDialogueListConfig:init()
return NPCDialogueListConfig