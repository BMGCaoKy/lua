require "common.stage"
local setting = require "common.setting"

local function getCurStageInfo(player)
    return T(player, "curStage")
end

local function emptyCurStageInfo(player)
    local empty = {}
    player["curStage"] = empty
    return empty
end

--��ȡ�½ڴ浵����
local function getChapterArchiveData(player, fullName, chapterId)
    assert(fullName)
    local chapters = T(player, "chapters")
    local plugin = T(chapters, fullName)
    if chapterId then
        return T(plugin, chapterId)
    else
        return plugin
    end
end

--��ȡ����ȡ���Ǽ�����
local function getReceivedStarReward(player, fullName, chapterId)
    local chapter = getChapterArchiveData(player, fullName, chapterId)
    return chapter.receivedStarReward or {}
end

--��ȡ�ؿ��浵����
local function getStageArchiveData(player, fullName, chapterId, stage)
    stage = tonumber(stage)
    local chapter = getChapterArchiveData(player, fullName, chapterId)
    return chapter.stages and chapter.stages[stage]
end

--��ͨ�صĹؿ�
local function getPassedStages(player, fullName, chapterId)
    local archiveData = getChapterArchiveData(player, fullName, chapterId)
    local passedStages = {}
    for k, v in pairs(archiveData.stages or {}) do
        table.insert(passedStages, k)
    end
    return passedStages
end

--���¿ɽ�������йؿ�
local function enableStages(player, fullName, chapterId)
    local chapterCfg = Stage.GetStageCfg(fullName, chapterId)
    local stages = {}
    for k, v in ipairs(chapterCfg.stages or {}) do
        if Stage.CanStartStage(player, fullName, chapterCfg.id, k) then
            stages[#stages + 1] = k
        end
    end
    return stages
end

--����ؿ�����
local function updateStageData(player, fullName, chapterId, stage, stageData)
    stage = tonumber(stage)
    if not (player and fullName and chapterId and stage and stageData) then
        return
    end
    local chapter = getChapterArchiveData(player, fullName, chapterId)
    chapter.stages = chapter.stages or {}
    local oldData = chapter.stages[stage] or {}

    oldData.stars = oldData.stars or {}
    for k, v in pairs(stageData.stars or {}) do
        oldData.stars[k] = v
    end
    if stageData.time then
        oldData.minTime = oldData.minTime and oldData.minTime < stageData.time and oldData.minTime or stageData.time
    end
    if stageData.score then
        oldData.maxScore = oldData.maxScore and oldData.maxScore > stageData.score and oldData.maxScore or stageData.score
    end
    oldData.baseReward = oldData.baseReward or stageData.baseReward
    oldData.firstReward = oldData.firstReward or stageData.firstReward
    oldData.starReward = oldData.starReward or stageData.starReward
    oldData.lastTime = os.time()
    chapter.stages[stage] = oldData
    Stage.ForceUnlockChapter(player, fullName, chapterId)
    Stage.ForceUnlockStage(player, fullName, chapterId, stage)
end

local function receiveReward(player, fullName, reward)
    if not reward then
        return false
    end
    local cfg = Stage.GetStageCfg(fullName)
    local args = {
        reward = reward,
        cfg = cfg
    }
    return player:reward(args)
end

--�ؿ��Ƿ��������(��һ�ؿɽ�and���ش��)
local function canStageUnlock(player, fullName, chapterId, stage)
    local ach = Stage.PassedStagesAchievement(player, fullName)
    local stageCfg = Stage.GetStageCfg(fullName, chapterId, stage)
    local stageDpStars = stageCfg.dependStars
    local reach = true
    if stageDpStars and ach.totalStars < stageDpStars then
        reach = false
    end
    if stage == 1 then
        local lastChapterCfg = Stage.GetLastChapterCfg(fullName, chapterId)
        if not lastChapterCfg then
            return true
        end
        local status, err, con = Stage.CanStartStage(player, fullName, lastChapterCfg.id, #lastChapterCfg.stages)
        if not status then
            return status, "stage_notPass"
        else
            if reach then
                return true
            else
                return false, "stage_notReach", stageDpStars
            end
        end
    end

    local status, err, con = Stage.CanStartStage(player, fullName, chapterId, stage - 1)
    if not status then
        return status, "stage_notPass"
    else
        if reach then
            return true
        else
            return false, "stage_notReach", stageDpStars
        end
    end
end


--�ж��½�/�ؿ��Ƿ����(���Ҫ�ж��½��Ƿ�ɿ�����stage������1����Ϊ������½ڵĵ�һ���ܽ����½���Ȼ�ܽ�)
function Stage.CanStartStage(player, fullName, chapterId, stage)
    stage = tonumber(stage)
    stage = stage and stage ~= 0 and stage or 1
    local cfg = Stage.GetStageCfg(fullName)
    local chapterCfg = Stage.GetStageCfg(fullName, chapterId)
    local stageCfg = Stage.GetStageCfg(fullName, chapterId, stage)
    local chapterData = getChapterArchiveData(player, fullName, chapterId)

    --�ȼ����
    if stageCfg.level and stageCfg.level > player:getValue("level") then
        return false, "level_limit", stageCfg.level
    end

    --��ͨ��
    local stagesData = chapterData.stages or {}
    local stageData = stagesData[stage]
    if stageData then
        return true
    end

    --�ѽ���
    if chapterData.unlockStages and chapterData.unlockStages[stage] then
        return true
    end

    local ach = Stage.PassedStagesAchievement(player, fullName)
    local chapterDpStars = chapterCfg.dependStars
    --�������½�����
    if chapterDpStars and chapterDpStars > 0 and ach.totalStars < chapterDpStars then
        return false, "chapter_notReach", chapterDpStars --��һ��δ���
    end

    local stageDpStars = stageCfg.dependStars
    --����ؿ�����
    if stageDpStars and stageDpStars > 0 and ach.totalStars < stageDpStars then
        return false, "stage_notReach", stageDpStars --����δ���
    end

    if not cfg.checkLock then
        return true--������Ƿ����
    end

    --�������һ��, �����Ƿ���ͨ��
    if stage > 1 then
        if stagesData[stage - 1] then
            return true
        else
            return false, "stage_notPass"
        end
    end

    --�������һ�£���һ�µ����һ���Ƿ���ͨ��
    local lastCfg = Stage.GetLastChapterCfg(fullName, chapterId)
    if lastCfg then
        local lastChapterData = getChapterArchiveData(player, fullName, lastCfg.id)
        local stagesData = lastChapterData.stages or {}
        if stagesData[#lastCfg.stages] then
            return true
        end
        return false, "last_chapter_noPass" --��һ��δͨ��
    end
    --�������֤���ǳ�ʼ�ؿ������Խ�
    return true
end

function Stage.CanLoadChapter(player, fullName, chapterId)
    local lastChapterCfg = Stage.GetLastChapterCfg(fullName, chapterId)
    --��ʼ�½�
    if not lastChapterCfg then
        return true
    end

    --�д浵
    local chapterData = getChapterArchiveData(player, fullName, chapterId)
    if next(chapterData) then
        return true
    end

    --�ѽ���
    local allData = getChapterArchiveData(player, fullName)
    local unlockChapters = allData.unlockChapters or {}
    if unlockChapters[chapterId] then
        return true
    end

    --���뱾������
    local ach = Stage.PassedStagesAchievement(player, fullName)
    local chapterCfg = Stage.GetStageCfg(fullName, chapterId)
    local dpStars = chapterCfg.dependStars
    if dpStars and dpStars > 0 and ach.totalStars < dpStars then
        return false, "chapter_notReach", dpStars --��һ��δ���
    end

    local cfg = Stage.GetStageCfg(fullName)
    if not cfg.checkLock then
        return true--������Ƿ����
    end

    --��һ�����һ���ѽ���
    local lastChapterId = lastChapterCfg.id
    local lastChapterData = getChapterArchiveData(player, fullName, lastChapterId)
    if Stage.CanStartStage(player, fullName, lastChapterId, #lastChapterCfg.stages) then
        return true
    end
    return false
end

--������ͨ�ص��ܳɼ�
function Stage.PassedStagesAchievement(player, fullName)
    local archive = getChapterArchiveData(player, fullName)
    local totalStars = 0
    local totalScore = 0
    local totalTime = 0
    for _, v in pairs(archive) do
        if v.stages then
            for _, stage in pairs(v.stages) do
                for _, v in pairs(stage.stars or {}) do
                    if v then
                        totalStars = totalStars + 1
                    end
                end
                totalScore = totalScore + stage.maxScore
                totalTime = totalTime + stage.minTime
            end
        end
    end
    return {totalStars = totalStars, totalScore = totalScore, totalTime = totalTime}
end

--ǿ�ƽ���ĳ�½�, pay�ֶ�Ϊtrue��������������
function Stage.ForceUnlockChapter(player, fullName, chapterId, refreshUI, winName, pay)
    local lastChapterCfg = Stage.GetLastChapterCfg(fullName, chapterId)
    if not pay and lastChapterCfg and not Stage.CanStartStage(player, fullName, lastChapterCfg.id) then
        return false, "lastChapter.lock"--��һ��δ����
    end
    local chapters = getChapterArchiveData(player, fullName)
    local unlockChapters = chapters.unlockChapters or {}
    if unlockChapters[chapterId] then
        return false, "chapter.unlocked"--�Ѿ�����
    end
    unlockChapters[chapterId] = true
    chapters.unlockChapters = unlockChapters
    if refreshUI and winName then
        Stage.SendEnableChapters(player, fullName, winName)
    end
    return true
end

--ǿ�ƽ���ĳ�ؿ�, pay�ֶ�Ϊtrue����������������������������
function Stage.ForceUnlockStage(player, fullName, chapterId, stage, refreshUI, winName, pay)
    stage = tonumber(stage)
    local status, errMsg, condition = canStageUnlock(player, fullName, chapterId, stage)
    if not status and not pay then
        return false, errMsg
    end
    local chapter = getChapterArchiveData(player, fullName, chapterId)
    local unlockStages = chapter.unlockStages or {}
    if unlockStages[stage] then
        return false, "stage.unlocked"
    end
    Stage.ForceUnlockChapter(player, fullName, chapterId, refreshUI, pay)
    unlockStages[stage] = true
    chapter.unlockStages = unlockStages
    if refreshUI and winName then
        Stage.SendEnableChapters(player, fullName, winName)
        Stage.LoadChapter(player, fullName, chapterId, winName)
    end
    return true
end

--�ѽ����½�
function Stage.SendEnableChapters(player, fullName, winName)
    if not fullName then return end
    local chapterIds = {}
    local cfg = Stage.GetStageCfg(fullName)
    for k, v in pairs(cfg.chapters) do
        if Stage.CanLoadChapter(player, fullName, v.id) then
            table.insert(chapterIds, v.id)
        end
    end
    player:sendPacket({pid = "SendEnableChapters", enableChapters = chapterIds, fullName = fullName, winName = winName})
end

function Stage.GetChapterData(player, fullName, chapterId, check)
    if check then
        local enable, errMsg = Stage.CanLoadChapter(player, fullName, chapterId)
        if not enable then
            --player:sendTip(2, errMsg, 30)
            Trigger.CheckTriggers(player:cfg(), "LOAD_CHAPTER_FAIL", {obj1 = player, fullName = fullName, chapterId = chapterId, errMsg = errMsg})
            return nil
        end
    end
    local chapterCfg = chapterId and Stage.GetStageCfg(fullName, chapterId) or Stage.GetFirstChapterCfg(fullName)
    local archiveData = getChapterArchiveData(player, fullName, chapterCfg.id)
    local enableStages = enableStages(player, fullName, chapterCfg.id)
    local passedStages = getPassedStages(player, fullName, chapterId)
    local achievement = Stage.PassedStagesAchievement(player, fullName)
    --����������÷����ͻ���
    local chapterInfo = {
        fullName = fullName,
        chapterId = chapterCfg.id,
        archiveData = archiveData,
        enableStages = enableStages,
        passedStages = passedStages,
        life = player.vars.life,
        totalStars = achievement.totalStars,
        totalScore = achievement.totalScore,
        totalTime = achievement.totalTime
    }
    return chapterInfo
end

--�����½�����
function Stage.LoadChapter(player, fullName, chapterId, winName, check)
    local chapterInfo = Stage.GetChapterData(player, fullName, chapterId, check)
    if chapterInfo then
        player:sendPacket({pid = "SendChapterInfo", chapterInfo = chapterInfo, winName = winName})
    end
end

--��ʼ�ؿ�
function Stage.StartStage(player, fullName, chapterId, stage, test)
    local context = {obj1 = player, fullName = fullName, chapterId = chapterId, stage = stage, canStart = true}
    Trigger.CheckTriggers(player:cfg(), "PREPARE_START_STAGE", context)
    if not context.canStart then
        return
    end
    local canStart, errMsg = Stage.CanStartStage(player, fullName, chapterId, stage)
    if not canStart and not test then
        local canUnlock, errMsg, condition = canStageUnlock(player, fullName, chapterId, stage)
        Trigger.CheckTriggers(player:cfg(), "STAGE_CAN_NOT_START", {obj1 = player, fullName = fullName, chapterId = chapterId, stage = stage, canUnlock = canUnlock, errMsg = errMsg, condition = condition})
        return
    end
    local stageCfg = Stage.GetStageCfg(fullName, chapterId, stage)
    local curStage = getCurStageInfo(player)
    if next(curStage) then
        Trigger.CheckTriggers(player:cfg(), "STAGE_END", {obj1 = player, fullName = curStage.fullName, chapterId = curStage.chapterId, stage = curStage.stage, finish = curStage.finish})
        curStage = emptyCurStageInfo(player)
    end

    local temp = curStage
    curStage.fullName = fullName
    curStage.chapterId = chapterId
    curStage.stage = stage
    curStage.stageName = stageCfg.name
    curStage.startTime = World.Now()
    curStage.endTime = 0
    curStage.score = 0
    curStage.stars = {}
    curStage.finish = false

    local map = World.CurWorld:createDynamicMap(stageCfg.map, true)
    player:setMapPos(map, map.cfg.birthPos or stageCfg.birthPos, stageCfg.ry, stageCfg.yp)
    local modName = "stageTimeEnd"
    local context = {fullName = fullName, chapterId = chapterId, stage = stage}
    local regId_TimeEnd = player:regRemoteCallback(modName, {key = "STAGE_TIME_END", warn = "STAGE_TIME_NEARLY_END"}, false, true, context, false, 600)
    local regId_TimeNearlyEnd = player:regRemoteCallback(modName, {key = "STAGE_TIME_END", warn = "STAGE_TIME_NEARLY_END"}, false, true, context, false, 600)
    player:sendPacket({
        pid = "RequestStartStageResult",
        started = true,
        fullName = fullName,
        chapterId = chapterId,
        stage = stage,
        modName = modName,
        regId = {
            regId_TimeEnd = regId_TimeEnd,
            regId_TimeNearlyEnd = regId_TimeNearlyEnd
        }
    })
    if stageCfg.time then
        curStage.countDownEndTime = World.Now() + stageCfg.time
        curStage.timer = player:timer(stageCfg.time, function ()
            player:doRemoteCallback(modName, "key", regId_TimeEnd, context)
        end)
    end
    local desc = string.format("%s-%s-%d", fullName, chapterId, stage)
    player:bhvLog("stage_begin", desc, player.platformUserId)
    Trigger.CheckTriggers(player:cfg(), "STAGE_BEGIN", {obj1 = player, fullName = fullName, chapterId = chapterId, stage = stage})
    return true
end

function Stage.UpdateStageScore(player, score, pyramid, oldScore)
    local curStage = getCurStageInfo(player)
    if next(curStage) then
        curStage.score = curStage.score + score
    end
    player:sendPacket({
        pid = "SyncStageScore",
        score = curStage.score or 0,
        pyramid = pyramid,
        oldScore = oldScore
    })
end

function Stage.AddStageStars(player, index, light)
    local curStage = getCurStageInfo(player)
    if not next(curStage) then
        return
    end
    curStage.stars[index or 1] = light == nil and true or light
    player:sendPacket({
        pid = "SyncStageStars",
        stars = curStage.stars
    })
end

function Stage.StageEndTime(player, event)
    local regId = player:regRemoteCallback("stageTime", { key = event }, false, true, {}, false, 600)
    player:sendPacket({
        pid = "StageEndTime",
        regId = regId
    })
end

function Stage.SetStageTopInfo(player, key, value, textKey)
    player:sendPacket({
        pid = "SetStageTopInfo",
        key = key,
        value = value,
        textKey = textKey
    })
end

--��ȡͨ�½���
function Stage.ReceiveChapterReward(player, fullName, chapterId, refreshUI, winName)
    local archiveData = getChapterArchiveData(player, fullName)
    local unlockChapters = archiveData.unlockChapters or {}
    if not unlockChapters[chapterId] then
        return false
    end
    local chapterData = archiveData[chapterId]
    local chapterCfg = Stage.GetStageCfg(fullName, chapterId)
    local passedCount = chapterData.stages and #chapterData.stages or 0
    local totalCount = chapterCfg.stages and #chapterCfg.stages or 0
    if passedCount < totalCount then
        return false
    end
    if chapterData.reward then
        return false
    end
    if not chapterCfg.reward then
        return false
    end
    chapterData.reward = true
    if refreshUI and winName then
        Stage.SendEnableChapters(player, fullName, winName)
        Stage.LoadChapter(player, fullName, chapterId, winName)
    end
    local ret = receiveReward(player, fullName, chapterCfg.reward)
    if ret then
        Trigger.CheckTriggers(player:cfg(), "RECEIVE_CHAPTER_REWARD", {obj1 = player, fullName = fullName, chapterId = chapterId})
    end
    return ret
end

--��ȡ�Ǽ�����
function Stage.ReceiveStarReward(player, fullName, chapterId, star, winName)
    local archiveData = getChapterArchiveData(player, fullName, chapterId)
    local curStars = 0
    archiveData.receivedStarReward = archiveData.receivedStarReward or {}
    for k, v in pairs(archiveData.stages or {}) do
        curStars = curStars + v.stars or 0
    end
    for k, v in pairs(archiveData.receivedStarReward) do
        if v == star then
            return false
        end
    end
    if star > curStars then
        return false
    end
    local chapterCfg = Stage.GetStageCfg(fullName, chapterId)
    local reward
    for k, v in pairs(chapterCfg.starReward) do
        if v.star == star then
            reward = v.reward
            break
        end
    end
    if not reward then
        return false
    end
    local result = receiveReward(player, fullName, reward)
    if result then
        table.insert(archiveData.receivedStarReward, star)
    end
    return result
end

--�ؿ�����
function Stage.ShowStageSettlement(player, winName)
    local curStage = getCurStageInfo(player)
    local time = World.Now() - curStage.startTime
    curStage.endTime = World.Now()
    curStage.finish = true
    if curStage.timer then
        curStage.timer()
        curStage.timer = nil
    end

    local fullName = curStage.fullName
    local chapterId = curStage.chapterId
    local stage = curStage.stage
    local stageData = getStageArchiveData(player, fullName, chapterId, stage) or {}
    local chapterCfg = Stage.GetStageCfg(fullName, chapterId)

    local temp = {time = time, score = curStage.score, stars = curStage.stars}
    --������
    local stageCfg = chapterCfg.stages[stage]
    if stageCfg.baseReward and not stageData.baseReward then
        if receiveReward(player, fullName, stageCfg.baseReward) then
            temp.baseReward = true
        end
    end
    if stageCfg.firstReward and not stageData.firstReward then
        if receiveReward(player, fullName, stageCfg.firstReward) then
            temp.firstReward = true
        end
    end
    if next(stageCfg.starReward or {}) and not stageData.starReward then
        local starCount = 0
        for _, _ in pairs(curStage.stars or {}) do
            starCount = starCount + 1
        end
        local reward = stageCfg.starReward[starCount]
        if receiveReward(player, fullName, reward) then
            temp.starReward = true
        end
    end

    updateStageData(player, fullName, chapterId, stage, temp)

    --�Ƿ���Կ���һ�¹�
    local nextStage
    if stage + 1 > #chapterCfg.stages then
        local nextCfg = Stage.GetNextChapterCfg(fullName, chapterId)
        if nextCfg then
            nextStage = {
                chapterId = nextCfg.id,
                stage = 1
            }
        end
    else
        nextStage = {
            chapterId = chapterId,
            stage = stage + 1
        }
    end
    if nextStage then
        local canStart, errMsg = Stage.CanStartStage(player, fullName, nextStage.chapterId, nextStage.stage)
        nextStage = canStart and nextStage or nil
    end

    local achievement = Stage.PassedStagesAchievement(player, fullName)
    player:sendPacket({
        pid = "ShowStageSettlement",
        winName = winName,
        nextStage = nextStage,
        fullName = fullName,
        chapterId = chapterId,
        stage = stage,
        stageName = curStage.stageName,
        time = time,
        score = curStage.score,
        stars = curStage.stars,
        historyScore = stageData.maxScore or 0,
        stars = curStage.stars,
        totalStars = achievement.totalStars,
        totalTime = achievement.totalTime,
        totalScore = achievement.totalScore
    })
    Trigger.CheckTriggers(player:cfg(), "STAGE_SETTLEMENT", {obj1 = player, fullName = curStage.fullName, chapterId = curStage.chapterId, stage = curStage.stage, time = time, score = curStage.score})
end

--�˳��ؿ�
function Stage.ExitStage(player)
    local curStage = getCurStageInfo(player)
    if not next(curStage) then
        return
    end
    local timer = curStage.timer
    if timer then
        timer()
        curStage.timer = nil
    end
    local fullName = curStage.fullName
    local chapterId = curStage.chapterId
    local stage = curStage.stage
    Trigger.CheckTriggers(player:cfg(), "STAGE_END", {obj1 = player, fullName = fullName, chapterId = chapterId, stage = stage, finish = curStage.finish})
    emptyCurStageInfo(player)
    local saveMapPos = player.saveMapPos
    if saveMapPos then
        player:setMapPos(World.CurWorld:getOrCreateStaticMap(saveMapPos.map), saveMapPos)
    end
    player:sendPacket({pid = "StageExited", fullName = curStage.fullName, chapterId = curStage.chapterId, stage = curStage.stage, finish = curStage.finish})
    local desc = string.format("%s-%s-%d", fullName, chapterId, stage)
    player:bhvLog("stage_exit", desc, player.platformUserId)
end

function Stage.SetTestStage()
    local chapterCfg = Stage.GetFirstChapterCfg("myplugin/main", 1)
    local testStage = chapterCfg.testStage
    World.vars.testStage = testStage
end

function Stage.GetTimeRemaining(player)
    local curStage = getCurStageInfo(player)
    if not next(curStage) or not curStage.countDownEndTime then
        return 0
    end
    local remaining = math.max(curStage.countDownEndTime - World.Now(), 0)
    return math.floor(remaining)
end

function Stage.GetCurStageScore(player)
    local curStage = getCurStageInfo(player)
    if not next(curStage)then
        return 0
    end
    return curStage.score
end

function Stage.GetStageArchiveValue(player, fullName, chapterId, stage, key)
    local data = getStageArchiveData(player, fullName, chapterId, stage)
    return key and data and data[key]
end