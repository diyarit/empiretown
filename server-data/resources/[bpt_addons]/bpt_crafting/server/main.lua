---@diagnostic disable: undefined-global

ESX = exports["es_extended"]:getSharedObject()
function SetCraftingLevel(identifier, level)
    MySQL.Async.execute("UPDATE `users` SET `crafting_level`= @xp WHERE `identifier` = @identifier", { ["@xp"] = level, ["@identifier"] = identifier }, function() end)
end

function GetCraftingLevel(identifier)
    return tonumber(MySQL.Sync.fetchScalar("SELECT `crafting_level` FROM users WHERE identifier = @identifier ", { ["@identifier"] = identifier }))
end

function GiveCraftingLevel(identifier, level)
    MySQL.Async.execute("UPDATE `users` SET `crafting_level`= `crafting_level` + @xp WHERE `identifier` = @identifier", { ["@xp"] = level, ["@identifier"] = identifier }, function() end)
end

RegisterServerEvent("bpt_crafting:setExperiance")
AddEventHandler("bpt_crafting:setExperiance", function(identifier, xp)
    SetCraftingLevel(identifier, xp)
end)

RegisterServerEvent("bpt_crafting:giveExperiance")
AddEventHandler("bpt_crafting:giveExperiance", function(identifier, xp)
    GiveCraftingLevel(identifier, xp)
end)

function Craft(src, item, retrying)
    local xPlayer = ESX.GetPlayerFromId(src)
    local cancraft = true

    local count = Config.Recipes[item].Amount

    if not retrying then
        for k, v in pairs(Config.Recipes[item].Ingredients) do
            if xPlayer.getInventoryItem(k).count < v then
                cancraft = false
            end
        end
    end

    if Config.Recipes[item].isGun then
        if cancraft then
            for k, v in pairs(Config.Recipes[item].Ingredients) do
                if not Config.PermanentItems[k] then
                    xPlayer.removeInventoryItem(k, v)
                end
            end

            TriggerClientEvent("bpt_crafting:craftStart", src, item, count)
        else
            TriggerClientEvent("bpt_crafting:sendMessage", src, TranslateCap("not_enough_ingredients"))
        end
    else
        if Config.UseLimitSystem then
            local xItem = xPlayer.getInventoryItem(item)

            if xItem.count + count <= xItem.limit then
                if cancraft then
                    for k, v in pairs(Config.Recipes[item].Ingredients) do
                        xPlayer.removeInventoryItem(k, v)
                    end

                    TriggerClientEvent("bpt_crafting:craftStart", src, item, count)
                else
                    TriggerClientEvent("bpt_crafting:sendMessage", src, TranslateCap("not_enough_ingredients"))
                end
            else
                TriggerClientEvent("bpt_crafting:sendMessage", src, TranslateCap("you_cant_hold_item"))
            end
        else
            if xPlayer.canCarryItem(item, count) then
                if cancraft then
                    for k, v in pairs(Config.Recipes[item].Ingredients) do
                        xPlayer.removeInventoryItem(k, v)
                    end

                    TriggerClientEvent("bpt_crafting:craftStart", src, item, count)
                else
                    TriggerClientEvent("bpt_crafting:sendMessage", src, TranslateCap("not_enough_ingredients"))
                end
            else
                TriggerClientEvent("bpt_crafting:sendMessage", src, TranslateCap("you_cant_hold_item"))
            end
        end
    end
end

RegisterServerEvent("bpt_crafting:itemCrafted")
AddEventHandler("bpt_crafting:itemCrafted", function(item, count)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if Config.Recipes[item].SuccessRate > math.random(0, Config.Recipes[item].SuccessRate) then
        if Config.UseLimitSystem then
            local xItem = xPlayer.getInventoryItem(item)

            if xItem.count + count <= xItem.limit then
                if Config.Recipes[item].isGun then
                    xPlayer.addWeapon(item, 0)
                else
                    xPlayer.addInventoryItem(item, count)
                end
                TriggerClientEvent("bpt_crafting:sendMessage", src, TranslateCap("item_crafted"))
                GiveCraftingLevel(xPlayer.identifier, Config.ExperiancePerCraft)
            else
                TriggerEvent("bpt_crafting:craft", item)
                TriggerClientEvent("bpt_crafting:sendMessage", src, TranslateCap("inv_limit_exceed"))
            end
        else
            if xPlayer.canCarryItem(item, count) then
                if Config.Recipes[item].isGun then
                    xPlayer.addWeapon(item, 0)
                else
                    xPlayer.addInventoryItem(item, count)
                end
                TriggerClientEvent("bpt_crafting:sendMessage", src, TranslateCap("item_crafted"))
                GiveCraftingLevel(xPlayer.identifier, Config.ExperiancePerCraft)
            else
                TriggerClientEvent("bpt_crafting:sendMessage", src, TranslateCap("inv_limit_exceed"))
            end
        end
    else
        TriggerClientEvent("bpt_crafting:sendMessage", src, TranslateCap("crafting_failed"))
    end
end)

RegisterServerEvent("bpt_crafting:craft")
AddEventHandler("bpt_crafting:craft", function(item, retrying)
    local src = source
    Craft(src, item, retrying)
end)

ESX.RegisterServerCallback("bpt_crafting:getXP", function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)

    cb(GetCraftingLevel(xPlayer.identifier))
end)

ESX.RegisterServerCallback("bpt_crafting:getItemNames", function(_, cb)
    local names = {}

    MySQL.Async.fetchAll("SELECT * FROM bpt_items WHERE 1", {}, function(info)
        for _, v in ipairs(info) do
            names[v.name] = v.label
        end

        cb(names)
    end)
end)
