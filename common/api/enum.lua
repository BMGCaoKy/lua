--不直接使用C++对应的枚举值的原因:引擎里设置材质是传路径然后将路径映射到材质枚举值;
Enum.PartMaterial =
{
    Plastic = "part_suliao.tga", -- 0
    SteelPlate = "part_gangban.tga",
    Board = "part_muban.tga",
    Grass = "part_caodi.tga",
    Ice = "part_bingkuai.tga",
    Cobblestone = "part_eluanshi.tga",
    Slate = "part_shiban.tga",
    Bricks = "part_zhuankuai.tga",
    Carpet = "part_ditan.tga",
    Cement = "part_shuini.tga",
    SandySoil = "part_shatu.tga",
    Marble = "part_dalishi.tga",
    Wood = "part_mutou.tga",
    Corrodedmetal = "part_xiushijinshu.tga",
    Diamondplate = "part_huawenban.tga",
    Foil = "part_xibo.tga",
    Fabric = "part_buliao.tga",
    Granite = "part_huagangyan.tga",
    Pebble = "part_luanshi.tga",
    Glass = "part_boli.tga",
    LimeBrick = "part_shihuizhuan.tga",-- 20
}


Enum.ConstraintType = { -- c++端缺少这类枚举
    Weld = "Weld",
    Hinge = "Hinge",
    Rod = "Rod",
    Spring = "Spring",
    Rope = "Rope",
    SlidingJoint = "SlidingJoint"
}

Enum.PartShape = {
    Cube = 1,
    Ball = 2,
    Cylinder = 3,
    Cone = 4,
}

Enum.TextureFillType = {
    Fill = 0,
    Tile = 2,
    -- center 为1， 没有开放出去
}

Enum.PartSurface = {
    Front = 0,
    Back = 1,
    Right = 2,
    Left = 3,
    Top = 4,
    Bottom = 5,
}