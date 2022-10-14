local events = {}

local noEventDebug = {
	scene_touch_begin	=	true,
	scene_touch_move	=	true,
	scene_touch_end		=	true,
	scene_touch_cancel	=	true,
	onGroundChanged = true,
	pickItem = true,
	onVoiceOperationResult = true,
	leaveGround			=	true,
	fallGround			=	true,
	dead				=	true,
	onGameActionTrigger =	true,
	calculateCameraWhenDriving = true
}

local connectEventType = {
	emConnectSuc = 0,
	emConnectFailed = 1,
	emConnectTimeout = 2,
	emConnectKickOut = 3,
	emDisconnect = 4
}

local gameOverEventType = {
	rkoutDuplicate 	= 100,
	rkoutTimeOut 	= 101,
	rkoutManual 	= 102
}

local resetGameResultType = {
    [2] = "ACCESS_FAILED",
    [3] = "TRANSFER_FAILED",
    [4] = "VISITOR_FULLED",
    [5] = "VERSION_UNMATCHED",
    [6] = "NETWORK_CONNECT_FAILED",
    [7] = "UNKNOW_ERROR",
}

local cjson = require("cjson")

function player_event(player, event, ...)
	if not noEventDebug[event] then
		print("player_event", player and player.name or "user", event, ...)
	end
	local func = events[event]
	if not func then
		print("no event!", event)
		return
	end

	if not player then
		Lib.logWarning("player_event not player ", event, ...)
	end

	Profiler:begin("player_event."..event)
	func(player, ...)
	Profiler:finish("player_event."..event)
end

function events:leaveGround()
	--TODO
end

function events:fallGround(fallDistance)
	--TODO
	Lib.emitEvent(Event.EVENT_ON_GROUND, fallDistance)
end

function events:dead(dead)
	--TODO
end

function events:resetGameResult(resultCode, networkConnected)
	Lib.logWarning("resetGameResult %d %d", resultCode, networkConnected and 1 or 0)
	if networkConnected then
		self:sendPacket({
			pid = "ResetGameFailed",
			resultCode = resultCode,
			resultType = resetGameResultType[resultCode],
		})
		local langKey = ""
		if resultCode == 4 then
			langKey = "game_allocation_failure_user_full"
		elseif resultCode == 5 then
			langKey = "game_allocation_failure_version_mismatch"
		else
			langKey = "game_allocation_failure"
		end
		if self:isWatch() then
			Lib.emitEvent(Event.EVENT_UPDATE_UI_DATA, "resetGameResult2FollowInterface", langKey)
		else
			UILib.openChoiceDialog({msgText = langKey})
		end
	else
		loadingUiPage("loading_page", 20)
	end
end

function events:connEvent(conntype)
	if conntype == connectEventType.emConnectSuc then
		--todo
	elseif conntype == connectEventType.emConnectFailed then
		Lib.emitEvent(Event.EVENT_SEND_GAMEOVER, Lang:toText("gui.loading.page.connected.server.failed"))
	elseif conntype == connectEventType.emConnectKickOut then
		Lib.emitEvent(Event.EVENT_SEND_GAMEOVER, Lang:toText("gui.message.network.connection.kick.out"))
	elseif conntype == connectEventType.emConnectTimeout then
		Lib.emitEvent(Event.EVENT_SEND_GAMEOVER, Lang:toText("gui.message.network.connection.network.error"))
	elseif conntype == connectEventType.emDisconnect then
		Lib.emitEvent(Event.EVENT_SEND_GAMEOVER, Lang:toText("gui.message.network.connection.disconnect"))
	else
		Lib.emitEvent(Event.EVENT_SEND_GAMEOVER, Lang:toText("gui.message.network.connection.disconnect"))
	end
end

function events:gameOverEvent(code)
	if code == gameOverEventType.rkoutDuplicate then
		Lib.emitEvent(Event.EVENT_SEND_GAMEOVER, Lang:toText("system.message.kick.user.out.duplicate.enter"))
	elseif code == gameOverEventType.rkoutTimeOut then
		Lib.emitEvent(Event.EVENT_SEND_GAMEOVER, Lang:toText("system.message.kick.user.out.timeout.enter"))
	elseif code == gameOverEventType.rkoutManual then
		Lib.emitEvent(Event.EVENT_SEND_GAMEOVER, Lang:toText("system.message.kick.user.out.manual.kick.out"))
	end
end

function events:onFriendOperationForAppHttpResult(operationType, userId)
	print("onFriendOperationForAppHttpResult", operationType, userId)
	Lib.emitEvent(Event.EVENT_FRIEND_OPERATION, operationType, userId)
end

function events:scene_touch_begin(x, y)
	Lib.emitEvent(Event.EVENT_SCENE_TOUCH_BEGIN, x, y)
	Event:EmitEvent("OnTouchScreenBegin", Vector2.new(x,y))
end

function events:scene_touch_move(x, y, preX, preY)
	Lib.emitEvent(Event.EVENT_SCENE_TOUCH_MOVE, x, y, preX, preY)
	Event:EmitEvent("OnTouchScreenMove", Vector2.new(x, y))
end

function events:scene_touch_end(x, y, preX, preY, touchId)
	Lib.emitEvent(Event.EVENT_SCENE_TOUCH_END, x, y, preX, preY, touchId)
	Event:EmitEvent("OnTouchScreenEnd", Vector2.new(x, y))
end


function events:scene_touch_cancel(x, y)
	Lib.emitEvent(Event.EVENT_SCENE_TOUCH_CANCEL, x, y)
end

function events:onWatchAdResult(type, params, code)
	local adHelper = Game.GetService("AdHelper")
	if adHelper then
		adHelper:onVideoAdResult(type, code)
	end
	local packet = {
		pid = "OnWatchAdResult",
		type = type,
		params = params,
		code = code
	}
	self:sendPacket(packet)
end

function events:onRechargeResult(type, result, productId)
	local packet = {
		pid = "OnRechargeResult",
		type = type,
		productId = productId
	}
	if result == 1 then
		self:sendPacket(packet)
	elseif result == 0 then
		--todo
	end
end

function events:onGameActionTrigger(type, info)
	Lib.logInfo("onGameActionTrigger", type, info)
	if type == Define.GameActionType.GAME_ACTION_EXTRA_PARAMS then
		GlobalProperty.Instance():setBoolProperty("IsChina", true)
	elseif type == Define.GameActionType.GAME_ACTION_JSON_FUNCTION then
		local success, data = pcall(cjson.decode, info)
		if not success or not data.functionName then
			return
		end
		local func = events[data.functionName]
		if func ~= nil then
			func(Me, data)
		end
	elseif type == Define.GameActionType.GAME_ACTION_SHOW_VIDEO_AD or type == Define.GameActionType.GAME_ACTION_HIDE_VIDEO_AD then
		local adHelper = Game.GetService("AdHelper")
		if adHelper then
			adHelper:enableVideoAd(type == Define.GameActionType.GAME_ACTION_SHOW_VIDEO_AD)
		end
	end
end

function events:onGroundChanged(lastOnGround, onGround)
	
end

function events:onVoiceOperationResult(type, time, path)
	VoiceManager:onVoiceOperationResult(type, time, path)
end

function events:receiveMessage(sourceType, messageType, content)
	Plugins.CallTargetPluginFunc("platform_chat", "receivePlatformPrivateMsg", sourceType, messageType, content)
	Plugins.CallTargetPluginFunc("new_platform_chat", "receivePlatformPrivateMsg", sourceType, messageType, content)
end

function events:receiveHistoryTalkList(listInfo)
	Plugins.CallTargetPluginFunc("platform_chat", "receiveHistoryTalkList", listInfo)
	Plugins.CallTargetPluginFunc("new_platform_chat", "receiveHistoryTalkList", listInfo)
end

function events:receiveHistoryTalkDetail( targetId, detailContent)
	Plugins.CallTargetPluginFunc("platform_chat", "receiveHistoryTalkDetail",  targetId, detailContent)
	Plugins.CallTargetPluginFunc("new_platform_chat", "receiveHistoryTalkDetail",  targetId, detailContent)
end

function events:calculateCameraWhenDriving(objID, yawOffset, cameraOffset)

end

function events:onbuyActionResult(type, result)
	if result == 1 then
		local packet = {
			pid = "onbuyActionResult",
			type = type,
			result = result
		}
		self:sendPacket(packet)
	end
end

function events:onPersonViewChanged(view)
	Lib.emitEvent(Event.EVENT_CHANGE_PERSONVIEW, self)
end

function events:onAutoMoveStop()
	Lib.emitEvent(Event.EVENT_AUTO_MOVE_STOP_ENGINE, self)
end

function events:onAutoMoveInterrupt()
	Lib.emitEvent(Event.EVENT_AUTO_MOVE_INTERRUPT_ENGINE, self)
end

function events:onVideoRecordResult(result)
	Lib.logInfo("onVideoRecordResult", result)
	Lib.emitEvent(Event.EVENT_APP_VIDEO_RECORD_RESULT, result)
end

function events:onPlyerJump() 
	local player = Player.CurPlayer
	Skill.DoBreakSwing(player,"Jump")
end