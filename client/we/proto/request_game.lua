local Cjson = require "cjson"
local Core = require "editor.core"

return {
	request_modify_flag = function(modified, module, item)
		Core.notify(Cjson.encode(
			{
				type = "MODIFY_FLAG",
				params = {
					modified = modified,
					module = module,
					item = item
				}
			}
		))
	end,
	request_open_game = function(game_name)
		Core.notify(Cjson.encode({
			type = "OPEN_GAME",
			params = {
				game_name = game_name
			}
		}))
	end,
	
	request_can_undo_redo = function(can_undo, can_redo)
		Core.notify(Cjson.encode({
			type = "CAN_UNDO_REDO",
			params = {
				can_undo = can_undo,
				can_redo = can_redo
			}
		}))
	end,

    request_function_param_change = function(path, param_type, oval, func_name)
		Core.notify(Cjson.encode({
			type = "FUNCTION_PARAM_CHANGE",
			params = {
				path = path,
                param_type = param_type,
                oval = oval,
                func_name = func_name
			}
		}))
	end,

	request_function_param_name_change = function(path, param_name, oval)
        Core.notify(Cjson.encode({
			type = "FUNCTION_PARAM_NAME_CHANGE",
			params = {
				path = path,
                param_name = param_name,
                oval = oval
			}
		}))
	end,

    request_custom_trigger_param_change = function(path, param_type, oval, register_id)
		Core.notify(Cjson.encode({
			type = "CUSTOM_TRIGGER_PARAM_CHANGE",
			params = {
				path = path,
                param_type = param_type,
                oval = oval,
                register_id = register_id
			}
		}))
	end,

    request_custom_trigger_param_name_change = function(path, param_name, oval)
        Core.notify(Cjson.encode({
			type = "CUSTOM_TRIGGER_PARAM_NAME_CHANGE",
			params = {
				path = path,
                param_name = param_name,
                oval = oval
			}
		}))
	end,

	request_change_gizmo_action = function(currentType,supported)
		Core.notify(Cjson.encode({
			type = "CHANGE_GIZMO_ACTION",
			params = {
				currentType = currentType,
				supported = supported
			}
		}))
	end,

	request_original_data_preprocess = function()
		Core.notify(Cjson.encode({
			type = "ORIGINAL_DATA_PREPROCESS",
			params = {
			}
		}))
	end,

	request_save_original_data = function(isAdd, srcPath, destPath)
		Core.notify(Cjson.encode({
			type = "SAVE_ORIGINAL_DATA",
			params = {
				isAdd = isAdd,
				srcPath = srcPath,
				destPath = destPath,
			}
		}))
	end,

	request_save_original_map_data = function()
		Core.notify(Cjson.encode({
			type = "SAVE_ORIGINAL_MAP_DATA",
		}))
	end,

	request_enable_ai_dialog = function()
		local ret = Core.notify(Cjson.encode({
			type = "POP_ENABLE_AI_DIALOG",
		}))

		ret = Cjson.decode(ret)
		return ret.ok
	end,
	
	request_copy_blue_function_script = function(fileName)
		local ret = Core.notify(Cjson.encode({
			type = "COPY_BLUE_FUNCTION_SCRIPT",
			params ={
				fileName = fileName
			}
		}))

		ret = Cjson.decode(ret)
		return ret
	end,

	request_effect_refresh =  function(path)
        Core.notify(Cjson.encode({
			type = "FUNCTION_EFFECT_REFRESH",
			params = {
				path = path
			}
		}))
	end,

	request_packaging_image = function(paths, max_width, max_height, out_path, atlas_name, fill_length)
		local path = Lib.combinePath(out_path,atlas_name)
		local ret = Core.notify(Cjson.encode({
			type = "PICKGING_IMAGE",
			params = {
				paths = paths,
				max_width = max_width,
				max_height = max_height,
				out_path = path,
				fill_length = fill_length,
			}
		}))
		ret = Cjson.decode(ret)
		return ret.ret
	end,

	request_effect_refresh =  function(path)
		Core.notify(Cjson.encode({
			type = "FUNCTION_EFFECT_REFRESH",
			params = {
				path = path
			}
		}))
	end, 

	request_set_copy_list = function(list)
		local paramsjson = Cjson.encode({
			type = "SET_COPY_LIST",
			params = {
				copy_list = list
			}
		})
		return Core.notify(paramsjson)	
	end
}