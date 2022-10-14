--[[
统一新的api规则：
 构造、静态函数使用 "." 调用
 成员函数使用 ":" 调用
 成员属性通过 "." 调用
 readOnly属性绝对不支持修改；
 字段相同的会优先取属性再取实例对象
--]]

require "common.api.math"
require "common.api.enum"
require "common.api.physic_properties"
require "common.api.hit_result"

require "common.api.vector2"
require "common.api.vector3"
require "common.api.color3"

require "common.api.world"
require "common.api.map"
require "common.api.game"

require "common.api.instance"
require "common.api.movable_node"
require "common.api.decal"
require "common.api.base_constraint"
require "common.api.base_part"
require "common.api.part"
require "common.api.mesh_part"
require "common.api.scene_ui"
require "common.api.debug"

