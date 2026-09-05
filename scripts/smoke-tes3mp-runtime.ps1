param(
    [Parameter(Mandatory = $true)]
    [string]$BuildDir,

    [string]$Configuration = "RelWithDebInfo",

    [int]$TimeoutSeconds = 12,

    [switch]$WithLocalMaster,

    [Alias("BrowserProbeIterations")]
    [int]$HubProbeIterations = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"


function Resolve-BuiltExecutable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $candidates = @(
        (Join-Path (Join-Path $BuildDir $Configuration) $Name),
        (Join-Path $BuildDir $Name)
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Could not find $Name in $BuildDir or $BuildDir\$Configuration"
}

function Stop-SmokeProcess {
    param($Process)

    if ($null -ne $Process -and -not $Process.HasExited) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
    }
}

function Read-SmokeLog {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        return (Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue | Select-Object -First 160) -join "`n"
    }

    return ""
}

$serverExe = Resolve-BuiltExecutable "communitymp-server.exe"
$masterExe = $null
$hubExe = $null
if ($WithLocalMaster) {
    if ($HubProbeIterations -lt 1) {
        throw "HubProbeIterations must be at least 1 when WithLocalMaster is enabled."
    }

    $masterExe = Resolve-BuiltExecutable "masterserver.exe"
    $hubExe = Resolve-BuiltExecutable "communitymp-hub.exe"
}

$runtimeDir = Split-Path -Parent $serverExe
$configDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "My Games\OpenMW"
if (Test-Path -LiteralPath (Join-Path $runtimeDir "openmw.cfg") -PathType Leaf) {
    $openMwConfigText = Get-Content -LiteralPath (Join-Path $runtimeDir "openmw.cfg") -Raw
    if ($openMwConfigText -match "(?m)^\s*config\s*=\s*`"?config`"?\s*$") {
        $configDir = Join-Path $runtimeDir "config"
    }
}
$serverConfig = Join-Path $configDir "communitymp-server.cfg"
$configBackup = Join-Path $env:TEMP "communitymp-server.cfg.smoke.bak"
$serverOut = Join-Path $env:TEMP "tes3mp-server-smoke.out.log"
$serverErr = Join-Path $env:TEMP "tes3mp-server-smoke.err.log"
$masterOut = Join-Path $env:TEMP "tes3mp-master-smoke.out.log"
$masterErr = Join-Path $env:TEMP "tes3mp-master-smoke.err.log"
$hubOut = Join-Path $env:TEMP "communitymp-hub-query-smoke.out.log"
$hubErr = Join-Path $env:TEMP "communitymp-hub-query-smoke.err.log"
$customScriptsConfig = Join-Path $runtimeDir "server\scripts\customScripts.lua"
$customScriptsBackup = Join-Path $env:TEMP "tes3mp-customScripts-smoke.bak"
$timerSmokeScript = Join-Path $runtimeDir "server\scripts\custom\timerSmoke.lua"
$timerSmokeResult = Join-Path $runtimeDir "server\data\timer-smoke.txt"
$globalCallbackSmokeScript = Join-Path $runtimeDir "server\scripts\custom\globalCallbackSmoke.lua"
$globalCallbackSmokeResult = Join-Path $runtimeDir "server\data\global-callback-smoke.txt"
$jsonPlayerSmokeScript = Join-Path $runtimeDir "server\scripts\custom\jsonPlayerSmoke.lua"
$jsonPlayerSmokeResult = Join-Path $runtimeDir "server\data\json-player-smoke.txt"
$jsonPlayerRestartSmokeScript = Join-Path $runtimeDir "server\scripts\custom\jsonPlayerRestartSmoke.lua"
$jsonPlayerRestartSmokeResult = Join-Path $runtimeDir "server\data\json-player-restart-smoke.txt"
$jsonPlayerSmokeAccount = "JsonSmoke" + [guid]::NewGuid().ToString("N")
$jsonPlayerSmokeFile = Join-Path $runtimeDir "server\data\saves\$jsonPlayerSmokeAccount\account.xml"
$accountFlowSmokeScript = Join-Path $runtimeDir "server\scripts\custom\accountFlowSmoke.lua"
$accountFlowSmokeResult = Join-Path $runtimeDir "server\data\account-flow-smoke.txt"
$accountFlowRestartSmokeScript = Join-Path $runtimeDir "server\scripts\custom\accountFlowRestartSmoke.lua"
$accountFlowRestartSmokeResult = Join-Path $runtimeDir "server\data\account-flow-restart-smoke.txt"
$accountFlowSmokeAccount = "AccountFlow" + [guid]::NewGuid().ToString("N")
$accountFlowSmokeCharacter = "Character" + [guid]::NewGuid().ToString("N")
$accountFlowSmokeFile = Join-Path $runtimeDir "server\data\saves\$accountFlowSmokeAccount\account.xml"
$deathFlowSmokeScript = Join-Path $runtimeDir "server\scripts\custom\deathFlowSmoke.lua"
$deathFlowSmokeResult = Join-Path $runtimeDir "server\data\death-flow-smoke.txt"
$deathFlowRestartSmokeScript = Join-Path $runtimeDir "server\scripts\custom\deathFlowRestartSmoke.lua"
$deathFlowRestartSmokeResult = Join-Path $runtimeDir "server\data\death-flow-restart-smoke.txt"
$deathFlowSmokeAccount = "DeathFlow" + [guid]::NewGuid().ToString("N")
$deathFlowSmokeFile = Join-Path $runtimeDir "server\data\saves\$deathFlowSmokeAccount\account.xml"
$disconnectFlowSmokeScript = Join-Path $runtimeDir "server\scripts\custom\disconnectFlowSmoke.lua"
$disconnectFlowSmokeResult = Join-Path $runtimeDir "server\data\disconnect-flow-smoke.txt"
$disconnectFlowRestartSmokeScript = Join-Path $runtimeDir "server\scripts\custom\disconnectFlowRestartSmoke.lua"
$disconnectFlowRestartSmokeResult = Join-Path $runtimeDir "server\data\disconnect-flow-restart-smoke.txt"
$disconnectFlowSmokeAccount = "DisconnectFlow" + [guid]::NewGuid().ToString("N")
$disconnectFlowSmokeFile = Join-Path $runtimeDir "server\data\saves\$disconnectFlowSmokeAccount\account.xml"

$server = $null
$master = $null
$hadUserConfig = Test-Path -LiteralPath $serverConfig

Remove-Item -LiteralPath $configBackup, $serverOut, $serverErr, $masterOut, $masterErr, $hubOut, $hubErr, $customScriptsBackup, $timerSmokeResult, $globalCallbackSmokeResult, $jsonPlayerSmokeResult, $jsonPlayerRestartSmokeResult, $jsonPlayerSmokeFile, $accountFlowSmokeResult, $accountFlowRestartSmokeResult, $accountFlowSmokeFile, $deathFlowSmokeResult, $deathFlowRestartSmokeResult, $deathFlowSmokeFile, $disconnectFlowSmokeResult, $disconnectFlowRestartSmokeResult, $disconnectFlowSmokeFile -ErrorAction SilentlyContinue

try {

    if (-not (Test-Path -LiteralPath $customScriptsConfig -PathType Leaf)) {
        throw "Could not install timer smoke script: missing customScripts.lua at $customScriptsConfig"
    }

    Copy-Item -LiteralPath $customScriptsConfig -Destination $customScriptsBackup -Force
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $timerSmokeScript) | Out-Null
    @'
local timerSmoke = {}

local resultPath = "server/data/timer-smoke.txt"

function TimerSmokeCallback(text, number, value)
    local file = io.open(resultPath, "w")
    if file ~= nil then
        file:write(text .. "|" .. tostring(number) .. "|" .. tostring(value))
        file:close()
    end
end

customEventHooks.registerHandler("OnServerPostInit", function(eventStatus)
    local timerId = tes3mp.CreateTimerEx("TimerSmokeCallback", 10, "sif", "timer-smoke", 42, 3.25)
    tes3mp.StartTimer(timerId)
end)

return timerSmoke
'@ | Set-Content -LiteralPath $timerSmokeScript -Encoding ASCII
    Add-Content -LiteralPath $customScriptsConfig -Encoding ASCII -Value "`r`nrequire(`"custom/timerSmoke`")"

    @'
local resultPath = "server/data/global-callback-smoke.txt"

local function appendLine(text)
    local file = io.open(resultPath, "a")
    if file ~= nil then
        file:write(text .. "\n")
        file:close()
    end
end

function OnServerInit()
    appendLine("OnServerInit")
end

function OnServerPostInit()
    appendLine("OnServerPostInit")
end
'@ | Set-Content -LiteralPath $globalCallbackSmokeScript -Encoding ASCII

    @"
local resultPath = "server/data/account-flow-smoke.txt"
local accountName = "$accountFlowSmokeAccount"
local characterName = "$accountFlowSmokeCharacter"
local clientPasswordHash = "client-password-hash"
local badClientPasswordHash = "bad-client-password-hash"
local pid = 41
local relogPid = 42
local badRelogPid = 43

local function writeResult(text)
    local file = io.open(resultPath, "w")
    if file ~= nil then
        file:write(text)
        file:close()
    end
end

local function fail(message)
    writeResult("FAIL|" .. message)
    error(message)
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        fail(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertInventoryCount(data, refId, expectedCount, message)
    local count = 0

    if type(data.inventory) == "table" then
        for _, item in pairs(data.inventory) do
            if type(item) == "table" and item.refId == refId then
                count = count + (item.count or 0)
            end
        end
    end

    assertEqual(count, expectedCount, message)
end

local function assertJournalEntry(data, quest, index, message)
    if type(data.journal) == "table" then
        for _, journalItem in pairs(data.journal) do
            if type(journalItem) == "table" and type(journalItem.quest) == "string" and
                string.lower(journalItem.quest) == string.lower(quest) and journalItem.index == index then
                return
            end
        end
    end

    fail(message)
end

local function assertTopic(data, topicId, message)
    if type(data.topics) == "table" and tableHelper.containsValue(data.topics, topicId, false) then
        return
    end

    fail(message)
end

local function removePidFromIpTracking(targetPid)
    if pidsByIpAddress == nil then
        return
    end

    for _, pids in pairs(pidsByIpAddress) do
        if tableHelper.containsValue(pids, targetPid) then
            tableHelper.removeValue(pids, targetPid)
        end
    end
end

local function runSmoke()
    local patched = {}
    local configSnapshot = {}
    local realPlayer = Player
    local realGetPlayerPacketTables = packetReader.GetPlayerPacketTables
    local counts = {
        connect = 0,
        endCharGen = 0,
        finishLogin = 0,
        auth = 0,
        charGenStage = 0,
        loginPrompt = 0,
        registerPrompt = 0,
        characterList = 0,
        handshakeClear = 0
    }

    local function patch(tableRef, key, value)
        table.insert(patched, { tableRef, key, tableRef[key] })
        tableRef[key] = value
    end

    local function noop()
    end

    local function patchConfig()
        for _, key in ipairs({
            "recordStoreLoadOrder",
            "useInstancedSpawn",
            "noninstancedSpawn",
            "defaultRespawn",
            "maxClientsPerIP",
            "shareJournal",
            "shareFactionRanks",
            "shareFactionExpulsion",
            "shareFactionReputation",
            "shareTopics",
            "shareBounty",
            "shareReputation",
            "shareKills",
            "shareMapExploration"
        }) do
            configSnapshot[key] = config[key]
        end

        config.recordStoreLoadOrder = {{}}
        config.useInstancedSpawn = false
        config.noninstancedSpawn = nil
        config.defaultRespawn = nil
        config.maxClientsPerIP = 8

        for _, key in ipairs({
            "shareJournal",
            "shareFactionRanks",
            "shareFactionExpulsion",
            "shareFactionReputation",
            "shareTopics",
            "shareBounty",
            "shareReputation",
            "shareKills",
            "shareMapExploration"
        }) do
            config[key] = false
        end
    end

    local function restore()
        for index = #patched, 1, -1 do
            local entry = patched[index]
            entry[1][entry[2]] = entry[3]
        end

        for key, value in pairs(configSnapshot) do
            config[key] = value
        end

        packetReader.GetPlayerPacketTables = realGetPlayerPacketTables
        Player = realPlayer
        Players[pid] = nil
        Players[relogPid] = nil
        Players[badRelogPid] = nil
        removePidFromIpTracking(pid)
        removePidFromIpTracking(relogPid)
        removePidFromIpTracking(badRelogPid)
    end

    patchConfig()

    patch(tes3mp, "GenerateRandomString", function(length)
        if length ~= 64 then
            fail("unexpected salt length")
        end
        return "runtime-salt"
    end)
    patch(tes3mp, "GetSHA256Hash", function(value)
        return "hash:" .. tostring(value)
    end)
    patch(tes3mp, "GetHandshakePasswordHash", function(requestPid)
        if requestPid == badRelogPid then
            return badClientPasswordHash
        end

        if requestPid ~= pid and requestPid ~= relogPid then
            fail("unexpected handshake pid")
        end

        return clientPasswordHash
    end)
    patch(tes3mp, "ClearHandshakePasswordHash", function(requestPid)
        if requestPid ~= pid and requestPid ~= relogPid and requestPid ~= badRelogPid then
            fail("unexpected handshake clear pid")
        end
        counts.handshakeClear = counts.handshakeClear + 1
    end)
    patch(tes3mp, "CreateTimerEx", function()
        return 9001
    end)
    patch(tes3mp, "StartTimer", noop)
    patch(tes3mp, "StopTimer", noop)
    patch(tes3mp, "GetIP", function(requestPid)
        return "127.0.0." .. tostring(requestPid)
    end)
    patch(tes3mp, "GetName", function(requestPid)
        if requestPid ~= pid then
            fail("unexpected character-name pid")
        end
        return characterName
    end)
    patch(tes3mp, "GetRace", function() return "dark elf" end)
    patch(tes3mp, "GetHead", function() return "b_n_dark elf_m_head_01" end)
    patch(tes3mp, "GetHair", function() return "b_n_dark elf_m_hair_01" end)
    patch(tes3mp, "GetBirthsign", function() return "the lady" end)
    patch(tes3mp, "GetIsMale", function() return 0 end)
    patch(tes3mp, "GetModel", function() return "" end)
    patch(tes3mp, "IsWerewolf", function() return false end)

    for _, name in ipairs({
        "SendMessage",
        "LogAppend",
        "SetDifficulty",
        "SetConsoleAllowed",
        "SetBedRestAllowed",
        "SetWildernessRestAllowed",
        "SetWaitAllowed",
        "SetPhysicsFramerate",
        "SetEnforcedLogLevel",
        "SendSettings",
        "SetPlayerCollisionState",
        "SetActorCollisionState",
        "SetPlacedObjectCollisionState",
        "UseActorCollisionForPlacedObjects",
        "SetName",
        "SetRace",
        "SetHead",
        "SetHair",
        "SetIsMale",
        "SetModel",
        "SetBirthsign",
        "SendBaseInfo",
        "SetCharGenStage",
        "SetCell",
        "SetCellChangeReason",
        "SetPos",
        "SetRot",
        "SendCell",
        "SendPos",
        "ClearInventoryChanges",
        "SetInventoryChangesAction",
        "AddItemChange",
        "SendInventoryChanges",
        "ClearJournalChanges",
        "AddJournalEntry",
        "AddJournalEntryWithTimestamp",
        "AddJournalIndex",
        "AddJournalFinished",
        "SendJournalChanges",
        "ClearTopicChanges",
        "AddTopic",
        "SendTopicChanges"
    }) do
        patch(tes3mp, name, function(...)
            if name == "SetCharGenStage" then
                counts.charGenStage = counts.charGenStage + 1
            end
        end)
    end

    patch(guiHelper, "ShowLogin", function(requestPid)
        if requestPid ~= badRelogPid then
            fail("unexpected login prompt pid")
        end
        counts.loginPrompt = counts.loginPrompt + 1
    end)
    patch(guiHelper, "ShowRegister", function()
        counts.registerPrompt = counts.registerPrompt + 1
    end)
    patch(guiHelper, "ShowCharacterList", function(requestPid)
        if requestPid ~= pid and requestPid ~= relogPid then
            fail("unexpected character list pid")
        end

        local player = Players[requestPid]
        if player == nil then
            fail("character list player missing")
        end

        if requestPid == pid then
            assertEqual(player:GetCharacterSlotCount(), 0, "registration character list slot count")
        else
            assertEqual(player:GetCharacterSlotCount(), 1, "character list slot count")
            assertEqual(player:GetCharacterSlotName(1), characterName, "character list slot name")
        end

        counts.characterList = counts.characterList + 1
    end)

    patch(logicHandler, "SendClientScriptDisables", noop)
    patch(logicHandler, "SendClientScriptSettings", noop)
    patch(logicHandler, "SendConfigCollisionOverrides", noop)
    patch(logicHandler, "LoadRegionForPlayer", noop)
    patch(logicHandler, "GetLoggedInPlayerByName", function()
        return nil
    end)

    patch(WorldInstance, "LoadTime", noop)
    patch(WorldInstance, "LoadWeather", noop)
    patch(WorldInstance, "LoadJournal", noop)
    patch(WorldInstance, "LoadFactionRanks", noop)
    patch(WorldInstance, "LoadFactionExpulsion", noop)
    patch(WorldInstance, "LoadFactionReputation", noop)
    patch(WorldInstance, "LoadTopics", noop)
    patch(WorldInstance, "LoadBounty", noop)
    patch(WorldInstance, "LoadReputation", noop)
    patch(WorldInstance, "LoadKills", noop)
    patch(WorldInstance, "LoadMap", noop)
    patch(WorldInstance, "LoadClientScriptVariables", noop)
    patch(WorldInstance, "LoadDestinationOverrides", noop)
    patch(WorldInstance, "HasRunStartupScripts", function()
        return true
    end)

    packetReader.GetPlayerPacketTables = function(requestPid, packetType)
        if requestPid ~= pid then
            fail("unexpected packet pid")
        end

        if packetType == "PlayerClass" then
            return {
                character = {
                    class = "warrior",
                    defaultClassState = 1
                }
            }
        elseif packetType == "PlayerStatsDynamic" then
            return {
                stats = {
                    healthBase = 45,
                    magickaBase = 50,
                    fatigueBase = 60,
                    healthCurrent = 45,
                    magickaCurrent = 50,
                    fatigueCurrent = 60
                }
            }
        elseif packetType == "PlayerEquipment" then
            return { equipment = {} }
        end

        fail("unexpected packet type " .. tostring(packetType))
    end

    Player = function(requestPid, playerName)
        local player = realPlayer(requestPid, playerName)

        for _, methodName in ipairs({
            "LoadSettings",
            "LoadClass",
            "LoadLevel",
            "LoadAttributes",
            "LoadSkills",
            "LoadStatsDynamic",
            "CleanInventory",
            "LoadInventory",
            "LoadEquipment",
            "CleanSpellbook",
            "LoadSpellbook",
            "LoadSpellsActive",
            "LoadCooldowns",
            "LoadQuickKeys",
            "LoadBooks",
            "LoadShapeshift",
            "LoadMarkLocation",
            "LoadSelectedSpell",
            "LoadSelectedEnchantedItem",
            "LoadJournal",
            "LoadFactionRanks",
            "LoadFactionExpulsion",
            "LoadFactionReputation",
            "LoadTopics",
            "LoadBounty",
            "LoadReputation",
            "LoadKills",
            "LoadSpecialStates",
            "LoadMap",
            "LoadClientScriptVariables",
            "LoadDestinationOverrides",
            "LoadAllies",
            "LoadCell",
            "RunPlayerSpecificStartupScripts"
        }) do
            player[methodName] = noop
        end

        player.GetInitialSpawn = function()
            return {
                cellDescription = "Seyda Neen, Census and Excise Office",
                position = { 1130.3388671875, -387.14947509766, 193 },
                rotation = { 0.09375, 1.5078122615814 }
            }
        end

        return player
    end

    customEventHooks.registerHandler("OnPlayerConnect", function()
        counts.connect = counts.connect + 1
    end)
    customEventHooks.registerHandler("OnPlayerEndCharGen", function()
        counts.endCharGen = counts.endCharGen + 1
    end)
    customEventHooks.registerHandler("OnPlayerFinishLogin", function()
        counts.finishLogin = counts.finishLogin + 1
    end)
    customEventHooks.registerHandler("OnPlayerAuthentified", function()
        counts.auth = counts.auth + 1
    end)

    local ok, errorMessage = pcall(function()
    local existingPlayer = realPlayer(pid, accountName)
    if existingPlayer.hasAccount then
        fail("temporary account already exists")
    end

    eventHandler.OnPlayerConnect(pid, accountName)
    local registeredPlayer = Players[pid]
    if registeredPlayer == nil then
        fail("registration handshake did not keep the player")
    end
    if registeredPlayer:IsLoggedIn() then
        fail("registration handshake logged in before character selection")
    end
    if not registeredPlayer.isNewlyRegistered then
        fail("registration handshake did not mark a newly registered player")
    end
    if registeredPlayer.accountAuthenticated ~= true then
        fail("registration handshake did not authenticate account before selection")
    end

    eventHandler.OnGUIAction(pid, guiHelper.ID.CHARACTERLIST, "0")
    registeredPlayer = Players[pid]
    if registeredPlayer == nil or not registeredPlayer:IsLoggedIn() then
        fail("registration character selection did not start character generation")
    end

    eventHandler.OnPlayerEndCharGen(pid)

    assertEqual(registeredPlayer.data.login.name, accountName, "registered account name")
    assertEqual(registeredPlayer.data.character.name, characterName, "registered character name")
    assertEqual(registeredPlayer.data.character.class, "warrior", "registered class")
    assertEqual(registeredPlayer.data.stats.healthBase, 45, "registered health base")
    assertEqual(registeredPlayer.data.ipAddresses[1], "127.0.0." .. tostring(pid), "registered IP address")
    assertInventoryCount(registeredPlayer.data, "bk_A1_1_DirectionsCaiusCosades", 1, "registered directions item")
    assertInventoryCount(registeredPlayer.data, "bk_a1_1_caiuspackage", 1, "registered Caius package")
    assertInventoryCount(registeredPlayer.data, "Gold_001", 87, "registered office gold")
    assertJournalEntry(registeredPlayer.data, "A1_1_FindSpymaster", 1, "registered office release journal")
    assertTopic(registeredPlayer.data, "Caius Cosades", "registered Caius topic")
    assertTopic(registeredPlayer.data, "duties", "registered duties topic")
    if not registeredPlayer.hasAccount then
        fail("EndCharGen did not create an account")
    end

    local loadedPlayer = realPlayer(0, accountName)
    if not loadedPlayer.hasAccount then
        fail("created account could not be reopened")
    end
    loadedPlayer:LoadFromDrive()
    assertEqual(loadedPlayer.data.login.name, accountName, "persisted account name")
    assertEqual(loadedPlayer.data.character.name, characterName, "persisted character name")
    assertInventoryCount(loadedPlayer.data.characters.entries[1], "bk_a1_1_caiuspackage", 1, "persisted slot Caius package")
    assertJournalEntry(loadedPlayer.data.characters.entries[1], "A1_1_FindSpymaster", 1, "persisted slot office release journal")
    assertTopic(loadedPlayer.data.characters.entries[1], "Caius Cosades", "persisted slot Caius topic")
    if not loadedPlayer:HasCompleteCharacter() then
        fail("created account did not persist a complete character")
    end

    Players[pid] = nil
    removePidFromIpTracking(pid)

    eventHandler.OnPlayerConnect(badRelogPid, accountName)
    local rejectedPlayer = Players[badRelogPid]
    if rejectedPlayer == nil then
        fail("bad existing-account handshake did not keep the retrying player")
    end
    if rejectedPlayer:IsLoggedIn() then
        fail("bad existing-account handshake logged in the player")
    end
    assertEqual(rejectedPlayer.loginTimerId, 9001, "bad existing-account retry timer")
    assertEqual(rejectedPlayer.data.login.name, accountName, "bad existing-account persisted account name")
    assertEqual(rejectedPlayer.data.character.name, characterName, "bad existing-account persisted character name")
    assertEqual(counts.connect, 2, "connect handler count after bad relog")
    assertEqual(counts.finishLogin, 0, "FinishLogin handler count after bad relog")
    assertEqual(counts.auth, 1, "auth handler count after bad relog")
    assertEqual(counts.loginPrompt, 1, "login prompt count after bad relog")
    assertEqual(counts.registerPrompt, 0, "register prompt count after bad relog")

    Players[badRelogPid] = nil
    removePidFromIpTracking(badRelogPid)

    eventHandler.OnPlayerConnect(relogPid, accountName)
    local reloggedPlayer = Players[relogPid]
    if reloggedPlayer == nil then
        fail("existing-account handshake did not keep the selecting player")
    end
    if reloggedPlayer:IsLoggedIn() then
        fail("existing-account handshake logged in before character selection")
    end
    if reloggedPlayer.accountAuthenticated ~= true then
        fail("existing-account handshake did not accept account credentials before selection")
    end

    eventHandler.OnGUIAction(relogPid, guiHelper.ID.CHARACTERLIST, "0")
    reloggedPlayer = Players[relogPid]
    if reloggedPlayer == nil or not reloggedPlayer:IsLoggedIn() then
        fail("existing-account character selection did not finish login")
    end
    assertEqual(reloggedPlayer.accountName, accountName, "relog account name")
    assertEqual(reloggedPlayer.name, characterName, "relog character display name")
    assertEqual(reloggedPlayer.data.login.name, accountName, "relog persisted account name")
    assertEqual(reloggedPlayer.data.character.name, characterName, "relog persisted character name")

    assertEqual(counts.connect, 3, "connect handler count")
    assertEqual(counts.endCharGen, 1, "EndCharGen handler count")
    assertEqual(counts.finishLogin, 1, "FinishLogin handler count")
    assertEqual(counts.auth, 2, "auth handler count")
    assertEqual(counts.charGenStage, 1, "chargen stage count")
    assertEqual(counts.loginPrompt, 1, "login prompt count")
    assertEqual(counts.registerPrompt, 0, "register prompt count")
    assertEqual(counts.characterList, 2, "character list count")
    assertEqual(counts.handshakeClear, 3, "handshake clear count")

    writeResult("OK|" .. accountName .. "|" .. characterName .. "|registered|bad-password-retry|relog")
    end)

    restore()

    if not ok then
        error(errorMessage)
    end
end

customEventHooks.registerHandler("OnServerPostInit", function(eventStatus)
    local ok, errorMessage = pcall(runSmoke)
    if not ok then
        writeResult("FAIL|" .. tostring(errorMessage))
        error(errorMessage)
    end
end)

return {}
"@ | Set-Content -LiteralPath $accountFlowSmokeScript -Encoding ASCII
    Add-Content -LiteralPath $customScriptsConfig -Encoding ASCII -Value "`r`nrequire(`"custom/accountFlowSmoke`")"

    @"
local resultPath = "server/data/death-flow-smoke.txt"
local accountName = "$deathFlowSmokeAccount"
local characterName = "DeathFlowCharacter"
local pid = 51
local respawnCell = "Balmora, Temple"

local function writeResult(text)
    local file = io.open(resultPath, "w")
    if file ~= nil then
        file:write(text)
        file:close()
    end
end

local function fail(message)
    writeResult("FAIL|" .. message)
    error(message)
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        fail(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function runSmoke()
    local patched = {}
    local configSnapshot = {}
    local realGetPlayerPacketTables = packetReader.GetPlayerPacketTables
    local counts = {
        death = 0,
        deathTimer = 0,
        revive = 0,
        resurrect = 0,
        stopTimer = 0
    }

    local function patch(tableRef, key, value)
        table.insert(patched, { tableRef, key, tableRef[key] })
        tableRef[key] = value
    end

    local function noop()
    end

    local function restore()
        for index = #patched, 1, -1 do
            local entry = patched[index]
            entry[1][entry[2]] = entry[3]
        end

        for key, value in pairs(configSnapshot) do
            config[key] = value
        end

        packetReader.GetPlayerPacketTables = realGetPlayerPacketTables
        Players[pid] = nil
    end

    for _, key in ipairs({
        "playersRespawn",
        "respawnAtImperialShrine",
        "respawnAtTribunalTemple",
        "defaultRespawn",
        "deathPenaltyJailDays",
        "bountyDeathPenalty"
    }) do
        configSnapshot[key] = config[key]
    end

    config.playersRespawn = true
    config.respawnAtImperialShrine = false
    config.respawnAtTribunalTemple = false
    config.deathPenaltyJailDays = 0
    config.bountyDeathPenalty = false
    config.defaultRespawn = {
        cellDescription = respawnCell,
        position = { 11.25, 22.5, 33.75 },
        rotation = { 0.5, 1.5 }
    }

    patch(tes3mp, "DoesPlayerHavePlayerKiller", function(requestPid)
        if requestPid ~= pid then
            fail("unexpected killer-check pid")
        end
        return false
    end)
    patch(tes3mp, "GetPlayerKillerName", function(requestPid)
        if requestPid ~= pid then
            fail("unexpected killer-name pid")
        end
        return ""
    end)
    patch(tes3mp, "CreateTimerEx", function(callback, delay, signature, requestPid, timerAccountName)
        assertEqual(callback, "OnDeathTimeExpiration", "death timer callback")
        assertEqual(signature, "is", "death timer signature")
        assertEqual(requestPid, pid, "death timer pid")
        assertEqual(timerAccountName, accountName, "death timer account")
        counts.deathTimer = counts.deathTimer + 1
        return 9101
    end)
    patch(tes3mp, "StartTimer", noop)
    patch(tes3mp, "StopTimer", function(timerId)
        if timerId == 9101 then
            counts.stopTimer = counts.stopTimer + 1
        end
    end)
    patch(tes3mp, "SendMessage", noop)
    patch(tes3mp, "SetCell", function(requestPid, cell)
        assertEqual(requestPid, pid, "respawn SetCell pid")
        assertEqual(cell, respawnCell, "respawn cell")
    end)
    patch(tes3mp, "SetCellChangeReason", function(requestPid, reason)
        assertEqual(requestPid, pid, "respawn SetCellChangeReason pid")
        assertEqual(reason, enumerations.cellChangeReason.RESPAWN, "respawn cell change reason")
    end)
    patch(tes3mp, "SetPos", function(requestPid, x, y, z)
        assertEqual(requestPid, pid, "respawn SetPos pid")
        assertEqual(x, 11.25, "respawn posX")
        assertEqual(y, 22.5, "respawn posY")
        assertEqual(z, 33.75, "respawn posZ")
    end)
    patch(tes3mp, "SetRot", function(requestPid, x, z)
        assertEqual(requestPid, pid, "respawn SetRot pid")
        assertEqual(x, 0.5, "respawn rotX")
        assertEqual(z, 1.5, "respawn rotZ")
    end)
    patch(tes3mp, "SendCell", noop)
    patch(tes3mp, "SendPos", noop)
    patch(tes3mp, "Resurrect", function(requestPid, resurrectType)
        assertEqual(requestPid, pid, "resurrect pid")
        assertEqual(resurrectType, enumerations.resurrect.REGULAR, "resurrect type")
        counts.resurrect = counts.resurrect + 1
    end)

    patch(contentFixer, "UnequipDeadlyItems", function(requestPid)
        assertEqual(requestPid, pid, "deadly item fixer pid")
    end)

    packetReader.GetPlayerPacketTables = function(requestPid, packetType)
        assertEqual(requestPid, pid, "death packet pid")

        if packetType == "PlayerCellChange" then
            return {
                location = {
                    cell = respawnCell,
                    posX = 11.25,
                    posY = 22.5,
                    posZ = 33.75,
                    rotX = 0.5,
                    rotZ = 1.5
                }
            }
        end

        fail("unexpected death packet type " .. tostring(packetType))
    end

    customEventHooks.registerHandler("OnPlayerDeath", function()
        counts.death = counts.death + 1
    end)
    customEventHooks.registerHandler("OnDeathTimeExpiration", function()
        counts.revive = counts.revive + 1
    end)

    local ok, errorMessage = pcall(function()
        local player = Player(pid, accountName)
        if player.hasAccount then
            fail("temporary death account already exists")
        end

        player.loggedIn = true
        player.data.login.passwordSalt = "salt"
        player.data.login.passwordHash = "hash"
        player.data.character.name = characterName
        player.name = characterName
        player.data.character.race = "dark elf"
        player.data.character.head = "b_n_dark elf_m_head_01"
        player.data.character.hair = "b_n_dark elf_m_hair_01"
        player.data.character.gender = 0
        player.data.character.class = "warrior"
        player.data.character.birthsign = "the lady"
        player.data.location.cell = "Balmora"
        player.data.location.posX = 1
        player.data.location.posY = 2
        player.data.location.posZ = 3
        player.data.location.rotX = 0
        player.data.location.rotZ = 0
        player.data.stats.healthBase = 45
        player.data.stats.healthCurrent = 45
        player.data.stats.magickaBase = 50
        player.data.stats.magickaCurrent = 50
        player.data.stats.fatigueBase = 60
        player.data.stats.fatigueCurrent = 60
        player:CreateAccount()
        Players[pid] = player

        eventHandler.OnPlayerDeath(pid)

        assertEqual(player.data.death.isDead, true, "death state")
        assertEqual(player.data.stats.healthCurrent, 0, "death health")
        assertEqual(player.resurrectTimerId, 9101, "death timer id")
        assertEqual(counts.deathTimer, 1, "death timer count")
        assertEqual(counts.death, 1, "death handler count")

        local deadPlayer = Player(0, accountName)
        if not deadPlayer.hasAccount then
            fail("dead account could not be reopened")
        end
        deadPlayer:LoadFromDrive()
        assertEqual(deadPlayer.data.death.isDead, true, "persisted death state")
        assertEqual(deadPlayer.data.stats.healthCurrent, 0, "persisted death health")

        eventHandler.OnDeathTimeExpiration(pid, accountName .. "_stale")
        assertEqual(counts.resurrect, 0, "stale death timer resurrect count")
        assertEqual(counts.revive, 0, "stale death timer handler count")

        eventHandler.OnDeathTimeExpiration(pid, accountName)

        assertEqual(player.data.death.isDead, false, "revived death state")
        assertEqual(player.data.death.timestamp, 0, "revived death timestamp")
        assertEqual(player.data.stats.healthCurrent, 45, "revived health")
        assertEqual(player.resurrectTimerId, nil, "revived timer id")
        assertEqual(player.data.location.cell, respawnCell, "revived location")
        assertEqual(player.data.location.posZ, 33.75, "revived position")
        assertEqual(counts.resurrect, 1, "resurrect call count")
        assertEqual(counts.stopTimer, 1, "stop timer count")
        assertEqual(counts.revive, 1, "revive handler count")

        local revivedPlayer = Player(0, accountName)
        if not revivedPlayer.hasAccount then
            fail("revived account could not be reopened")
        end
        revivedPlayer:LoadFromDrive()
        assertEqual(revivedPlayer.data.death.isDead, false, "persisted revived death state")
        assertEqual(revivedPlayer.data.stats.healthCurrent, 45, "persisted revived health")
        assertEqual(revivedPlayer.data.location.cell, respawnCell, "persisted revived location")
        assertEqual(revivedPlayer.data.location.posZ, 33.75, "persisted revived position")

        writeResult("OK|" .. accountName .. "|" .. characterName .. "|death|revive")
    end)

    restore()

    if not ok then
        error(errorMessage)
    end
end

customEventHooks.registerHandler("OnServerPostInit", function(eventStatus)
    local ok, errorMessage = pcall(runSmoke)
    if not ok then
        writeResult("FAIL|" .. tostring(errorMessage))
        error(errorMessage)
    end
end)

return {}
"@ | Set-Content -LiteralPath $deathFlowSmokeScript -Encoding ASCII
    Add-Content -LiteralPath $customScriptsConfig -Encoding ASCII -Value "`r`nrequire(`"custom/deathFlowSmoke`")"

    @"
local resultPath = "server/data/disconnect-flow-smoke.txt"
local accountName = "$disconnectFlowSmokeAccount"
local characterName = "DisconnectFlowCharacter"
local pid = 61
local relogPid = 62
local clientPasswordHash = "disconnect-client-password-hash"
local ipAddress = "127.0.0.61"
local savedCell = "Caldera"

local function writeResult(text)
    local file = io.open(resultPath, "w")
    if file ~= nil then
        file:write(text)
        file:close()
    end
end

local function fail(message)
    writeResult("FAIL|" .. message)
    error(message)
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        fail(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function runSmoke()
    local patched = {}
    local configSnapshot = {}
    local realPlayer = Player
    local realGetPlayerPacketTables = packetReader.GetPlayerPacketTables
    local realRecordStores = RecordStores
    local unloads = {}
    local counts = {
        connect = 0,
        disconnect = 0,
        cellUnload = 0,
        staleConfiscationLookups = 0,
        finishLogin = 0,
        auth = 0,
        characterList = 0
    }

    local function patch(tableRef, key, value)
        table.insert(patched, { tableRef, key, tableRef[key] })
        tableRef[key] = value
    end

    local function noop()
    end

    local function patchConfig()
        for _, key in ipairs({
            "recordStoreLoadOrder",
            "useInstancedSpawn",
            "maxClientsPerIP",
            "shareJournal",
            "shareFactionRanks",
            "shareFactionExpulsion",
            "shareFactionReputation",
            "shareTopics",
            "shareBounty",
            "shareReputation",
            "shareKills",
            "shareMapExploration"
        }) do
            configSnapshot[key] = config[key]
        end

        config.recordStoreLoadOrder = {{}}
        config.useInstancedSpawn = false
        config.maxClientsPerIP = 8

        for _, key in ipairs({
            "shareJournal",
            "shareFactionRanks",
            "shareFactionExpulsion",
            "shareFactionReputation",
            "shareTopics",
            "shareBounty",
            "shareReputation",
            "shareKills",
            "shareMapExploration"
        }) do
            config[key] = false
        end
    end

    local function restore()
        for index = #patched, 1, -1 do
            local entry = patched[index]
            entry[1][entry[2]] = entry[3]
        end

        for key, value in pairs(configSnapshot) do
            config[key] = value
        end

        packetReader.GetPlayerPacketTables = realGetPlayerPacketTables
        Player = realPlayer
        RecordStores = realRecordStores
        Players[pid] = nil
        Players[relogPid] = nil
        if pidsByIpAddress[ipAddress] ~= nil then
            tableHelper.removeValue(pidsByIpAddress[ipAddress], pid)
            tableHelper.removeValue(pidsByIpAddress[ipAddress], relogPid)
        end
    end

    patchConfig()

    patch(tes3mp, "GetIP", function(requestPid)
        if requestPid ~= pid and requestPid ~= relogPid then
            fail("unexpected disconnect GetIP pid " .. tostring(requestPid))
        end
        return ipAddress
    end)
    patch(tes3mp, "SendMessage", noop)
    patch(tes3mp, "LogMessage", noop)
    patch(tes3mp, "LogAppend", noop)
    patch(tes3mp, "GetSHA256Hash", function(value)
        return "hash:" .. tostring(value)
    end)
    patch(tes3mp, "GetHandshakePasswordHash", function(requestPid)
        if requestPid ~= relogPid then
            fail("unexpected reconnect handshake pid " .. tostring(requestPid))
        end
        return clientPasswordHash
    end)
    patch(tes3mp, "ClearHandshakePasswordHash", noop)
    patch(tes3mp, "CreateTimerEx", function()
        return 9101
    end)
    patch(tes3mp, "StartTimer", noop)
    patch(tes3mp, "StopTimer", noop)
    patch(tes3mp, "GetCell", function(requestPid)
        assertEqual(requestPid, pid, "disconnect GetCell pid")
        return savedCell
    end)
    patch(tes3mp, "IsInExterior", function(requestPid)
        assertEqual(requestPid, pid, "disconnect IsInExterior pid")
        return true
    end)
    for _, name in ipairs({
        "SetDifficulty",
        "SetConsoleAllowed",
        "SetBedRestAllowed",
        "SetWildernessRestAllowed",
        "SetWaitAllowed",
        "SetPhysicsFramerate",
        "SetEnforcedLogLevel",
        "SendSettings",
        "SetPlayerCollisionState",
        "SetActorCollisionState",
        "SetPlacedObjectCollisionState",
        "UseActorCollisionForPlacedObjects",
        "SetName",
        "SetRace",
        "SetHead",
        "SetHair",
        "SetIsMale",
        "SetModel",
        "SetBirthsign",
        "SendBaseInfo",
        "SetCell",
        "SetCellChangeReason",
        "SetPos",
        "SetRot",
        "SendCell",
        "SendPos"
    }) do
        patch(tes3mp, name, noop)
    end

    patch(guiHelper, "ShowCharacterList", function(requestPid)
        if requestPid ~= relogPid then
            fail("unexpected reconnect character list pid " .. tostring(requestPid))
        end

        local player = Players[requestPid]
        if player == nil then
            fail("reconnect character list player missing")
        end
        assertEqual(player:GetCharacterSlotCount(), 1, "reconnect character list slot count")
        assertEqual(player:GetCharacterSlotName(1), characterName, "reconnect character list slot name")
        counts.characterList = counts.characterList + 1
    end)

    patch(logicHandler, "GetLoggedInPlayerByName", function(name)
        assertEqual(name, "MissingTarget", "stale confiscation target")
        counts.staleConfiscationLookups = counts.staleConfiscationLookups + 1
        return nil
    end)
    patch(logicHandler, "UnloadCellForPlayer", function(requestPid, cellDescription)
        assertEqual(requestPid, pid, "disconnect unload pid")
        table.insert(unloads, cellDescription)

        if cellDescription == "Balmora" and Players[pid] ~= nil then
            Players[pid].cellsLoaded = {}
        end
    end)
    patch(logicHandler, "UnloadRegionForPlayer", function(requestPid, regionName)
        assertEqual(requestPid, pid, "disconnect unload region pid")
        assertEqual(regionName, "West Gash", "disconnect region")
    end)
    patch(logicHandler, "SendClientScriptDisables", noop)
    patch(logicHandler, "SendClientScriptSettings", noop)
    patch(logicHandler, "SendConfigCollisionOverrides", noop)
    patch(logicHandler, "LoadRegionForPlayer", noop)

    patch(WorldInstance, "SaveToDrive", noop)
    patch(WorldInstance, "LoadTime", noop)
    patch(WorldInstance, "LoadWeather", noop)
    patch(WorldInstance, "LoadJournal", noop)
    patch(WorldInstance, "LoadFactionRanks", noop)
    patch(WorldInstance, "LoadFactionExpulsion", noop)
    patch(WorldInstance, "LoadFactionReputation", noop)
    patch(WorldInstance, "LoadTopics", noop)
    patch(WorldInstance, "LoadBounty", noop)
    patch(WorldInstance, "LoadReputation", noop)
    patch(WorldInstance, "LoadKills", noop)
    patch(WorldInstance, "LoadMap", noop)
    patch(WorldInstance, "LoadClientScriptVariables", noop)
    patch(WorldInstance, "LoadDestinationOverrides", noop)
    patch(WorldInstance, "HasRunStartupScripts", function()
        return true
    end)
    RecordStores = {}

    packetReader.GetPlayerPacketTables = function(requestPid, packetType)
        assertEqual(requestPid, pid, "disconnect packet pid")

        if packetType == "PlayerCellChange" then
            return {
                location = {
                    cell = savedCell,
                    posX = 7.25,
                    posY = 8.5,
                    posZ = 9.75,
                    rotX = 0.25,
                    rotZ = 0.75
                }
            }
        elseif packetType == "PlayerStatsDynamic" then
            return {
                stats = {
                    healthBase = 45,
                    magickaBase = 50,
                    fatigueBase = 60,
                    healthCurrent = 31,
                    magickaCurrent = 22,
                    fatigueCurrent = 44
                }
            }
        end

        fail("unexpected disconnect packet type " .. tostring(packetType))
    end

    Player = function(requestPid, playerName)
        local player = realPlayer(requestPid, playerName)

        for _, methodName in ipairs({
            "LoadSettings",
            "LoadClass",
            "LoadLevel",
            "LoadAttributes",
            "LoadSkills",
            "LoadStatsDynamic",
            "CleanInventory",
            "LoadInventory",
            "LoadEquipment",
            "CleanSpellbook",
            "LoadSpellbook",
            "LoadSpellsActive",
            "LoadCooldowns",
            "LoadQuickKeys",
            "LoadBooks",
            "LoadShapeshift",
            "LoadMarkLocation",
            "LoadSelectedSpell",
            "LoadSelectedEnchantedItem",
            "LoadJournal",
            "LoadFactionRanks",
            "LoadFactionExpulsion",
            "LoadFactionReputation",
            "LoadTopics",
            "LoadBounty",
            "LoadReputation",
            "LoadKills",
            "LoadSpecialStates",
            "LoadMap",
            "LoadClientScriptVariables",
            "LoadDestinationOverrides",
            "LoadAllies",
            "LoadCell",
            "RunPlayerSpecificStartupScripts"
        }) do
            player[methodName] = noop
        end

        return player
    end

    customEventHooks.registerHandler("OnPlayerConnect", function()
        counts.connect = counts.connect + 1
    end)
    customEventHooks.registerHandler("OnPlayerDisconnect", function()
        counts.disconnect = counts.disconnect + 1
    end)
    customEventHooks.registerHandler("OnCellUnload", function()
        counts.cellUnload = counts.cellUnload + 1
    end)
    customEventHooks.registerHandler("OnPlayerFinishLogin", function()
        counts.finishLogin = counts.finishLogin + 1
    end)
    customEventHooks.registerHandler("OnPlayerAuthentified", function()
        counts.auth = counts.auth + 1
    end)

    local ok, errorMessage = pcall(function()
        local player = Player(pid, accountName)
        if player.hasAccount then
            fail("temporary disconnect account already exists")
        end

        player.loggedIn = true
        player.name = characterName
        player.ipAddress = ipAddress
        player.confiscationTargetName = "MissingTarget"
        player.cellsLoaded = { "Balmora", "Seyda Neen" }
        player.data.login.passwordSalt = "salt"
        player.data.login.passwordHash = "hash:" .. clientPasswordHash .. "salt"
        player.data.character.name = characterName
        player.data.character.race = "dark elf"
        player.data.character.head = "b_n_dark elf_m_head_01"
        player.data.character.hair = "b_n_dark elf_m_hair_01"
        player.data.character.gender = 0
        player.data.character.class = "warrior"
        player.data.character.birthsign = "the lady"
        player.data.location.cell = "Balmora"
        player.data.location.regionName = "West Gash"
        player.data.location.posX = 1
        player.data.location.posY = 2
        player.data.location.posZ = 3
        player.data.stats.healthBase = 45
        player.data.stats.healthCurrent = 45
        player.data.stats.magickaBase = 50
        player.data.stats.magickaCurrent = 50
        player.data.stats.fatigueBase = 60
        player.data.stats.fatigueCurrent = 60
        player.data.timestamps.lastLogin = os.time() - 15
        player:CreateAccount()
        Players[pid] = player
        pidsByIpAddress[ipAddress] = { pid }

        eventHandler.OnPlayerDisconnect(pid)

        if Players[pid] ~= nil then
            fail("disconnect did not destroy player entry")
        end
        if tableHelper.containsValue(pidsByIpAddress[ipAddress], pid) then
            fail("disconnect did not remove pid from IP tracking")
        end
        assertEqual(counts.disconnect, 1, "disconnect handler count")
        assertEqual(counts.cellUnload, 2, "cell unload handler count")
        assertEqual(counts.staleConfiscationLookups, 1, "stale confiscation lookup count")
        assertEqual(#unloads, 2, "unload snapshot count")
        assertEqual(unloads[1], "Balmora", "first unloaded cell")
        assertEqual(unloads[2], "Seyda Neen", "second unloaded cell")

        local loadedPlayer = Player(0, accountName)
        if not loadedPlayer.hasAccount then
            fail("disconnect account could not be reopened")
        end
        loadedPlayer:LoadFromDrive()

        assertEqual(loadedPlayer.data.location.cell, savedCell, "saved disconnect cell")
        assertEqual(loadedPlayer.data.location.posZ, 9.75, "saved disconnect position")
        assertEqual(loadedPlayer.data.stats.healthCurrent, 31, "saved disconnect health")
        assertEqual(loadedPlayer.data.stats.magickaCurrent, 22, "saved disconnect magicka")
        assertEqual(loadedPlayer.data.stats.fatigueCurrent, 44, "saved disconnect fatigue")
        if loadedPlayer.data.timestamps.lastDisconnect == nil or
            loadedPlayer.data.timestamps.lastDisconnect <= 0 then
            fail("disconnect timestamp was not saved")
        end
        if loadedPlayer.data.timestamps.lastSessionDuration == nil or
            loadedPlayer.data.timestamps.lastSessionDuration < 1 then
            fail("disconnect session duration was not saved")
        end
        if #loadedPlayer.data.mapExplored ~= 1 or loadedPlayer.data.mapExplored[1] ~= savedCell then
            fail("disconnect map exploration was not saved")
        end

        eventHandler.OnPlayerConnect(relogPid, accountName)
        local reloggedPlayer = Players[relogPid]
        if reloggedPlayer == nil then
            fail("immediate reconnect did not keep the selecting player")
        end
        if reloggedPlayer:IsLoggedIn() then
            fail("immediate reconnect logged in before character selection")
        end
        if reloggedPlayer.accountAuthenticated ~= true then
            fail("immediate reconnect did not accept account credentials before selection")
        end

        eventHandler.OnGUIAction(relogPid, guiHelper.ID.CHARACTERLIST, "0")
        reloggedPlayer = Players[relogPid]
        if reloggedPlayer == nil or not reloggedPlayer:IsLoggedIn() then
            fail("immediate reconnect character selection did not finish login")
        end
        assertEqual(reloggedPlayer.accountName, accountName, "reconnect account name")
        assertEqual(reloggedPlayer.name, characterName, "reconnect character display name")
        assertEqual(reloggedPlayer.data.login.name, accountName, "reconnect persisted account name")
        assertEqual(reloggedPlayer.data.character.name, characterName, "reconnect persisted character name")
        assertEqual(reloggedPlayer.data.location.cell, savedCell, "reconnect saved cell")
        assertEqual(reloggedPlayer.data.stats.healthCurrent, 31, "reconnect saved health")
        if not tableHelper.containsValue(pidsByIpAddress[ipAddress], relogPid) then
            fail("immediate reconnect did not add the new pid to IP tracking")
        end
        if tableHelper.containsValue(pidsByIpAddress[ipAddress], pid) then
            fail("immediate reconnect left the old pid in IP tracking")
        end

        assertEqual(counts.connect, 1, "reconnect handler count")
        assertEqual(counts.finishLogin, 1, "reconnect finish-login handler count")
        assertEqual(counts.auth, 1, "reconnect auth handler count")
        assertEqual(counts.characterList, 1, "reconnect character list count")

        writeResult("OK|" .. accountName .. "|" .. characterName .. "|disconnect|reconnect")
    end)

    restore()

    if not ok then
        error(errorMessage)
    end
end

customEventHooks.registerHandler("OnServerPostInit", function(eventStatus)
    local ok, errorMessage = pcall(runSmoke)
    if not ok then
        writeResult("FAIL|" .. tostring(errorMessage))
        error(errorMessage)
    end
end)

return {}
"@ | Set-Content -LiteralPath $disconnectFlowSmokeScript -Encoding ASCII
    Add-Content -LiteralPath $customScriptsConfig -Encoding ASCII -Value "`r`nrequire(`"custom/disconnectFlowSmoke`")"

        @"
local resultPath = "server/data/json-player-smoke.txt"
local accountName = "$jsonPlayerSmokeAccount"

local function writeResult(text)
    local file = io.open(resultPath, "w")
    if file ~= nil then
        file:write(text)
        file:close()
    end
end

local function fail(message)
    writeResult("FAIL|" .. message)
    error(message)
end

customEventHooks.registerHandler("OnServerPostInit", function(eventStatus)
    if Database ~= nil or Player == nil then
        fail("CommunityMP XML backend was not initialized")
    end

    local player = Player(0, accountName)
    if player.hasAccount then
        fail("temporary account already exists")
    end

    player.data.login.passwordSalt = "salt"
    player.data.login.passwordHash = "hash"
    player.data.character.name = "JsonSmokeCharacter"
    player.data.character.race = "dark elf"
    player.data.character.head = "b_n_dark elf_m_head_01"
    player.data.character.hair = "b_n_dark elf_m_hair_01"
    player.data.character.gender = 0
    player.data.character.class = "warrior"
    player.data.character.birthsign = "the lady"
    player.data.location.cell = "Balmora"
    player.data.location.posX = 1.5
    player.data.location.posY = 2.5
    player.data.location.posZ = 3.5
    player.data.stats.level = 12
    player.data.stats.levelProgress = 7
    player.data.stats.healthBase = 80
    player.data.stats.healthCurrent = 63
    player.data.stats.magickaBase = 55
    player.data.stats.magickaCurrent = 21
    player.data.fame.bounty = 123
    player.data.fame.reputation = 4
    player.data.miscellaneous.markLocation = {
        cell = "Caldera",
        posX = 12.5,
        posY = 23.5,
        posZ = 34.5,
        rotX = 0.25,
        rotZ = 1.25
    }
    player.data.miscellaneous.selectedSpell = "fire bite"
    player.data.inventory[1] = {
        refId = "gold_001",
        count = 75,
        charge = -1,
        enchantmentCharge = -1,
        soul = ""
    }
    player.data.spellbook[1] = "fire bite"
    player.data.cooldowns[1] = {
        spellId = "ancestor guardian",
        startDay = 8,
        startHour = 13.25
    }
    player.data.quickKeys[1] = {
        keyType = 1,
        itemId = "iron dagger"
    }
    player.data.journal[1] = {
        type = enumerations.journal.ENTRY,
        quest = "a1_1_findspymaster",
        index = 10,
        actorRefId = "caius cosades",
        timestamp = {
            daysPassed = 7,
            month = 3,
            day = 16
        }
    }
    player.data.journal[2] = {
        type = enumerations.journal.FINISHED,
        quest = "a1_1_findspymaster",
        isFinished = true
    }
    player.data.topics[1] = "caius cosades"
    player.data.books[1] = "bk_a1_1_caiuspackage"
    player.data.factionRanks["mages guild"] = 2
    player.data.factionExpulsion["fighters guild"] = true
    player.data.factionReputation["thieves guild"] = 5
    player.data.mapExplored[1] = "0, 0"
    player.data.destinationOverrides["Balmora"] = "Balmora, Guild of Mages"
    player.data.alliedPlayers[1] = "FriendAccount"
    player.data.customVariables.jsonSmoke = {
        value = 25,
        flag = false
    }

    player:CreateAccount()
    if not player.hasAccount then
        fail("created account was not marked as existing")
    end

    local loadedPlayer = Player(0, accountName)
    if not loadedPlayer.hasAccount then
        fail("created account could not be found")
    end

    loadedPlayer:LoadFromDrive()

    if loadedPlayer.data.login.name ~= accountName then
        fail("login name did not round-trip")
    end
    if loadedPlayer.data.character.name ~= "JsonSmokeCharacter" then
        fail("character name did not round-trip")
    end
    if loadedPlayer.data.location.cell ~= "Balmora" or loadedPlayer.data.location.posZ ~= 3.5 then
        fail("location did not round-trip")
    end
    if loadedPlayer.data.stats.level ~= 12 or loadedPlayer.data.stats.healthCurrent ~= 63 or
        loadedPlayer.data.stats.magickaCurrent ~= 21 then
        fail("stats did not round-trip")
    end
    if loadedPlayer.data.fame.bounty ~= 123 or loadedPlayer.data.fame.reputation ~= 4 then
        fail("fame did not round-trip")
    end
    if loadedPlayer.data.miscellaneous.markLocation.cell ~= "Caldera" or
        loadedPlayer.data.miscellaneous.markLocation.posZ ~= 34.5 or
        loadedPlayer.data.miscellaneous.selectedSpell ~= "fire bite" then
        fail("miscellaneous magic state did not round-trip")
    end
    if #loadedPlayer.data.inventory ~= 1 or loadedPlayer.data.inventory[1].refId ~= "gold_001" or
        loadedPlayer.data.inventory[1].count ~= 75 then
        fail("inventory did not round-trip")
    end
    if #loadedPlayer.data.spellbook ~= 1 or loadedPlayer.data.spellbook[1] ~= "fire bite" or
        #loadedPlayer.data.cooldowns ~= 1 or loadedPlayer.data.cooldowns[1].spellId ~= "ancestor guardian" or
        loadedPlayer.data.quickKeys[1].itemId ~= "iron dagger" then
        fail("spellbook/cooldowns/quickKeys did not round-trip")
    end
    if #loadedPlayer.data.journal ~= 2 or loadedPlayer.data.journal[1].quest ~= "a1_1_findspymaster" or
        loadedPlayer.data.journal[1].timestamp.daysPassed ~= 7 or
        loadedPlayer.data.journal[2].type ~= enumerations.journal.FINISHED or
        loadedPlayer.data.journal[2].isFinished ~= true then
        fail("journal did not round-trip")
    end
    if #loadedPlayer.data.topics ~= 1 or loadedPlayer.data.topics[1] ~= "caius cosades" then
        fail("topics did not round-trip")
    end
    if #loadedPlayer.data.books ~= 1 or loadedPlayer.data.books[1] ~= "bk_a1_1_caiuspackage" then
        fail("books did not round-trip")
    end
    if loadedPlayer.data.factionRanks["mages guild"] ~= 2 or
        loadedPlayer.data.factionExpulsion["fighters guild"] ~= true or
        loadedPlayer.data.factionReputation["thieves guild"] ~= 5 then
        fail("faction state did not round-trip")
    end
    if #loadedPlayer.data.mapExplored ~= 1 or loadedPlayer.data.mapExplored[1] ~= "0, 0" or
        loadedPlayer.data.destinationOverrides.Balmora ~= "Balmora, Guild of Mages" then
        fail("map/destination state did not round-trip")
    end
    if #loadedPlayer.data.alliedPlayers ~= 1 or loadedPlayer.data.alliedPlayers[1] ~= "FriendAccount" then
        fail("allies did not round-trip")
    end
    if loadedPlayer.data.customVariables.jsonSmoke.value ~= 25 or
        loadedPlayer.data.customVariables.jsonSmoke.flag ~= false then
        fail("customVariables did not round-trip")
    end

    local saveCodec = require("communitympSaveCodec")
    local savedAccount = saveCodec.load(loadedPlayer.accountFile)
    if savedAccount == nil or savedAccount.login.name ~= accountName or
        savedAccount.characters.entries[1].summary.name ~= "JsonSmokeCharacter" then
        fail("player account XML did not contain expected account and character data")
    end

    local characterStorage = savedAccount.characters.entries[1].storage
    local savedCharacter = saveCodec.load(loadedPlayer.accountDirectory .. "/" .. characterStorage.path)
    if savedCharacter == nil or savedCharacter.character.name ~= "JsonSmokeCharacter" then
        fail("player character XML did not contain expected character data")
    end

    writeResult("OK|" .. accountName .. "|" .. loadedPlayer.data.character.name)
end)

return {}
"@ | Set-Content -LiteralPath $jsonPlayerSmokeScript -Encoding ASCII
        Add-Content -LiteralPath $customScriptsConfig -Encoding ASCII -Value "`r`nrequire(`"custom/jsonPlayerSmoke`")"


    New-Item -ItemType Directory -Force -Path $configDir | Out-Null
    if ($hadUserConfig) {
        Copy-Item -LiteralPath $serverConfig -Destination $configBackup -Force
    }

    if ($WithLocalMaster) {
        @"
[Plugins]
home = ./server
plugins = serverCore.lua,custom/globalCallbackSmoke.lua

[MasterServer]
enabled = true
address = localhost
port = 25560
rate = 8000
"@ | Set-Content -LiteralPath $serverConfig -Encoding ASCII

        $master = Start-Process -FilePath $masterExe -WorkingDirectory $runtimeDir `
            -RedirectStandardOutput $masterOut -RedirectStandardError $masterErr -WindowStyle Hidden -PassThru
        Start-Sleep -Seconds 2

        if ($master.HasExited) {
            throw "masterserver.exe exited during smoke start with code $($master.ExitCode).`nstdout:`n$(Read-SmokeLog $masterOut)`nstderr:`n$(Read-SmokeLog $masterErr)"
        }
    }
    else {
        @"
[Plugins]
home = ./server
plugins = serverCore.lua,custom/globalCallbackSmoke.lua

[MasterServer]
enabled = false
"@ | Set-Content -LiteralPath $serverConfig -Encoding ASCII
    }

    $server = Start-Process -FilePath $serverExe -WorkingDirectory $runtimeDir `
        -RedirectStandardOutput $serverOut -RedirectStandardError $serverErr -WindowStyle Hidden -PassThru

    Start-Sleep -Seconds $TimeoutSeconds

    if ($server.HasExited) {
        throw "communitymp-server.exe exited during smoke start with code $($server.ExitCode).`nstdout:`n$(Read-SmokeLog $serverOut)`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    if (-not (Test-Path -LiteralPath $timerSmokeResult -PathType Leaf)) {
        throw "Lua timer smoke did not create $timerSmokeResult.`nstdout:`n$(Read-SmokeLog $serverOut)`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    $timerSmokeText = Get-Content -LiteralPath $timerSmokeResult -Raw
    if ($timerSmokeText -notmatch "^timer-smoke\|42\|3\.25") {
        throw "Lua timer smoke wrote unexpected content to ${timerSmokeResult}: '$timerSmokeText'.`nstdout:`n$(Read-SmokeLog $serverOut)`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    if (-not (Test-Path -LiteralPath $globalCallbackSmokeResult -PathType Leaf)) {
        throw "Legacy global callback smoke did not create $globalCallbackSmokeResult.`nstdout:`n$(Read-SmokeLog $serverOut)`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    $globalCallbackSmokeText = Get-Content -LiteralPath $globalCallbackSmokeResult -Raw
    if ($globalCallbackSmokeText -notmatch "OnServerInit\r?\nOnServerPostInit") {
        throw "Legacy global callback smoke wrote unexpected content to ${globalCallbackSmokeResult}: '$globalCallbackSmokeText'.`nstdout:`n$(Read-SmokeLog $serverOut)`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    if (-not (Test-Path -LiteralPath $accountFlowSmokeResult -PathType Leaf)) {
        throw "Account flow smoke did not create $accountFlowSmokeResult.`nstdout:`n$(Read-SmokeLog $serverOut)`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    $accountFlowSmokeText = Get-Content -LiteralPath $accountFlowSmokeResult -Raw
    if ($accountFlowSmokeText -notmatch "^OK\|$accountFlowSmokeAccount\|$accountFlowSmokeCharacter\|registered\|bad-password-retry\|relog") {
        throw "Account flow smoke wrote unexpected content to ${accountFlowSmokeResult}: '$accountFlowSmokeText'.`nstdout:`n$(Read-SmokeLog $serverOut)`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    if (-not (Test-Path -LiteralPath $deathFlowSmokeResult -PathType Leaf)) {
        throw "Death/revive flow smoke did not create $deathFlowSmokeResult.`nstdout:`n$(Read-SmokeLog $serverOut)`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    $deathFlowSmokeText = Get-Content -LiteralPath $deathFlowSmokeResult -Raw
    if ($deathFlowSmokeText -notmatch "^OK\|$deathFlowSmokeAccount\|DeathFlowCharacter\|death\|revive") {
        throw "Death/revive flow smoke wrote unexpected content to ${deathFlowSmokeResult}: '$deathFlowSmokeText'.`nstdout:`n$(Read-SmokeLog $serverOut)`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    if (-not (Test-Path -LiteralPath $disconnectFlowSmokeResult -PathType Leaf)) {
        throw "Disconnect flow smoke did not create $disconnectFlowSmokeResult.`nstdout:`n$(Read-SmokeLog $serverOut)`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    $disconnectFlowSmokeText = Get-Content -LiteralPath $disconnectFlowSmokeResult -Raw
    if ($disconnectFlowSmokeText -notmatch "^OK\|$disconnectFlowSmokeAccount\|DisconnectFlowCharacter\|disconnect\|reconnect") {
        throw "Disconnect flow smoke wrote unexpected content to ${disconnectFlowSmokeResult}: '$disconnectFlowSmokeText'.`nstdout:`n$(Read-SmokeLog $serverOut)`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    $serverLog = Read-SmokeLog $serverOut
    if ($serverLog -notmatch 'Called "OnServerInit"' -or $serverLog -notmatch 'Called "OnServerPostInit"') {
        throw "Default serverCore.lua startup callbacks were not observed.`nstdout:`n$serverLog`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

        if (-not (Test-Path -LiteralPath $jsonPlayerSmokeResult -PathType Leaf)) {
            throw "CommunityMP XML player persistence smoke did not create $jsonPlayerSmokeResult.`nstdout:`n$serverLog`nstderr:`n$(Read-SmokeLog $serverErr)"
        }

        $jsonPlayerSmokeText = Get-Content -LiteralPath $jsonPlayerSmokeResult -Raw
        if ($jsonPlayerSmokeText -notmatch "^OK\|$jsonPlayerSmokeAccount\|JsonSmokeCharacter") {
            throw "CommunityMP XML player persistence smoke wrote unexpected content to ${jsonPlayerSmokeResult}: '$jsonPlayerSmokeText'.`nstdout:`n$serverLog`nstderr:`n$(Read-SmokeLog $serverErr)"
        }

        if (-not (Test-Path -LiteralPath $jsonPlayerSmokeFile -PathType Leaf)) {
            throw "CommunityMP XML player persistence smoke did not create account file $jsonPlayerSmokeFile.`nstdout:`n$serverLog`nstderr:`n$(Read-SmokeLog $serverErr)"
        }


    Stop-SmokeProcess $server
    $server = $null
    Remove-Item -LiteralPath $serverOut, $serverErr, $timerSmokeResult, $globalCallbackSmokeResult, $accountFlowRestartSmokeResult, $deathFlowRestartSmokeResult, $disconnectFlowRestartSmokeResult, $jsonPlayerRestartSmokeResult -ErrorAction SilentlyContinue
    Copy-Item -LiteralPath $customScriptsBackup -Destination $customScriptsConfig -Force

    @"
local resultPath = "server/data/account-flow-restart-smoke.txt"
local accountName = "$accountFlowSmokeAccount"
local characterName = "$accountFlowSmokeCharacter"

local function writeResult(text)
    local file = io.open(resultPath, "w")
    if file ~= nil then
        file:write(text)
        file:close()
    end
end

local function fail(message)
    writeResult("FAIL|" .. message)
    error(message)
end

customEventHooks.registerHandler("OnServerPostInit", function(eventStatus)
    local player = Player(0, accountName)
    if not player.hasAccount then
        fail("account-flow account was not found after server restart")
    end

    player:LoadFromDrive()

    if player.data.login.name ~= accountName then
        fail("account-flow login name did not survive server restart")
    end
    if player.data.character.name ~= characterName then
        fail("account-flow character name did not survive server restart")
    end
    if player.data.character.class ~= "warrior" or player.data.character.race ~= "dark elf" or
        player.data.character.birthsign ~= "the lady" then
        fail("account-flow character data did not survive server restart")
    end
    if player.data.stats.healthBase ~= 45 or player.data.stats.magickaBase ~= 50 or
        player.data.stats.fatigueBase ~= 60 then
        fail("account-flow stats did not survive server restart")
    end
    if not player:HasCompleteCharacter() then
        fail("account-flow account did not have a complete character after server restart")
    end

    writeResult("OK|" .. accountName .. "|" .. characterName .. "|restart")
end)

return {}
"@ | Set-Content -LiteralPath $accountFlowRestartSmokeScript -Encoding ASCII
    Add-Content -LiteralPath $customScriptsConfig -Encoding ASCII -Value "`r`nrequire(`"custom/accountFlowRestartSmoke`")"

    @"
local resultPath = "server/data/death-flow-restart-smoke.txt"
local accountName = "$deathFlowSmokeAccount"

local function writeResult(text)
    local file = io.open(resultPath, "w")
    if file ~= nil then
        file:write(text)
        file:close()
    end
end

local function fail(message)
    writeResult("FAIL|" .. message)
    error(message)
end

customEventHooks.registerHandler("OnServerPostInit", function(eventStatus)
    local player = Player(0, accountName)
    if not player.hasAccount then
        fail("death-flow account was not found after server restart")
    end

    player:LoadFromDrive()

    if player.data.character.name ~= "DeathFlowCharacter" then
        fail("death-flow character name did not survive server restart")
    end
    if player.data.death.isDead ~= false or player.data.death.timestamp ~= 0 then
        fail("death-flow revive state did not survive server restart")
    end
    if player.data.stats.healthCurrent ~= 45 or player.data.stats.healthBase ~= 45 then
        fail("death-flow revived health did not survive server restart")
    end
    if player.data.location.cell ~= "Balmora, Temple" or player.data.location.posZ ~= 33.75 then
        fail("death-flow respawn location did not survive server restart")
    end

    writeResult("OK|" .. accountName .. "|DeathFlowCharacter|restart")
end)

return {}
"@ | Set-Content -LiteralPath $deathFlowRestartSmokeScript -Encoding ASCII
    Add-Content -LiteralPath $customScriptsConfig -Encoding ASCII -Value "`r`nrequire(`"custom/deathFlowRestartSmoke`")"

    @"
local resultPath = "server/data/disconnect-flow-restart-smoke.txt"
local accountName = "$disconnectFlowSmokeAccount"

local function writeResult(text)
    local file = io.open(resultPath, "w")
    if file ~= nil then
        file:write(text)
        file:close()
    end
end

local function fail(message)
    writeResult("FAIL|" .. message)
    error(message)
end

customEventHooks.registerHandler("OnServerPostInit", function(eventStatus)
    local player = Player(0, accountName)
    if not player.hasAccount then
        fail("disconnect-flow account was not found after server restart")
    end

    player:LoadFromDrive()

    if player.data.character.name ~= "DisconnectFlowCharacter" then
        fail("disconnect-flow character name did not survive server restart")
    end
    if player.data.location.cell ~= "Caldera" or player.data.location.posZ ~= 9.75 then
        fail("disconnect-flow location did not survive server restart")
    end
    if player.data.stats.healthCurrent ~= 31 or player.data.stats.magickaCurrent ~= 22 or
        player.data.stats.fatigueCurrent ~= 44 then
        fail("disconnect-flow dynamic stats did not survive server restart")
    end
    if player.data.timestamps.lastDisconnect == nil or player.data.timestamps.lastDisconnect <= 0 or
        player.data.timestamps.lastSessionDuration == nil or player.data.timestamps.lastSessionDuration < 1 then
        fail("disconnect-flow disconnect timestamps did not survive server restart")
    end
    if #player.data.mapExplored ~= 1 or player.data.mapExplored[1] ~= "Caldera" then
        fail("disconnect-flow map exploration did not survive server restart")
    end

    writeResult("OK|" .. accountName .. "|DisconnectFlowCharacter|restart")
end)

return {}
"@ | Set-Content -LiteralPath $disconnectFlowRestartSmokeScript -Encoding ASCII
    Add-Content -LiteralPath $customScriptsConfig -Encoding ASCII -Value "`r`nrequire(`"custom/disconnectFlowRestartSmoke`")"

        @"
local resultPath = "server/data/json-player-restart-smoke.txt"
local accountName = "$jsonPlayerSmokeAccount"

local function writeResult(text)
    local file = io.open(resultPath, "w")
    if file ~= nil then
        file:write(text)
        file:close()
    end
end

local function fail(message)
    writeResult("FAIL|" .. message)
    error(message)
end

customEventHooks.registerHandler("OnServerPostInit", function(eventStatus)
    if Database ~= nil or Player == nil then
        fail("CommunityMP XML backend was not initialized after restart")
    end

    local player = Player(0, accountName)
    if not player.hasAccount then
        fail("JSON account was not found after server restart")
    end

    player:LoadFromDrive()

    if player.data.login.name ~= accountName then
        fail("login name did not survive server restart")
    end
    if player.data.character.name ~= "JsonSmokeCharacter" then
        fail("character name did not survive server restart")
    end
    if player.data.location.cell ~= "Balmora" or player.data.location.posZ ~= 3.5 then
        fail("location did not survive server restart")
    end
    if player.data.stats.level ~= 12 or player.data.stats.healthCurrent ~= 63 or
        player.data.stats.magickaCurrent ~= 21 then
        fail("stats did not survive server restart")
    end
    if player.data.fame.bounty ~= 123 or player.data.fame.reputation ~= 4 then
        fail("fame did not survive server restart")
    end
    if player.data.miscellaneous.markLocation.cell ~= "Caldera" or
        player.data.miscellaneous.markLocation.posZ ~= 34.5 or
        player.data.miscellaneous.selectedSpell ~= "fire bite" then
        fail("miscellaneous magic state did not survive server restart")
    end
    if #player.data.inventory ~= 1 or player.data.inventory[1].refId ~= "gold_001" or
        player.data.inventory[1].count ~= 75 then
        fail("inventory did not survive server restart")
    end
    if #player.data.spellbook ~= 1 or player.data.spellbook[1] ~= "fire bite" or
        #player.data.cooldowns ~= 1 or player.data.cooldowns[1].spellId ~= "ancestor guardian" or
        player.data.quickKeys[1].itemId ~= "iron dagger" then
        fail("spellbook/cooldowns/quickKeys did not survive server restart")
    end
    if #player.data.journal ~= 2 or player.data.journal[1].quest ~= "a1_1_findspymaster" or
        player.data.journal[1].timestamp.daysPassed ~= 7 or
        player.data.journal[2].type ~= enumerations.journal.FINISHED or
        player.data.journal[2].isFinished ~= true then
        fail("journal did not survive server restart")
    end
    if #player.data.topics ~= 1 or player.data.topics[1] ~= "caius cosades" then
        fail("topics did not survive server restart")
    end
    if #player.data.books ~= 1 or player.data.books[1] ~= "bk_a1_1_caiuspackage" then
        fail("books did not survive server restart")
    end
    if player.data.factionRanks["mages guild"] ~= 2 or
        player.data.factionExpulsion["fighters guild"] ~= true or
        player.data.factionReputation["thieves guild"] ~= 5 then
        fail("faction state did not survive server restart")
    end
    if #player.data.mapExplored ~= 1 or player.data.mapExplored[1] ~= "0, 0" or
        player.data.destinationOverrides.Balmora ~= "Balmora, Guild of Mages" then
        fail("map/destination state did not survive server restart")
    end
    if #player.data.alliedPlayers ~= 1 or player.data.alliedPlayers[1] ~= "FriendAccount" then
        fail("allies did not survive server restart")
    end
    if player.data.customVariables.jsonSmoke.value ~= 25 or
        player.data.customVariables.jsonSmoke.flag ~= false then
        fail("customVariables did not survive server restart")
    end

    writeResult("OK|" .. accountName .. "|" .. player.data.character.name .. "|restart")
end)

return {}
"@ | Set-Content -LiteralPath $jsonPlayerRestartSmokeScript -Encoding ASCII
        Add-Content -LiteralPath $customScriptsConfig -Encoding ASCII -Value "`r`nrequire(`"custom/jsonPlayerRestartSmoke`")"


    $server = Start-Process -FilePath $serverExe -WorkingDirectory $runtimeDir `
        -RedirectStandardOutput $serverOut -RedirectStandardError $serverErr -WindowStyle Hidden -PassThru

    Start-Sleep -Seconds $TimeoutSeconds

    if ($server.HasExited) {
        throw "communitymp-server.exe exited during restart smoke with code $($server.ExitCode).`nstdout:`n$(Read-SmokeLog $serverOut)`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    $restartServerLog = Read-SmokeLog $serverOut
    if ($restartServerLog -notmatch 'Called "OnServerInit"' -or $restartServerLog -notmatch 'Called "OnServerPostInit"') {
        throw "Default serverCore.lua restart callbacks were not observed.`nstdout:`n$restartServerLog`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    if (-not (Test-Path -LiteralPath $accountFlowRestartSmokeResult -PathType Leaf)) {
        throw "Account flow restart smoke did not create $accountFlowRestartSmokeResult.`nstdout:`n$restartServerLog`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    $accountFlowRestartSmokeText = Get-Content -LiteralPath $accountFlowRestartSmokeResult -Raw
    if ($accountFlowRestartSmokeText -notmatch "^OK\|$accountFlowSmokeAccount\|$accountFlowSmokeCharacter\|restart") {
        throw "Account flow restart smoke wrote unexpected content to ${accountFlowRestartSmokeResult}: '$accountFlowRestartSmokeText'.`nstdout:`n$restartServerLog`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    if (-not (Test-Path -LiteralPath $deathFlowRestartSmokeResult -PathType Leaf)) {
        throw "Death/revive flow restart smoke did not create $deathFlowRestartSmokeResult.`nstdout:`n$restartServerLog`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    $deathFlowRestartSmokeText = Get-Content -LiteralPath $deathFlowRestartSmokeResult -Raw
    if ($deathFlowRestartSmokeText -notmatch "^OK\|$deathFlowSmokeAccount\|DeathFlowCharacter\|restart") {
        throw "Death/revive flow restart smoke wrote unexpected content to ${deathFlowRestartSmokeResult}: '$deathFlowRestartSmokeText'.`nstdout:`n$restartServerLog`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    if (-not (Test-Path -LiteralPath $disconnectFlowRestartSmokeResult -PathType Leaf)) {
        throw "Disconnect flow restart smoke did not create $disconnectFlowRestartSmokeResult.`nstdout:`n$restartServerLog`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

    $disconnectFlowRestartSmokeText = Get-Content -LiteralPath $disconnectFlowRestartSmokeResult -Raw
    if ($disconnectFlowRestartSmokeText -notmatch "^OK\|$disconnectFlowSmokeAccount\|DisconnectFlowCharacter\|restart") {
        throw "Disconnect flow restart smoke wrote unexpected content to ${disconnectFlowRestartSmokeResult}: '$disconnectFlowRestartSmokeText'.`nstdout:`n$restartServerLog`nstderr:`n$(Read-SmokeLog $serverErr)"
    }

        if (-not (Test-Path -LiteralPath $jsonPlayerRestartSmokeResult -PathType Leaf)) {
            throw "CommunityMP XML player restart smoke did not create $jsonPlayerRestartSmokeResult.`nstdout:`n$restartServerLog`nstderr:`n$(Read-SmokeLog $serverErr)"
        }

        $jsonPlayerRestartSmokeText = Get-Content -LiteralPath $jsonPlayerRestartSmokeResult -Raw
        if ($jsonPlayerRestartSmokeText -notmatch "^OK\|$jsonPlayerSmokeAccount\|JsonSmokeCharacter\|restart") {
            throw "CommunityMP XML player restart smoke wrote unexpected content to ${jsonPlayerRestartSmokeResult}: '$jsonPlayerRestartSmokeText'.`nstdout:`n$restartServerLog`nstderr:`n$(Read-SmokeLog $serverErr)"
        }


    if ($WithLocalMaster) {
        $masterLog = Read-SmokeLog $masterOut
        if ($masterLog -notmatch "Added server|Updated server|Keeping alive server") {
            throw "Local master did not record a CommunityMP server announcement.`nmaster stdout:`n$masterLog`nmaster stderr:`n$(Read-SmokeLog $masterErr)`nserver stdout:`n$(Read-SmokeLog $serverOut)`nserver stderr:`n$(Read-SmokeLog $serverErr)"
        }

        $serversResponse = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:8080/api/servers" -TimeoutSec 5
        if ($serversResponse.Content -notmatch "127\.0\.0\.1:25565") {
            throw "Local master REST list did not expose the advertised TES3MP endpoint.`nresponse:`n$($serversResponse.Content)`nmaster stdout:`n$masterLog`nmaster stderr:`n$(Read-SmokeLog $masterErr)`nserver stdout:`n$(Read-SmokeLog $serverOut)`nserver stderr:`n$(Read-SmokeLog $serverErr)"
        }

        $runHubProbe = {
            param(
                [string[]] $Arguments,
                [string] $Description,
                [string] $ExpectedPattern
            )

            Remove-Item -LiteralPath $hubOut, $hubErr -ErrorAction SilentlyContinue
            $process = Start-Process -FilePath $hubExe -ArgumentList $Arguments -WorkingDirectory $runtimeDir `
                -RedirectStandardOutput $hubOut -RedirectStandardError $hubErr -WindowStyle Hidden -PassThru
            $exited = $process.WaitForExit(30000)
            if (-not $exited) {
                Stop-SmokeProcess $process
                throw "$Description timed out.`nstdout:`n$(Read-SmokeLog $hubOut)`nstderr:`n$(Read-SmokeLog $hubErr)`nmaster stdout:`n$(Read-SmokeLog $masterOut)`nmaster stderr:`n$(Read-SmokeLog $masterErr)`nserver stdout:`n$(Read-SmokeLog $serverOut)`nserver stderr:`n$(Read-SmokeLog $serverErr)"
            }

            $process.WaitForExit()
            $process.Refresh()
            $exitCode = $process.ExitCode
            $log = Read-SmokeLog $hubOut
            $errorLog = Read-SmokeLog $hubErr
            if ($null -eq $exitCode -and $process.HasExited -and $log -match $ExpectedPattern -and
                [string]::IsNullOrWhiteSpace($errorLog)) {
                $exitCode = 0
            }

            if ($exitCode -ne 0 -or $log -notmatch $ExpectedPattern) {
                throw "$Description failed with code $exitCode.`nstdout:`n$log`nstderr:`n$errorLog`nmaster stdout:`n$(Read-SmokeLog $masterOut)`nmaster stderr:`n$(Read-SmokeLog $masterErr)`nserver stdout:`n$(Read-SmokeLog $serverOut)`nserver stderr:`n$(Read-SmokeLog $serverErr)"
            }
        }

        for ($probeIndex = 1; $probeIndex -le $HubProbeIterations; ++$probeIndex) {
            & $runHubProbe -Arguments @("--query-master-once", "--master-address=localhost", "--master-port=25560") `
                -Description "Hub master query smoke #$probeIndex" -ExpectedPattern "127\.0\.0\.1:25565"
            & $runHubProbe -Arguments @("--query-server-once", "--master-address=localhost", "--master-port=25560", "--server-address=127.0.0.1", "--server-port=25565") `
                -Description "Hub master update smoke #$probeIndex" -ExpectedPattern "Master update details: listedPlayers=0 reportedPlayers=0 maxPlayers=64 plugins=3 rules=[1-9][0-9]*"
            & $runHubProbe -Arguments @("--ping-server-once", "--server-address=127.0.0.1", "--server-port=25565") `
                -Description "Hub direct ping smoke #$probeIndex" -ExpectedPattern "Server ping returned"
        }
    }

    Write-Host "TES3MP runtime smoke passed."
    Write-Host "Default serverCore.lua startup callbacks were observed."
    Write-Host "Legacy global Lua callbacks fired through the plugin loader."
    Write-Host "Lua timer callback smoke fired with string/int/float arguments."
    Write-Host "Account registration, separate chargen name, bad-password retry, and handshake relog smoke passed."
    Write-Host "Account registration and character identity survived a server restart."
    Write-Host "Player death, stale death timer guard, and configured respawn revive smoke passed."
    Write-Host "Player revived state and respawn location survived a server restart."
    Write-Host "Player disconnect save, stale confiscation cleanup, IP removal, cell-unload snapshot, and immediate reconnect smoke passed."
    Write-Host "Player disconnect-saved state survived a server restart."
        Write-Host "CommunityMP XML player persistence save/load smoke passed."
        Write-Host "CommunityMP XML player persistence survived a server restart."
    if ($WithLocalMaster) {
        Write-Host "Local GNS master announcement observed."
        Write-Host "Local master server list exposed the advertised game endpoint."
        Write-Host "Hub binary master query returned the advertised game endpoint for $HubProbeIterations refresh cycle(s)."
        Write-Host "Hub binary master update returned the advertised game endpoint for $HubProbeIterations refresh cycle(s)."
        Write-Host "Hub binary direct ping reached the advertised game endpoint for $HubProbeIterations refresh cycle(s)."
    }
}
finally {
    Stop-SmokeProcess $server
    Stop-SmokeProcess $master

    if ($hadUserConfig -and (Test-Path -LiteralPath $configBackup)) {
        Copy-Item -LiteralPath $configBackup -Destination $serverConfig -Force
    }
    else {
        Remove-Item -LiteralPath $serverConfig -ErrorAction SilentlyContinue
    }


    if (Test-Path -LiteralPath $customScriptsBackup) {
        Copy-Item -LiteralPath $customScriptsBackup -Destination $customScriptsConfig -Force
    }

    Remove-Item -LiteralPath $configBackup, $serverOut, $serverErr, $masterOut, $masterErr, $hubOut, $hubErr, $customScriptsBackup, $timerSmokeScript, $timerSmokeResult, $globalCallbackSmokeScript, $globalCallbackSmokeResult, $accountFlowSmokeScript, $accountFlowSmokeResult, $accountFlowRestartSmokeScript, $accountFlowRestartSmokeResult, $accountFlowSmokeFile, $deathFlowSmokeScript, $deathFlowSmokeResult, $deathFlowRestartSmokeScript, $deathFlowRestartSmokeResult, $deathFlowSmokeFile, $disconnectFlowSmokeScript, $disconnectFlowSmokeResult, $disconnectFlowRestartSmokeScript, $disconnectFlowRestartSmokeResult, $disconnectFlowSmokeFile, $jsonPlayerSmokeScript, $jsonPlayerSmokeResult, $jsonPlayerRestartSmokeScript, $jsonPlayerRestartSmokeResult, $jsonPlayerSmokeFile -ErrorAction SilentlyContinue
}
