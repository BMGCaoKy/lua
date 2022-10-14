local M = {}

--队伍的初始化
function M.TeamParaInit(self, op)
	local init_pos = self.initPos
	local start_pos = self.startPos
	self = self.team
	if op == "INSERT" then
	   self.team[#self.team].name="team"..#self.team
	   local Def = require "we.def"
	   local Lfs = require "lfs"
	   local currentdir = Lib.normalizePath(Lfs.currentdir())
	   local path_game_asset = Def.PATH_GAME_ASSET
	   if string.find(path_game_asset, currentdir, 1, true) == 1 then
			--path_game_asset = string.gsub(Def.PATH_GAME_ASSET, currentdir, ".")
			--lua的字符串替换有些字符似乎有问题
			path_game_asset = string.sub(path_game_asset, #currentdir + 2)
		end
		--"asset/Texture/Team/flag/flag_1.png"
		local idx = math.fmod(#self.team,10)
		if idx == 0 then
		   idx = 10
		end
	   self.team[#self.team].image.selector =path_game_asset.."Texture/Team/flag/flag_"..idx..".png"
	   self.team[#self.team].initPos = init_pos
	   self.team[#self.team].startPos = start_pos
	end
end
function M.NumberOfInspection(parameter)
	local cumulative_max = 0
	for _, v in ipairs(parameter.team.team) do
		cumulative_max = cumulative_max +v.memberLimit
	end
	local warning_info = string.format("max number Is too small-(%d)",cumulative_max)
	return parameter.player_range.max < cumulative_max and warning_info or ""
end
return M