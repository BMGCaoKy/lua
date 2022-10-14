local Cjson = require "cjson"
local Def = require "we.def"
local Seri = require "we.gamedata.seri"
local ItemDataUtils = require "we.gamedata.item_data_utils"
local Converter = require "we.gamedata.export.data_converter"
local ItemBase = require "we.gamedata.module.class.item_base"
local Meta = require "we.gamedata.meta.meta"
local PropImport = require "we.gamedata.module.prop_import"
local Map = require "we.map"
local TreeSet = require "we.gamedata.vtree"

local M = Lib.derive(ItemBase)

local MODULE_NAME = "actor_editor"
local ITEM_TYPE = "ActorEditorCfg"

local PATH_DATA_DIR = Lib.combinePath(Def.PATH_GAME, MODULE_NAME)

function M:update_props_cache()
	self._props = {
		name = tostring(self._id),
		dir_game = self:game_dir()
	}
end

function M:load(path)
    assert(not self._tree)
    path = path or "./Media/Actor/empty.actor"
    self.path_ = path

    for _, entry in ipairs(self.config) do
        local reader = assert(entry.reader)
        local import = assert(entry.import)
        local content = reader(path)
		local file_name = Lib.toFileName(path)
        local item_value = import(content, file_name)
        self:init(self:id(), self._module, item_value)
    end
end

function M:save()
    self:save_as(self.path_)
end

function M:save_as(path)
    assert(self.path_)
    self:set_modified(false)
    for _, entry in ipairs(self.config) do
        local reader = assert(entry.reader)
        local writer = assert(entry.writer)
        local export = assert(entry.export)
        local content = reader(self.path_)
        local val = export(self:val(), content)
        writer(path, val)
    end
end

function M:lock_actor_file()
    if self.path_ then
        print("lock_actor_file : ", self.path_)
       -- self.file_ = io.open(self.path_ , "a")
    end
end

function M:unlock_actor_file()
    if self.file_ then
        print("unlock_actor_file : ", self.path_)
        self.file_:close()
        self.file_ = nil
    end
end

function M:preprocess()
    assert(false)
end

M.config = {
    {
        key = "setting.json",
        reader = function(path)
            local xml2lua = require("common.xml2lua.xml2lua")
            local handler = require("common.xml2lua.xmlhandler.tree")
            local ActorHandler = handler:new()
            local ActorParser = xml2lua.parser(ActorHandler)
            ActorParser:parse(xml2lua.loadFile(path))
            return  ActorHandler.root.ActorTemplates.ActorTemplate
        end,
        import = function(content, file_name)
            local function tobool(bool)
                if type(bool) == "nil" then
                    return nil
                end
                if bool == "true" then
                    return true
                elseif bool == "false" then
                    return false
                end
                assert(false, bool)
            end

            local function color_to_rgba(color)
                if color then
                    local t = Lib.splitIncludeEmptyString(color, " ")
                    return {
                        r = tonumber(t[1]) * 255,
                        g = tonumber(t[2]) * 255,
                        b = tonumber(t[3]) * 255,
                        a = tonumber(t[4]) * 255
                    }
                end
            end

            local function get_name(file_name) --aaa.skin  return aaa
                local tb = Lib.splitIncludeEmptyString(Lib.toFileName(file_name), ".")
                return tb[1]
            end

			local function get_full_path(file_name)
				if file_name == "" then
					return ""
				end
				local path = FileResourceManager.Instance():GetResourceLocalFullPath(file_name)
				path = Lib.normalizePath(path)
				path = string.gsub(path, Root.Instance():getGamePath(), "")
				return path
			end

            local ret = {}
            ret.res_skeleton = content._attr.Skeleton
            ret.sub_actors = content.SubActors
			if content._attr.Originalscale then
				local t = Lib.splitIncludeEmptyString(content._attr.Originalscale, " ")
				ret.scale = {
					x = tonumber(t[1]),
					y = tonumber(t[2]),
					z = tonumber(t[3])
				}
			end
			ret.name = get_name(file_name)
            local alpha = 1
            if type(content._attr.Alpha)=="string" then
                 alpha = tonumber(content._attr.Alpha)
            end
            if alpha then
                ret.alpha = {value = alpha}
            end 
             --骨架文件
            ret.actor_face = {} --外观
            ret.actor_face.body_parts = {} --部件
            --大写开头是引擎数据，小写开头是编辑器数据
            local BodyParts = content.BodyParts.BodyPart
            if BodyParts then --外观配置
                if #BodyParts == 0 then
                    BodyParts = {BodyParts}
                end
                for _, BodyPart in ipairs(BodyParts) do
                    local body_part = {
                        id = 0,
                        master_name = BodyPart._attr.MasterName,
                        slave_name = BodyPart._attr.SlaveName,
                        default_use_enable = tobool(BodyPart._attr.DefaultUse)
                    }

                    --Skin
                    local Skins = BodyPart.Skin
                    if Skins then
                        body_part.skin = {}
                        if #Skins == 0 then
                            Skins = {Skins}
                        end
                        for _, Skin in ipairs(Skins) do
                            local Attr = Skin._attr
                            local material = {
                                alpha = {value = tonumber(Attr.LocalAlpha)},
                                discard_alpha = {value = tonumber(Attr.DiscardAlpha)},
                                brightness = {value = tonumber(Attr.LocalBrightnessScale)},
                                --use_transparent_nearest_slice = tobool(Attr.UseTransparentNearestSlice),
                                glow_enable = tobool(Attr.UseBloom),
                                linght_enable = tobool(Attr.UseOriginalcolor),
                                hight_light = {
                                    light_color = color_to_rgba(Attr.SpecularColor),
                                    light_ratio = {value = tonumber(Attr.SpecularCoef)},
                                    brightness = {value = tonumber(Attr.SpecularStrength)}
                                },
								reflex_light = {
									enable = Attr.UseReflect and tobool(Attr.UseReflect),
									reflect_scale = Attr.ReflectScale and { value = tonumber(Attr.ReflectScale) },
									reflect_texture = Attr.ReflectTexture and { asset = get_full_path(Attr.ReflectTexture) },
									reflect_mask_texture = Attr.ReflectMaskTexture and { asset = get_full_path(Attr.ReflectMaskTexture) }
								},
                                edge_light = {
                                    enable = tobool(Attr.UseEdge),
                                    light_color = color_to_rgba(Attr.EdgeColor)
                                },
                                overlayColor = color_to_rgba(Attr.OverlayColor)
                            }
                            if Attr.UseOverlayColorReplaceMode == "true" then
                                material.overlayMode = "replace"
                            else
                                material.overlayMode = Attr.OverlayColor == "1 1 1 1" and "no" or "overlay"
                            end
                            if Attr.UseTransparentNearestSlice then
                                material["use_transparent_nearest_slice"] = tobool(Attr.UseTransparentNearestSlice)
                            end
                            local skin = {
                                id = 0,
                                name = Skin._attr.type_name or get_name(Skin._attr.MeshName),
                                res_file = {asset = Skin._attr.MeshName},
                                material = material
                            }
                            table.insert(body_part.skin, skin)
                        end
                    end

                    --mesh
                    local StaticMeshs = BodyPart.StaticMesh
                    if StaticMeshs then
                        body_part.mesh = {}
                        if #StaticMeshs == 0 then
                            StaticMeshs = {StaticMeshs}
                        end
                        for _, StaticMesh in ipairs(StaticMeshs) do
                            local material = {
                                alpha = (StaticMesh._attr or {}).LocalAlpha and
                                    {value = tonumber(StaticMesh._attr.LocalAlpha)},
                                discard_alpha = (StaticMesh._attr or {}).DiscardAlpha and
                                    {value = tonumber(StaticMesh._attr.DiscardAlpha)},
                                brightness = ((StaticMesh.LocalBrightnessScale or {})._attr or {}).value and
                                    {value = tonumber(StaticMesh.LocalBrightnessScale._attr.value)},
                                glow_enable = ((StaticMesh.UseBloom or {})._attr or {}).value and
                                    tobool(StaticMesh.UseBloom._attr.value),
                                linght_enable = ((StaticMesh.UseOriginalcolor or {})._attr or {}).value and
                                    tobool(StaticMesh.UseOriginalcolor._attr.value),
                                hight_light = {
                                    light_color = StaticMesh.SpecularColor and
                                        color_to_rgba(StaticMesh.SpecularColor._attr.value),
                                    light_ratio = StaticMesh.SpecularCoef and
                                        {tonumber(StaticMesh.SpecularCoef._attr.value)},
                                    brightness = StaticMesh.SpecularStrength and
                                        {tonumber(StaticMesh.SpecularStrength._attr.value)}
                                },
								reflex_light = {
									enable = StaticMesh.UseReflect and tobool(StaticMesh.UseReflect._attr.value),
									reflect_scale = StaticMesh.ReflectScale and 
										{ value = tonumber(StaticMesh.ReflectScale._attr.value) },
									reflect_texture = StaticMesh.ReflectTexture and 
										{ asset = get_full_path(StaticMesh.ReflectTexture._attr.value) },
									reflect_mask_texture = StaticMesh.ReflectMaskTexture and 
										{ asset = get_full_path(StaticMesh.ReflectMaskTexture._attr.value) }
								},
                                edge_light = {
                                    enable = StaticMesh.UseEdge and tobool(StaticMesh.UseEdge._attr.value),
                                    light_color = StaticMesh.EdgeColor and
                                        color_to_rgba(StaticMesh.EdgeColor._attr.value)
                                }
                            }
                            local OverlayColor = ((StaticMesh.OverlayColor or {})._attr or {}).value
                            local Mode = ((StaticMesh.UseOverlayColorReplaceMode or {})._attr or {}).value
                            material.overlayColor = OverlayColor and color_to_rgba(OverlayColor)
                            if Mode == "true" then
                                material.overlayMode = "replace"
                            else
                                material.overlayMode = OverlayColor == "1 1 1 1" and "no" or "overlay"
                            end
                            local transform = {
                                pos = {
                                    x = tonumber(StaticMesh.Position_X._attr.value),
                                    y = tonumber(StaticMesh.Position_Y._attr.value),
                                    z = tonumber(StaticMesh.Position_Z._attr.value)
                                },
                                rotate = {
                                    x = tonumber(StaticMesh.pitch._attr.value),
                                    y = tonumber(StaticMesh.yaw._attr.value),
                                    z = tonumber(StaticMesh.roll._attr.value)
                                },
                                scale = tonumber(StaticMesh.scale._attr.value)
                            }
                            local mesh = {
                                id = 0,
                                name = (StaticMesh._attr or {}).type_name or get_name(StaticMesh.FileName._attr.value),
                                res_file = {asset = StaticMesh.FileName._attr.value},
                                bind_part = StaticMesh.SocketName and StaticMesh.SocketName._attr.value,
                                material = material,
                                transform = transform
                            }
                            table.insert(body_part.mesh, mesh)
                        end
                    end

                    --Effect
                    local Effects = BodyPart.Effect
                    if Effects then
                        body_part.effect = {}
                        if #Effects == 0 then
                            Effects = {Effects}
                        end
                        for _, Effect in ipairs(Effects) do
                            local transform = {
                                pos = {
                                    x = tonumber(Effect.Position_X._attr.value),
                                    y = tonumber(Effect.Position_Y._attr.value),
                                    z = tonumber(Effect.Position_Z._attr.value)
                                },
                                rotate = {
                                    x = tonumber(Effect.pitch._attr.value),
                                    y = tonumber(Effect.yaw._attr.value),
                                    z = tonumber(Effect.roll._attr.value)
                                },
                                scale = tonumber(Effect.scale._attr.value)
                            }

                            local effect = {
                                id = 0,
                                name = ((Effect.type_name or {})._attr or {}).value or
                                    get_name(Effect.FileName._attr.value),
                                res_file = {asset = Effect.FileName._attr.value},
                                bind_part = Effect.SocketName._attr.value,
                                transform = transform,
                                play_speed = tonumber(Effect.TimeScale._attr.value),
                                alpha = {tonumber(Effect.Alpha._attr.value)}
                            }
                            table.insert(body_part.effect, effect)
                        end
                    end

                    table.insert(ret.actor_face.body_parts, body_part)
                end
            end

            ret.actor_action = {} --动作配置

            --Skill
            local Skills = content.Skills.Skill --技能
            if Skills then
                ret.actor_action.skill = {}
                if #Skills == 0 then
                    Skills = {Skills}
                end
                for _, Skill in ipairs(Skills) do
                    local skill = {
                        name = Skill._attr.Name
                    }

                    local Animation = Skill.Animation --动画
                    
                    if Animation then
                        if #Animation >=2 then --TODO 2个以上的动画 只保留第一个
                            Animation = Animation[1]
                        end
                        local channel = "all" --作用通道 全身 上半身 下半身
                        if Animation._attr.Channel ~= "" then
                            channel = Animation._attr.Channel
                        end
                        skill.action_editor_animation = {
                            res_file = { asset = Animation._attr.Name},
                            length = tonumber(Animation._attr.Length),
                            start_time = tonumber(Animation._attr.BeginTime),
                            channel_mode = channel,
                            loop_play_set = {
                                play_times = tonumber(Animation._attr.Times),
                                enable = tonumber(Animation._attr.Times) == -1
                            },
                            play_speed = tonumber(Animation._attr.TimeScale),
                            transition_time = tonumber(Animation._attr.FadeTime)
                        }
                    end

                    local Effects = Skill.Effect
                    if Effects then
                        skill.action_editor_effect = {}
                        if #Effects == 0 then
                            Effects = {Effects}
                        end
                        for _, Effect in ipairs(Effects) do
                            local effect = {
                                name = ((Effect.type_name or {})._attr or {}).value or
                                    get_name(Effect.FileName._attr.value),
                                --res_file = Effect.FileName._attr.value,
				                res_file = {asset = Effect.FileName._attr.value},
                                bind_part = Effect.SocketName._attr.value,
                                follow_bind_part = tobool(Effect.FollowActor._attr.value),
                                alpha = {value = tonumber(Effect.Alpha._attr.value)},
                                loop_play_set = {
                                    play_times = tonumber(Effect.Times._attr.value),
                                    enable = tonumber(Effect.Times._attr.value) == -1
                                },
                                start_time = tonumber(Effect.BeginTime._attr.value),
                                play_speed = tonumber(Effect.TimeScale._attr.value),
                                custom_time_set = {
                                    play_times = tonumber(Effect.CycleTime._attr.value),
                                    enable = tonumber(Effect.CycleTime._attr.value) ~= -1
                                },
                                transform = {
                                    pos = {
                                        x = tonumber(Effect.Position_X._attr.value),
                                        y = tonumber(Effect.Position_Y._attr.value),
                                        z = tonumber(Effect.Position_Z._attr.value)
                                    },
                                    rotate = {
                                        x = tonumber(Effect.pitch._attr.value),
                                        y = tonumber(Effect.yaw._attr.value),
                                        z = tonumber(Effect.roll._attr.value)
                                    },
                                    scale = tonumber(Effect.scale._attr.value)
                                }
                            }
                            table.insert(skill.action_editor_effect, effect)
                        end
                    end

                    local ActorScaleChanges = Skill.ActorScaleChange
                    if ActorScaleChanges then
                        skill.actor_scale_changes = {}
                        if #ActorScaleChanges == 0 then
                            ActorScaleChanges = {ActorScaleChanges}
                        end
                        for _, ActorScaleChange in ipairs(ActorScaleChanges) do
                            local actor_scale_change = {
                                 end_scale=tonumber(ActorScaleChange._attr.endScale),
                                 begin_scale=tonumber(ActorScaleChange._attr.endScale),
                            }
                            table.insert(skill.actor_scale_changes, actor_scale_change)
                        end
                    end

                    table.insert(ret.actor_action.skill, skill)
                end
            end

            local Anims = content.Anims.Anim --动画资源列表
            if Anims then
                ret.actor_action.ani_list = {}
                if #Anims == 0 then
                    Anims = {Anims}
                end
                for _, Anim in ipairs(Anims) do
                    table.insert(ret.actor_action.ani_list, Anim._attr.Name)
                end
            end
            --ret = {} --test empty
            return ret
        end,
        export = function(item, content)
            --[[Lib.pv(item)
			print("======================================================")
			Lib.pv(content)]]
            ActorEditor:newActor(item)
            ActorEditor:updateSubActors(item.sub_actors)
            local body_parts = item.actor_face.body_parts --分组 外观配置
            for k, v in pairs(body_parts) do
                local xml_body_part = ActorEditor:getBodyPart(k)
                ActorEditor:updateBodyPart(xml_body_part, v)
                 --更新分组信息
                for ks, vs in pairs(v.skin) do
                    local xml_skin = ActorEditor:getSkin(k, ks)
                    ActorEditor:updateSkin(xml_skin, vs) --更新skin
                end
                for km, vm in pairs(v.mesh) do
                    local xml_mesh = ActorEditor:getStaticMesh(k, km)
                    ActorEditor:updateStaticMesh(xml_mesh, vm) --更新mesh
                end
                for ke, ve in pairs(v.effect) do
                    local xml_effect = ActorEditor:getEffect(k, ke)
                    ActorEditor:updateEffect(xml_effect, ve) --更新mesh
                end
            end

            local actor_action = item.actor_action --动作配置
            local ani_list = {}
            --[[ //存储的列表数据
            for k, v in pairs(actor_action.ani_list) do --缓存 动画资源列表
                ani_list[v] = v
            end
            ]]

            for k, v in pairs(actor_action.skill) do --动作=技能
                local sk = ActorEditor:getSkill(k)
                ActorEditor:updateSkill(sk, v)

                local anim = actor_action.skill[k].action_editor_animation --动作的动画
                anim = {anim} --动画 目前是只能有一个 注意
                for ke, vm in pairs(anim) do
                    local al = ActorEditor:get_file_name(anim[1].res_file.asset)
                    if #al > 0 then  --空资源名不导出
                        local am = ActorEditor:getAnimation(k, ke)
                        ActorEditor:updateAnimation(am, vm)
                    end
                end

                local al = ActorEditor:get_file_name(anim[1].res_file.asset)
                --print("file name 11111 :",al)
                 --(k) --是否有新增 动画资源
                if #al > 0 then --空资源名不导出
                     ani_list[al] = al
                end

                for ke, ve in pairs(actor_action.skill[k].action_editor_effect) do --动作的特效
                    local ae = ActorEditor:getActionEffect(k, ke)
                    ActorEditor:updateActionEffect(ae, ve)
                end
                if actor_action.skill[k].actor_scale_changes then
                    for ke, ve in pairs(actor_action.skill[k].actor_scale_changes) do --动作的特效
                        local ae = ActorEditor:getActionActorScaleChange(k, ke)
                        ActorEditor:updateActionActorScaleChange(ae, ve)
                    end
                end

                --[[ todo
                for ks, vs in pairs(actor_action.skill[k].action_editor_sound) do --动作的音效
                    local as = ActorEditor:getActionSound(k, ks)
                    ActorEditor:updateActionSound(as, ve)
                end
                --]]
            end
            local index = 1
            for _, v in pairs(ani_list) do --存盘 动画资源列表
                local al = ActorEditor:getAnim(index)
                ActorEditor:updateAni(al, v)
                index = index + 1
            end

            local data = {}
            return data
        end,
        writer = function(path, data)
            ActorEditor:export(path)
        end,
        discard = function(item_name)
            local path = Lib.combinePath(PATH_DATA_DIR, item_name, "setting.json")
            ItemDataUtils:del(path)
        end
    },
    discard = function(item_name)
        local path = Lib.combinePath(PATH_DATA_DIR, item_name)
        ItemDataUtils:delDir(path)
    end
}

return M
