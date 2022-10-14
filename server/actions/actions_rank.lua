local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

function Actions.AddEntityScore(data, params, context)
	local entity = params.entity
	if ActionsLib.isInvalidPlayer(entity) then
		return 0
	end
	local main = entity:data("main")
	main.score = (main.score or 0) + params.add
	Game.checkGameOverWithScoreChange({obj = params.entity})
	entity:sendPacket( {
        pid = "PlayerScoreShow",
        score = params.add
    })
    return main.score
end

function Actions.GetEntityScore(data, params, context)
	local entity = params.entity
	if ActionsLib.isInvalidPlayer(entity) then
		return
	end
	return entity:data("main").score or 0
end

function Actions.SetEntityScore(data, params, contetx)
	local entity = params.entity
	if ActionsLib.isInvalidPlayer(entity) or ActionsLib.isNil(params.val, "Score") then
		return
	end
	local main = entity:data("main")
	main.score = params.val
	Game.checkGameOverWithScoreChange({obj = entity})
	params.entity:sendPacket( {
		pid = "PlayerScoreShow",
		score = main.score
	})

    return main.score
end

function Actions.ShowRank(data, params, context)
	if not params.rankName then
		--print(params.npc:data("main").rankType)
		params.entity:sendPacket({ pid = "ShowRank", rankType = params.npc:data("main").rankType or 0, uiName = params.uiName})
	else
		local player = params.entity
		local rank = Rank.rankList[params.rankName]
		player:sendPacket({
			pid = "ShowNewRanks",
			uiName = params.uiName,
			rankName = params.rankName,
			ranks = rank:getRanks(params.start, params.count),
			myrank = {
				myrank = rank:queryRank(params.id or player.platformUserId),
				myscores = rank:queryData(params.id or player.platformUserId)
			}
		})
	end
end

function Actions.GetRankScoreRecord(node, params, context)
	if not params.rankName then
		return params.entity:getRankScore(params.rankType, params.subId) or 0
	elseif params.rankName and params.id then
		return Rank.getRankScore(params.rankName, params.id)
	end
end

function Actions.AddRankScore(node, params, context)
	return params.entity:addRankScore(params.rankType, params.subId, params.score)
end

function Actions.UpdateRankScore(data, params, context)
	if not params.rankName then
		params.entity:updateRankScore(params.rankType, params.subId, params.score)
	else
		Rank.UpdateRankData(params)
	end
end

function Actions.DeleteFromRank(data, params, context)
	if not params.id or not params.rankName or params.rank then
		return
	end
	local rank = params.rank or Rank.rankList[params.rankName]
	rank:RankDelID(params.id)
end

function Actions.requestRankData(data, params, context)
	if not params.player then
		Rank.RequestRankData(params.rankType)
		return
	end
	if not params.rankName then
		Rank.RequestRankData(params.rankType)
		params.player:requestRankInfo(params.rankType)
	else
		local player = params.player
		local id = params.id or player.platformUserId
		local rank = Rank.rankList[params.rankName]
		if not rank then
			return
		end
		player:sendPacket({
			pid = "UpdataRankData",
			ranks = rank:getRanks(params.start, params.count),
			myrank = {
				myrank = rank:queryRank(id),
				myscores = rank:queryData(id)
			},
			rankName = params.rankName
		})
	end
end

function Actions.GetPlayerRank(data, params, context)
	return params.player:getMyRank(params.rankType, params.subId)
end