require "common.stage"

--�����½�
function Stage.LoadEnableChapters(player, fullName, winName)
    player:sendPacket({pid = "LoadEnableChapters", fullName = fullName, winName = winName})
end

--������������½�����
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

--�����˷��ͽ���ؿ�����
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

--�ѽ���ؿ�
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

--��ȡͨ�½���
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

--��ȡ�Ǽ�����
function Stage.ReceiveStarReward(player, fullName, chapterId, star, func)
    local packet = {
                pid = "ReceivedStarReward",
                fullName = fullName,
                chapterId = chapterId,
                star = star
            }
    player:sendPacket(packet, func)
end

--�˳��ؿ�
function Stage.RequestExitStage(player)
    player:sendPacket({pid = "RequestExitStage"})
end

--���˳��ؿ���finish: yes��ɹؿ��������˳���no��;�˳������ش������رո�����ؿ���صĽ���
function Stage.StageExited(self, fullName, chapterId, stage, finish)
    Lib.emitEvent(Event.EVENT_SHOW_STAGE_INFO, false)
    Lib.emitEvent(Event.EVENT_CLOSE_RELATED_WND)
end