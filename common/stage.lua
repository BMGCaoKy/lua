local setting = require "common.setting"

--获取配置
function Stage.GetStageCfg(fullName, chapterId, stage)
    local cfg = assert(setting:fetch("stage",fullName), fullName)
    if not chapterId then
        return cfg
    end
    local chapterCfg
    for _, v in pairs(cfg.chapters) do
        if v.id == chapterId then
            chapterCfg = v
            chapterCfg.cfg = cfg
            break
        end
    end
    if not stage then
        return assert(chapterCfg, chapterId)
    end
    local stageCfg = chapterCfg and chapterCfg.stages and chapterCfg.stages[tonumber(stage)]
    return assert(stageCfg, string.format("%s-%d", chapterId, stage))
end

--获取首章节配置
function Stage.GetFirstChapterCfg(fullName)
    local cfg = Stage.GetStageCfg(fullName)
    return assert(cfg.chapters[1], fullName)
end

--for editor
function Stage.GetFirstStageCfg(fullName, isTest)
    local chapterCfg = Stage.GetFirstChapterCfg(fullName, 1)
    local targetIndex = 1
    if isTest then
        targetIndex = chapterCfg.testStage or targetIndex
    end
    return chapterCfg.stages[targetIndex]
end

--获取上一章配置
function Stage.GetLastChapterCfg(fullName, curChapterId)
    local cfg = Stage.GetStageCfg(fullName)
    local curIndex = 0
    for k, v in ipairs(cfg.chapters) do
        if v.id == curChapterId then
            curIndex = k
            break
        end
    end
    return cfg.chapters[curIndex - 1]
end

--获取下一章配置
function Stage.GetNextChapterCfg(fullName, curChapterId)
    local cfg = Stage.GetStageCfg(fullName)
    local curIndex = 0
    for k, v in pairs(cfg.chapters) do
        if v.id == curChapterId then
            curIndex = k
            break
        end
    end
    return cfg.chapters[curIndex + 1]
end