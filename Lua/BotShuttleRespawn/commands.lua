local BSR = ...

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