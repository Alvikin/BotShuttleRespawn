if CLIENT and not SERVER then return end

print("[BotShuttleRespawn] Mod loaded successfully (Debug Mode ON)!")

local allowFireCharacter = false

local function ApplyDeathPenalty(info)
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

local function GiveShuttleDivingSuit(bot)
    if bot == nil or bot.Inventory == nil then
        print("[BotShuttleRespawn] ERROR: GiveShuttleDivingSuit received nil bot or Inventory!")
        return
    end

    local suitPrefab = ItemPrefab.GetItemPrefab("respawndivingsuit") or ItemPrefab.GetItemPrefab("divingsuit")
    if suitPrefab == nil then
        print("[BotShuttleRespawn] ERROR: Could not find diving suit prefab!")
        return
    end

    -- Aguarda 500ms (junto com os itens da classe) para garantir que o inventário já esteja pronto
    Timer.Wait(function()
        if bot == nil or bot.Removed or bot.IsDead or bot.Inventory == nil then return end

        Entity.Spawner.AddItemToSpawnQueue(suitPrefab, bot.Inventory, nil, nil, function(spawnedSuit)
            if spawnedSuit ~= nil and bot ~= nil and not bot.Removed and not bot.IsDead then
                local oxygenPrefab = ItemPrefab.GetItemPrefab("oxygentank")
                if oxygenPrefab ~= nil and spawnedSuit.OwnInventory ~= nil and spawnedSuit.OwnInventory.IsEmpty() then
                    Entity.Spawner.AddItemToSpawnQueue(oxygenPrefab, spawnedSuit.OwnInventory)
                end

                bot.Inventory.TryPutItem(spawnedSuit, nil, { InvSlotType.OuterClothes })
                print("[BotShuttleRespawn] SUCCESS: Equipped diving suit + oxygen directly onto bot: " .. tostring(bot.Name))
            end
        end)
    end, 600)
end

local function SpawnBotBody(info, targetSubmarine)
    if info == nil or targetSubmarine == nil then
        print("[BotShuttleRespawn] ERROR: SpawnBotBody received nil info or targetSubmarine!")
        return nil
    end

    ApplyDeathPenalty(info)

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

Hook.Patch(
    "Barotrauma.CrewManager",
    "RemoveCharacterInfo",
    function(instance, ptable)
        local targetInfo = ptable["characterInfo"]
        local infoName = targetInfo and targetInfo.Name or "Unknown"

        if not allowFireCharacter then
            ptable.PreventExecution = true
            print("[BotShuttleRespawn] Prevented deletion of CharacterInfo for: " .. tostring(infoName))
        else
            print("[BotShuttleRespawn] Allowed deletion (fired) of CharacterInfo for: " .. tostring(infoName))
        end
        allowFireCharacter = false
        return nil
    end,
    Hook.HookMethodType.Before
)

Hook.Patch(
    "Barotrauma.CrewManager",
    "FireCharacter",
    function(instance, ptable)
        allowFireCharacter = true
        print("[BotShuttleRespawn] FireCharacter triggered!")
    end,
    Hook.HookMethodType.Before
)

Hook.Patch(
    "Barotrauma.Networking.RespawnManager",
    "DispatchShuttle",
    function(instance, ptable)
        print("[BotShuttleRespawn] === DispatchShuttle triggered! ===")

        if Game.GameSession == nil or Game.GameSession.CrewManager == nil then
            print("[BotShuttleRespawn] ERROR: GameSession or CrewManager is nil!")
            return
        end

        local crewManager = Game.GameSession.CrewManager

        local shuttle = nil
        for _, sub in pairs(Submarine.Loaded) do
            if sub ~= nil and sub ~= Submarine.MainSub then
                local subType = sub.Info and tostring(sub.Info.Type) or "nil"
                if subType == "RespawnShuttle" then
                    shuttle = sub
                    break
                end
            end
        end

        if shuttle == nil then
            for _, client in pairs(Client.ClientList) do
                if client.Character ~= nil and not client.Character.IsDead and client.Character.Submarine ~= nil and client.Character.Submarine ~= Submarine.MainSub then
                    shuttle = client.Character.Submarine
                    print("[BotShuttleRespawn] Found shuttle via respawned player: " .. tostring(shuttle.Info and shuttle.Info.Name or "Unknown"))
                    break
                end
            end
        end

        if shuttle == nil then
            print("[BotShuttleRespawn] ERROR: Could not find respawn shuttle!")
            return
        end

        local respawnedBots = 0

        for _, info in pairs(crewManager.GetCharacterInfos()) do
            local isPlayer = false
            for _, client in pairs(Client.ClientList) do
                if client.CharacterInfo == info then
                    isPlayer = true
                    break
                end
            end

            local charState = "NoBody"
            if info.Character ~= nil then
                charState = info.Character.IsDead and "DeadBody" or "AliveBody"
            end
            print("[BotShuttleRespawn] CrewManager Queue -> Name: " .. tostring(info.Name) .. " | IsPlayer: " .. tostring(isPlayer) .. " | State: " .. charState)

            if not isPlayer and info ~= nil and (info.Character == nil or info.Character.IsDead) then
                if info.Character ~= nil then
                    info.Character.Info = nil
                    info.Character = nil
                end

                local newBot = SpawnBotBody(info, shuttle)
                if newBot ~= nil then
                    GiveShuttleDivingSuit(newBot)
                    respawnedBots = respawnedBots + 1
                    print("[BotShuttleRespawn] SUCCESS: Created new body + equipped suit on shuttle for: " .. info.Name)
                end
            end
        end

        print("[BotShuttleRespawn] Total bots respawned on shuttle: " .. respawnedBots)
    end,
    Hook.HookMethodType.After
)

Hook.Add(
    "roundStart",
    "RespawnBotsOnLevelTransition",
    function()
        Timer.Wait(function()
            print("[BotShuttleRespawn] === Level Transition (roundStart) check ===")
            if Submarine.MainSub == nil or Game.GameSession == nil or Game.GameSession.CrewManager == nil then
                print("[BotShuttleRespawn] ERROR: Missing MainSub, GameSession, or CrewManager on roundStart!")
                return
            end

            local crewManager = Game.GameSession.CrewManager
            local respawnedBots = 0
            local reequippedBots = 0

            for _, info in pairs(crewManager.GetCharacterInfos()) do
                local isPlayer = false
                for _, client in pairs(Client.ClientList) do
                    if client.CharacterInfo == info then
                        isPlayer = true
                        break
                    end
                end

                local charState = "NoBody"
                if info.Character ~= nil then
                    charState = info.Character.IsDead and "DeadBody" or "AliveBody"
                end
                print("[BotShuttleRespawn] Transition Queue -> Name: " .. tostring(info.Name) .. " | IsPlayer: " .. tostring(isPlayer) .. " | State: " .. charState)

                if not isPlayer and info ~= nil then
                    -- Caso 1: O bot continua morto ou sem corpo -> cria um novo corpo com itens
                    if info.Character == nil or info.Character.IsDead then
                        if info.Character ~= nil then
                            info.Character.Info = nil
                            info.Character = nil
                        end

                        if SpawnBotBody(info, Submarine.MainSub) ~= nil then
                            respawnedBots = respawnedBots + 1
                            print("[BotShuttleRespawn] SUCCESS: Respawned bot on level transition: " .. info.Name)
                        end

                    -- Caso 2: O jogo base reviveu o bot na estação, mas deixou ele sem uniforme/itens
                    elseif info.Character.Inventory ~= nil then
                        local hasClothes = info.Character.Inventory.GetItemInLimbSlot(InvSlotType.InnerClothes) ~= nil
                        local isEmpty = info.Character.Inventory.IsEmpty()

                        print("[BotShuttleRespawn]   Inventory check for " .. tostring(info.Name) .. " -> IsEmpty: " .. tostring(isEmpty) .. " | HasInnerClothes: " .. tostring(hasClothes))

                        if isEmpty or not hasClothes then
                            info.Character.GiveJobItems(false, nil)
                            reequippedBots = reequippedBots + 1
                            print("[BotShuttleRespawn] SUCCESS: Delivered missing job items on station to: " .. info.Name)
                        end
                    end
                end
            end

            print("[BotShuttleRespawn] Total bots respawned: " .. respawnedBots .. " | Total bots re-equipped: " .. reequippedBots)
        end, 3000)
    end
)

Game.AddCommand(
    "crewstatus",
    "Lists all crew members, their alive/dead status, and saved CharacterInfo IDs.",
    function(args)
        print("=== [BotShuttleRespawn] CREW STATUS REPORT ===")

        if Game.GameSession and Game.GameSession.CrewManager then
            print("--- Saved CharacterInfos in CrewManager ---")
            for _, info in pairs(Game.GameSession.CrewManager.GetCharacterInfos()) do
                local bodyState = "NoBody (Queued)"
                if info.Character ~= nil then
                    bodyState = info.Character.IsDead and "DeadBody" or "AliveBody"
                end

                local isPlayer = false
                for _, client in pairs(Client.ClientList) do
                    if client.CharacterInfo == info then
                        isPlayer = true
                        break
                    end
                end

                print(string.format(
                    "Name: %s | Type: %s | InfoID: %s | Body: %s",
                    tostring(info.Name),
                    isPlayer and "Player" or "Bot",
                    tostring(info.ID),
                    bodyState
                ))
            end
        else
            print("No active GameSession or CrewManager.")
        end

        print("--- Active/Dead Characters in World (CharacterList) ---")
        for _, c in pairs(Character.CharacterList) do
            if c.TeamID == CharacterTeamType.Team1 and c.IsHuman then
                print(string.format(
                    "Name: %s | IsBot: %s | IsDead: %s | HasInfo: %s | InfoID: %s",
                    tostring(c.Name),
                    tostring(c.IsBot),
                    tostring(c.IsDead),
                    tostring(c.Info ~= nil),
                    tostring(c.Info and c.Info.ID or "nil")
                ))
            end
        end

        print("==============================================")
    end
)