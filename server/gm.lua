
require "common.gm"
local lfs = require "lfs"
local setting = require "common.setting"
local debugport = require "common.debugport"
local mri = require("common.util.MemoryReferenceInfo")
local LuaTimer = T(Lib, "LuaTimer") ---@type LuaTimer

-- Set config.
mri.m_cConfig.m_bAllMemoryRefFileAddTime = false
--mri.m_cConfig.m_bSingleMemoryRefFileAddTime = false
--mri.m_cConfig.m_bComparedMemoryRefFileAddTime = false

local path = Root.Instance():getGamePath():gsub("\\", "/") .. "lua/gm_server.lua"
local file, err = io.open(path, "r")
local GMItem
if file then
    GMItem = require("gm_server")
    file:close()
end
if not GMItem then
    GMItem = GM:createGMItem()
end

local listCallBack = {}
function GM:listCallBack(tb)
    local func = listCallBack[tb.typ]
    func(self, tb)
end

function listCallBack:vars(tb)
    local typ = type(self.vars[tb.name])
    local value = tb.value
	if typ=="boolean" then
		value = value=="true"
	elseif typ=="number" then
		value = tonumber(value)
	elseif typ~="string" then
		return
	end
    self.vars[key] = value
end

local function listResource(typ, defaultValue, excludeItems, callBack)
	listCallBack[typ] = callBack
    return function(self)
		local excludeSet = {}
		for _, v in ipairs(excludeItems or {}) do
			excludeSet[v] = true
		end
		local list = {}
		for name, item in pairs(setting:mod(typ):loadAll()) do
			if not excludeSet[name] then
				list[#list+1] = {
					name = name,
					typ = typ,
					default = defaultValue,
				}
			end
		end
        self:sendPacket({pid = "GMSubList", list = list})
    end
end

function GM:serverError(msg)
    if GM.isOpen then
        self:sendPacket({pid = "ServerError", errMsg = msg})
    end
end

function GM:updateGMList()
	if GM.isOpen or Game.HasGMPermission(self.platformUserId) then
		self:sendPacket({pid = "GMList", list = GM.GMList, btsList = GM.BTSGMList})
	end
end

function GM.updateAllPlayer()
    GM.BTSGMItem = {}
    GM.BTSGMList = {}
    local BTSGMItem = GM.BTSGMItem
    -- 临时兼容，player1也读取下，以后gm命令尽量写在全局
    for _, cfg in ipairs({Entity.GetCfg("myplugin/player1"), World.cfg}) do
        for _, trigger in pairs(cfg.triggers or {}) do
            local typ = trigger.type
            if typ:sub(1, 2) == "GM" then
                BTSGMItem["BTS/" .. typ] = function(self)
                    Trigger.CheckTriggers(self:cfg(), typ, {obj1 = self})
                end
            end
        end
    end
    if not next(GM.BTSGMList) then
        for k, v in pairs(BTSGMItem) do
            table.insert(GM.BTSGMList, k)
        end
    end
	if GM.isOpen then
		WorldServer.BroadcastPacket({pid = "GMList", list = GM.GMList, btsList = GM.BTSGMList})
	end
end

--------------------------------------------------------------------------------------------------------------------------------------
GMItem["玩家/PART事件加载"] = function(self)
    local manager = World.CurWorld:getSceneManager()
    local scene = manager:getOrCreateScene(self.map.obj)
    local pos = self:getFrontPos(1, true, true) + Lib.v3(0, 0.5, 2)
    local part = Instance.Create("Part")
    part:loadTrigger(Root.Instance():getGamePath() .. "test.bts")
    Trigger.CheckTriggers(part._cfg, "TEST_PART", {})
    part:setPosition(pos)
    part:setParent(scene:getRoot())
end

GMItem["玩家/升1级"] = function(self)
    self:addExp(self:prop("levelUpExp"), "GM")
end

GMItem["玩家/升10级"] = function(self)
	for i = 1, 10 do
		self:addExp(self:prop("levelUpExp"), "GM")
	end
end

GMItem["PART/测试remove"] =  GM:inputNumber(function(self, runId)
    local Modle = Instance.Create("Model")
    local oldInsTance = Instance.getByRuntimeId(runId)
    local oldInstanceId = oldInsTance:getInstanceID()
    oldInsTance:setParent(Modle)
    local node = Instance.getByInstanceId(oldInstanceId )
    print("测试", node)
end, 99)

GMItem["玩家/升...级"] = GM:inputNumber(function(self, level)
    for i = 1, level do
        self:addExp(self:prop("levelUpExp"), "GM")
    end
end, 99)

GMItem["玩家/加...经验"] = GM:inputNumber(function(self, exp)
    self:addExp(exp, "GM")
end, 1000)

GMItem.NewLine()

GMItem["玩家/血量回满"] = function(self)
    self:setHp(self:prop("maxHp"))
end

GMItem["玩家/体力回满"] = function(self)
    self:setVp(self:prop("maxVp"))
end

GMItem["玩家/base64解析"] = function(self)
    local seri = require "seri"
    local misc = require "misc"
    --local txt = "zgYAAAYsc3RvcmUGAFRzaWduSW5EYXRhBgAkdmFycwZ0Y2hhdERhdGFSZXBvcnQGAABEY2hhcHRlcnMGAER0YXNrRGF0YQYAVHRhc2tGaW5pc2gGAGRyZWNoYXJnZURhdGEGXHN1bVJlY2hhcmdlBkxjdXJyZW50SWQKAUxyZW1pbmREYXkCAAA0d2FsbGV0BnRncmVlbl9jdXJyZW5jeQYsY291bnQiyC0DAAAsZ29sZHMGLGNvdW50AgBMZ0RpYW1vbmRzBixjb3VudBJlXQAALGN1ckhwQgAAAAAAAFlALGN1clZwQgAAAAAAAFlAJHRyYXkGNHN5c3RlbR4GTHRyYXlfZGF0YQZEY2FwYWNpdHkKAQBcY3JlYXRlX2RhdGEGJHR5cGUKAVxtYXhDYXBhY2l0eQoBRGNhcGFjaXR5CgEATGl0ZW1fZGF0YQYAAAZMdHJheV9kYXRhBkRjYXBhY2l0eQoCAFxjcmVhdGVfZGF0YQYkdHlwZQoCXG1heENhcGFjaXR5CgJEY2FwYWNpdHkKAgBMaXRlbV9kYXRhBgAABkx0cmF5X2RhdGEGRGNhcGFjaXR5CgoAXGNyZWF0ZV9kYXRhBiR0eXBlCgNcbWF4Q2FwYWNpdHkKCkRjYXBhY2l0eQoKAExpdGVtX2RhdGEGAAACBkx0cmF5X2RhdGEGRGNhcGFjaXR5CgoAXGNyZWF0ZV9kYXRhBiR0eXBlAlxtYXhDYXBhY2l0eQoKRGNhcGFjaXR5CgoATGl0ZW1fZGF0YQYAAAoUBkx0cmF5X2RhdGEGRGNhcGFjaXR5CgMAXGNyZWF0ZV9kYXRhBiR0eXBlChRcbWF4Q2FwYWNpdHkKA0RjYXBhY2l0eQoDAExpdGVtX2RhdGEGAAAS6AMGTHRyYXlfZGF0YQZEY2FwYWNpdHkKCgBcY3JlYXRlX2RhdGEGJHR5cGUS6ANcbWF4Q2FwYWNpdHkKCkRjYXBhY2l0eQoKAExpdGVtX2RhdGEGAAAAACRidWZmBgAccGV0BgBcdHJlYXN1cmVib3gGAHxyYW5rU2NvcmVSZWNvcmQGADR2YWx1ZXMGlFJlcG9ydEZpcnN0T3V0SG9sZQmUZmluaXNoUm9iRG9udXRTaG9wCXRyb2JiZXJJdGVtTGlzdAYArFJlcG9ydEZpcnN0UG9saWNlRG9vcgmkUmVwb3J0Rmlyc3RFbnRlckJhbmsJdFBhY2thZ2VFbmxhcmdlCgd0UmVwb3J0Rmlyc3RCb3gJXE1vbnRobHlDYXJkBkxsYXN0QXdhcmQCNGV4cGlyeQIAzFJlcG9ydFJvbGVGaXJzdE9ubGluZVRpbWUGNFJvYmJlcgk0UG9saWNlCQCsZmlyc3RQb2xpY2VTZWxlY3RSb2xlCcxSZXBvcnRGaXJzdFNlbGVjdENyaW1pbmFsCTxjaGF0Q250EikEtGZpcnN0UHJpc29uTGVhdmVEYW5nZXIJrFJlcG9ydEZpcnN0RW50ZXJEb251dAmsUmVwb3J0Rmlyc3RFbGVjdHJvbmljCbRSZXBvcnRGaXJzdE1hbmhvbGVIb2xlCXRpc1Nob3dRdWVzdGlvbgm8UmVwb3J0Rmlyc3RTZWxlY3RQb2xpY2UJtGZpcnN0UHJpc29uRW50ZXJXZWFwb24JdFJlcG9ydEZpcnN0T3V0CZxSZXBvcnRGaXJzdEVudGVyR2FzCSxpc1ZpcAlMZ3VpZGVTdGVwLHN0ZXAyrGZpcnN0UHJpc29uU2VsZWN0Um9sZQmUUmVwb3J0Rmlyc3RNYW5ob2xlCURhdXRoTGlzdAY0Y2FyXzA2Iv////98bW9iaWxlX2d1bl9zaG9wIv////9UZ3VuX3Bpc3RvbCL/////PGd1bl91emki/////1RndW5fc25pcGVyIv////9sbW9iaWxlX2dhcmFnZSL/////NGNhcl8wNSL/////zHBhY2thZ2VfZW5sYXJnZV9wcml2aWxlZ2Ui/////0xndW5fcmlmbGUi/////2x2aXBfcHJpdmlsZWdlIv////9cZ3VuX3Nob3RndW4i/////3RndW5fc2Nhcl9nY3ViZSL/////ALRmaXJzdFBvbGljZUxlYXZlRGFuZ2VyCVRtZXJpdFZhbHVlEjyltGZpcnN0UG9saWNlRW50ZXJXZWFwb24JdHBvbGljZUl0ZW1MaXN0LpRteXBsdWdpbi9ndW5fbTE5MTF8bXlwbHVnaW4vZ3VuX20zhG15cGx1Z2luL2d1bl9hd3DEbXlwbHVnaW4vcHJvcHNfaGFuZGN1ZmZzbG15cGx1Z2luL2NhcmQAAAA="
    local txt = ""
    local data = seri.deseristring_string(misc.base64_decode(txt))
    print(Lib.v2s(data, 2))
end

GMItem["玩家/自杀"] = function(self, num)
	if self.curHp<=0 then
		return
	end
    self:setHp(0)
    self:onDead({
        from = self,
        cause = "GM_SUICIDE",
    })
end

GMItem["玩家/无敌与取消"] = function(self)
    local prop = self:prop()
    if prop["undamageable"] > 0 then
        prop["undamageable"] = 0
    else
        prop["undamageable"] = 1
    end
end

GMItem.NewLine()

GMItem["玩家/加绿钞1000"] = function(self)
    self:addCurrency("green_currency", 1000, "gm_board")
end

GMItem["玩家/加绿钞1亿"] = function(self)
    self:addCurrency("green_currency", 100000000, "gm_board")
end

GMItem.NewLine()

GMItem["玩家/读写vars"] = function(self)
    local list = {}
    for k, v in pairs(self.vars) do
        if type(v) ~= "table" then
            list[#list+1] = {
				name = k,
				typ = "vars",
				default = tostring(v),
			}
        end
    end
    self:sendPacket({pid = "GMSubList", list = list})
end

GMItem["玩家/当前位置"] = GM:inputStr(function(self, value)
    local arr = Lib.splitString(value, ",")
    if #arr ~= 3 then
        return
    end
    local pos = {x = arr[1], y = arr[2], z = arr[3]}
    self:setMapPos(self.map, pos)
end, function(self)
	local pos = self:getPosition()
	return string.format("%f, %f, %f", pos.x, pos.y, pos.z)
end)

GMItem["机器人/集合"] = function(self)
    local pos = self:getPosition()
    for _, player in pairs(Game.GetAllPlayers()) do
        player:setPosition(pos)
    end
end

GMItem["资源/加道具"] = listResource("item", 1, {"/block"}, function(self, tb)
    local count = tonumber(tb.value)
    if not self:tray():add_item(tb.name, count, nil, true) then
        return
    end
    self:data("tray"):add_item(tb.name, count, nil, false, "GM")
end)

GMItem["资源/加方块"] = listResource("block", 10, {Block.GetAirBlockName and Block.GetAirBlockName() or nil}, function(self, tb)
    print("GetAirBlockName = ", debug.traceback())
    local function func(item)
		item:set_block(tb.name)
	end
    self:addItem("/block", tonumber(tb.value), func, "GM")
end)

GMItem["资源/加buff"] = listResource("buff", 200, nil, function(self, tb)
    self:addBuff(tb.name, tonumber(tb.value))
end)

GMItem["资源/获得方块名字"] = GM:inputStr(function(self, value)
    local arr = Lib.splitString(value, ",")
    if #arr ~= 3 then
        return
    end
    local pos = {x = arr[1], y = arr[2], z = arr[3]}
	local map = self.map
	print(map:getBlock(pos).fullName)
end)

GMItem["系统/更新server"] = function(self)
    debugport.Reload()
end

GMItem["系统/更新全部C&S"] = function(self)
	WorldServer.BroadcastPacket({pid = "Reload", hasChangeImage = false})
    debugport.Reload(true)
end

GMItem["系统/关闭服务器"] = function(self)
    Server.CurServer:testSigHandler(10)
end

GMItem["LuaProfiler/开始server采样"] = function(self)
    LuaProfiler.Start()
end

GMItem["LuaProfiler/结束server采样"] = function(self)
    LuaProfiler.Stop()
end

GMItem["LuaProfiler/测试server采样准确率"] = function(self)
    LuaProfiler.TestAccuracy()
end

GMItem["LuaProfiler/开启S性能统计"] = function(self)
    Profiler:init()
end

GMItem["LuaProfiler/关闭S性能统计"] = function(self)
    Profiler:reset()
end

GMItem["LuaProfiler/导出S性能统计"] = function(self)
    print(Profiler:dumpString())
end

GMItem["LuaProfiler/S内存分析"] = function (self)
    require("common.mem").List()
end

--GMItem["LuaProfiler/server内存分析index"] = GM:inputNumber(function(self, index)
--    require("common.mem").List(index)
--end)

GMItem["LuaProfiler/S内存清理"] = function (self)
    require("common.mem").Clear()
end

GMItem["LuaProfiler/统计S网络包"] = function (self)
    World.EnablePacketCount(true)
    Server.CurServer:enablePacketStat()
    Server.CurServer:clearPacketStat()
end

GMItem["LuaProfiler/显示S网络包"] = function (self)
    World.ShowPacketCount()
    Server.CurServer:printPacketStat()
end

GMItem["LuaProfiler/lua S内存占用"] = function (self)
    collectgarbage("collect")
    collectgarbage("collect")
    Lib.logInfo(string.format("lua memory %dKB", math.ceil(collectgarbage("count"))))
end

GMItem["LuaProfiler/S 1-Before"] = function (self)
    -- 打印当前 Lua 虚拟机的所有内存引用快照到文件(或者某个对象的所有引用信息快照)到本地文件。
    -- strSavePath - 快照保存路径，不包括文件名。
    -- strExtraFileName - 添加额外的信息到文件名，可以为 "" 或者 nil。
    -- nMaxRescords - 最多打印多少条记录，-1 打印所有记录。
    -- strRootObjectName - 遍历的根节点对象名称，"" 或者 nil 时使用 tostring(cRootObject)
    -- cRootObject - 遍历的根节点对象，默认为 nil 时使用 debug.getregistry()。
    -- MemoryReferenceInfo.m_cMethods.DumpMemorySnapshot(strSavePath, strExtraFileName, nMaxRescords, strRootObjectName, cRootObject)
    collectgarbage("collect")
    collectgarbage("collect")
    mri.m_cMethods.DumpMemorySnapshot("./", "S1-Before", -1)
end

GMItem["LuaProfiler/S 2-After"] = function (self)
    collectgarbage("collect")
    collectgarbage("collect")
    mri.m_cMethods.DumpMemorySnapshot("./", "S2-After", -1)
end

GMItem["LuaProfiler/S ComparedFile"] = function (self)
    -- 比较两份内存快照结果文件，打印文件 strResultFilePathAfter 相对于 strResultFilePathBefore 中新增的内容。
    -- strSavePath - 快照保存路径，不包括文件名。
    -- strExtraFileName - 添加额外的信息到文件名，可以为 "" 或者 nil。
    -- nMaxRescords - 最多打印多少条记录，-1 打印所有记录。
    -- strResultFilePathBefore - 第一个内存快照文件。
    -- strResultFilePathAfter - 第二个用于比较的内存快照文件。
    -- MemoryReferenceInfo.m_cMethods.DumpMemorySnapshotComparedFile(strSavePath, strExtraFileName, nMaxRescords,
    -- strResultFilePathBefore, strResultFilePathAfter)
    mri.m_cMethods.DumpMemorySnapshotComparedFile("./", "Compared", -1, "./LuaMemRefInfo-All-[S1-Before].txt", "./LuaMemRefInfo-All-[S2-After].txt")
end

GMItem["LuaProfiler/S Statistics"] = function (self)
    PerformanceStatistics.SetCPUTimerEnabled(true)
end

GMItem["LuaProfiler/S PrintResults"] = function (self)
    PerformanceStatistics.PrintResults(5000)
    print(Profiler:dumpString())
end

GMItem["LuaProfiler/S LuaMemState"] = function(self)
    Lib.logInfo("**********************************************************")
    LuaTimer:printState()
    Lib.logInfo("timerCalls size", Lib.getTableSize(World.getTimerCalls()))
    Lib.logInfo("ObjectList size", Lib.getTableSize(self.ObjectList))
    Lib.logInfo("mapList size", Lib.getTableSize(World.mapList))
    Lib.logInfo("**********************************************************")
end

local function comp(s1, s2)
    if s2 == "cfg" then
        return false
    elseif s1 == "cfg" then
        return true
    else
        if s1 == "x" or s1 == "y" or s1 == "z" then
            return s1 < s2
        end
        return s1 > s2
    end
    return true
end

GMItem["开发/转移编辑地图新增entity至新文件"] = function(self)
    print(" 该gm用于多人编辑同个地图时，新增多个entity导致合并冲突处理。在编辑地图后拉取配置前使用这个gm命令把本次拉取前对地图的所有新增entity的操作新增的entity进行转移操作，")
    print(" 将所有新增的entity转移到 map地图同级的newEntitySetting.json文件下，然后汇总所有策划的该文件，把数据复制到map的setting文件即可。")
    local mapName = self.map.name
    local filePath = Root.Instance():getGamePath() .. "map/" .. mapName .. "/" .. "setting.json"
    local cfg = assert(Lib.read_json_file(filePath), "GM : 转移编辑地图新增entity至新文件. " .. filePath)
    if not cfg.entity then
        return
    end
    local newEntityArr = {}
    local entitys = cfg.entity
    for index = #entitys, 1, -1 do
        if entitys[index].isNew then
            entitys[index].isNew = nil
            newEntityArr[#newEntityArr + 1] = entitys[index]
            entitys[index] = nil
        end
    end

    local file = io.open(filePath, "w+")
    file:write(Lib.toJson(cfg, function(s1, s2) return comp(s1, s2) end))
    file:close()

    filePath = Root.Instance():getGamePath() .. "map/" .. mapName .. "/" .. "newEntitySetting.json"

    file = io.open(filePath, "w+")
    file:write(Lib.toJson(newEntityArr))
    file:close()
end

GMItem.NewLine()
World.sendErrToClientPlayerIds = {}
GMItem["报错处理/(当前玩家)\n启用服务端报错\n输出到客户端"] = function(self)
    if not self or self.objID==0 or (not self.isPlayer) then
        return
    end
    World.sendErrToClient = "target"
    World.sendErrToClientPlayerIds[self.objID] = true
end

-- GMItem["报错处理/(所有玩家)\n启用服务端报错\n输出到客户端"] = function(self)
--     World.sendErrToClient = "all"
--     World.sendErrToClientPlayerIds = {}
-- end

GMItem["报错处理/(当前玩家)\n禁用服务端报错\n输出到客户端"] = function(self)
    if not self or self.objID==0 or (not self.isPlayer) then
        return
    end
    World.sendErrToClientPlayerIds[self.objID] = nil
    World.sendErrToClient = (not next(World.sendErrToClientPlayerIds)) and "none" or "target"
end

GMItem.NewLine()
GMItem["报错处理/测试"] = function(self)
    io.open()
end

GMItem.NewLine()

GM.updateAllPlayer()	-- 热更新用，放在最后一行
