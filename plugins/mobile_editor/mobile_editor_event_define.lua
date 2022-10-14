--- mobile_editor_event_define.lua

if World.isClient then

    Event.EVENT_TOUCH_BEGIN = Event.register("EVENT_TOUCH_BEGIN")
    Event.EVENT_TOUCH_MOVE = Event.register("EVENT_TOUCH_MOVE")
    Event.EVENT_TOUCH_END = Event.register("EVENT_TOUCH_END")
    Event.EVENT_TOUCH_CANCEL = Event.register("EVENT_TOUCH_CANCEL")


    Event.EVENT_SET_CAMERA = Event.register("EVENT_SET_CAMERA")
    Event.EVENT_PINCH_CAMERA = Event.register("EVENT_PINCH_CAMERA")
    Event.EVENT_PAN_CAMERA = Event.register("EVENT_PAN_CAMERA")
    Event.EVENT_FOCUS_TARGET = Event.register("EVENT_FOCUS_TARGET")
    Event.EVENT_SET_FOCUS = Event.register("EVENT_SET_FOCUS")
    Event.EVENT_PITCH_CAMERA = Event.register("EVENT_PITCH_CAMERA")
    Event.EVENT_TURN_CAMERA = Event.register("EVENT_TURN_CAMERA")

    Event.EVENT_PRESS_FLY = Event.register("EVENT_PRESS_FLY")
    Event.EVENT_PRESS_JUMP = Event.register("EVENT_PRESS_JUMP")


    Event.EVENT_TOUCH_DOWN_NODE = Event.register("EVENT_TOUCH_DOWN_NODE")
    Event.EVENT_TOUCH_MOVE_NODE = Event.register("EVENT_TOUCH_MOVE_NODE")
    Event.EVENT_TOUCH_END_NODE = Event.register("EVENT_TOUCH_END_NODE")

    Event.EVENT_RESET_GEOMETRY = Event.register("EVENT_RESET_GEOMETRY")
    Event.EVENT_RESET_MODEL = Event.register("EVENT_RESET_MODEL")

    Event.EVENT_TOGGLE_CAMERA = Event.register("EVENT_TOGGLE_CAMERA")
    Event.EVENT_KEY_DOWN = Event.register("EVENT_KEY_DOWN")

    Event.EVENT_ENABLE_MULTIPLE = Event.register("EVENT_ENABLE_MULTIPLE")

    Event.EVENT_GROUP_TARGET = Event.register("EVENT_GROUP_TARGET")
    Event.EVENT_DUPLICATE_TARGET = Event.register("EVENT_DUPLICATE_TARGET")

    Event.EVENT_ADD_GROUP = Event.register("EVENT_ADD_GROUP")
    Event.EVENT_REMOVE_GROUP = Event.register("EVENT_REMOVE_GROUP")


    Event.EVENT_CONFIRM_MULTIPLE = Event.register("EVENT_CONFIRM_MULTIPLE")
    Event.EVENT_CANCEL_MULTIPLE = Event.register("EVENT_CANCEL_MULTIPLE")

    Event.EVENT_NEW_NODE = Event.register("EVENT_NEW_NODE")
    Event.EVENT_UPDATE_NODE = Event.register("EVENT_UPDATE_NODE")
    Event.EVENT_DELETE_NODE = Event.register("EVENT_DELETE_NODE")

    Event.EVENT_START_TRANSLATE = Event.register("EVENT_START_TRANSLATE")
    Event.EVENT_FINISH_TRANSLATE = Event.register("EVENT_FINISH_TRANSLATE")

    Event.EVENT_SELECT_TARGET = Event.register("EVENT_SELECT_TARGET")
    Event.EVENT_UNSELECT_TARGET = Event.register("EVENT_UNSELECT_TARGET")
    Event.EVENT_UPDATE_TARGET = Event.register("EVENT_UPDATE_TARGET")
    Event.EVENT_RESET_TARGET = Event.register("EVENT_RESET_TARGET")
    Event.EVENT_CHANGE_TARGET_STATE = Event.register("EVENT_CHANGE_TARGET_STATE")

    Event.EVENT_START_SELECTION = Event.register("EVENT_START_SELECTION")
    Event.EVENT_UPDATE_SELECTION = Event.register("EVENT_UPDATE_SELECTION")
    Event.EVENT_END_SELECTION = Event.register("EVENT_END_SELECTION")


    Event.EVENT_ADD_TARGET = Event.register("EVENT_ADD_TARGET")
    Event.EVENT_REMOVE_TARGET = Event.register("EVENT_REMOVE_TARGET")
    Event.EVENT_DELETE_TARGET = Event.register("EVENT_DELETE_TARGET")

    Event.EVENT_START_MOVE = Event.register("EVENT_START_MOVE")
    Event.EVENT_MOVE_TARGET = Event.register("EVENT_MOVE_TARGET")
    Event.EVENT_END_MOVE = Event.register("EVENT_END_MOVE")

    Event.EVENT_SHOW_WINDOW = Event.register("EVENT_SHOW_WINDOW")
    Event.EVENT_HIDE_WINDOW = Event.register("EVENT_HIDE_WINDOW")

    Event.EVENT_UPDATE_SPACE = Event.register("EVENT_UPDATE_SPACE")
    Event.EVENT_SHOW_GIZMO = Event.register("EVENT_SHOW_GIZMO")
    Event.EVENT_HIDE_GIZMO = Event.register("EVENT_HIDE_GIZMO")
    Event.EVENT_SWITCH_GIZMO = Event.register("EVENT_SWITCH_GIZMO")
    Event.EVENT_MOVE_GIZMO = Event.register("EVENT_MOVE_GIZMO")
    Event.EVENT_ROTATE_GIZMO = Event.register("EVENT_ROTATE_GIZMO")
    Event.EVENT_SCALE_GIZMO = Event.register("EVENT_SCALE_GIZMO")







    Event.EVENT_SHOW_TARGET_MATERIAL = Event.register("EVENT_SHOW_TARGET_MATERIAL")
    Event.EVENT_UPDATE_TARGET_MATERIAL = Event.register("EVENT_UPDATE_TARGET_MATERIAL")



    Event.EVENT_CHANGE_MATERIAL_TEXTURE = Event.register("EVENT_CHANGE_MATERIAL")
    Event.EVENT_CHANGE_MATERIAL_COLOR = Event.register("EVENT_CHANGE_MATERIAL_COLOR")

    Event.EVENT_UPDATE_MATERIAL_COLOR = Event.register("EVENT_UPDATE_MATERIAL_COLOR")
    Event.EVENT_UPDATE_MATERIAL_TEXTURE = Event.register("EVENT_UPDATE_MATERIAL_TEXTURE")


    Event.EVENT_UNDO_COMMAND = Event.register("EVENT_UNDO_COMMAND")
    Event.EVENT_REDO_COMMAND = Event.register("EVENT_REDO_COMMAND")
    Event.EVENT_UPDATE_COMMAND = Event.register("EVENT_UPDATE_COMMAND")

    Event.EVENT_CHECK_UNDO_REDO = Event.register("EVENT_CHECK_UNDO_REDO")


    Event.EVENT_ENTER_PLAY_MODE = Event.register("EVENT_ENTER_PLAY_MODE")
    Event.EVENT_ENTER_EDIT_MODE = Event.register("EVENT_ENTER_EDIT_MODE")

    Event.EVENT_UNLOCK_FLY_MODE = Event.register("EVENT_UNLOCK_FLY_MODE")
    Event.EVENT_LOCK_FLY_MODE = Event.register("EVENT_LOCK_FLY_MODE")

    Event.EVENT_ENTER_CAPTURE_STATE = Event.register("EVENT_ENTER_CAPTURE_STATE")
    Event.EVENT_EXIT_CAPTURE_STATE = Event.register("EVENT_EXIT_CAPTURE_STATE")

    Event.EVENT_ENTER_ENVIRONMENT_STATE = Event.register("EVENT_ENTER_ENVIRONMENT_STATE")
    Event.EVENT_EXIT_ENVIRONMENT_STATE = Event.register("EVENT_EXIT_ENVIRONMENT_STATE")

    Event.EVENT_CHANGE_TOOL_BAR = Event.register("EVENT_CHANGE_TOOL_BAR")
    Event.EVENT_SHOW_NOTIFICATION = Event.register("EVENT_SHOW_NOTIFICATION")
    Event.EVENT_SAVE_MAP_CHANGE = Event.register("EVENT_SAVE_MAP_CHANGE")
    Event.EVENT_SAVE_MAP_FINISH = Event.register("EVENT_SAVE_MAP_FINISH")


    Event.EVENT_SAVE_ENVIRONMENT_DATA = Event.register("EVENT_SAVE_ENVIRONMENT_DATA")

    Event.EVENT_PLAY_SOUND = Event.register("EVENT_PLAY_SOUND")
    Event.EVENT_STOP_SOUND = Event.register("EVENT_STOP_SOUND")

    Event.EVENT_PLAY_BGM = Event.register("EVENT_PLAY_BGM")
    Event.EVENT_STOP_BGM = Event.register("EVENT_STOP_BGM")
    Event.EVENT_PAUSE_BGM = Event.register("EVENT_PAUSE_BGM")
    Event.EVENT_RESUME_BGM = Event.register("EVENT_RESUME_BGM")


    Event.EVENT_UPDATE_SKYBOX = Event.register("EVENT_UPDATE_SKYBOX")
    Event.EVENT_UPDATE_WEATHER = Event.register("EVENT_UPDATE_WEATHER")

    Event.EVENT_UPDATE_AMBIENT_STRENGTH = Event.register("EVENT_UPDATE_AMBIENT_STRENGTH")
    Event.EVENT_UPDATE_AMBIENT_COLOR = Event.register("EVENT_UPDATE_AMBIENT_COLOR")
    Event.EVENT_UPDATE_DIFFUSE_COLOR = Event.register("EVENT_UPDATE_DIFFUSE_COLOR")

    Event.EVENT_UPDATE_GROUND_MATERIAL = Event.register("EVENT_UPDATE_GROUND_MATERIAL")
    Event.EVENT_UPDATE_GROUND_COLOR = Event.register("EVENT_UPDATE_GROUND_COLOR")


    Event.EVENT_EXIT_GAME = Event.register("EVENT_EXIT_GAME")

    Event.EVENT_SHOW_ENVIRONMENT_EDITOR =  Event.register("EVENT_SHOW_ENVIRONMENT_EDITOR")
    Event.EVENT_SHOW_MODEL_EDITOR =  Event.register("EVENT_SHOW_MODEL_EDITOR")
    Event.EVENT_ENVIRONMENT_ITEM_CLICK =  Event.register("EVENT_ENVIRONMENT_ITEM_CLICK")
    Event.EVENT_SHOW_TOOL_PANEL = Event.register("EVENT_SHOW_TOOL_PANEL")
    Event.EVENT_SHOW_LAST_TOOL_PANEL = Event.register("EVENT_SHOW_LAST_TOOL_PANEL")
    Event.EVENT_SHOW_TOOL_SETTING = Event.register("EVENT_SHOW_TOOL_SETTING")
    Event.EVENT_SETTING_RETURN = Event.register("Event.EVENT_SETTING_RETURN")
    Event.EVENT_OPEN_SETTING = Event.register("EVENT_OPEN_SETTING")
    Event.EVENT_CLOSE_SETTING = Event.register("EVENT_CLOSE_SETTING")
    Event.EVENT_CLOSE_MAIN = Event.register("EVENT_CLOSE_MAIN")
    Event.EVENT_OPEN_MAIN = Event.register("EVENT_OPEN_MAIN")
    Event.EVENT_CLOSE_TOP = Event.register("EVENT_CLOSE_TOP")
    Event.EVENT_OPEN_TOP = Event.register("EVENT_OPEN_TOP")
    Event.EVENT_CLOSE_SCREENSHOT = Event.register("Event.EVENT_CLOSE_SCREENSHOT")
    Event.EVENT_OPEN_SCREENSHOT = Event.register("EVENT_OPEN_SCREENSHOT")
    Event.EVENT_QUALITY_CLICK = Event.register("EVENT_QUALITY_CLICK")
    Event.EVENT_SHADOWS_CLICK = Event.register("EVENT_SHADOWS_CLICK")
    Event.EVENT_CLOSE_AMBIENT_LIGHT = Event.register("EVENT_CLOSE_AMBIENT_LIGHT")
    Event.EVENT_OPEN_AMBIENT_LIGHT = Event.register("EVENT_OPEN_AMBIENT_LIGHT")

    Event.EVENT_RESET_SELECT_VIEW = Event.register("EVENT_RESET_SELECT_VIEW")

    Event.EVENT_UPDATE_GIZMO_SCENE_UI = Event.register("EVENT_UPDATE_GIZMO_SCENE_UI")
    Event.EVENT_UPDATE_GIZMO_SCENE_UI_DATA = Event.register("EVENT_UPDATE_GIZMO_SCENE_UI_DATA")
end