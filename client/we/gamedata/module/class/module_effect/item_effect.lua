local Def = require "we.def"
local VN = require "we.gamedata.vnode"
local ItemBase = require "we.gamedata.module.class.item_base"

local cjson = require "cjson"


local M = Lib.derive(ItemBase)


function M:preprocess()
	assert(false)
end


function M:load(item_value)
	assert(not self._tree)
	for _, entry in ipairs(self.config) do
		local import = assert(entry.import)
		self:init(self:id(), self._module, import(item_value))
	end
end

function M:save()
	self:set_modified(false)
end

local function load_preset(_preset)
	-- 解析vector3
	local function parse_vector3(vector3)
		if vector3 then
			local v = Lib.splitString(vector3, " ", true)
			return {x = v[1], y = v[2], z = v[3]}
		end
		return {x = 0, y = 0, z = 0}
	end

	-- 解析color
	local function parse_color(color)
		if color then
			local c = Lib.splitString(color, " ", true)
			return {r = c[1] * 255, g = c[2] * 255, b = c[3] * 255, a = c[4] * 255}
		end
		return {r = 0, g = 0, b = 0, a = 1}
	end

	-- 公共属性
	local preset = {
		id = _preset.id,
		name = _preset.name,
		visible = _preset.visible,
		transform = {
			pos = parse_vector3(_preset.position),
			rotate = parse_vector3(_preset.rotation)
		},
		loop = {
			enable = _preset.loop,
			play_times = _preset.loop_times,
			interval = _preset.interval,
			reset = _preset.reset,
			length = _preset.length
		}
	}

	local type = _preset.type
	-- 爆炸
	if type == "explosion" then
		preset[Def.OBJ_TYPE_MEMBER] = "EffectPresetExplosion"
		preset.inner_color = {
			parse_color(_preset.inner_color[1]),
			parse_color(_preset.inner_color[2]),
			parse_color(_preset.inner_color[3])
		}
		preset.outer_color = {
			parse_color(_preset.outer_color[1]),
			parse_color(_preset.outer_color[2]),
			parse_color(_preset.outer_color[3])
		}
		preset.intensity = _preset.intensity
		preset.range = _preset.range
	-- 火焰
	elseif type == "fire" then
		preset[Def.OBJ_TYPE_MEMBER] = "EffectPresetFire"
		preset.inner_color = {
			parse_color(_preset.inner_color[1]),
			parse_color(_preset.inner_color[2]),
			parse_color(_preset.inner_color[3]),
			parse_color(_preset.inner_color[4])
		}
		preset.outer_color = {
			parse_color(_preset.outer_color[1]),
			parse_color(_preset.outer_color[2]),
			parse_color(_preset.outer_color[3]),
			parse_color(_preset.outer_color[4])
		}
		preset.intensity = _preset.intensity
		preset.range = _preset.range
	-- 烟雾
	elseif type == "smoke" then
		preset[Def.OBJ_TYPE_MEMBER] = "EffectPresetSmoke"
		preset.color = parse_color(_preset.color)
		preset.speed = _preset.speed
		preset.range = _preset.range
		preset.alpha = preset.color.a / 255
		preset.color.a = 1
	-- 火花
	elseif type == "sparks" then
		preset[Def.OBJ_TYPE_MEMBER] = "EffectPresetSparks"
		preset.color = parse_color(_preset.color)
		preset.size = _preset.size
		preset.intensity = _preset.intensity
	-- 天气
	elseif type == "weather" then
		preset[Def.OBJ_TYPE_MEMBER] = "EffectPresetWeather"
		local weather = _preset.weather
		if weather == 1 then
			preset.weather_type = "Snow"
		elseif weather == 2 then
			preset.weather_type = "Rain"
		end
		preset.snow = _preset.snow
		preset.rain = _preset.rain
	-- 粒子系统
	elseif type == "particle" then
		preset[Def.OBJ_TYPE_MEMBER] = "EffectPresetParticle"
		preset.emitter_type = _preset.emitter_type
		local _emitter = _preset.emitter
		preset.emitter = {
			area = parse_vector3(_emitter.area),
			surface_only = _emitter.surface_only,
			unlimited = _emitter.unlimited,
			quota = _emitter.quota,
			rate = _emitter.rate,
			angle = _emitter.angle,
			visible = _emitter.visible,
		}
		local _material = _preset.material
		preset.material = {
			res_file = {
				selector = _material.res_file.selector,
				asset = _material.res_file.asset
			},
			blend_mode = _material.blend_mode,
			alpha = _material.alpha,
			bloom = _material.bloom
		}
		preset.width = _preset.width
		preset.height = _preset.height
		preset.scale = _preset.scale
		preset.color_mode = _preset.color_mode
		preset.color_1 = parse_color(_preset.color_1)
		preset.color_2 = parse_color(_preset.color_2)
		preset.speed = _preset.speed
		preset.acceleration = _preset.acceleration
		preset.angle = _preset.angle
		preset.life = _preset.life
		preset.uv_flip_mode = _preset.uv_flip_mode
		preset.uv_swap = _preset.uv_swap
		preset.u_speed = _preset.u_speed
		preset.v_speed = _preset.v_speed
		preset.b3d_particle = _preset.b3d_particle
		preset.b3d_trans = _preset.b3d_trans
		local _noise = _preset.noise
		preset.noise = {
			enable = _noise.enable,
			res_file = _noise.res_file,
			threshold = _noise.threshold,
			u_offset = _noise.u_offset,
			v_offset = _noise.v_offset,
			u_scale = _noise.u_scale,
			v_scale = _noise.v_scale,
			time_factor = _noise.time_factor,
			texture_only = _noise.texture_only
		}
	-- 非预设
	elseif type == "normal" then
		preset[Def.OBJ_TYPE_MEMBER] = "EffectPresetNormal"
	end

	return preset
end


function M:add_preset(preset_value, pos)
	local presets = self:obj().presets
	local _preset = cjson.decode(preset_value)
	VN.insert(presets, pos, load_preset(_preset))
end


function M:remove_preset(pos)
	local presets = self:obj().presets
	VN.remove(presets, pos, nil)
end


function M:discard()
	--
end


M.config = {
	{
		key = "setting.json",

		reader = function(path)
			return {}
		end,

		import = function(content)
			-- 解析特效
			local effect = {presets = {}}
			for _, _preset in pairs(content.presets) do
				table.insert(effect.presets, load_preset(_preset))
			end
			return effect
		end,

		export = function(item, content)
			local data = {}
			return data
		end,

		writer = function(path, data)
			--
		end,

		discard = function(item_name)
			--
		end
	},

	discard = function(item_name)
		--
	end
}


return M
