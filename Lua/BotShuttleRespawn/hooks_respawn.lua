local BSR = ...

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

        local newlyRespawnedBots = {}

        -- Etapa 1: Revive todos os bots mortos e entrega os itens básicos da função
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

                local newBot = BSR.SpawnBotBody(info, shuttle)
                if newBot ~= nil then
                    table.insert(newlyRespawnedBots, newBot)
                    print("[BotShuttleRespawn] SUCCESS: Created new body on shuttle for: " .. info.Name)
                end
            end
        end

        -- Etapa 2: Gera 1 traje descartável (respawndivingsuit) exclusivamente para cada bot que acabou de renascer
        for _, bot in ipairs(newlyRespawnedBots) do
            BSR.ProvideShuttleDivingSuit(shuttle, bot)
        end

        print("[BotShuttleRespawn] Total bots respawned on shuttle: " .. tostring(#newlyRespawnedBots))
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

                        if BSR.SpawnBotBody(info, Submarine.MainSub) ~= nil then
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
