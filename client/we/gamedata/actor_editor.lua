local ActorEditor = {}

local xml2lua = require("common.xml2lua.xml2lua")
local handler = require("common.xml2lua.xmlhandler.tree")

--深度拷贝
local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function ActorEditor:get_file_name(path)
    return path
	--local tb = Lib.splitIncludeEmptyString(path, "/")
	--return tb[#tb]
end

--新建空的actor默认骨骼boy.skel 文件名 111.actor
local ActorTemplates = {
    ActorTemplate = {
        _attr = {
            name = '111.actor',
            Originalscale = '1 1 1',
            Skeleton = 'boy.skel',
            AttackScale = '1',
            TextHeight = '0',
            IsShowShadow = 'true',
            WoundBone = '',
            WoundAngle = '25',
            SelectedRingSize = '1',
            SoundName1 = '',
            SoundName2 = '',
            SoundName3 = '',
            SoundName4 = '',
            SoundName5 = '',
            SoundFileNum = '0',
            Volume = '0.8',
            MinDistance = '1',
            MaxDistance = '16',
            IntervalTime = '2',
            Alpha = '1'
        },
         --_attr
        BodyParts = {
           -- BodyPart = {}
        },
        Skills = {},
        Anims = {}
    }
}

local two = function(v)
    if v == 0 then
        return v
    end
    v = v / 255
    if v == 1 then
        return v
    end
    return string.format('%.2f', v)
end

local color_to_str = function(color)
    return two(color.r) .. ' ' .. two(color.g) .. ' ' .. two(color.b) .. ' ' .. two(color.a)
end

local color_to_rgba = function(color)
    local ret = {}
	
    local t = Lib.splitIncludeEmptyString(color, ' ')
    ret.r = tonumber(t[1]) * 255
    ret.g = tonumber(t[2]) * 255
    ret.b = tonumber(t[3]) * 255
    ret.a = tonumber(t[4]) * 255
    return ret
end

local toType = function(v)
    if v == 'true' or v == 'false' then
        if v == 'true' then
            return true
        else
            return false
        end
    else
        return tonumber(v)
    end
end

--新建空的actor的备份
local copy_actor_templates = deepcopy(ActorTemplates)

--会把所有的数据清空，是默认新建actor文件，必须要设置骨骼文件
function ActorEditor:newActor(item)
    local temp = deepcopy(copy_actor_templates)
    ActorTemplates = temp
    ActorTemplates.ActorTemplate._attr.Skeleton = item.res_skeleton
	local scale = item.scale
	ActorTemplates.ActorTemplate._attr.Originalscale = 
		string.format("%s %s %s", tostring(scale.x), tostring(scale.y), tostring(scale.z))
	ActorTemplates.ActorTemplate._attr.Alpha = tostring(item.alpha.value)
end

--打开actor文件
function ActorEditor:openActor(actor_file)
    local acHandler = handler:new()
    local acParser = xml2lua.parser(acHandler)
    acParser:parse(xml2lua.loadFile(actor_file))
    ActorTemplates = acHandler.root.ActorTemplates
    return ActorTemplates
end

function ActorEditor:updateSubActors(sub_actors)
    ActorTemplates.ActorTemplate.SubActors = sub_actors
end


--创建分组
--[[
function ActorEditor:createBodyPart()
  local bodypart = ActorTemplates.ActorTemplate.BodyParts.BodyPart
  local newbodypart ={ _attr = {MasterName="11" ,SlaveName="11" ,DefaultUse="true" ,EdgeColor="1 1 1 1" ,ColorParams="1 1 1 1"}}
  bodypart[#bodypart + 1] =newbodypart
  return #bodypart;
  --local n_bodypart = deepcopy(newbodypart)
  --n_bodypart._attr.MasterName ="test11" --分组名修改
  --bodypart[#bodypart + 1] = deepcopy(n_bodypart)
end
--]]
--删除分组 bodypart_index 分组索引
function ActorEditor:removeBodyPart(bodypart_index)
    local bodypart = ActorTemplates.ActorTemplate.BodyParts.BodyPart
    local ret = table.remove(bodypart, bodypart_index)
    if ret == nil then
        error('table remove error ', 2)
    end
end

--获取分组 如果不存在就创建
function ActorEditor:getBodyPart(bodypart_index)
    ActorTemplates.ActorTemplate.BodyParts.BodyPart= ActorTemplates.ActorTemplate.BodyParts.BodyPart or {}
    local bodypart = ActorTemplates.ActorTemplate.BodyParts.BodyPart 

    bodypart[bodypart_index] =
        bodypart[bodypart_index] or
        {
            _attr = {
                MasterName = '11',
                SlaveName = '11',
                DefaultUse = 'true',
                EdgeColor = '1 1 1 1',
                ColorParams = '1 1 1 1'
            }
        }
    return bodypart[bodypart_index]
end

--获取分组数
function ActorEditor:getBodyPartCount()
    return #ActorTemplates.ActorTemplate.BodyParts.BodyPart
end

function ActorEditor:updateBodyPart(target, source) --外观 --分组BodyPart attr 更新
    target._attr.MasterName =   source.master_name
    target._attr.SlaveName = source.slave_name 
    target._attr.DefaultUse  = tostring(source.default_use_enable)
end

--新的skin
function ActorEditor:newSkin()
    local new_skin = {
        _attr = {
            type_name = 'skin_name',
            MeshName = '01_suit_boy.skin', --资源文件
            ChangeColor = '1.4013e-45 -0.487196 0.0893673 -0.567287',
            UVSpeed = '0 0',
            LocalAlpha = '1',
             --透明度
            LocalBrightnessScale = '1', --亮度
            UseBloom = 'false',
             --辉光
            UseOriginalcolor = 'false',
             --光照
            UseTransparentNearestSlice = 'false',
            SpecularColor = '1 1 1 1',
            SpecularCoef = '0.15',
            SpecularStrength = '1',
            UseEdge = 'false',
             --边缘光
            EdgeColor = '1 1 1 1'
         --边缘颜色
        }
    }
    return new_skin
end
--删除Skin bodypart_index分组索引 index索引
function ActorEditor:removeSkin(bodypart_index, index)
    local bodypart = ActorTemplates.ActorTemplate.BodyParts.BodyPart
    local op_bodypart = bodypart[bodypart_index]
    table.remove(op_bodypart[bodypart_index].Skin, index)
end

--获取Skin的数据 如果不存在就创建 分组的索引  对应skin的索引
function ActorEditor:getSkin(bodypart_index, index)
    local op_bodypart = self:getBodyPart(bodypart_index)
    op_bodypart.Skin = op_bodypart.Skin or {}
    op_bodypart.Skin[index] = op_bodypart.Skin[index] or self:newSkin()
    return op_bodypart.Skin[index]
end

--更新skin的数据
function ActorEditor:updateSkin(target, source) --外观skin 更新
    --local skin_pro   		  			= source
    --local face_skin  		  			= target
    target._attr.type_name = source.name --部件名称
    target._attr.MeshName = self:get_file_name(source.res_file.asset) --资源文件
    if source.material.use_transparent_nearest_slice then
        target._attr.UseTransparentNearestSlice = tostring(source.material.use_transparent_nearest_slice)
    end
    target._attr.LocalAlpha = source.material.alpha.value --透明度
    target._attr.DiscardAlpha =source.material.discard_alpha.value  --透明遮罩
    target._attr.LocalBrightnessScale = source.material.brightness.value --亮度
    target._attr.UseBloom = tostring(source.material.glow_enable) --辉光
    target._attr.UseOriginalcolor = tostring(source.material.linght_enable) --关照
    --高光
    target._attr.SpecularColor = color_to_str(source.material.hight_light.light_color)
     --高光颜色
    target._attr.SpecularCoef = source.material.hight_light.light_ratio.value --系数
    target._attr.SpecularStrength = source.material.hight_light.brightness.value --强度
	--反射
	target._attr.UseReflect = tostring(source.material.reflex_light.enable)
	if source.material.reflex_light.enable then
		target._attr.ReflectScale = source.material.reflex_light.reflect_scale.value
		local texture = self:get_file_name(source.material.reflex_light.reflect_texture.asset)
		target._attr.ReflectTexture = texture
		local mask_texture = self:get_file_name(source.material.reflex_light.reflect_mask_texture.asset)
		target._attr.ReflectMaskTexture = mask_texture
	end

    --边缘光
    target._attr.UseEdge = tostring(source.material.edge_light.enable)
    target._attr.EdgeColor = color_to_str(source.material.edge_light.light_color)
	target._attr.UseOverlayColorReplaceMode = source.material.overlayMode == "replace" and "true" or "false"
	target._attr.OverlayColor = source.material.overlayMode == "no" and "1 1 1 1" or color_to_str(source.material.overlayColor)
end

--分组添加部件StaticMesh
function ActorEditor:newStaticMesh()
    local new_staticmesh = {
        _attr = {type_name = 'mesh_name', LocalAlpha = '1'},
         --type_name新增字段
        FileName = {_attr = {value = '01_face_boy.mesh'}},
        SocketName = {_attr = {value = 'Bip01'}},
        Position_X = {_attr = {value = '0'}},
        Position_Y = {_attr = {value = '0'}},
        Position_Z = {_attr = {value = '0'}},
        yaw = {_attr = {value = '0'}},
        pitch = {_attr = {value = '0'}},
        roll = {_attr = {value = '0'}},
        scale = {_attr = {value = '1'}},
        UseBloom = {_attr = {value = 'false'}},
        UseOriginalcolor = {_attr = {value = 'false'}},
         --光照
        UseEdge = {_attr = {value = 'false'}},
         --边缘光
        LocalBrightnessScale = {_attr = {value = '1'}},
         --亮度
        UseTransparentNearestSlice = {_attr = {value = 'false'}},
        SpecularColor = {_attr = {value = '1 1 1 1'}},
        SpecularCoef = {_attr = {value = '0.15'}},
        SpecularStrength = {_attr = {value = '1'}},
        EdgeColor = {_attr = {value = '1 1 1 1'}}
     --边缘光
    }
    return new_staticmesh
    -- op_bodypart.StaticMesh[#op_bodypart.StaticMesh+1] = new_staticmesh
    --local decopy_new_staticmesh = deepcopy(new_staticmesh)
    --decopy_new_staticmesh.Position_Z._attr.value =1; --修改值 value
    -- decopy_new_staticmesh.FileName._attr.value ="2_weapon.mesh";
    -- op_bodypart.StaticMesh[2] = decopy_new_staticmesh
end

--删除StaticMesh bodypart_index分组索引 index索引
function ActorEditor:removeStaticMesh(bodypart_index, index)
    local op_bodypart = getBodyPart(bodypart_index)
    table.remove(op_bodypart.StaticMesh, index)
end

--获取StaticMesh的数据 如果不存在就创建 分组的索引  对应skin的索引
function ActorEditor:getStaticMesh(bodypart_index, index)
    local op_bodypart = self:getBodyPart(bodypart_index)
    op_bodypart.StaticMesh = op_bodypart.StaticMesh or {}
    op_bodypart.StaticMesh[index] = op_bodypart.StaticMesh[index] or self:newStaticMesh()
    return op_bodypart.StaticMesh[index]
end

function ActorEditor:updateStaticMesh(target, source) --外观mesh 更新
    target._attr.type_name = source.name
    --部件名称
    target.FileName._attr.value = self:get_file_name(source.res_file.asset) --资源文件 "2_weapon.mesh";
    target.SocketName._attr.value = source.bind_part --绑定位置

    --材质
    target._attr.LocalAlpha = source.material.alpha.value
    --透明度

	target._attr.DiscardAlpha  = source.material.discard_alpha.value --亮度

	target.LocalBrightnessScale._attr.value = source.material.brightness.value --亮度

	target.UseBloom._attr.value = tostring(source.material.glow_enable)
	--辉光
	target.UseOriginalcolor._attr.value = tostring(source.material.linght_enable)
	--关照
	--高光
	target.SpecularColor._attr.value = color_to_str(source.material.hight_light.light_color)
	--高光颜色
	target.SpecularCoef._attr.value = source.material.hight_light.light_ratio.value
	--系数
	target.SpecularStrength._attr.value = source.material.hight_light.brightness.value

	--反射
	target.UseReflect = { _attr = { value = tostring(source.material.reflex_light.enable) } }
	if source.material.reflex_light.enable then
		target.ReflectScale = { _attr = { value = tostring(source.material.reflex_light.reflect_scale.value) } }
		local texture = self:get_file_name(source.material.reflex_light.reflect_texture.asset)
		target.ReflectTexture = { _attr = { value = texture } }
		local mask_texture = self:get_file_name(source.material.reflex_light.reflect_mask_texture.asset)
		target.ReflectMaskTexture = { _attr = { value = mask_texture } }
	end

	--强度
	--边缘光
	target.UseEdge._attr.value = tostring(source.material.edge_light.enable)
	target.EdgeColor._attr.value = color_to_str(source.material.edge_light.light_color)
	--变换
	----位置
	target.Position_X._attr.value = source.transform.pos.x
	target.Position_Y._attr.value = source.transform.pos.y
	target.Position_Z._attr.value = source.transform.pos.z
	----旋转
	target.pitch._attr.value = source.transform.rotate.x
	target.yaw._attr.value = source.transform.rotate.y
	target.roll._attr.value = source.transform.rotate.z
	----缩放
	target.scale._attr.value = source.transform.scale

	target.UseOverlayColorReplaceMode = { _attr = { value = source.overlayMode == "replace" and "true" or "false" }}
	target.OverlayColor = { _attr = { value = source.overlayMode == "no" and "1 1 1 1" or color_to_str(source.material.overlayColor)}}
end

--分组添加部件Effect
function ActorEditor:newEffect()
    --local op_bodypart = self:getBodyPart(bodypart_index)
    local new_effect = {
        type_name = {_attr = {value = 'effect_name'}},
        FileName = {_attr = {value = 'flyrobot.effect'}},
        SocketName = {_attr = {value = 'Bip01'}},
        Position_X = {_attr = {value = '0'}},
        Position_Y = {_attr = {value = '0'}},
        Position_Z = {_attr = {value = '0'}},
        yaw = {_attr = {value = '0'}},
        pitch = {_attr = {value = '0'}},
        roll = {_attr = {value = '0'}},
        scale = {_attr = {value = '1'}},
        TimeScale = {_attr = {value = '1'}},
        Alpha = {_attr = {value = '1'}}
    }
    return new_effect
    -- op_bodypart.Effect =  op_bodypart.Effect or {}
    -- op_bodypart.Effect[#op_bodypart.Effect +1] = new_effect
    -- local decopy_new_effect = deepcopy(new_effect)
    -- decopy_new_effect.Position_Z._attr.value =1 --修改值 value
    -- op_bodypart.Effect[2] = decopy_new_effect
end
--删除Effect bodypart_index分组索引 index索引
function ActorEditor:removeEffect(bodypart_index, index)
    local op_bodypart = self:getBodyPart(bodypart_index)
    table.remove(op_bodypart.Effect, index)
end

--获取Effect的数据
function ActorEditor:getEffect(bodypart_index, index)
    local op_bodypart = self:getBodyPart(bodypart_index)
    op_bodypart.Effect = op_bodypart.Effect or {}
    op_bodypart.Effect[index] = op_bodypart.Effect[index] or self:newEffect()
    return op_bodypart.Effect[index]
end

function ActorEditor:updateEffect(target, source) --外观mesh 更新
    --外观:effect
    local face_effect_pro = source
    local face_effect = target
    face_effect.type_name._attr.value = face_effect_pro.name --别名
    face_effect.FileName._attr.value = self:get_file_name(face_effect_pro.res_file.asset) --资源文件
    face_effect.SocketName._attr.value = face_effect_pro.bind_part --绑定的位置
    ----变换
    face_effect.Position_X._attr.value = face_effect_pro.transform.pos.x
    face_effect.Position_Y._attr.value = face_effect_pro.transform.pos.y
    face_effect.Position_Z._attr.value = face_effect_pro.transform.pos.z
    face_effect.pitch._attr.value = face_effect_pro.transform.rotate.x
    face_effect.yaw._attr.value = face_effect_pro.transform.rotate.y
    face_effect.roll._attr.value = face_effect_pro.transform.rotate.z
    face_effect.scale._attr.value = face_effect_pro.transform.scale

    --播放速度
    face_effect.TimeScale._attr.value = face_effect_pro.play_speed
    face_effect.Alpha._attr.value = face_effect_pro.alpha.value
end

--动画 ani
function ActorEditor:newAnim()
    -- local anims = ActorTemplates.ActorTemplate.Anims
    local new_ani = {_attr = {Name = '82_body_boy_zashua.anim'}} --{ Anim =
    --}
    return new_ani
    --new_ani.Anim._attr.Name ="395_boneless.anim" --更改动画资源
end

function ActorEditor:getAnim(index)
    ActorTemplates.ActorTemplate.Anims = ActorTemplates.ActorTemplate.Anims or {}
    ActorTemplates.ActorTemplate.Anims.Anim = ActorTemplates.ActorTemplate.Anims.Anim or {}
    ActorTemplates.ActorTemplate.Anims.Anim[index] = ActorTemplates.ActorTemplate.Anims.Anim[index] or self:newAnim()
    return ActorTemplates.ActorTemplate.Anims.Anim[index]
end

function ActorEditor:updateAni(target, source) --动作ani 更新
    target._attr.Name = source
end

function ActorEditor:updateAniToVnode(target, source) --动作ani 更新
    target = source._attr.Name
end

--删除动画
function ActorEditor:removeAnim(index)
    local anims = ActorTemplates.ActorTemplate.Anims
    table.remove(anims, index)
end

--技能
function ActorEditor:newSkill()
    --local skills = ActorTemplates.ActorTemplate.Skills
    local new_skill = { --{ Skill =
        _attr = {
            --type_name = 'new name',
            Name = '82_body_boy_zashua.anim',
            EnableWound = 'false',
            UserDefineTime = '-2',
            TextMode = '0'
        },
         --attr
    }
     --Skill
    return new_skill
end

--删除技能
function ActorEditor:removeSkill(index)
    local skills = ActorTemplates.ActorTemplate.Skills
    table.remove(skills, index)
end
--获取技能
function ActorEditor:getSkill(index)
    ActorTemplates.ActorTemplate.Skills = ActorTemplates.ActorTemplate.Skills or {}

    ActorTemplates.ActorTemplate.Skills.Skill = ActorTemplates.ActorTemplate.Skills.Skill or {}
    ActorTemplates.ActorTemplate.Skills.Skill[index] =
        ActorTemplates.ActorTemplate.Skills.Skill[index] or self:newSkill()
    return ActorTemplates.ActorTemplate.Skills.Skill[index]
end

function ActorEditor:updateSkill(target, source) --动作skill 更新
    --target._attr.type_name = source.name --别名
    target._attr.Name = source.name 
    
end

function ActorEditor:newAnimation( )
    --local skills = ActorTemplates.ActorTemplate.Skills[].Animation
    local Animation = {
            _attr = {
                Name = '82_body_boy_zashua.anim',
                BeginTime = '0',
                Times = '1',
                Length = '1.033',
                FadeTime = '0.25',
                Channel = '',
                TimeScale = '1'
            }
        }
    return Animation
end

function ActorEditor:getAnimation(skills_index, index) --技能 的动画
    local skill = self:getSkill(skills_index)
    skill.Animation = skill.Animation or {}
    skill.Animation[index] = skill.Animation[index] or self:newAnimation()
    return skill.Animation[index]
end


function ActorEditor:updateAnimation(target, source) --技能 的动画

    target._attr.Name = self:get_file_name(source.res_file.asset) --资源文件名
    target._attr.BeginTime = tostring(source.start_time) --开始时间
    local times = -1 --循环
    if not source.loop_play_set.enable then --todo 设置播放次数为0?
        times = source.loop_play_set.play_times
    end
    target._attr.Times = times --播放次数 -1 循环
    target._attr.TimeScale = source.play_speed --播放速度
    --target.Skill._attr.EnableWound = source.res_file -- 是否受击

    target._attr.Length =source.length --持续时间

    target._attr.FadeTime = source.transition_time --过渡时间


    local channel ='' --作用通道 全身 上半身 下半身
    if source.channel_mode ~='all' then
        channel = source.channel_mode
    end
    target._attr.Channel = channel
end

function ActorEditor:newActionEffect() --技能 的特效
    local Effect = {
        type_name = {_attr = {value = 'type_name'}},
        FileName = {_attr = {value = '01_face_boy.mesh'}},
        SocketName = {_attr = {value = 'Bip01'}},
        FollowActor = {_attr = {value = 'true'}},
        BeginTime = {_attr = {value = '0'}},
        Position_X = {_attr = {value = '0'}},
        Position_Y = {_attr = {value = '0'}},
        Position_Z = {_attr = {value = '0'}},
        yaw = {_attr = {value = '0'}},
        pitch = {_attr = {value = '0'}},
        roll = {_attr = {value = '0'}},
        scale = {_attr = {value = '1'}},
        Alpha = {_attr = {value = '1'}},
        TimeScale = {_attr = {value = '1'}},
		Times = {_attr = {value = '1'}} ,
		CycleTime ={_attr = {value = '-1'}} 
    }
    return Effect
end

function ActorEditor:getActionEffect(skills_index, index) --技能 的特效
    local skill = self:getSkill(skills_index)
    skill.Effect = skill.Effect or {}
    skill.Effect[index] = skill.Effect[index] or self:newActionEffect()
    return skill.Effect[index]
end

function ActorEditor:updateActionEffect(target, source) --技能 的特效
    target.type_name._attr.value = source.name --别名
    --target.FileName._attr.value = source.res_file --资源文件
    target.FileName._attr.value =self:get_file_name(source.res_file.asset) --资源文件
    target.SocketName._attr.value = source.bind_part --绑定的位置
    target.FollowActor._attr.value = tostring(source.follow_bind_part) --跟随绑定位置
    target.Alpha._attr.value = source.alpha.value --透明度
    local times = -1 --循环
    if not source.loop_play_set.enable then --todo 设置播放次数为0?
        times = source.loop_play_set.play_times
    end
    target.Times._attr.value = times --播放次数 -1 循环

    target.BeginTime._attr.value = source.start_time -- 开始时间
    target.TimeScale._attr.value = source.play_speed --播放速度
	
	--自定义时长
	times = -1 --循环
    if  source.custom_time_set.enable then --todo 设置播放次数为0?
        times = source.custom_time_set.play_times
    end
    target.CycleTime._attr.value = times --播放次数 -1 循环
	
	
    ----变换
    target.Position_X._attr.value = source.transform.pos.x
    target.Position_Y._attr.value = source.transform.pos.y
    target.Position_Z._attr.value = source.transform.pos.z
    target.pitch._attr.value = source.transform.rotate.x
    target.yaw._attr.value = source.transform.rotate.y
    target.roll._attr.value = source.transform.rotate.z
    target.scale._attr.value = source.transform.scale
end


function ActorEditor:newActionActorScaleChange()

    local ActorScaleChange = {
        _attr = {
            endScale = '1',
            endScale = '1',
        }
    }
    return ActorScaleChange
    -- body
end

function ActorEditor:getActionActorScaleChange(skills_index, index) --技能 的特效
    local skill = self:getSkill(skills_index)
    skill.ActorScaleChange = skill.ActorScaleChange or {}
    skill.ActorScaleChange[index] = skill.ActorScaleChange[index] or self:newActionActorScaleChange()
    return skill.ActorScaleChange[index]
end

function ActorEditor:updateActionActorScaleChange(target, source) --技能 
    --
    target._attr.endScale = source.end_scale 
    target._attr.beginScale = source.begin_scale 
end

function ActorEditor:newActionSound() --技能 的音效 Todo
    local Sound = {
        FileName = {_attr = {value = '01_face_boy.mesh'}},
        SocketName = {_attr = {value = 'Bip01'}},
        BeginTime = {_attr = {value = '0'}},
        Position_X = {_attr = {value = '0'}},
        Position_Y = {_attr = {value = '0'}},
        Position_Z = {_attr = {value = '0'}},
        yaw = {_attr = {value = '0'}},
        pitch = {_attr = {value = '0'}},
        roll = {_attr = {value = '0'}},
        scale = {_attr = {value = '1'}},
        Alpha = {_attr = {value = '1'}},
        TimeScale = {_attr = {value = '1'}}
    }
    return Sound
end

function ActorEditor:getActionSound(skills_index, index) --技能 的音效 Todo
    local skill = getSkill(skills_index)
    skill.Sound = skill.Sound or {}
    skill.Sound[index] = skill.Sound[index] {}
    self:newActionEffect()
    return skill.Sound[index]
end

function ActorEditor:updateActionSound(target, source) --技能 的音效 Todo
    target.type_name._attr.value = source.name --别名
    target.FileName._attr.value = source.res_file --资源文件
    target.SocketName._attr.value = source.bind_part --绑定的位置
    target.Alpha._attr.value = source.alpha.value --透明度
    local times = -1
    if not source.enable then --todo 设置播放次数为0?
        times = source.play_times
    end

    target.BeginTime._attr.value = source.start_time -- 开始时间
    target.TimeScale._attr.value = source.play_speed --播放速度

    ----变换
    target.Position_X._attr.value = source.transform.pos.x
    target.Position_Y._attr.value = source.transform.pos.y
    target.Position_Z._attr.value = source.transform.pos.z
    target.pitch._attr.value = source.transform.rotate.x
    target.yaw._attr.value = source.transform.rotate.y
    target.roll._attr.value = source.transform.rotate.z
    target.scale._attr.value = source.transform.scale
end

function ActorEditor:export(path)
    --print()
    --  print("XML Representation\n")
    --print(" ActorEditor:export",path)
    local copy = deepcopy(ActorTemplates)
    --print(xml2lua.toXml(ActorTemplates, "ActorTemplates"))
    --ActorTemplates = copy
	local lua2xml = require("common.xml2lua.lua2xml")
    local s = lua2xml(ActorTemplates, 'ActorTemplates')
    ActorTemplates = copy
    local file = io.open(path, 'w+')
    io.output(file)
    file:write(s)
    file:close()
    if DataLink:useDataLink() then
        DataLink:modify(path)
    end
end

return ActorEditor