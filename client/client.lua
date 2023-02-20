local QBCore = exports['qb-core']:GetCoreObject()

local zoneName = nil
local inZone = false

local PlayerData = {}
local PlayerJob = {}
local PlayerGang = {}

local TargetPeds = {
    Store = {},
    ClothingRoom = {},
    PlayerOutfitRoom = {}
}

local function RemoveTargetPeds(peds)
    for i = 1, #peds, 1 do
        DeletePed(peds[i])
    end
end

local function RemoveTargets()
    if Config.EnablePedsForShops then
        RemoveTargetPeds(TargetPeds.Store)
    else
        for k, v in pairs(Config.Stores) do
            exports['qb-target']:RemoveZone(v.shopType .. k)
        end
    end

    if Config.EnablePedsForClothingRooms then
        RemoveTargetPeds(TargetPeds.ClothingRoom)
    else
        for k, v in pairs(Config.ClothingRooms) do
            exports['qb-target']:RemoveZone('clothing_' .. v.requiredJob .. k)
        end
    end

    if Config.EnablePedsForPlayerOutfitRooms then
        RemoveTargetPeds(TargetPeds.PlayerOutfitRoom)
    else
        for k in pairs(Config.PlayerOutfitRooms) do
            exports['qb-target']:RemoveZone('playeroutfitroom_' .. k)
        end
    end
end

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        PlayerData = QBCore.Functions.GetPlayerData()
        PlayerJob = PlayerData.job
        PlayerGang = PlayerData.gang
        TriggerEvent("updateJob", PlayerJob.name)
        TriggerEvent("updateGang", PlayerGang.name)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and GetResourceState("qb-target") == "started" then
        if Config.UseTarget then
            RemoveTargets()
        end
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
    PlayerJob = JobInfo
    TriggerEvent("updateJob", PlayerJob.name)
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function(GangInfo)
    PlayerData.gang = GangInfo
    PlayerGang = GangInfo
    TriggerEvent("updateGang", PlayerGang.name)
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(duty)
    PlayerJob.onduty = duty
end)

local function LoadPlayerUniform()
    QBCore.Functions.TriggerCallback("fivem-appearance:server:getUniform", function(uniformData)
        if not uniformData then
            return
        end
        local outfits = Config.Outfits[uniformData.jobName][uniformData.gender]
        local uniform = nil
        for i = 1, #outfits, 1 do
            if outfits[i].outfitLabel == uniformData.label then
                uniform = outfits[i]
                break
            end
        end

        if not uniform then
            TriggerServerEvent("fivem-appearance:server:syncUniform", nil) -- Uniform doesn't exist anymore
            return
        end

        uniform.jobName = uniformData.jobName
        uniform.gender = uniformData.gender

        TriggerEvent("qb-clothing:client:loadOutfit", uniform)
    end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    PlayerJob = PlayerData.job
    PlayerGang = PlayerData.gang

    TriggerEvent("updateJob", PlayerJob.name)
    TriggerEvent("updateGang", PlayerGang.name)

    QBCore.Functions.TriggerCallback('fivem-appearance:server:getAppearance', function(appearance)
        if not appearance then
            return
        end
        exports['fivem-appearance']:setPlayerAppearance(appearance)
        if Config.PersistUniforms then
            LoadPlayerUniform()
        end

        if Config.Debug then -- This will detect if the player model is set as "player_zero" aka michael. Will then set the character as a freemode ped based on gender.
            Wait(5000)
            if GetEntityModel(PlayerPedId()) == `player_zero` then
                print('Player detected as "player_zero", Starting CreateFirstCharacter event')
                TriggerEvent('qb-clothes:client:CreateFirstCharacter')
            end
        end
    end)
end)

local function getConfigForPermission(hasPedPerms)
    local config = {
        ped = true,
        headBlend = true,
        faceFeatures = true,
        headOverlays = true,
        components = true,
        props = true,
        tattoos = true
    }

    if Config.EnablePedMenu then
        config.ped = hasPedPerms
    end

    return config
end

RegisterNetEvent('qb-clothes:client:CreateFirstCharacter', function()
    QBCore.Functions.GetPlayerData(function(pd)
        local skin = 'mp_m_freemode_01'
        if pd.charinfo.gender == 1 then
            skin = "mp_f_freemode_01"
        end
        exports['fivem-appearance']:setPlayerModel(skin)
        -- Fix for tattoo's appearing when creating a new character
        local ped = PlayerPedId()
        exports['fivem-appearance']:setPedTattoos(ped, {})
        ClearPedDecorations(ped)
        QBCore.Functions.TriggerCallback("QBCore:HasPermission", function(permission)
            local config = getConfigForPermission(permission)
            exports['fivem-appearance']:startPlayerCustomization(function(appearance)
                if (appearance) then
                    TriggerServerEvent('fivem-appearance:server:saveAppearance', appearance)
                end
            end, config)
        end, Config.PedMenuGroup)
    end)
end)

function OpenShop(config, isPedMenu, shopType)
    QBCore.Functions.TriggerCallback("fivem-appearance:server:hasMoney", function(hasMoney, money)
        if not hasMoney and not isPedMenu then
            QBCore.Functions.Notify("Not enough cash. Need $" .. money, "error")
            return
        end

        exports['fivem-appearance']:startPlayerCustomization(function(appearance)
            if appearance then
                if not isPedMenu then
                    TriggerServerEvent("fivem-appearance:server:chargeCustomer", shopType)
                end
                TriggerServerEvent('fivem-appearance:server:saveAppearance', appearance)
            else
                QBCore.Functions.Notify("Cancelled Customization")
            end
        end, config)
    end, shopType)
end

local function OpenClothingShop(isPedMenu)
    local config = {
        ped = false,
        headBlend = false,
        faceFeatures = false,
        headOverlays = false,
        components = true,
        props = true,
        tattoos = false
    }
    if isPedMenu then
        config = {
            ped = true,
            headBlend = true,
            faceFeatures = true,
            headOverlays = true,
            components = true,
            props = true,
            tattoos = true
        }
    end
    OpenShop(config, isPedMenu, 'clothing')
end

local function OpenBarberShop()
    OpenShop({
        ped = false,
        headBlend = false,
        faceFeatures = false,
        headOverlays = true,
        components = false,
        props = false,
        tattoos = false
    }, false, 'barber')
end

local function OpenTattooShop()
    OpenShop({
        ped = false,
        headBlend = false,
        faceFeatures = false,
        headOverlays = false,
        components = false,
        props = false,
        tattoos = true
    }, false, 'tattoo')
end

local function OpenSurgeonShop()
    OpenShop({
        ped = false,
        headBlend = true,
        faceFeatures = true,
        headOverlays = false,
        components = false,
        props = false,
        tattoos = false
    }, false, 'surgeon')
end

RegisterNetEvent('fivem-appearance:client:openClothingShop', OpenClothingShop)

RegisterNetEvent('fivem-appearance:client:saveOutfit', function()
    local keyboard = exports['qb-input']:ShowInput({
        header = "Name your outfit",
        submitText = "Save Outfit",
        inputs = {{
            text = "Outfit Name",
            name = "input",
            type = "text",
            isRequired = true
        }}
    })

    if keyboard ~= nil then
        Wait(500)
        QBCore.Functions.TriggerCallback("fivem-appearance:server:getOutfits", function(outfits)
            local outfitExists = false
            for i = 1, #outfits, 1 do
                if outfits[i].outfitname == keyboard.input then
                    outfitExists = true
                    break
                end
            end

            if outfitExists then
                QBCore.Functions.Notify("Outfit with this name already exists.", "error")
                return
            end

            local playerPed = PlayerPedId()
            local pedModel = exports['fivem-appearance']:getPedModel(playerPed)
            local pedComponents = exports['fivem-appearance']:getPedComponents(playerPed)
            local pedProps = exports['fivem-appearance']:getPedProps(playerPed)

            TriggerServerEvent('fivem-appearance:server:saveOutfit', keyboard.input, pedModel, pedComponents, pedProps)
        end)
    end
end)

function OpenMenu(isPedMenu, backEvent, menuType, menuData)
    local menuItems = {}
    local outfitMenuItems = {{
        header = "Change Outfit",
        txt = "Pick from any of your currently saved outfits",
        params = {
            event = "fivem-appearance:client:changeOutfitMenu",
            args = {
                isPedMenu = isPedMenu,
                backEvent = backEvent
            }
        }
    }, {
        header = "Save New Outfit",
        txt = "Save a new outfit you can use later on",
        params = {
            event = "fivem-appearance:client:saveOutfit"
        }
    }, {
        header = "Delete Outfit",
        txt = "Yeah... We didnt like that one either",
        params = {
            event = "fivem-appearance:client:deleteOutfitMenu",
            args = {
                isPedMenu = isPedMenu,
                backEvent = backEvent
            }
        }
    }}
    if menuType == "default" then
        local header = "Buy Clothing - $" .. Config.ClothingCost
        if isPedMenu then
            header = "Change Clothing"
        end
        menuItems[#menuItems + 1] = {
            header = "Clothing Store Options",
            icon = "fas fa-shirt",
            isMenuHeader = true -- Set to true to make a nonclickable title
        }
        menuItems[#menuItems + 1] = {
            header = header,
            txt = "Pick from a wide range of items to wear",
            params = {
                event = "fivem-appearance:client:openClothingShop",
                args = isPedMenu
            }
        }
        for i = 0, #outfitMenuItems, 1 do
            menuItems[#menuItems + 1] = outfitMenuItems[i]
        end
    elseif menuType == "outfit" then
        menuItems[#menuItems + 1] = {
            header = "👔 | Outfit Options",
            isMenuHeader = true -- Set to true to make a nonclickable title
        }
        for i = 0, #outfitMenuItems, 1 do
            menuItems[#menuItems + 1] = outfitMenuItems[i]
        end
    elseif menuType == "job-outfit" then
        menuItems[#menuItems + 1] = {
            header = "👔 | Outfit Options",
            isMenuHeader = true -- Set to true to make a nonclickable title
        }
        menuItems[#menuItems + 1] = {
            header = "Civilian Outfit",
            txt = "Put on your clothes",
            params = {
                event = "fivem-appearance:client:reloadSkin"
            }
        }
        menuItems[#menuItems + 1] = {
            header = "Work Clothes",
            txt = "Pick from any of your work outfits",
            params = {
                event = "fivem-appearance:client:openJobOutfitsListMenu",
                args = {
                    backEvent = backEvent,
                    menuData = menuData
                }
            }
        }
    end
    exports['qb-menu']:openMenu(menuItems)
end

RegisterNetEvent("fivem-appearance:client:openJobOutfitsListMenu", function(data)
    local menu = {{
        header = '< Go Back',
        params = {
            event = data.backEvent,
            args = data.menuData
        }
    }}
    if data.menuData then
        for _, v in pairs(data.menuData) do
            menu[#menu + 1] = {
                header = v.outfitLabel,
                params = {
                    event = 'qb-clothing:client:loadOutfit',
                    args = v
                }
            }
        end
    end
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent("fivem-appearance:client:openClothingShopMenu", function(isPedMenu)
    OpenMenu(isPedMenu, "fivem-appearance:client:openClothingShopMenu", "default")
end)

RegisterNetEvent("fivem-appearance:client:changeOutfitMenu", function(data)
    QBCore.Functions.TriggerCallback('fivem-appearance:server:getOutfits', function(result)
        local outfitMenu = {{
            header = '< Go Back',
            params = {
                event = data.backEvent,
                args = data.isPedMenu
            }
        }}
        for i = 1, #result, 1 do
            outfitMenu[#outfitMenu + 1] = {
                header = result[i].outfitname,
                txt = result[i].model,
                params = {
                    event = 'fivem-appearance:client:changeOutfit',
                    args = {
                        outfitName = result[i].outfitname,
                        model = result[i].model,
                        components = result[i].components,
                        props = result[i].props
                    }
                }
            }
        end
        exports['qb-menu']:openMenu(outfitMenu)
    end)
end)

RegisterNetEvent("fivem-appearance:client:changeOutfit", function(data)
    local playerPed = PlayerPedId()
    local pedModel = exports['fivem-appearance']:getPedModel(playerPed)
    local failed = false
    local appearanceDB = nil
    -- check if canBuy
    print(data)
    local canBuy = exports['vip-groups']:canBuyClothing(data)
    if canBuy ~= true then
        for k, v in pairs(canBuy) do
            QBCore.Functions.Notify('You need at least ' .. v.group .. ' to buy item: ' .. v.category .. ', ID: ' .. v.id, 'error')
        end
        -- set back apperance
        return
    end
    if pedModel ~= data.model then
        QBCore.Functions.TriggerCallback("fivem-appearance:server:getAppearance", function(appearance)
            if appearance then
                exports['fivem-appearance']:setPlayerAppearance(appearance)
                appearanceDB = appearance
            else
                QBCore.Functions.Notify(
                    "Something went wrong. The outfit that you're trying to change to, does not have a base appearance.",
                    "error")
                failed = true
            end
        end, data.model)
    else
        appearanceDB = exports['fivem-appearance']:getPedAppearance(playerPed)
    end
    if not failed then
        while not appearanceDB do
            Wait(100)
        end
        playerPed = PlayerPedId()
        exports['fivem-appearance']:setPedComponents(playerPed, data.components)
        exports['fivem-appearance']:setPedProps(playerPed, data.props)
        exports['fivem-appearance']:setPedHair(playerPed, appearanceDB.hair)

        local appearance = exports['fivem-appearance']:getPedAppearance(playerPed)
        TriggerServerEvent('fivem-appearance:server:saveAppearance', appearance)
    end
end)

RegisterNetEvent("fivem-appearance:client:deleteOutfitMenu", function(data)
    QBCore.Functions.TriggerCallback('fivem-appearance:server:getOutfits', function(result)
        local outfitMenu = {{
            header = '< Go Back',
            params = {
                event = data.backEvent,
                args = data.isPedMenu
            }
        }}
        for i = 1, #result, 1 do
            outfitMenu[#outfitMenu + 1] = {
                header = 'Delete "' .. result[i].outfitname .. '"',
                txt = 'You will never be able to get this back!',
                params = {
                    event = 'fivem-appearance:client:deleteOutfit',
                    args = result[i].id
                }
            }
        end
        exports['qb-menu']:openMenu(outfitMenu)
    end)
end)

RegisterNetEvent('fivem-appearance:client:deleteOutfit', function(id)
    TriggerServerEvent('fivem-appearance:server:deleteOutfit', id)
    QBCore.Functions.Notify('Outfit Deleted', 'error')
end)

RegisterNetEvent('fivem-appearance:client:openJobOutfitsMenu', function(outfitsToShow)
    OpenMenu(nil, "fivem-appearance:client:openJobOutfitsMenu", "job-outfit", outfitsToShow)
end)

RegisterNetEvent('fivem-appearance:client:reloadSkin', function()
    QBCore.Functions.TriggerCallback('fivem-appearance:server:getAppearance', function(appearance)
        if not appearance then
            return
        end
        exports['fivem-appearance']:setPlayerAppearance(appearance)
        if Config.PersistUniforms then
            TriggerServerEvent("fivem-appearance:server:syncUniform", nil)
        end
    end)
end)

local function isPlayerAllowedForOutfitRoom(outfitRoom)
    local isAllowed = false
    for i = 1, #outfitRoom.citizenIDs, 1 do
        if outfitRoom.citizenIDs[i] == PlayerData.citizenid then
            isAllowed = true
            break
        end
    end
    return isAllowed
end

local function OpenOutfitRoom(outfitRoom)
    local isAllowed = isPlayerAllowedForOutfitRoom(outfitRoom)
    if isAllowed then
        TriggerEvent('qb-clothing:client:openOutfitMenu')
    end
end

local function getPlayerJobOutfits(clothingRoom)
    local outfits = {}
    local gender = "male"
    if PlayerData.charinfo.gender == 1 then
        gender = "female"
    end
    local gradeLevel = clothingRoom.isGang and PlayerGang.grade.level or PlayerJob.grade.level
    local jobName = clothingRoom.isGang and PlayerGang.name or PlayerJob.name

    for i = 1, #Config.Outfits[jobName][gender], 1 do
        for _, v in pairs(Config.Outfits[jobName][gender][i].grades) do
            if v == gradeLevel then
                outfits[#outfits + 1] = Config.Outfits[jobName][gender][i]
                outfits[#outfits].gender = gender
                outfits[#outfits].jobName = jobName
            end
        end
    end

    return outfits
end

local function CheckDuty()
    return not Config.OnDutyOnlyClothingRooms or (Config.OnDutyOnlyClothingRooms and PlayerJob.onduty)
end

local function SetupStoreZones()
    local zones = {}
    for _, v in pairs(Config.Stores) do
        zones[#zones + 1] = BoxZone:Create(v.coords, v.length, v.width, {
            name = v.shopType,
            minZ = v.coords.z - 1.5,
            maxZ = v.coords.z + 1.5,
            heading = v.coords.w
        })
    end

    local clothingCombo = ComboZone:Create(zones, {
        name = "clothingCombo",
        debugPoly = Config.Debug
    })
    clothingCombo:onPlayerInOut(function(isPointInside, _, zone)
        if isPointInside then
            inZone = true
            zoneName = zone.name
            if zoneName == 'clothing' then
                exports['qb-core']:DrawText('[E] Clothing Store')
            elseif zoneName == 'barber' then
                exports['qb-core']:DrawText('[E] Barber')
            elseif zoneName == 'tattoo' then
                exports['qb-core']:DrawText('[E] Tattoo Shop')
            elseif zoneName == 'surgeon' then
                exports['qb-core']:DrawText('[E] Plastic Surgeon')
            end
        else
            inZone = false
            exports['qb-core']:HideText()
        end
    end)
end

local function SetupClothingRoomZones()
    local roomZones = {}
    for k, v in pairs(Config.ClothingRooms) do
        roomZones[#roomZones + 1] = BoxZone:Create(v.coords, v.length, v.width, {
            name = 'ClothingRooms_' .. k,
            minZ = v.coords.z - 1.5,
            maxZ = v.coords.z + 1,
            heading = v.coords.w
        })
    end

    local clothingRoomsCombo = ComboZone:Create(roomZones, {
        name = "clothingRoomsCombo",
        debugPoly = Config.Debug
    })
    clothingRoomsCombo:onPlayerInOut(function(isPointInside, _, zone)
        if isPointInside then
            zoneName = zone.name
            local clothingRoom = Config.ClothingRooms[tonumber(string.sub(zone.name, 15))]
            local jobName = clothingRoom.isGang and PlayerGang.name or PlayerJob.name
            if jobName == clothingRoom.requiredJob then
                if CheckDuty() then
                    inZone = true
                    exports['qb-core']:DrawText('[E] Clothing Room')
                end
            end
        else
            inZone = false
            exports['qb-core']:HideText()
        end
    end)
end

local function SetupPlayerOutfitRoomZones()
    local roomZones = {}
    for k, v in pairs(Config.PlayerOutfitRooms) do
        roomZones[#roomZones + 1] = BoxZone:Create(v.coords, v.length, v.width, {
            name = 'PlayerOutfitRooms_' .. k,
            minZ = v.coords.z - 1.5,
            maxZ = v.coords.z + 1
        })
    end

    local playerOutfitRoomsCombo = ComboZone:Create(roomZones, {
        name = "playerOutfitRoomsCombo",
        debugPoly = Config.Debug
    })
    playerOutfitRoomsCombo:onPlayerInOut(function(isPointInside, _, zone)
        if isPointInside then
            zoneName = zone.name
            local outfitRoom = Config.PlayerOutfitRooms[tonumber(string.sub(zone.name, 19))]
            local isAllowed = isPlayerAllowedForOutfitRoom(outfitRoom)
            if isAllowed then
                inZone = true
                exports['qb-core']:DrawText('[E] Outfits')
            end
        else
            inZone = false
            exports['qb-core']:HideText()
        end
    end)
end

local function SetupZones()
    SetupStoreZones()
    SetupClothingRoomZones()
    SetupPlayerOutfitRoomZones()
end

local function EnsurePedModel(pedModel)
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do
        Wait(10)
    end
end

local function CreatePedAtCoords(pedModel, coords, scenario)
    pedModel = type(pedModel) == "string" and GetHashKey(pedModel) or pedModel
    EnsurePedModel(pedModel)
    local ped = CreatePed(0, pedModel, coords.x, coords.y, coords.z - 0.98, coords.w, false, false)
    TaskStartScenarioInPlace(ped, scenario, true)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true)
    SetEntityInvincible(ped, true)
    PlaceObjectOnGroundProperly(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    return ped
end

local function SetupStoreTargets()
    for k, v in pairs(Config.Stores) do
        local targetConfig = Config.TargetConfig[v.shopType]
        local action

        if v.shopType == 'barber' then
            action = OpenBarberShop
        elseif v.shopType == 'clothing' then
            action = function()
                TriggerEvent("fivem-appearance:client:openClothingShopMenu")
            end
        elseif v.shopType == 'tattoo' then
            action = OpenTattooShop
        elseif v.shopType == 'surgeon' then
            action = OpenSurgeonShop
        end

        local parameters = {
            options = {{
                type = "client",
                action = action,
                icon = targetConfig.icon,
                label = targetConfig.label
            }},
            distance = targetConfig.distance
        }

        if Config.EnablePedsForShops then
            TargetPeds.Store[k] = CreatePedAtCoords(targetConfig.model, v.coords, targetConfig.scenario)
            exports['qb-target']:AddTargetEntity(TargetPeds.Store[k], parameters)
        else
            exports['qb-target']:AddBoxZone(v.shopType .. k, v.coords, v.length, v.width, {
                name = v.shopType .. k,
                debugPoly = Config.Debug,
                minZ = v.coords.z - 1,
                maxZ = v.coords.z + 1,
                heading = v.coords.w
            }, parameters)
        end
    end
end

local function SetupClothingRoomTargets()
    for k, v in pairs(Config.ClothingRooms) do
        local targetConfig = Config.TargetConfig["clothingroom"]
        local action = function()
            local outfits = getPlayerJobOutfits(v)
            TriggerEvent('fivem-appearance:client:openJobOutfitsMenu', outfits)
        end

        local parameters = {
            options = {{
                type = "client",
                action = action,
                icon = targetConfig.icon,
                label = targetConfig.label,
                canInteract = CheckDuty,
                job = v.requiredJob
            }},
            distance = targetConfig.distance
        }

        if Config.EnablePedsForClothingRooms then
            TargetPeds.ClothingRoom[k] = CreatePedAtCoords(targetConfig.model, v.coords, targetConfig.scenario)
            exports['qb-target']:AddTargetEntity(TargetPeds.ClothingRoom[k], parameters)
        else
            exports['qb-target']:AddBoxZone('clothing_' .. v.requiredJob .. k, v.coords, v.length, v.width, {
                name = 'clothing_' .. v.requiredJob .. k,
                debugPoly = Config.Debug,
                minZ = v.coords.z - 2,
                maxZ = v.coords.z + 2
            }, parameters)
        end
    end
end

local function SetupPlayerOutfitRoomTargets()
    for k, v in pairs(Config.PlayerOutfitRooms) do
        local targetConfig = Config.TargetConfig["playeroutfitroom"]

        local parameters = {
            options = {{
                type = "client",
                action = function()
                    OpenOutfitRoom(v)
                end,
                icon = targetConfig.icon,
                label = targetConfig.label,
                canInteract = function()
                    return isPlayerAllowedForOutfitRoom(v)
                end
            }},
            distance = targetConfig.distance
        }

        if Config.EnablePedsForClothingRooms then
            TargetPeds.PlayerOutfitRoom[k] = CreatePedAtCoords(targetConfig.model, v.coords, targetConfig.scenario)
            exports['qb-target']:AddTargetEntity(TargetPeds.ClothingRoom[k], parameters)
        else
            exports['qb-target']:AddBoxZone('playeroutfitroom_' .. k, v.coords, v.length, v.width, {
                name = 'playeroutfitroom_' .. k,
                debugPoly = Config.Debug,
                minZ = v.coords.z - 2,
                maxZ = v.coords.z + 2
            }, parameters)
        end
    end
end

local function SetupTargets()
    SetupStoreTargets()
    SetupClothingRoomTargets()
    SetupPlayerOutfitRoomTargets()
end

local function ZonesLoop()
    Wait(1000)
    while true do
        local sleep = 1000
        if inZone then
            sleep = 5
            if IsControlJustReleased(0, 38) then
                if string.find(zoneName, 'ClothingRooms_') then
                    local clothingRoom = Config.ClothingRooms[tonumber(string.sub(zoneName, 15))]
                    local outfits = getPlayerJobOutfits(clothingRoom)
                    TriggerEvent('fivem-appearance:client:openJobOutfitsMenu', outfits)
                elseif string.find(zoneName, 'PlayerOutfitRooms_') then
                    local outfitRoom = Config.PlayerOutfitRooms[tonumber(string.sub(zoneName, 19))]
                    OpenOutfitRoom(outfitRoom)
                elseif zoneName == 'clothing' then
                    TriggerEvent("fivem-appearance:client:openClothingShopMenu")
                elseif zoneName == 'barber' then
                    OpenBarberShop()
                elseif zoneName == 'tattoo' then
                    OpenTattooShop()
                elseif zoneName == 'surgeon' then
                    OpenSurgeonShop()
                end
            end
        end
        Wait(sleep)
    end
end

CreateThread(function()
    if Config.UseTarget then
        SetupTargets()
    else
        SetupZones()
        ZonesLoop()
    end
end)
