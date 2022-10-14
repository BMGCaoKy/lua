local editorLog = L("editorLog", {})
local baseDerive = L("baseDerive", Lib.derive(editorLog))
local LOG_LEVEL = 1 -- log

function editorLog.info(...)
	local level = 1
	if LOG_LEVEL >= level then
		Lib.logInfo(...)
	end
end

function editorLog.debug(...)
	local level = 2
	if LOG_LEVEL >= level then
		Lib.logDebug(...)
	end
end

function editorLog.warning(...)
	local level = 3
	if LOG_LEVEL >= level then
		Lib.logWarning(...)
	end
end

function editorLog.error(...)
	local level = 4
	if LOG_LEVEL >= level then
		Lib.logError(...)
		print(debug.traceback())	
	end
end

function baseDerive:showTips(text, time)
	Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText(text), time or 20)
end

RETURN(baseDerive)