local def = {}

local id = 0;
local function accumulator(segment)
	id = segment or id + 1
	return id
end

def.TBLOCK							= 1
def.TENTITY							= 2
def.TREGION							= 3
def.TCHUNK							= 4
def.TFRAME							= 5
def.TFRAME_POS						= 6
def.TBLOCK_FILL						= 7

def.ECOMMON							= 1
def.EMOVE							= 2
def.ESCALE							= 3
def.EROTATE							= 4


def.PATH							= ""

def.BLOCK_ITERATE_STEP				= 8192

def.CHECK_NULL						= 1
def.CHECK_QUICK_CUT					= 2
def.CHECK_MIRROR					= 3

def.DIR_GAME_OUTPUT					= Lib.combinePath(Root.Instance():getRootPath(), "out")
-- editor conf
-- 改为相对于资源的路径, OSX下可执行文件和资源分离
local rootpath = Root.Instance():getRootPath()
def.PATH_META_CONFIG				= rootpath .. "conf/meta.json"
def.PATH_META_DIR					= rootpath .. "conf/meta/"
def.PATH_MODULE_CONFIG				= rootpath .. "conf/module.json"
def.PATH_SYS_TEXT					= rootpath .. "conf/lang/"
def.PATH_ASSET_DIR					= rootpath .. "conf/asset/"
def.PATH_APP_DATA_DIR				= WorldEditor.LuaAppDataDir()	-- 数据根目录，根据产品/平台要求会指定在不同的位置
def.PATH_APP_CONFIG_DIR				= WorldEditor.LuaAppConfigDir()	-- 配置根目录，根据产品/平台要求会指定在不同的位置
def.PATH_GAME_ROOT_DIR				= WorldEditor.LuaGameRootDir()	-- 同上，不一定是根目录下的“editor”
def.PATH_GAME_LINK_DIR				= WorldEditor.LuaGameLinkDir()	-- 同上，不一定是根目录下的“editor_link”
def.PATH_META_CUSTOM_CONFIG			= Lib.combinePath(def.PATH_APP_CONFIG_DIR, "meta_custom.ini")
def.PATH_LANGUAGE					= Lib.combinePath(def.PATH_APP_CONFIG_DIR, "editor_language.json")
def.PATH_ASSET_MAP_DIR				= Lib.combinePath(def.PATH_ASSET_DIR, "map")

def.ITEM_META_TAG					= "__ITEM_META"
def.ITEM_META_VERSION				= "VERSION"
def.ITEM_META_EXPORT				= "EXPORT"

--material texture slot
def.BUMP_SLOT						=9
def.SPECULAR_SLOT					=10
def.EMISSION_SLOT					=11

-- game data
def.DEFAULT_PLUGIN					= "myplugin"
def.PATH_GAME_META_DIR				= Lib.combinePath(Root.Instance():getGamePath(), ".meta")
def.PATH_GAME_META_ASSET			= Lib.combinePath(def.PATH_GAME_META_DIR, "asset")
def.PATH_GAME_META_TEXT				= Lib.combinePath(def.PATH_GAME_META_DIR, "lang.csv")
def.PATH_GAME_META_ID_MAPPING		= Lib.combinePath(def.PATH_GAME_META_DIR, "id_mapping.json")

def.PATH_GAME_ORIGINAL				= Root.Instance():getGameMasterPath()
def.PATH_GAME						= Root.Instance():getGamePath()
def.PATH_GAME_ASSET					= Lib.combinePath(Root.Instance():getGamePath(), "asset/")
def.PATH_EXPORT_TEXT				= Lib.combinePath(Root.Instance():getGamePath(), "lang", "lang.csv")
def.PATH_EXPORT_ID_MAPPING			= Lib.combinePath(Root.Instance():getGamePath(), "id_mappings.json")
def.PATH_EXPORT_COIN				= Lib.combinePath(Root.Instance():getGamePath(), "coin.json")
def.PATH_EVENTS						= Lib.combinePath(Root.Instance():getGamePath(), "events/")
def.PATH_MERGESHAPESDATA			= Lib.combinePath(Root.Instance():getGamePath(), "scene_asset/mergeShapesData/")
def.PATH_PART_COLLISION				= Lib.combinePath(Root.Instance():getGamePath(), "part_collision/")
def.PATH_MESHPART_COLLISION			= Lib.combinePath(Root.Instance():getGamePath(), "meshpart_collision/")
def.PATH_ADDITIONAL_META			= Lib.combinePath(Root.Instance():getGamePath(), "plugin", def.DEFAULT_PLUGIN, "custom_meta")
def.PATH_UI_FONTS					= Lib.combinePath(Root.Instance():getGamePath(), "gui/fonts")
def.PATH_UI_FONTS_JSON				= Lib.combinePath(Root.Instance():getGamePath(), "gui/schemes/user_font.json")
def.PATH_UI_EVENTS					= Lib.combinePath(Root.Instance():getGamePath(), "gui" ,"events")
def.PATH_UI_CUSTOM_LAYOUT			= Lib.combinePath(Root.Instance():getGamePath(), "gui/layout_presets/")

def.OBJ_TYPE_MEMBER					= "__OBJ_TYPE"
def.ATTR_KEY_STORE					= "Store"
def.ATTR_KEY_RELOAD					= "RELOAD"
def.ATTR_KEY_GROUP					= "GROUP"
def.ATTR_KEY_COPY					= "COPY"

def.ATTR_KEY_ENUM_LIST				= "LIST"

def.ATTR_KEY_STRING_UUID			= "UUID"
def.ATTR_KEY_NUMBER_INTEGER			= "Integer"
def.ATTR_KEY_NUMBER_MIN				= "MIN"
def.ATTR_KEY_ENUM_NONEMPTY			= "Nonempty"
def.ATTR_KEY_VALUE_MIXED			= "Mixed"


def.PROTO = {
	ITEM_NEW					= "ITEM_NEW",
	ITEM_DEL					= "ITEM_DEL",

	PROPERTY_CTOR				= "PROPERTY_CTOR",
	PROPERTY_ASSIGN				= "PROPERTY_ASSIGN",
	PROPERTY_ARRAY_INSERT		= "PROPERTY_ARRAY_INSERT",
	PROPERTY_ARRAY_REMOVE		= "PROPERTY_ARRAY_REMOVE",
	PROPERTY_ARRAY_MOVE			= "PROPERTY_ARRAY_MOVE",

	PROPERTY_ATTR_CHANGED		= "PROPERTY_ATTR_CHANGED",
	
	MODIFY_FLAG					= "MODIFY_FLAG"
}


def.NODE_EVENT = {
	ON_CTOR							= accumulator(),
	ON_ASSIGN						= accumulator(),
	ON_INSERT						= accumulator(),
	ON_REMOVE						= accumulator(),
	ON_MOVE							= accumulator(),

	ON_MODIFY						= accumulator(),

	ON_ATTR_CHANGED					= accumulator(),
	ON_ATTR_MODIFY					= accumulator()
}

def.TREE_EVENT = {
	ON_NODE_CTOR					= accumulator(),
	ON_NODE_ASSIGN					= accumulator(),
	ON_NODE_INSERT					= accumulator(),
	ON_NODE_REMOVE					= accumulator(),
	ON_NODE_MOVE					= accumulator(),
	ON_NODE_ATTR_CHANGED			= accumulator()
}

def.LOG = {
	TREE_NODE_CTOR					= "TREE_NODE_CTOR",
	TREE_NODE_ASSIGN				= "TREE_NODE_ASSIGN",
	TREE_NODE_INSERT				= "TREE_NODE_INSERT",
	TREE_NODE_REMOVE				= "TREE_NODE_REMOVE",
	TREE_NODE_MOVE					= "TREE_NODE_MOVE",
	TREE_NODE_ATTR_CHANGE			= "TREE_NODE_ATTR_CHANGE",

	ITEM_TREE_BIND					= "ITEM_TREE_BIND",
}

def.ERROR_CODE = {
	TYPE_ERROR	= 101
}

def.TYPE_ASSET						= "__ASSET__"

-- 和 Blockman::getRayTraceResult 对应
def.SCENE_NODE_TYPE = {
	NONE							= 0,
	
	BLOCK							= 1 << 0,
	ENTITY							= 1 << 1,
	DROPITEM						= 1 << 2,
	PART							= 1 << 3,
	INSTANCE						= 1 << 4,
	TERRAIN							= 1 << 5,

	OBJECT							= 0xFFFFFFFF & ~(1 << 0),	-- 目前排除 BLOCK 的都算 OBJECT
	ALL								= 0xFFFFFFFF
}


def.SCENE_NODE_TYPE_NAME = {
	[def.SCENE_NODE_TYPE.NONE]		= "EMPTY",
	[def.SCENE_NODE_TYPE.BLOCK]		= "BLOCK",
	[def.SCENE_NODE_TYPE.ENTITY]	= "ENTITY",
	[def.SCENE_NODE_TYPE.DROPITEM]	= "DROPITEM",
	[def.SCENE_NODE_TYPE.PART]		= "PART",
	[def.SCENE_NODE_TYPE.INSTANCE]	= "INSTANCE",
	[def.SCENE_NODE_TYPE.TERRAIN]	= "TERRAIN",
}
for k, v in pairs(Lib.copy(def.SCENE_NODE_TYPE_NAME)) do
	assert(not def.SCENE_NODE_TYPE_NAME[v], v)
	def.SCENE_NODE_TYPE_NAME[v] = k
end

def.SCENE_MODEL_TYPE = {
	Model	= true,
	Part	= true,
	PartOperation	= true,
	MeshPart= true,
	SceneUI	= true,
	EffectPart = true,
	AudioNode = true
}

def.SCENE_UNION_TYPE = {
	Part	= true,
	PartOperation	= true
}

-- 支持蓝图的类型 键值对<class,module_name>
def.SCENE_SUPPORT_BLUEPRINT_TYPE = {
	Part			= "part",
	MeshPart		= "meshpart",
	PartOperation	= "part_operation"
}

def.filter = {} --过滤模块用的

--设值时会从model向下传递的属性类型
def.MODEL_PROPAGATABLE_PROP_TYPE =
{
	batchType = true,
	canAcceptShadow = true,
	canGenerateShadow = true,
	bakeTextureWeight = true
}

def.PROP_SUPPORT_TYPE =
{
	batchType = 
	{
		Model = true,
		Part = true,
		PartOperation = true,
		MeshPart = true
	},
	bake_enable = 
	{
		Model = true,
		Part = true,
		PartOperation = true,
		MeshPart = true
	}
}

return def
