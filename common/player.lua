local setting = require "common.setting"

Player.isPlayer = true

local function initTask()
    Player.Tasks = setting:mod("task"):loadAll()
    Player.TaskMap = {}
    for _, cfg in pairs(Player.Tasks) do
        cfg.tasks = cfg.tasks or {}
        for index, task in pairs(cfg.tasks) do
            task.index = index
            task.group = cfg
            task.show = task.show == nil and true or task.show
            task.status = task.status == "own" and 1 or 0
            task.times = task.times or "once"
            task.fullName = cfg.fullName .. "/" .. task.key
            Player.TaskMap[task.fullName] = task
            for i, tt in pairs(task.targets or {}) do
                tt.task = task
                tt.index = i
                tt.count = tt.count or 1
            end
        end
    end
end

local function initSignIn()
    Player.SignIns = {}
    for _, sign_in in pairs(setting:mod("sign_in"):loadAll()) do
        Player.SignIns[sign_in.showOrder] = sign_in
    end
    for _, cfg in pairs(Player.SignIns) do
        print(cfg._name)
        --default init
        cfg.image_bg = cfg.image_bg or ""
        cfg.image_tips = cfg.image_tips or ""
        cfg.imagePos = cfg.imagePos or "LeftTop"
        cfg.imageOccupy = cfg.imageOccupy or 0
        cfg.stretch = cfg.stretch or "vertical"

        cfg.rowSize = cfg.rowSize or 7
        cfg.interval_x = cfg.interval_x or 10
        cfg.interval_y = cfg.interval_y or 10

        cfg.show_item_order = cfg.show_item_order or false
        cfg.border_x = cfg.border_x or 10
        cfg.border_y = cfg.border_y or 10

        cfg.finish_text = cfg.finish_text or ""
        cfg.text_pos_x = cfg.text_pos_x or 0
        cfg.text_pos_y = cfg.text_pos_y or 0

        cfg.sign_in_items = cfg.sign_in_items or {}
		if not cfg.randomItem then
			for index, item in pairs(cfg.sign_in_items) do
				item.index = index
				item.group = cfg
				item.fullName = cfg.fullName .. "/" .. index
			end
		end
    end
end

local function initRecharge()
    Player.SumRechargeConfig = {}
    for _, cfg in pairs(setting:mod("recharge"):loadAll()) do
        if cfg._name == "sum_recharge" then
            Player.SumRechargeConfig = cfg
            for _, item in pairs(Player.SumRechargeConfig.items or {}) do
                item.dailyRemind = item.dailyRemind == 1
            end
        end
    end
end

local function init()
    initTask()
    initSignIn()
    initRecharge()
end

function Player.Reload()
    init()
end

function Player.GetTask(name, cfg)
    local ary = Lib.splitString(name, "/")
    if #ary < 3 then
        assert(cfg, name)    -- 不完全名称，必须有相对参照物
        if #ary == 2 then
            name = cfg.plugin .. "/" .. name
        else
            name = cfg.fullName .. "/" .. name
        end
    end
    return assert(Player.TaskMap[name], name)
end

function Player.CheckTaskHint(name, targets)
    local task = Player.GetTask(name)
    local hint = true
    for i, t in ipairs(targets) do
        if t < task.targets[i].count then
            hint = false
        end
    end
    return hint
end

function Player.getSumRecharge(id)
    for _, config in pairs(Player.SumRechargeConfig.items or {}) do
        if config.id == id then
            return config
        end
    end
end

function Player.getMinGCubeConfig(sex)
    local result
    for _, config in pairs(Player.SumRechargeConfig.items or {}) do
        if config.sex == sex or config.sex == 0 then
            if result == nil then
                result = config
            end
            if result.gcube > config.gcube then
                result = config
            end
        end
    end
    return result
end

function Player:RequestFriendList(callback, first, last)
    
end

function Player:RequestIsFriendWith(UserID, callback)
end

function Player:GetUserData(callback)

end

init()
