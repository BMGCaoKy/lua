--- editor lua hotfix
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by GIGABYTE.
--- DateTime: 2021/5/12 10:15
---@class Hotfix
local M = {}

local function update_func(new_func, old_func)
    assert("function" == type(new_func))
    assert("function" == type(old_func))

    -- Get upvalues of old function.
    local old_upvalue_map = {}
    for i = 1, math.huge do
        local name, value = debug.getupvalue(old_func, i)
        if not name then break end
        old_upvalue_map[name] = value
		print('get up value: name:',name)
    end

    -- Update new upvalues with old.
    for i = 1, math.huge do
        local name, value = debug.getupvalue(new_func, i)
        if not name then break end
        print('set up value: name:',name)
        local old_value = old_upvalue_map[name]
        if old_value then
            debug.setupvalue(new_func, i, old_value)
        end
    end
end

local function update_table(new_table, old_table)
    assert("table" == type(new_table))
    assert("table" == type(old_table))

    -- Compare 2 tables, and update old table.
    for key, value in pairs(new_table) do
        local old_value = old_table[key]
        local type_value = type(value)
        if type_value == "function" then
            --update_func(value, old_value)
            old_table[key] = value
        elseif type_value == "table" then
            update_table(value, old_value)
        end
    end

    -- Update metatable.
    local old_meta = debug.getmetatable(old_table)
    local new_meta = debug.getmetatable(new_table)
    if type(old_meta) == "table" and type(new_meta) == "table" then
        update_table(new_meta, old_meta)
    end
    local localTable = {}
    for i = 1, 999 do
        local k, v = debug.getlocal(1, i)
        if not k then
            break
        end
        localTable[k] = v
    end
end


local function hotfix(filename)
    print("start hotfix: ",filename)
    local oldModule = package.loaded[filename]
    if oldModule and "table" == type(oldModule) then
        package.loaded[filename] = nil
        local ok,err = pcall(require, filename)
        if not ok then
            package.loaded[filename] = oldModule
            print('reload lua file failed.',err)
            return
        end
        local newModule = package.loaded[filename]
        update_table(newModule, oldModule)
        if oldModule.OnReload ~= nil then
            oldModule:OnReload()
        end
        print('replaced succeed')
        package.loaded[filename] = oldModule
    else
        print("", filename)
        package.loaded[filename] = nil
        require(filename)
    end
end

function M:reload()
    local changed = {}
    for name, info in pairs(package.filelist) do
        local time = lfs.attributes(info.path, "modification")
        if time and time~=info.time then
            changed[#changed+1] = name
        end
    end
    print("changed lua file(s):", #changed)
    for _, name in ipairs(changed) do
        hotfix(name)
    end
end

return M