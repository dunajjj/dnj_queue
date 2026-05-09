local bt = "" -- bot token (https://discord.com/developers/applications)

local queue = {}

local function discordhook(source)
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if string.sub(id, 1, 8) == "discord:" then
            return string.sub(id, 9)
        end
    end
    return nil
end

local function squeue()
    table.sort(queue, function(a, b)
        return a.points > b.points
    end)
end

local function queuecard(deferrals,message)
    local card = {
        type = "AdaptiveCard",
        version = "1.2",
        body = {
            {
                type = "Image",
                url = dnj.queueimage,
                horizontalAlignment = "Center",
                size = "Large"
            },
            {
                type = "TextBlock",
                text = message,
                wrap = true,
                horizontalAlignment = "Center",
                weight = "Bolder",
                size = "Medium"
            }
        }
    }
    deferrals.presentCard(card, function() end)
end

AddEventHandler('playerConnecting', function(name,deferrals)
    local source = source
    local discordid = discordhook(source)
    local maxplayers = GetConvarInt('sv_maxplayers', dnj.maxplayers )

    deferrals.defer()
    
    Wait(0)

    deferrals.update("Queue se načítá...")
    Wait(50) 

    queuecard(deferrals, "Ověřuji tvé priority body...")
    Wait(1500)

    if not discordid then
        deferrals.done("Pro připojení musíš mít zapnutý Discord.")
        return
    end

    PerformHttpRequest("https://discord.com/api/v10/guilds/" .. dnj.guildid .. "/members/" .. discordid, function(err, text, headers)
        local points = 0
        
        if err == 200 then
            local data = json.decode(text)
            if data and data.roles then
                for _, roleid in pairs(data.roles) do
                    if dnj.priorityroles[roleid] then
                        points = points + dnj.priorityroles[roleid]
                    end
                end
            end
        end

        queuecard(deferrals, "Tvé body: " .. points .. "\nPřipravuji relaci, čekej prosím...")
        
        Wait(6500)

        local crplayers = GetNumPlayerIndices()

        if crplayers < maxplayers then
            deferrals.done()
        else
            table.insert(queue, {
                source = source,
                name = name,
                points = points,
                deferrals = deferrals,
                discordid = discordid
            })
            squeue()
        end

    end, "GET", "", {["Authorization"] = "Bot " .. bt})
end)

CreateThread(function()
    while true do
        Wait(2000)

        if #queue > 0 then
            local maxplayers = GetConvarInt('sv_maxplayers', dnj.maxplayers) 
            local crplayers = GetNumPlayerIndices()
            
            if crplayers < maxplayers then
                local nextplayer = table.remove(queue, 1)
                if nextplayer then
                    nextplayer.deferrals.done()
                end
            end

            for i, player in ipairs(queue) do
                queuecard(player.deferrals, "Server je plný.\nJsi v řadě na pozici: " .. i .. "/" .. #queue .. "\nTvé prioritní body: " .. player.points)
            end
        end
    end
end)

AddEventHandler('playerDropped', function(reason)
    local source = source
    for i, player in ipairs(queue) do
        if player.source == source then
            table.remove(queue, i)
            break
        end
    end
end)