require "common.composition"

local setting = require "common.setting"

local dealType = {}
-- 添加配方
function Composition:addRecipes(player, class, name)
    local recipeName = class .. "/" .. name
    if not Composition.RecipeMap[recipeName] then
        return false, "recipes.inexistence"
    end
    local recipeData = T(player:data("masterRecipes"), class)
    if Composition:isMasterRecipe(player, class, class .. "/" .. name) then
        return false, "recipes.already.know"
    end
    local recipeContent = Composition:getRecipe(recipeName)
    if recipeContent.unlockLevel then
        return false, { "recipes.unlockLevel.auto", recipeName, recipeContent.unlockLevel }
    end
    local needLevel = recipeContent.needLevel
    local level = player:getValue("level")
    if needLevel and level < needLevel then
        return false, { "recipes.needLevel.need", recipeName, needLevel }
    end
    recipeData[#recipeData + 1] = name
    return true, "recipes.successful.know"
end

-- 得到掌握配方
function Composition:getMasterRecipes(player, class)
    local list = {}
    for name, recipe in pairs(Composition.RecipeMap) do
        local level = player:getValue("level")
        local unlockLevel = recipe.unlockLevel
        if unlockLevel and level >= unlockLevel and recipe.class == class then
            list[#list + 1] = name
        end
    end
    local m_recipes = player:data("masterRecipes")[class] or {}
    for _, name in pairs(m_recipes) do
        list[#list + 1] = class .. "/" .. name
    end

    return list
end

function Composition:isMasterRecipe(player, class, recipeName)
    local list = Composition:getInnateRecipes(class)
    for _, n in pairs(list) do
        if n == recipeName then
            return true
        end
    end
    list = Composition:getMasterRecipes(player, class)
    for _, n in pairs(list) do
        if n == recipeName then
            return true
        end
    end
    return false
end

-- 开始合成
function Composition:startCompound(player, class, recipeName, times)
    if not Composition:isMasterRecipe(player, class, recipeName) then
        return false, "recipes.failing.master"
    end
    local workbench = player:data("workbench")
    if workbench[class] then
        return false, "compound.process"
    end
    local recipeContent = Composition:getRecipe(recipeName)
    local ret = Composition:addComposition(player, recipeContent.composition, times, true)
    if not ret then
        return false, "compound.inventory.full"
    end
    local materials = recipeContent.materials
    local sup = {}
    ret, sup = Composition:consumeMaterials(player, materials, times, true, false, recipeContent.spendable)
    if not ret then
        if next(sup) then
            workbench[class] = {
                recipeName = recipeName,
                times = times,
                sup = sup
            }
        end
        return false, "recipes.materials.lacking", sup
    end
    Composition:consumeMaterials(player, materials, times)
    workbench[class] = {
        recipeName = recipeName,
        times = times
    }
    return true, "start.compound"
end

--消耗平台货币补充材料合成
function Composition:supStartCompound(player, class)
    local workbench = player:data("workbench")
    local benchData = workbench[class]
    local sup = benchData and benchData.sup
    if not sup then
        return
    end
    player:consumeDiamonds(sup.coinName, sup.price, function(ret)
        if ret then
            Composition:compelCompound(player, class, benchData.recipeName, benchData.times)
        else
            Composition:stopCompound(player, class)
            Composition:sendCompoundResult(player, ret)
        end
    end)
end

--强制消耗已有材料进行合成
function Composition:compelCompound(player, class, recipeName, times)
    local workbench = player:data("workbench")
    local recipeContent = Composition:getRecipe(recipeName)
    local materials = recipeContent.materials
    Composition:consumeMaterials(player, materials, times, false, true)
    workbench[class] = {
        recipeName = recipeName,
        times = times
    }
    Composition:sendCompoundResult(player, true)
end

--中止合成
function Composition:stopCompound(player, class)
    --todo
    local workbench = player:data("workbench")
    if workbench[class] then
        workbench[class] = nil
    end
end

-- 完成合成
function Composition:finishCompound(player, class)
    local workbench = player:data("workbench")
    if not workbench[class] then
        return false, "compound.notstarted"
    end
    local recipeContent = Composition:getRecipe(workbench[class].recipeName)
    local times = workbench[class].times
    if not Composition:addComposition(player, recipeContent.composition, times, true) then
        return false, "compound.inventory.full"
    end
    local _, reward = Composition:addComposition(player, recipeContent.composition, times)
    local context = { obj1 = player, recipeName = workbench[class].recipeName, class = class }
    Trigger.CheckTriggers(player and player:cfg(), "FINISH_COMPOUND", context)
    workbench[class] = nil
    return true, context.msg or "finish.compound", times, reward
end

function Composition:sendCompoundResult(player, result)
    player:sendPacket({
        pid = "SendCompoundResult",
        result = result
    })
end

function Composition:consumeMaterials(player, materials, times, check, mglichst, spendable)
    local ret = true
    local sup = {}
    local consumData = {}
    for _, mat in pairs(materials) do
        if consumData[mat.name] then
            local data = consumData[mat.name]
            data.count = (data.count or 0 ) + (mat.count or 0)
        else
            consumData[mat.name] = Lib.copy(mat)
        end
    end
    for _, mat in pairs(consumData) do
        assert(mat.type ~= "Special")
        local _ret = true
        local count = mat.count and mat.count * times or times
        local func = assert(dealType[mat.type], mat.type)
        local has = 0
        _ret, has = func(player, mat.name, count, check, mglichst)
        ret = ret == true and _ret
        if not ret and spendable and mat.price and mat.coinName then
            sup.coinId = sup.coinId or Coin:getCoinId(mat.coinName or "gDiamonds")
            sup.coinName = sup.coinName or mat.coinName
            sup.price = (sup.price or 0) + math.ceil((mat.count * times - has) * (mat.price or 1))
            sup.msg = "recipes.materials.polishing"
        end
    end
    return ret, sup
end

function Composition:addComposition(player, composition, times, check)
    local ret, reward = dealType.Special(player, composition, times, check)
    return ret, reward
end

-- 检查处理类型，及消耗消耗或添加
function dealType:Item(name, count, check, mglichst)
    local ret, has = self:tray():remove_item(name, count, check, mglichst, false, "composition")
    if not ret then
        return false, has
    end
    return true, has
end

function dealType:Block(name, count, check, mglichst)
    local ret, has = self:tray():remove_item("/block", count, check, mglichst, function(_item)
        return _item:block_id() == setting:name2id("block", name)
    end, "composition")
    if not ret then
        return false, has
    end
    return true, has
end

function dealType:Coin(coinName, count, check, mglichst)
    local item = assert(Coin:getCoin(coinName) and Coin:getCoin(coinName).item, coinName)
    local has = 0
    if item and next(item) then
        local ret = false
        local func = assert(dealType[item.type], item.type)
        ret, has = func(self, item.name, count, check, mglichst)
        if not ret then
            return false, has
        end
    else
        if not self:payCurrency(coinName, count, mglichst, check, "composition") then
            return false, self:getCurrency(coinName, true).countobject
        end
    end
    return true, has
end

-- 特殊处理， 只用于添加，像随机品质之类..
function dealType:Special(cfgName, count, check)
    local ret
	local args = {
		times = count,
		check = check,
		reward = cfgName
	}
    ret = self:reward(args)
    return ret
end