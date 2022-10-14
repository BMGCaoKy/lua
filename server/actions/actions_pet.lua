local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

function Actions.CreatePet(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidPlayer(entity) then
        return
    end
    local petCfg = params.cfg
    if ActionsLib.isEmptyString(petCfg, "Pet") then
        return
    end
    return entity:createPet(petCfg, params.show~=false, params.map, params.pos)
end

function Actions.GetPet(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidPlayer(entity) or ActionsLib.isNil(params.index, "Index") then
        return
    end
    return entity:getPet(params.index)
end

function Actions.ShowPet(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidPlayer(entity) or ActionsLib.isNil(params.index, "Index") then
        return
    end
    entity:showPet(params.index, params.map, params.pos)
end

function Actions.SetPetFollow(data, params, context)
    local entity = params.entity
    local followSwitch = params.followSwitch
    if ActionsLib.isInvalidPlayer(entity) or ActionsLib.isNil(params.index, "Index") then
        return
    end
    entity:setPetFollow(params.index, followSwitch)
end

function Actions.HidePet(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidPlayer(entity) or ActionsLib.isNil(params.index, "Index") then
        return
    end
    entity:hidePet(params.index)
end

function Actions.ChangePet(data,params,content)
    local entity = params.entity
    if ActionsLib.isInvalidPlayer(entity) then
        return
    end
    local petCfg = params.cfgName
    if ActionsLib.isEmptyString(petCfg, "Pet") or ActionsLib.isNil(params.index, "Index") then
        return
    end
    return entity:changePetCfg(params.index, petCfg)
end

function Actions.AddPet(data, params, context)
    local player  = params.player
    if ActionsLib.isInvalidPlayer(player) then
        return
    end
    local pet = params.entity
    if ActionsLib.isInvalidEntity(pet, "Pet") then
        return
    end
    return player:addPet(pet)
end

function Actions.RelievedPet(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidPlayer(entity) or ActionsLib.isNil(params.index, "Index") then
        return
    end
    return entity:relievedPet(params.index)
end

function Actions.GetPetIndex(data, params, context)
    return params.entity:getValue("petIndex")
end

