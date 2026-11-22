local BSR = ...

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

function BSR.ProvideShuttleDivingSuit(shuttle, bot)
    if shuttle == nil or bot == nil then
        print("[BotShuttleRespawn] ERROR: ProvideShuttleDivingSuit received nil shuttle or bot!")
        return
    end

    local suitPrefab = ItemPrefab.GetItemPrefab("respawndivingsuit") or ItemPrefab.GetItemPrefab("divingsuit")
    if suitPrefab == nil then
        print("[BotShuttleRespawn] ERROR: Could not find diving suit prefab!")
        return
    end

    -- Procura um armário de traje de mergulho ou contêiner compatível com espaço livre dentro do shuttle
    local targetContainer = nil
    for _, item in pairs(Item.ItemList) do
        if item ~= nil and not item.Removed and item.Submarine == shuttle and item.OwnInventory ~= nil then
            local identifier = tostring(item.Prefab.Identifier)
            local hasTag = item.HasTag("divingsuitcontainer") or item.HasTag("diving")
            if hasTag or string.find(identifier, "divingsuitlocker") or string.find(identifier, "suitlocker") then
                if not item.OwnInventory.IsFull(false) and item.OwnInventory.CanBePut(suitPrefab) then
                    targetContainer = item
                    break
                end
            end
        end
    end

    if targetContainer ~= nil then
        Entity.Spawner.AddItemToSpawnQueue(suitPrefab, targetContainer.OwnInventory, nil, nil, function(spawnedSuit)
            print("[BotShuttleRespawn] SUCCESS: Placed disposable diving suit inside shuttle container (" .. tostring(targetContainer.Name) .. ") for: " .. tostring(bot.Name))
        end)
    else
        local dropPos = bot.WorldPosition
        Entity.Spawner.AddItemToSpawnQueue(suitPrefab, dropPos, nil, nil, function(spawnedSuit)
            print("[BotShuttleRespawn] SUCCESS: No free suit locker on shuttle; dropped disposable diving suit on floor next to: " .. tostring(bot.Name))
        end)
    end
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
                -- Força o kit básico padrão (índice 0) no respawn para evitar farm de armas avançadas
                if info.Job ~= nil then
                    info.Job.PreferredItemSet = 0
                end
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