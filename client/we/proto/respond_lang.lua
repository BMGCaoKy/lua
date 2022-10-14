local Lang = require "we.gamedata.lang"

return {
	TEXT = function(key, sys)
		return {ok = true, data = Lang:text(key, sys)}
	end,

	SET_TEXT = function(key, text)
		Lang:set_text(key, text)
		return {ok = true}
	end,
	
	LOCALE_CODES = function ()
		return {ok = true, data = Lang:locale_codes()}
	end,

	RELOAD_USER_TEXT = function ()
		Lang:reload()
		return {ok = true}
	end,

	REMOVE_TEXT = function(key)
		Lang:remove_key(key)
		return {ok = true}
	end
}
