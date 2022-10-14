require "common.stage"

--所有章节
function Stage.LoadEnableChapters(player, fullName, winName)
    player:sendPacket({pid = "LoadEnableChapters", fullName = fullName, winName = winName})
end

--向服务器请求章节数据
function Stage.LoadChapter(player, fullName, chapterId, winName, check)
    player:sendPacket({pid = "LoadChapter", fullName = fullName, chapterId = chapterId, winName = winName, check = check})
end

function Stage.ShowChapterInfo(player, packet)
    local chapterInfo = packet.chapterInfo
    local fullName = chapterInfo.fullName
    local chapterId = chapterInfo.chapterId
    local nextCfg = Stage.GetNextChapterCfg(fullName, chapterId)
    local lastCfg = Stage.GetLastChapterCfg(fullName, chapterId)
    chapterInfo.chapterCfg = Stage.GetStageCfg(fullName, chapterId)
    chapterInfo.nextChapterId = nextCfg and nextCfg.id
    chapterInfo.lastChapterId = lastCfg and lastCfg.id
    local winName = packet.winName
    if winName == "win_stage" then
        Lib.emitEvent(Event.EVENT_SHOW_STAGES, {show = true, chapterInfo = chapterInfo})
    elseif winName == "win_general_options" then
        
    end
end

--向服务端发送进入关卡请求
function Stage.RequestStartStage(player, fullName, chapterId, stage)
    assert(fullName and chapterId and stage)
    local packet = {
		pid = "PrepareToStartStage",
		fullName = fullName,
        chapterId = chapterId,
        stage = stage
	}
	player:sendPacket(packet)
end

--已进入关卡
function Stage.RequestStartStageResult(packet)
    if packet.started then
        Lib.emitEvent(Event.EVENT_SHOW_STAGE_INFO, false)
        Lib.emitEvent(Event.EVENT_SHOW_STAGE_INFO, true, packet)
        Lib.emitEvent(Event.EVENT_CLOSE_RELATED_WND)
    end
end

function Stage.ShowStageSettlement(packet)
    Lib.emitEvent(Event.EVENT_SHOW_STAGE_INFO, false)
    Lib.emitEvent(Event.EVENT_SHOW_STAGESETTLEMENT, packet)
end

--领取通章奖励
function Stage.ReceivedChapterReward(player, fullName, chapterId, refreshUI, winName, func)
    local packet = {
                pid = "ReceivedChapterReward",
                fullName = fullName,
                chapterId = chapterId,
                refreshUI = refreshUI,
                winName = winName
            }
    player:sendPacket(packet, func)
end

--领取星级宝箱
function Stage.ReceiveStarReward(player, fullName, chapterId, star, func)
    local packet = {
                pid = "ReceivedStarReward",
                fullName = fullName,
                chapterId = chapterId,
                star = star
            }
    player:sendPacket(packet, func)
end

--退出关卡
function Stage.RequestExitStage(player)
    player:sendPacket({pid = "RequestExitStage"})
end

--已退出关卡，finish: yes完成关卡后正常退出，no中途退出，返回大厅，关闭各种与关卡相关的界面
function Stage.StageExited(self, fullName, chapterId, stage, finish)
    Lib.emitEvent(Event.EVENT_SHOW_STAGE_INFO, false)
    Lib.emitEvent(Event.EVENT_CLOSE_RELATED_WND)
end