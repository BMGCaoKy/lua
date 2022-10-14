local editorInitCfg = L("editorInitCfg", Lib.derive(EditorModule.baseDerive))
local setting = require "common.setting"

function editorInitCfg:init()
    self:initBuffCfg()
end

function editorInitCfg:initBuffCfg()
    local flyBuff = {
        id = 0,
        fullName = "/fly",
        flyModulus = -1,
        actionMap = {
            fly = "run"
        }
    }
    setting:mod("buff"):set(flyBuff)
end

RETURN(editorInitCfg)
