
local lfs = require "lfs"
local cjson = require "cjson"
local base = L("editFunBase", {})

base.enable = true
base.localEditroEnvironment = CGame.instance:getIsEditor()
base.localTestEnvironment = not CGame.instance:getIsEditor() and CGame.instance:getIsEditorEnvironment()

local function init()
    if CGame.instance:getPlatformId() == 1 then  --pc
        base.enable = false
        return
    end

    if CGame.instance:getEditorType() ~= 1 then
        base.enable = false
        return
    end
end

function base.getFileContent(path)
    local attr = lfs.attributes(path)
    if not attr then
        return {}
    end
    return Lib.read_json_file(path)
end

function base.saveFile(path, data)
    assert(type(data) == "table")
    local ok, content = pcall(cjson.encode, data)
    assert(ok)
    local file = io.open(path, "w+")
    file:write(content)
    file:close()
end

function base.getEditRecordPath()
    local gamePath = Root.Instance():getGamePath()
    return string.format("%seditRecord/", gamePath)
end

init()
return base