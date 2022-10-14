local editorPatch = L("editorPatch", Lib.derive(EditorModule.baseDerive))
local editorSetting = require "editor.setting"
local cfgPatchData = require "editor.module.patch.cfg_patch.patch"

function editorPatch:init()
    -- self:updateCustomScriptPatch()
	self:updateGameCfgPatch()
end

function editorPatch:updateCustomScriptPatch()
    local version = EditorModule:getGameCustomScriptVersion()
    local newVerison = EditorModule:getNewCustomScriptVersion()
    if version ~= newVerison then
        Lib.copyFiles("./lua/client/editor/module/patch/script_patch/", Root.Instance():getGamePath() .. "lua/")
    end
end

function editorPatch:updateGameCfgPatch()
    local version = EditorModule:getGameCustomScriptVersion()
    local newVerison = EditorModule:getNewCustomScriptVersion()
    local function modifyCfg(mod, name, cfgDatas)
        for key, value in pairs(cfgDatas or {}) do
            if value == "nil" then
                value = nil
            end
            editorSetting:saveValueByKey(mod, name, key, value, true)
        end
    end
    if version ~= newVerison then
        for mod, modDatas in pairs(cfgPatchData) do
            if mod == "global" then
                modifyCfg(mod, nil, modDatas)
            else
                for name, jsonDatas in pairs(modDatas) do
                    modifyCfg(mod, name, modDatas)
                end
            end
        end
        editorSetting:saveAll(true)
    end
end

RETURN(editorPatch)
