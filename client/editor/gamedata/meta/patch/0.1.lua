-- 是转类型还是修改原类型
-- 如果是转类型，则原类型不变，所有用到原类型的地方都替换成新类型，
-- 这是运行过程中的一个操作，并没有存状态，如果之后还有用到原类型(比如转换
-- 某个类型，此类型又包括原类型)，则会存在替换不干净
-- 如果是修改类型，则所有用到此类型的地方都得持续关注这个类型得变化，以便传入合适的值
-- 综上，修改类型似乎更合适
local meta = {
	{
		type = "BlockCfg",
		value = function(oval)
			local ret = Lib.copy(oval)

			ret.name = "hello, hello"
			ret.pos = ctor("Vector4", oval.pos)

			return ret
		end
	},
}

for _, patch in ipairs(meta) do
	patch.value = string.dump(patch.value)
end

return {
	meta = meta
}
