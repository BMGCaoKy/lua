local Def = require "we.def"
local GameRequest = require "we.proto.request_game"
local useDataLink = false
local path_game_normalize = Lib.normalizePath(Def.PATH_GAME)
print("path_game_normalize:"..path_game_normalize)

local function v_include(tab, value)
    for k,v in pairs(tab) do
        if v == value then
            return true
        end
    end
    return false
end

function DataLink:useDataLink()
    return useDataLink
end

function DataLink:init()
    self.add_file = {}
    self.del_file = {}
    self.del_dir = {}
    self.modify_file = {}

    local _conf = Lib.read_json_file("./conf/default_cfg.json")
    if _conf then
        if _conf.hardLink then
            useDataLink = _conf.hardLink == 1
        end
    end
end

--function HardLink:mklink(path)
--    for file in lfs.dir(path, true) do
--        if file ~= "." and file ~= ".." then
--            local f = path .. '/' .. file
--            local attr = lfs.attributes(f)
--            if attr.mode == "directory" then
--                local find, q = string.find(f, gamePath, 1, true)
--                if find then
--                    local entryName = string.sub(f, q + 1)
--                    local hardLinkPath = Lib.combinePath(gamePath_hardLink, entryName)
--                    local command = string.format([[mkdir "%s"]], hardLinkPath)
--                    --print(command)
--                    os.execute(command)
--                end
--                self:mklink(f)
--            else
--                local find, q = string.find(f, gamePath, 1, true)
--                if find then
--                    local entryName = string.sub(f, q + 1)
--                    local hardLinkPath = Lib.combinePath(gamePath_hardLink, entryName)
--                    local command = string.format([[mklink /H "%s" "%s"]], hardLinkPath, f)
--                    --print(command)
--                    --os.execute(command)
--                    lfs.link (hardLinkPath, f)
--                end
--            end
--        end
--    end
--end


local function getOriginalPath(path)
    assert(Def.PATH_GAME_ORIGINAL, "Def.PATH_GAME_ORIGINAL == Null")
    path = Lib.normalizePath(path)
    local find, q = string.find(path, path_game_normalize, 1, true)
    assert(q, path)
    local entryName = string.sub(path, q + 1)
    local destPath = Lib.combinePath(Def.PATH_GAME_ORIGINAL, entryName)
    return destPath
end

function DataLink:save()
    for k, v in pairs(self.modify_file) do
        local destPath = getOriginalPath(v)
        GameRequest.request_save_original_data(true, v, destPath)
    end
    for k, v in pairs(self.del_file) do
        local destPath = getOriginalPath(v)
        GameRequest.request_save_original_data(false, nil, destPath)
    end
    for k, v in pairs(self.del_dir) do
        local destPath = getOriginalPath(v)
        GameRequest.request_save_original_data(false, nil, destPath)
    end
    self.add_file = {}
    self.del_file = {}
    self.del_dir = {}
    GameRequest.request_save_original_map_data()
end

function DataLink:modify(path)
    if not v_include(self.modify_file, path) then
        table.insert(self.modify_file, path)
    end
end

function DataLink:delDir(path)
    os.execute(string.format([[RD /S/Q "%s"]], path))
    if not v_include(self.del_dir, path) then
        table.insert(self.del_dir, path)
    end
end

function DataLink:delFile(path)
    os.remove(path)
    if not v_include(self.del_file, path) then
        table.insert(self.del_file, path)
    end
end

DataLink:init()