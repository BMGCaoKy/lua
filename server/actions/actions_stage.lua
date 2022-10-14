local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions

function Actions.ShowStageSettlement(data, params, context)
    Stage.ShowStageSettlement(params.entity, params.winName)
end

function Actions.CanStartStage(data, params, context)
    local status, errMsg, value = Stage.CanStartStage(params.entity, params.fullName, params.chapterId, params.stage)
    return {status = status, errMsg = errMsg, value = value}
end

function Actions.StartStage(data, params, context)
    return Stage.StartStage(params.entity, params.fullName, params.chapterId, params.stage, params.test)
end

function Actions.ShowStageOptions(data, params, context)
    Stage.SendEnableChapters(params.player, params.fullName, params.winName)
end

function Actions.UpdateStageScore(data, params, context)
    Stage.UpdateStageScore(params.player, params.score, params.pyramid, params.oldScore)
end

function Actions.AddStageStars(data, params, context)
    Stage.AddStageStars(params.player, params.index, params.light)
end

function Actions.SetStageTopInfo(data, params, context)
    Stage.SetStageTopInfo(params.player, params.key, params.value, params.textKey)
end

function Actions.StageEndTime(data, params, context)
    Stage.StageEndTime(params.player, params.event)
end

function Actions.ExitStage(data, params, context)
    Stage.ExitStage(params.player)
end

function Actions.GetChapterData(data, params, context)
    return Stage.GetChapterData(params.entity, params.fullName, params.chapterId)
end

function Actions.GetStageCfg(data, params, context)
    local cfg = Stage.GetStageCfg(params.fullName, params.chapterId, params.stage)
    return cfg[params.key]
end

function Actions.UnlockStage(data, params, context)
    return Stage.ForceUnlockStage(params.player, params.fullName, params.chapterId, params.stage, params.refreshUI, params.winName, params.pay)
end

--{totalStars = totalStars, totalScore = totalScore, totalTime = totalTime}
function Actions.PassedStagesTranscript(data, params, context)
    local achievement = Stage.PassedStagesAchievement(params.player, params.fullName)
    return params.key and achievement[params.key] or achievement
end

function Actions.GetStageArchiveValue(data, params, context)
    return Stage.GetStageArchiveValue(params.player, params.fullName, params.chapterId, params.stage, params.key)
end

function Actions.GetCurStageScore(data, params, context)
    return Stage.GetCurStageScore(params.player)
end

function Actions.GetTimeRemaining(data, params, context)
    return Stage.GetTimeRemaining(params.player)
end