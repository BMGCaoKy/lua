--- mobile_editor_define.lua

Define.GAME_MODE = {
    NONE = 0,
    EDIT = 1,
    PLAY = 2,
}

Define.MOD_INTERVAL = {
    NONE = 0,
    GEOMETRY = 0.5, -- 1
    PROP = 0.25,
}

Define.MATERIAL_ATTRIBUTE = {
    NONE = 0,
    WATER = 1,
    GLASS = 2,
}

Define.LIGHT_TYPE = {
    NONE = 0,
    AMBIENT = 1,
    DIFFUSE = 2,
    SPECULAR = 3,
}

Define.RAY_CAST_TYPE = {
    ["EMPTY"] = 0,
    ["BLOCK"] = 1 << 0,
    ["ENTITY"] = 1 << 1,
    ["DROPITEM"] = 1 << 2,
    ["PART"] = 1 << 3,
    ["INSTANCE"] = 1 << 4,
    ["TERRAIN"] = 1 << 5,
    ["OBJECT"] =  0xFFFFFFFF & ~(1 << 0),
    ["ALL"] = 0xFFFFFFFF
}

Define.ABILITY = {
    TRANSLATE			= 1 << 1,
    SCALE				= 1 << 2,
    ROTATE				= 1 << 3,
    TRANSFORM			= 1 << 1 | 1 << 2 | 1 << 3,
    AABB				= 1 << 4,
    DUPLICATE           = 1 << 5,
    GROUP               = 1 << 6,
    FOCUS 				= 1 << 7,
    MATERIAL            = 1 << 8,
    SELECTABLE			= 1 << 9,
    DELETE              = 1 << 10,
    UNGROUP             = 1 << 11,
    CHANGLIGHTANGLE     = 1 << 12,

}

Define.NODE_TYPE = {
    NONE = 0,
    PART = 1,
    MODEL = 2,
    MESHPART = 3,
    REGIONPART = 4,
    PARTOPERATION = 5,
}

Define.CLASS_ABILITY = {
    [Define.NODE_TYPE.PARTOPERATION] = Define.ABILITY.TRANSFORM | Define.ABILITY.AABB | Define.ABILITY.FOCUS | Define.ABILITY.SELECTABLE | Define.ABILITY.DUPLICATE | Define.ABILITY.DELETE | Define.ABILITY.GROUP | Define.ABILITY.MATERIAL,
    [Define.NODE_TYPE.PART] = Define.ABILITY.TRANSFORM | Define.ABILITY.AABB | Define.ABILITY.FOCUS | Define.ABILITY.SELECTABLE  | Define.ABILITY.DUPLICATE | Define.ABILITY.DELETE | Define.ABILITY.GROUP | Define.ABILITY.MATERIAL,
    [Define.NODE_TYPE.MODEL] = Define.ABILITY.TRANSFORM | Define.ABILITY.AABB | Define.ABILITY.FOCUS | Define.ABILITY.SELECTABLE  | Define.ABILITY.DUPLICATE | Define.ABILITY.DELETE | Define.ABILITY.GROUP | Define.ABILITY.UNGROUP,
    [Define.NODE_TYPE.MESHPART] = Define.ABILITY.TRANSFORM  | Define.ABILITY.AABB | Define.ABILITY.FOCUS | Define.ABILITY.SELECTABLE  | Define.ABILITY.DUPLICATE | Define.ABILITY.DELETE | Define.ABILITY.GROUP,
    [Define.NODE_TYPE.REGIONPART] = Define.ABILITY.TRANSLATE | Define.ABILITY.SCALE | Define.ABILITY.AABB | Define.ABILITY.FOCUS | Define.ABILITY.SELECTABLE  | Define.ABILITY.DUPLICATE | Define.ABILITY.DELETE | Define.ABILITY.GROUP,
}

Define.TRANSFORM_TYPE = {
    NONE = 0,
    TRANSLATE = 1,
    ROTATE = 2,
    SCALE = 3,
}

Define.SPACE_MODE = {
    NONE = 0,
    LOCAL = 1,
    WORLD = 2,
}

Define.ENV_TYPE = {
    NONE = 0,
    SKYBOX = 1,
    WEATHER = 2,
    LIGHT = 3,
    MUSIC = 4,
}

Define.GRAPHICS_QUALITY = {
    LOW = 0,
    MID = 1,
    HIGH = 2,
}

Define.GRAPHICS_SHADOW = {
    ON = 1,
    OFF = 2,
}

Define.SOUND_CHANNEL_GROUP = {
    BGM = 0,
    EFFECT = 1,
}