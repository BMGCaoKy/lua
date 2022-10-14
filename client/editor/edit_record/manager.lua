
local lfs = require "lfs"
local base = require "editor.edit_record.base"
local similarity = require "editor.edit_record.similarity"
local duration = require "editor.edit_record.duration"
local editRecordMgr = L("editRecordMgr", {})

local function createRecordFolder()
    local recordPath = base.getEditRecordPath()
    local attr = lfs.attributes(recordPath)
    if attr and attr.mode == "directory" then
        return
    end
    lfs.mkdir(recordPath)
end

local function initSimilarity()
    if not base.enable then
        return
    end
    createRecordFolder()
    similarity:init()
end

function editRecordMgr:init()
    initSimilarity()
    duration:init()
end

function editRecordMgr:initOnlineEventTracking()
    if base.localEditroEnvironment or base.localTestEnvironment then
        return
    end

    if not Me.isEditorServerEnvironment then
        -- 排除掉编辑和本地测试场景，又不是联机游戏环境，则为优秀游戏
        duration:addStarGameDataReport(World.GameName)
    else
        duration:addOnlineGameDataReport()
    end

end

return editRecordMgr