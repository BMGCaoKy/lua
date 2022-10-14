local Module = require "we.gamedata.module.module"
local Lang = require "we.gamedata.lang"

return {
	TAG_LIST = function(item)
		local m = Module:module("tag")
		assert(m, "tag")

		local i = m:item(item)
		assert(i, item)

		local tags = i:val()["tags"]

		return {ok = true,data = tags}
    end,

	TAG_NEW = function(item,key,text)
		Lang:set_text(key,text)
		local m = Module:module("tag")
		assert(m, "tag")

		local i = m:item(item)
		assert(i,item)

		i:data():insert("tags",nil,nil,key)

		return{ok = true}	
	end,

	TAG_DEL = function(item,index)
		local m = Module:module("tag")
		assert(m, "tag")

		local i = m:item(item)
		assert(i,item)
		print("index",index)
		i:data():remove("tags", index)
		return{ok = true}
	end
}