print("Start Effect Editor Script!", World.GameName)

local Def = require "we.def"
local Signal = require "we.signal"
local Module = require "we.gamedata.module.module"
local VN = require "we.gamedata.vnode"

local M = {}

local effect_id = nil
local preset = nil
local preset_index = nil
local effect_control = nil
local structure_dock = nil

local cancel_subscribe = nil
local particle_index = {}


local function check_params(event, ips)
	if event ~= Def.NODE_EVENT.ON_ASSIGN or not preset or ips ~= preset_index then
		return false
	end
	return true
end


function M:base_router(_preset, event, key, ips, oval)
	if not check_params(event, ips) then
		return
	end
	-- 范围
	if key == "range" then
		preset:SetRange(_preset.range)
	-- 大小
	elseif key == "size" then
		preset:SetSize(_preset.size)
	-- 强度
	elseif key == "intensity" then
		preset:SetIntensity(_preset.intensity)
	-- 速度
	elseif key == "speed" then
		preset:SetSpeed(_preset.speed)
	-- 不透明度
	elseif key == "alpha" then
		preset:SetAlpha(_preset.alpha)
	-- 是否可见
	elseif key == "visible" then
		local visible = _preset.visible
		preset:SetVisible(visible)
		structure_dock:SetPresetVisible(ips-1, visible)
	else
		print("No handler for key:", key)
	end
end


function M:particle_base_router(_preset, event, key, ips, oval)
	if not check_params(event, ips) then
		return
	end
	if key == "emitter_type" then
		preset:SwitchEmitter(_preset.emitter_type)
		if oval == "Point" then
			preset:SetEmissionArea(Vector3.fromTable(_preset.emitter.area))
		end
	-- 粒子宽度
	elseif key == "width" then
		preset:SetParticleWidth(_preset.width)
	-- 粒子高度
	elseif key == "height" then
		preset:SetParticleHeight(_preset.height)
	-- 粒子加速度
	elseif key == "acceleration" then
		preset:SetAcceleration(_preset.acceleration)
	-- UV翻转
	elseif key == "uv_flip_mode" then
		preset:SetUVFlipMode(_preset.uv_flip_mode)
	-- UV互换
	elseif key == "uv_swap" then
		preset:SetUVSwap(_preset.uv_swap)
	-- U动画速度
	elseif key == "u_speed" then
		preset:SetUSpeed(_preset.u_speed)
	-- V动画速度
	elseif key == "v_speed" then
		preset:SetVSpeed(_preset.v_speed)
	-- 3D粒子
	elseif key == "b3d_particle" then
		preset:SetIs3dParticle(_preset.b3d_particle)
	-- 视角偏移
	elseif key == "b3d_trans" then
		preset:SetIs3dTransform(_preset.b3d_trans)
	else
		print("No handler for key:", key)
	end
end


function M:init()
	-- TODO: router分成base和extend，extend按不同预设动态调整
	self._router = {
		-- 预设增删
		["^presets$"] = function(event, index, oval)
			if event == Def.NODE_EVENT.ON_INSERT then
				effect_control:LuaPresetInsert(self._root.presets[index].id, index)
			elseif event == Def.NODE_EVENT.ON_REMOVE then
				effect_control:LuaPresetRemove(oval.id, index)
			end
		end,

		-- 基础字段
		["^presets/(%d+)$"] = function(event, key, ips, oval)
			if not check_params(event, ips) then
				return
			end
			-- 名字
			if key == "name" then
				local name = self._preset.name
				preset:SetName(name)
				structure_dock:SetPresetName(ips-1, name)
			-- 是否可见
			elseif key == "visible" then
				local visible = self._preset.visible
				preset:SetVisible(visible)
				structure_dock:SetPresetVisible(ips-1, visible)
			-- 天气类型
			elseif key == "weather_type" then
				local weather_type = self._preset.weather_type
				local transform = self._preset.transform
				local loop = self._preset.loop
				local loop_times = loop.play_times
				if loop.enable then
					loop_times = -1
				end
				local _preset_old = nil
				local _preset_new = nil
				if weather_type == "Snow" then
					_preset_old = self._preset.rain
					_preset_new = self._preset.snow
					preset:SwitchToSnow()
				elseif weather_type == "Rain" then
					_preset_old = self._preset.snow
					_preset_new = self._preset.rain
					preset:SwitchToRain()
				end
				if _preset_old and _preset_new then
					_preset_new.range = _preset_old.range
					preset:SetRange(_preset_new.range)
					_preset_new.size = _preset_old.size
					preset:SetSize(_preset_new.size)
					local max_intensity = math.tointeger(VN.attr(_preset_new, "intensity", "Max"))
					_preset_new.intensity = _preset_old.intensity
					if _preset_new.intensity > max_intensity then
						_preset_new.intensity = max_intensity
					end
					preset:SetIntensity(_preset_new.intensity)
					_preset_new.speed = _preset_old.speed
					preset:SetSpeed(_preset_new.speed)
					_preset_new.visible = _preset_old.visible
					preset:SetVisible(_preset_new.visible)
					structure_dock:SetPresetVisible(ips-1, _preset_new.visible)
				end
				preset:SetPosition(Vector3.fromTable(transform.pos))
				preset:SetRotation(Vector3.fromTable(transform.rotate))
				preset:SetLoopInterval(loop.interval)
				preset:SetLoopReset(loop.reset)
				preset:SetLoop(loop_times)
			-- 粒子系统字段
			elseif particle_index[ips] then
				self:particle_base_router(self._preset, event, key, ips, oval)
			-- 公共字段
			else
				self:base_router(self._preset, event, key, ips, oval)
			end
		end,

		-- 位置
		["^presets/(%d+)/transform/pos$"] = function(event, key, ips, oval)
			if not check_params(event, ips) then
				return
			end
			local pos = self._preset.transform.pos
			preset:SetPosition(Vector3.fromTable(pos))
		end,

		-- 旋转
		["^presets/(%d+)/transform/rotate$"] = function(event, key, ips, oval)
			if not check_params(event, ips) then
				return
			end
			local rotate = self._preset.transform.rotate
			preset:SetRotation(Vector3.fromTable(rotate))
		end,

		-- 循环播放
		["^presets/(%d+)/loop$"] = function(event, key, ips, oval)
			if not check_params(event, ips) then
				return
			end
			local loop = self._preset.loop
			if key == "interval" then
				local interval = self._preset.loop.interval
				preset:SetLoopInterval(interval)
			elseif key == "reset" then
				local reset = self._preset.loop.reset
				preset:SetLoopReset(reset)
			else
				local enable = loop.enable
				local loop_times = loop.play_times
				if enable then
					loop_times = -1
				end
				preset:SetLoop(loop_times)
			end
		end,

		-- 颜色
		["^presets/(%d+)/color$"] = function(event, key, ips, oval)
			if not check_params(event, ips) then
				return
			end
			local color = Lib.toPercentageColor(self._preset.color)
			preset:SetColor(color.r, color.g, color.b)
		end,

		-- 内焰
		["^presets/(%d+)/inner_color/(%d+)$"] = function(event, key, ips, icl, oval)
			if not check_params(event, ips) then
				return
			end
			local color = Lib.toPercentageColor(self._preset.inner_color[icl])
			preset:SetInnerColor(icl, color.r, color.g, color.b)
		end,

		-- 外焰
		["^presets/(%d+)/outer_color/(%d+)$"] = function(event, key, ips, icl, oval)
			if not check_params(event, ips) then
				return
			end
			local color = Lib.toPercentageColor(self._preset.outer_color[icl])
			preset:SetOuterColor(icl, color.r, color.g, color.b)
		end,

		-- 天气（雪）
		["^presets/(%d+)/snow$"] = function(event, key, ips, oval)
			self:base_router(self._preset.snow, event, key, ips, oval)
		end,

		-- 天气（雨）
		["^presets/(%d+)/rain$"] = function(event, key, ips, oval)
			self:base_router(self._preset.rain, event, key, ips, oval)
		end,

		-- 粒子系统 - 发射器
		["^presets/(%d+)/emitter/?(%g*)"] = function(event, key, ips, subpath, oval)
			if not check_params(event, ips) then
				return
			end
			local emitter = self._preset.emitter
			if subpath == "area" then
				preset:SetEmissionArea(Vector3.fromTable(emitter.area))
			elseif key == "surface_only" then
				preset:SetEmissionSurfaceOnly(emitter.surface_only)
			elseif key == "unlimited" then
				local quota = emitter.quota
				if emitter.unlimited then
					quota = -1
				end
				preset:SetEmissionQuota(quota)
			elseif key == "quota" then
				preset:SetEmissionQuota(emitter.quota)
			elseif key == "rate" then
				preset:SetEmissionRate(emitter.rate)
			elseif key == "angle" then
				preset:SetEmissionAngle(emitter.angle)
			elseif key == "visible" then
				local visible = emitter.visible
				preset:SetVisible(visible)
				structure_dock:SetPresetVisible(ips-1, visible)
			end
		end,

		-- 粒子系统 - 材质
		["^presets/(%d+)/material/?(%g*)"] = function(event, key, ips, subpath, oval)
			if not check_params(event, ips) then
				return
			end
			local material = self._preset.material
			if subpath == "res_file" then
				if key == "asset" then
					local asset = material.res_file.asset
					if asset == oval then
						return
					end
					preset:SetMaterialTexture(asset)
				end
			elseif key == "blend_mode" then
				preset:SetMaterialBlendMode(material.blend_mode)
			elseif key == "alpha" then
				preset:SetMaterialAlpha(material.alpha)
			elseif key == "bloom" then
				preset:SetMaterialBloom(material.bloom)
			end
		end,

		-- 粒子系统 - 粒子比例
		["^presets/(%d+)/scale$"] = function(event, key, ips, oval)
			if not check_params(event, ips) then
				return
			end
			local scale = self._preset.scale
			if key == "min" then
				preset:SetParticleScaleMin(scale.min)
			elseif key == "max" then
				preset:SetParticleScaleMax(scale.max)
			end
		end,

		-- 粒子系统 - 颜色1
		["^presets/(%d+)/color_1$"] = function(event, key, ips, oval)
			if not check_params(event, ips) then
				return
			end
			local color = Lib.toPercentageColor(self._preset.color_1)
			preset:SetColorMin(color.r, color.g, color.b)
		end,

		-- 粒子系统 - 颜色2
		["^presets/(%d+)/color_2$"] = function(event, key, ips, oval)
			if not check_params(event, ips) then
				return
			end
			local color = Lib.toPercentageColor(self._preset.color_2)
			preset:SetColorMax(color.r, color.g, color.b)
		end,

		-- 粒子系统 - 速度
		["^presets/(%d+)/speed$"] = function(event, key, ips, oval)
			if not check_params(event, ips) then
				return
			end
			local speed = self._preset.speed
			if key == "min" then
				preset:SetSpeedMin(speed.min)
			elseif key == "max" then
				preset:SetSpeedMax(speed.max)
			end
		end,

		-- 粒子系统 - 角度
		["^presets/(%d+)/angle$"] = function(event, key, ips, oval)
			if not check_params(event, ips) then
				return
			end
			local angle = self._preset.angle
			if key == "min" then
				preset:SetAngleMin(angle.min)
			elseif key == "max" then
				preset:SetAngleMax(angle.max)
			end
		end,

		-- 粒子系统 - 生命
		["^presets/(%d+)/life$"] = function(event, key, ips, oval)
			if not check_params(event, ips) then
				return
			end
			local life = self._preset.life
			if key == "min" then
				preset:SetLifeMin(life.min)
			elseif key == "max" then
				preset:SetLifeMax(life.max)
			end
		end,

		-- 粒子系统 - 扰动
		["^presets/(%d+)/noise/?(%g*)"] = function(event, key, ips, subpath, oval)
			if not check_params(event, ips) then
				return
			end
			local noise = self._preset.noise
			if subpath == "res_file" then
				if key == "asset" then
					local asset = noise.res_file.asset
					if asset == oval then
						return
					end
					if asset == "" then
						noise.enable = false
					end
					preset:SetNoiseTexture(asset)
				end
			elseif key == "enable" then
				preset:SetNoiseEnabled(noise.enable)
			elseif key == "threshold" then
				preset:SetNoiseAlphaThreshold(noise.threshold)
			elseif key == "u_offset" then
				preset:SetNoiseTextureUOffset(noise.u_offset)
			elseif key == "v_offset" then
				preset:SetNoiseTextureVOffset(noise.v_offset)
			elseif key == "u_scale" then
				preset:SetNoiseTextureUScale(noise.u_scale)
			elseif key == "v_scale" then
				preset:SetNoiseTextureVScale(noise.v_scale)
			elseif key == "time_factor" then
				preset:SetNoiseTimeFactor(noise.time_factor)
			elseif key == "texture_only" then
				preset:SetNoiseOnly(noise.texture_only)
			end
		end,
	}
end


function M:deinit()
	if cancel_subscribe then
		cancel_subscribe()
		cancel_subscribe = nil
	end
	self._router = nil
	self._root = nil
	self._preset = nil
	effect_id = nil
end


function M:set_preset_item(item_id)
	effect_id = item_id
	local preset_helper = EffectPresetHelper:Instance()
	effect_control = preset_helper:GetEffectControl()
	structure_dock = preset_helper:GetEffectStructureDock()

	if cancel_subscribe then
		cancel_subscribe()
	end

	self._root = Module:module("effect"):item(item_id):obj()
	assert(self._root, item_id)

	cancel_subscribe = Signal:subscribe(self._root, Def.NODE_EVENT.ON_MODIFY, function(path, event, index, ...)
		path = table.concat(path, "/")
		local captures = nil
		for pattern, processor in pairs(self._router) do
			captures = table.pack(string.find(path, pattern))
			if #captures > 0 then
				local args = {}
				for i = 3, #captures do
					table.insert(args, math.tointeger(captures[i]) or captures[i])
				end
				for _, arg in ipairs({...}) do
					table.insert(args, arg)
				end
				print(string.format("Process: [%s] %s(%s, %s)", path, pattern, event, index),
						table.unpack(args))
				processor(event, index, table.unpack(args))
				break
			end
		end
		if #captures <= 0 then
			print("No router for path:", path, index)
		end
	end)
end


function M:set_preset(item_id, index)
	if item_id ~= effect_id then
		return
	end
	-- 获取当前EffectPreset
	particle_index[index] = nil
	local preset_helper = EffectPresetHelper:Instance()
	preset = preset_helper:GetActivePreset()
	if not preset then
		return
	end

	local type = preset:GetTypeName()
	if type == "explosion" then
		preset = preset_helper:GetExplosionPreset()
	elseif type == "fire" then
		preset = preset_helper:GetFirePreset()
	elseif type == "smoke" then
		preset = preset_helper:GetSmokePreset()
	elseif type == "sparks" then
		preset = preset_helper:GetSparksPreset()
	elseif type == "weather" then
		preset = preset_helper:GetWeatherPreset()
	elseif type == "particle" then
		preset = preset_helper:GetParticlePreset()
		particle_index[index] = preset
	end

	-- 获取preset
	preset_index = index
	self._preset = self._root.presets[index]
	assert(self._preset, "presets[" .. index .. "]")
end


function M:unset_preset(item_id)
	if item_id and item_id ~= effect_id then
		return
	end
	if item_id then
		if cancel_subscribe then
			cancel_subscribe()
			cancel_subscribe = nil
		end
		effect_id = nil
	end
	preset = nil
	preset_index = nil
	self._preset = nil
end


Lib.subscribeEvent(Event.EVENT_EDITOR_DATA_MODIFIED, function(module, item_id)
	if module ~= "effect" or item_id ~= effect_id then
		return
	end
	effect_control:onEffectModified()
end)


Lib.subscribeEvent(Event.EVENT_EDITOR_ITEM_SAVE, function(module, item_id)
	if module ~= "effect" then
		return
	end
	effect_control:SaveEffect()
end)


return M
