local M = {}

function M:init(compare, data) --每种排行榜都用自己的compare， 
	self.ranks = {}
	self.compateDatas = {}
	self.idtoRanks = {}
	self.maxLen = 10
	self.compareType = compare -- 生成一种排行榜，通过这种排行榜的配置rankcompare：按数组的顺序排序，越在前面越优先
	if data then -- 可以初始化排行榜
		for id,comdata in pairs(data.idList or {}) do
			self.ranks[#self.ranks + 1] = id
			self.compateDatas[id] = comdata
		end
		self.maxLen = data.maxLen or 10
		table.sort(self.ranks, self:compare()) --??
		for th,id in pairs(self.ranks) do
			self.idtoRanks[id] = th
		end
	end
end

function M:setRankMaxLen(len)
	self.maxLen = len
end

function M:getRankMaxLen()
	return self.maxLen
end

function M:getCompareType(key)
	if not key then
		return self.compareType
	end
	return self.compareType[key]
end

function M:queryRank(id)
	return self.idtoRanks[id]
end

function M:queryData(id)
	return self.compateDatas[id]
end

function M:compare(id1, id2)
	if id1 == id2 then
		return false
	end
	local comA = self.compateDatas[id1] or {}
	local comB = self.compateDatas[id2] or {}
	for _,data in pairs(self.compareType) do
		local key = data.key
		local orderByDesc = data.order
		local com1 = comA
		local com2 = comB
		if orderByDesc == "<"then
			com1 = comB
			com2 = comA
		end
		if com2[key] or com1[key] then
			if not com1[key] or not com2[key] then
				if not com2[key] and type(com1[key])  == "number" and com1[key] < 0 then
					return false
				end
				return com1[key] ~= nil
			end
			if com1[key] ~= com2[key] then
				return com1[key] > com2[key]
			end
		end
	end
	return id1 > id2
end

function M:UpdataRanks(id, data) --只有更新,没有增减，这里只接受数据进行排行
	if not id then
		return
	end
	if (not data or data == {} and not self.compateDatas[id]  or self.compateDatas == {})then
		return
	end
	data = data or {}
	self.compateDatas[id] = self.compateDatas[id] or {}
	for key,val in pairs(data) do
		self.compateDatas[id][key] = val
	end

	self:doUpdata(id)
end

function M:doUpdata(id) --do sort
	local leng = #self.ranks
	local th = self.idtoRanks[id]
	local tmplen = leng
	if not th then
		th = leng + 1
		tmplen = tmplen + 1
	end
	local to = th
	self.ranks[th] = id
	self.idtoRanks[id] = th
	self.compateDatas[id] = self.compateDatas[id] or {}

	while to > 1 and self:compare(self.ranks[to], self.ranks[to-1]) do
		local tmprank = self.ranks[to]
		self.ranks[to] = self.ranks[to-1]
		self.ranks[to-1] = tmprank
		self.idtoRanks[self.ranks[to]] = to 
		self.idtoRanks[self.ranks[to-1]] = to - 1
		to = to - 1
	end
	while to < tmplen and  not self:compare(self.ranks[to], self.ranks[to+1]) do
		local tmprank = self.ranks[to]
		self.ranks[to] = self.ranks[to+1]
		self.ranks[to+1] = tmprank
		self.idtoRanks[self.ranks[to]] = to 
		self.idtoRanks[self.ranks[to+1]] = to + 1
		to = to + 1
	end
	if tmplen > self.maxLen then
		self.idtoRanks[self.ranks[tmplen]] = nil
		self.compateDatas[self.ranks[tmplen]] = nil
		self.ranks[tmplen] = nil
	end
end

function M:RankDelID(id)
	local th = self.idtoRanks[id]
	local len = #self.ranks
	for i=th,len-1 do
		self.ranks[i] = self.ranks[i+1]
		self.idtoRanks[self.ranks[i]] = i
	end
	self.ranks[len] = nil
	self.idtoRanks[id] = nil
	self.compateDatas[id] = nil
end

function M:getRanks(start, count)
	start = start or 1
	count = count or #self.ranks
	local ranks = {}
	local idlist = {}
	local lenEnd = math.min(start + count - 1, self.maxLen, #self.ranks)
	for i = start,lenEnd do
		local id = self.ranks[i]
		local rank = {
			rank = i,
			id = id,
			score = self.compateDatas[id],
		}
		local cache = UserInfoCache.GetCache(id)
		if cache then
			 rank.name = cache.name
		else
			idlist[#idlist + 1] = id -- TODO 
		end
		ranks[#ranks + 1] = rank
	end
	return ranks
end

return M