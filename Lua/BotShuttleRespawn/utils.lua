local BSR = ...

local reservedLockerSlots = {}

function BSR.ApplyDeathPenalty(info)
    local penalty = Game.ServerSettings and Game.ServerSettings.SkillLossPercentageOnDeath or 0
    print("[BotShuttleRespawn] Applying death penalty (" .. tostring(penalty) .. "%) to: " .. tostring(info.Name))
    if penalty > 0 and info.Job ~= nil then
        for skill in info.Job.GetSkills() do
            local oldLevel = skill.Level
            local loss = skill.Level * (penalty / 100.0)
            skill.Level = math.max(0, skill.Level - loss)
            print(string.format("[BotShuttleRespawn]   Skill %s: %.2f -> %.2f", tostring(skill.Identifier), oldLevel, skill.Level))
        end
    end
end

function BSR.ProvideShuttleDivingSuit(shuttle, character)
    if shuttle == nil or character == nil then
        print("[BotShuttleRespawn] ERROR: ProvideShuttleDivingSuit received nil shuttle or character!")
        return
    end

    local suitPrefab = ItemPrefab.GetItemPrefab("respawndivingsuit")
    if suitPrefab == nil then
        print("[BotShuttleRespawn] ERROR: Could not find respawndivingsuit prefab!")
        return
    end

    -- Aguarda 600ms para garantir que o cliente já carregou o shuttle na rede
    Timer.Wait(function()
        if shuttle == nil or shuttle.Removed or character == nil or character.Removed then
            return
        end

        -- Procura um armário de traje de mergulho com espaço livre dentro do shuttle
        local targetLocker = nil
        for _, item in pairs(Item.ItemList) do
            if item ~= nil and not item.Removed and item.Submarine == shuttle and item.OwnInventory ~= nil then
                local identifier = tostring(item.Prefab.Identifier)
                local hasTag = item.HasTag("divingsuitcontainer") or item.HasTag("diving")
                if hasTag or string.find(identifier, "divingsuitlocker") or string.find(identifier, "suitlocker") then
                    local currentCount = 0
                    for _ in item.OwnInventory.AllItems do
                        currentCount = currentCount + 1
                    end

                    local reserved = reservedLockerSlots[item] or 0
                    local freeSlots = item.OwnInventory.Capacity - currentCount - reserved
                    if freeSlots > 0 then
                        targetLocker = item
                        reservedLockerSlots[item] = reserved + 1
                        break
                    end
                end
            end
        end

        local spawnPos = targetLocker and targetLocker.WorldPosition or character.WorldPosition
        Entity.Spawner.AddItemToSpawnQueue(suitPrefab, spawnPos, nil, nil, function(spawnedSuit)
            if targetLocker ~= nil then
                reservedLockerSlots[targetLocker] = math.max(0, (reservedLockerSlots[targetLocker] or 1) - 1)
            end

            if targetLocker ~= nil and not targetLocker.Removed and spawnedSuit ~= nil then
                local ok = pcall(function()
                    targetLocker.OwnInventory.TryPutItem(spawnedSuit, nil)
                end)
                if ok then
                    print("[BotShuttleRespawn] SUCCESS: Placed disposable suit inside shuttle locker (" .. tostring(targetLocker.Name) .. ") for: " .. tostring(character.Name))
                    return
                end
            end

            print("[BotShuttleRespawn] SUCCESS: Placed disposable suit on shuttle floor next to: " .. tostring(character.Name))
        end)
    end, 600)
end

function BSR.SpawnBotBody(info, targetSubmarine)
    if info == nil or targetSubmarine == nil then
        print("[BotShuttleRespawn] ERROR: SpawnBotBody received nil info or targetSubmarine!")
        return nil
    end

    BSR.ApplyDeathPenalty(info)

    local spawnPoint = WayPoint.GetRandom(SpawnType.Human, info.Job and info.Job.Prefab, targetSubmarine)
    if spawnPoint == nil then
        spawnPoint = WayPoint.GetRandom(SpawnType.Human, nil, targetSubmarine)
    end
    local spawnPosition = spawnPoint and spawnPoint.WorldPosition or targetSubmarine.WorldPosition
    print("[BotShuttleRespawn] Spawning " .. tostring(info.Name) .. " at " .. tostring(spawnPosition) .. " (HasJobSpawnPoint: " .. tostring(spawnPoint ~= nil) .. ")")

    local newBot = Character.Create(info, spawnPosition, info.Name, 0, false, true)
    if newBot ~= nil then
        newBot.TeamID = CharacterTeamType.Team1

        if Game.GameSession and Game.GameSession.CrewManager then
            Game.GameSession.CrewManager.AddCharacter(newBot)
        end

        Timer.Wait(function()
            if newBot ~= nil and not newBot.Removed and not newBot.IsDead then
                pcall(function()
                    if info.Job ~= nil and info.Job.Prefab ~= nil then
                        local itemSets = info.Job.Prefab.ItemSets
                        if itemSets ~= nil and #itemSets > 0 then
                            info.Job.ItemSet = itemSets[1]
                        end
                    end
                end)

                newBot.GiveJobItems(false, nil)
                print("[BotShuttleRespawn] Basic job items delivered to: " .. tostring(newBot.Name))
            end
        end, 500)

        print("[BotShuttleRespawn] Character created and added to CrewManager: " .. tostring(newBot.Name))
    else
        print("[BotShuttleRespawn] ERROR: Character.Create returned nil for: " .. tostring(info.Name))
    end

    return newBot
end
