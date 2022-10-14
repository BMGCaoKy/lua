local baseDerive = require "editor.module.baseDerive"
EditorModule.baseDerive = Lib.derive(baseDerive)

local editorItem = require "editor.module.editorItem"
local editorSetting = require "editor.module.editorSetting"
local editorUIControl = require "editor.module.editorUIControl"
local editorViewControl = require "editor.module.editorViewControl"
local editorMoveControl = require "editor.module.editorMoveControl"
local editorEventSolve = require "editor.module.editorEventSolve"
local editorInitCfg = require "editor.module.editorInitCfg"
local editorPatch = require "editor.module.editorPatch"


function EditorModule:init()
	self.curNewCustomScriptVersion = "1.0.2"
	editorInitCfg:init()
	editorPatch:init()
	self.gmDesc = {
		item = false,
		entity = false,
		block = false,
	}
end

function EditorModule:setDescCreate(type)
	if self.gmDesc[type] == nil then
		return
	end
	self.gmDesc[type] = not self.gmDesc[type]
end

function EditorModule:isMustCreateDesc(type)
	if not self.gmDesc[type] then
		return false
	end
	return true
end

function EditorModule:createItem(mod, fullName)
    return editorItem:new(mod, fullName)
end

function EditorModule:getCfg(mod, fullName)
    return editorSetting:getCfg(mod, fullName)
end

function EditorModule:getUIControl()
	return editorUIControl
end

function EditorModule:getViewControl()
	return editorViewControl
end

function EditorModule:emitEvent(eventName, ...)
	editorEventSolve:event(eventName, ...)
end

function EditorModule:getMoveControl()
	return editorMoveControl
end

function EditorModule:getNewCustomScriptVersion()
	return self.curNewCustomScriptVersion
end

function EditorModule:getGameCustomScriptVersion()
	return ""
end

EditorModule:init()