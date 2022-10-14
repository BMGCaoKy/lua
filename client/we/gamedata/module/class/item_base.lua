local Lfs = require "lfs"
local Core = require "editor.core"
local Def = require "we.def"
local VN = require "we.gamedata.vnode"
local Signal = require "we.signal"
local Meta = require "we.gamedata.meta.meta"
local TreeSet = require "we.gamedata.vtree"
local Log = require "we.log"
local Engine = require "we.engine"
local ModuleRequest = require "we.proto.request_module"

local M = {}

local function build_tree(self, rawval)
	assert(not self._tree)
	self._tree = TreeSet:create(self._type, rawval)

	Signal:subscribe(self._tree, self._tree.ON_NODE_CTOR, function(node, index)
		local not_store = VN.check_attr(node, index, Def.ATTR_KEY_STORE, "0", true)
		self:on_modify(
			not not_store and VN.check_attr(node, index, Def.ATTR_KEY_RELOAD, "true", true),
			not_store
		)
	end)

	Signal:subscribe(self._tree, self._tree.ON_NODE_ASSIGN, function(node, index)
		local not_store = VN.check_attr(node, index, Def.ATTR_KEY_STORE, "0", true)
		self:on_modify(
			not not_store and VN.check_attr(node, index, Def.ATTR_KEY_RELOAD, "true", true),
			not_store
		)
	end)

	Signal:subscribe(self._tree, self._tree.ON_NODE_INSERT, function(node, index)
		local not_store = VN.check_attr(node, index, Def.ATTR_KEY_STORE, "0", true)
		self:on_modify(
			not not_store and VN.check_attr(node, nil, Def.ATTR_KEY_RELOAD, "true", true),
			not_store
		)
	end)

	Signal:subscribe(self._tree, self._tree.ON_NODE_REMOVE, function(node, index, val)
		local not_store = VN.check_attr(node, index, Def.ATTR_KEY_STORE, "0", true)
		self:on_modify(
			not not_store and VN.check_attr(node, nil, Def.ATTR_KEY_RELOAD, "true", true),
			not_store
		)
	end)

	Signal:subscribe(self._tree, self._tree.ON_NODE_MOVE, function(node, from, to)
		local not_store = VN.check_attr(node, nil, Def.ATTR_KEY_STORE, "0", true)
		self:on_modify(
			not not_store and VN.check_attr(node, nil, Def.ATTR_KEY_RELOAD, "true", true),
			not_store
		)
	end)
end

function M:init(id, module, rawval)
	self._module = module
	self._id = assert(id)
	self._modified = false
	self._type = self._module:item_type()
	self._tree = nil
	self._props = {}

	if rawval then
		self:update_props_cache(rawval)
		build_tree(self, rawval)
		--Log(Def.LOG.ITEM_TREE_BIND, self._tree:id(), self._module:name(), self._id)
	end
end

local function export_game_data(self, dump, val, save)
	local export_info = {}
	local dataSetMD5s

	local val = val or self:val()
	for _, entry in ipairs(self.config) do
		local key = assert(entry.key)
		local writer = assert(entry.writer)
		local export = assert(entry.export)
		local reader = assert(entry.reader)
		local content = reader(self:id(), true, self)

		local data = export(val, content, save, self, dump)
		assert(type(data) == "table")

		assert(not export_info[key])
		export_info[key], dataSetMD5s = writer(self._id, data, dump, self)
	end

	return export_info, dataSetMD5s
end

function M:preprocess()
	local modified = false

	local item_value = {}
	local export_info = {}
	local exportMD5s = {}

	local item_path = Lib.combinePath(Def.PATH_GAME_META_DIR,
		"module", self._module:name(),
		"item",	self._id,
		"setting.json")

	if Lfs.attributes(item_path, "mode") == "file" then
		local data = Lib.read_json_file(item_path)
		if self.folderConfig then
			-- load folder data set
			local folderPath = Lib.combinePath(Def.PATH_GAME_META_DIR, "module", self._module:name(), "item", self._id, self.folderConfig.folder_name)
			self.folderConfig:load_folder_editor(data.data.instances, folderPath, exportMD5s)
		end

		local item_version = assert(data.meta[Def.ITEM_META_VERSION], string.format("item version error %s", item_path))
		item_value = data.data
		item_value[Def.OBJ_TYPE_MEMBER] = item_value[Def.OBJ_TYPE_MEMBER] or self._module:item_type()
		export_info = data.meta[Def.ITEM_META_EXPORT] or export_info

		-- verify
		local meta_set = Meta:meta_set(item_version ~= Meta:version() and item_version)
		local meta = meta_set:meta(self._type)
		local ok, errmsg = meta:verify(item_value)
		assert(ok, string.format("%s data error:\n %s", item_path, errmsg))

		-- upgrade
		repeat
			if item_version == Meta:version() then
				break
			end

			local version
			item_value, version = Meta:upgrade(item_value, item_version)
			assert(version == Meta:version())

			-- verify
			local meta = Meta:meta(self._type)
			assert(meta:verify(item_value))
	
			modified = true
		until(true)
	else
		modified = true
	end

	local dirty = false
	-- update editor data
	local dataSetMD5s_temp
	for _, entry in ipairs(self.config) do
		local key = assert(entry.key)
		local member = entry.member
		local reader = assert(entry.reader)
		local import = assert(entry.import)
		if key ~= "triggers.bts" and key ~= "triggers_client.bts" then	-- TODO: temp，bts 不能依赖引擎数据，因为填错参数就生成不了
			local content, contentMd5, dataSetMD5s = reader(self._id, nil, self)
			if content then
				local is_import = false
				local md5
				if self.folderConfig then
					--[FolderDataSet]判断是否节点资源文件md5
					md5 = contentMd5
					is_import = export_info[key] ~= md5 or not self.folderConfig:check_md5_same(exportMD5s, dataSetMD5s)
					dataSetMD5s_temp = dataSetMD5s
				else
					--判断是否导出引擎数据
					md5 = content ~= "" and Core.md5(content) or ""
					is_import = export_info[key] ~= md5
				end
				if is_import then
					if member then
						item_value[member] = import(content, item_value[member], self)
					else
						-- main
						item_value = import(content, item_value, self)
					end
					export_info[key] = md5
					modified = true
					dirty = true
				end
			else
				assert(member, item_path .. "  " .. key)
				if item_value[member] and next(item_value[member]) then
					item_value[member] = nil
					export_info[key] = nil
					modified = true
					dirty = true
				end
			end
		end
	end

	if modified then
		local meta = Meta:meta(self._type)
		if not dirty then
			-- 导出新的引擎数据，因为编辑器数据做了内容升级，可能会影响引擎数据，如果编辑器数据可信则导出引擎数据
			export_info, dataSetMD5s_temp = export_game_data(self, true, meta:ctor(item_value), false)
		end

		--[FolderDataSet]导出节点资源数据（编辑器）
		self:export_folder_editor(item_value, dataSetMD5s_temp, true)

		local item = {
			meta = {
				[Def.ITEM_META_VERSION] = Meta:version(),
				[Def.ITEM_META_EXPORT] = export_info
			},
			data = meta:diff(item_value, nil, true) or { [Def.OBJ_TYPE_MEMBER] = self._type}
		}

		local ok, errmsg = meta:verify(item.data)
		assert(ok, errmsg)

		local dir = Lib.combinePath(Def.PATH_GAME_META_DIR, "module", self._module:name(), "item", self._id)
		Lib.mkPath(dir)
		local path = Lib.combinePath(dir, "setting.json")
		local file, errmsg = io.open(path, "w+b")
		assert(file, errmsg)
		file:write(Lib.toJson(item))
		file:close()
	end

	self:update_props_cache(item_value)
end

--加载数据
function M:load_data()
	return function() --返回function，使用时再加载
		local item_path = Lib.combinePath(Def.PATH_GAME_META_DIR,
			"module", self._module:name(),
			"item",	self._id,
			"setting.json")
		local data = Lib.read_json_file(item_path)
		return assert(data.data, item_path)
	end
end

function M:load()
	build_tree(self, self:load_data())
	--Log(Def.LOG.ITEM_TREE_BIND, self._tree:id(), self._module:name(), self._id)
end

--[FolderDataSet]导出节点资源数据（编辑器）
function M:export_folder_editor()
end

function M:save()
	if not self:modified() then
		return
	end

	local export_info = {}
	local dataSetMD5s

	-- game data
	do
		export_info, dataSetMD5s = export_game_data(self, true, nil, true)
	end
	
	-- editor data
	do
		local val = self:val()

		--[FolderDataSet]导出节点资源数据（编辑器）
		self:export_folder_editor(val, dataSetMD5s)

		local meta = Meta:meta(self._type)
		local item = {
			meta = {
				[Def.ITEM_META_VERSION] = Meta:version(),
				[Def.ITEM_META_EXPORT] = export_info
			},
			data = meta:diff(val, nil, true) or {}
		}
		local dir = Lib.combinePath(Def.PATH_GAME_META_DIR, "module", self._module:name(), "item", self._id)	
		Lib.mkPath(dir)
		local path = Lib.combinePath(dir, "setting.json")
		os.remove(path)
		local file, errmsg = io.open(path, "w+b")
		assert(file, errmsg)
		file:write(Lib.toJson(item))
		file:close()
		if DataLink:useDataLink() then
			DataLink:modify(path)
		end
	end

	self:set_modified(false)	
end

function M:flush()
	export_game_data(self, false)
end

function M:discard()
	-- game data
	do
		for _, entry in ipairs(self.config) do
			if entry.discard then
				entry.discard(self:id())
			end
		end

		local discard = self.config.discard
		if discard then
			discard(self:id())
		end
	end

	-- editor data
	do
		local dir = Lib.combinePath(Def.PATH_GAME_META_DIR, "module", self._module:name(), "item", self._id)
		--os.execute(string.format([[RD /S/Q "%s"]], dir))
		Lib.rmdir(dir) --遍历删除目录，不弹出窗口
	end
end

function M:reload()
	if self._module:need_reload() then
		Engine:reload_item(Def.DEFAULT_PLUGIN, self._module:name(), self:id())
	end
end

function M:release()
	if self._tree then
		TreeSet:delete(self._tree:id())
		self._tree = nil
	end
end

function M:id()
	return self._id
end

function M:set_modified(state)
	if self._modified == state then
		return
	end

	self._modified = state
end

function M:modified()
	return self._modified
end

function M:data()
	return self._tree
end

function M:val()
	return self._tree:value()
end

function M:obj()
	return self._tree:root()
end

function M:module_name()
	return self._module:name()
end

function M:dir()
	return Lib.combinePath(Def.PATH_GAME_META_DIR, "module", self._module:name(), "item", self._id)
end

--引擎数据位置
function M:game_dir()
	return Lib.combinePath(Def.PATH_GAME, "plugin", Def.DEFAULT_PLUGIN, self._module:name(), self._id)
end

function M:props()
	return self._props
end

function M:update_props_cache(rawval)
	rawval = rawval or self:obj()
	self._props = {
		name = rawval.name and rawval.name.value or tostring(self._id),
		dir_game = self:game_dir()
	}
end

function M:on_modify(reload, no_store)
	if no_store then
		return
	end

	self:set_modified(true)
	if reload then
		self:flush()
		self:reload()
	end
	self:update_props_cache()
	Lib.emitEvent(Event.EVENT_EDITOR_DATA_MODIFIED, self._module:name(), self._id)
end

return M
