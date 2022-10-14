local showKillCount, showScore, propsCollection, endPoint
local ret = {}
local function initRealtimeRankCondition()
    local condition = World.cfg.gameOverCondition
    assert(condition and next(condition))
    showKillCount = condition.killCount and condition.killCount.enable or false
    showScore = condition.attainScore and condition.attainScore.enable or false
    propsCollection = condition.propsCollection and condition.propsCollection.enable or false
    endPoint = condition.endPointCondition and condition.endPointCondition.enable or false
    if condition.otherAllDie or condition.noCondition or propsCollection or endPoint then
        showKillCount = true
        showScore = true
    end
    if not (showKillCount or showScore) then
        assert(condition.timeOver.enable)
        if condition.timeOver.value == "score" then
            showScore = true
        else
            showKillCount = true
        end
    end
    ret.noCondition = condition.noCondition and true or false
    ret.showGameTimeRank = World.cfg.showGameInfoMode == "GAME_TIME_RANK" and true or false
end

if not next(ret) then
    initRealtimeRankCondition()
    ret.showKillCount = showKillCount
    ret.showScore = showScore
end

return ret