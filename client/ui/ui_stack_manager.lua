local uiStackManeger = L("uiStackManeger", {})

local function getOrCreateUIStack(uiName)
	assert(uiName, "uiName is nil! in ui_stack_manager")
	if not uiStackManeger[uiName] then
		uiStackManeger[uiName] = Lib.CreateStack()
	end
	return uiStackManeger[uiName]
end

Lib.subscribeEvent(Event.EVENT_PUSH_UI_INFORMATION_QUEUE, function(uiName, packet)
	local uiStack = getOrCreateUIStack(uiName)
	local now = World.Now()
	local endTime = now + (packet.time or 0)
	packet.startSubTime = now
	packet.endSubTime = endTime
	uiStack:Push({
		endTime = endTime,
		func = function()
			if UI:isOpen(uiName) then
				UI:closeWnd(uiName)
			end
			UI:openWnd(uiName, packet)
		end
	})
end)

Lib.subscribeEvent(Event.EVENT_POP_UI_INFORMATION_QUEUE, function(uiName)
	local uiStack = getOrCreateUIStack(uiName)
	local now = World.Now()
	while uiStack:Size() > 0 do
		local ret = uiStack:Pop()
		if ret.endTime > now then
			ret.func()
			break
		end
	end
end)