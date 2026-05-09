--[[
    YourHub - Loader/Games.lua
    Entry point utama. Detect game, init core, load features.
    Re-execute safe via getgenv() singleton guard.
]]

-- ============================================================
-- SINGLETON GUARD — re-execute safe
-- ============================================================
if getgenv().YourHub then
    -- Cleanup sebelumnya sebelum re-execute
    if getgenv().YourHub.Cleanup then
        getgenv().YourHub.Cleanup()
    end
end

-- Init global namespace
getgenv().YourHub = {
    Version    = "1.0.0",
    Name       = "YourHub",
    Loaded     = false,
    GameId     = nil,
    GameConfig = nil,
    Cleanup    = nil,
}

local Hub = getgenv().YourHub

-- ============================================================
-- SERVICES
-- ============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- BASE PATH — ganti sesuai cara kamu load script
-- Untuk Delta executor, semua file di-require via loadstring(game:HttpGet(...))
-- atau bisa menggunakan folder lokal jika executor support filesystem
-- ============================================================

-- Helper require dari raw URL atau path lokal
-- Contoh: loadstring(game:HttpGet("https://raw.githubusercontent.com/.../Core/Init.lua"))()
-- Untuk simplicity, kita pakai pattern require tabel inline

-- ============================================================
-- GAME REGISTRY — tambah game baru di sini
-- ============================================================
local GAME_REGISTRY = {
    -- [PlaceId] = "GameConfigPath"
    [92416421522960] = "SlimeRNG",  -- Slime RNG
    -- Tambah game baru nanti:
    -- [12345678] = "BloxFruits",
    -- [87654321] = "PetSimX",
}

-- ============================================================
-- DETECT GAME
-- ============================================================
local currentPlaceId = game.PlaceId
local gameName = GAME_REGISTRY[currentPlaceId]

if not gameName then
    warn("[YourHub] Game tidak dikenali. PlaceId: " .. tostring(currentPlaceId))
    warn("[YourHub] Tambahkan PlaceId ke GAME_REGISTRY di Loader/Games.lua")
    return
end

Hub.GameId   = currentPlaceId
Hub.GameName = gameName

print("[YourHub] ✓ Game terdeteksi: " .. gameName)

-- ============================================================
-- LOAD CORE SYSTEMS
-- ============================================================
-- Di real implementation, ini di-require dari URL atau filesystem
-- Untuk sekarang, kita load inline sesuai struktur

local Core        = require(script.Parent.Core.Init)
local Globals     = require(script.Parent.Shared.Globals)
local Flags       = require(script.Parent.Config.Flags)
local Settings    = require(script.Parent.Config.Settings)

-- Init core (scheduler, cache, connections, remotes, utilities)
Core.Init()

-- ============================================================
-- LOAD GAME CONFIG
-- ============================================================
local GameConfig = require(script.Parent.Games[gameName])
Hub.GameConfig = GameConfig

-- Init remotes dari game config
local Remotes = require(script.Parent.Core.Remotes)
Remotes.LoadFromConfig(GameConfig.Remotes)

-- Init cache folders dari game config
local Cache = require(script.Parent.Core.Cache)
Cache.LoadFolders(GameConfig.Folders)

-- ============================================================
-- LOAD FEATURES UNIVERSAL
-- ============================================================
local FeaturePaths = {
    ESP          = script.Parent.Features.Universal.ESP,
    Fly          = script.Parent.Features.Universal.Fly,
    NoClip       = script.Parent.Features.Universal.NoClip,
    Teleport     = script.Parent.Features.Universal.Teleport,
    Notifications = script.Parent.Features.Universal.Notifications,
}

-- ============================================================
-- LOAD FEATURES GAME-SPECIFIC
-- ============================================================
local GameFeaturePaths = {
    AutoFarm        = script.Parent.Features[gameName].AutoFarm,
    AutoRoll        = script.Parent.Features[gameName].AutoRoll,
    AutoPotion      = script.Parent.Features[gameName].AutoPotion,
    AutoCraft       = script.Parent.Features[gameName].AutoCraft,
    AutoUpgrade     = script.Parent.Features[gameName].AutoUpgrade,
    AutoEquipBestPet = script.Parent.Features[gameName].AutoEquipBestPet,
    AutoBuyZone     = script.Parent.Features[gameName].AutoBuyZone,
    AutoTeleportZone = script.Parent.Features[gameName].AutoTeleportZone,
}

-- Load semua features yang ada di game config
local LoadedFeatures = {}
local Scheduler = require(script.Parent.Core.Scheduler)

for _, featureName in ipairs(GameConfig.Features) do
    local path = FeaturePaths[featureName] or GameFeaturePaths[featureName]
    if path then
        local ok, feature = pcall(require, path)
        if ok and feature then
            LoadedFeatures[featureName] = feature
            -- Init feature (register ke scheduler jika perlu)
            if feature.Init then
                feature.Init()
            end
            print("[YourHub] ✓ Feature loaded: " .. featureName)
        else
            warn("[YourHub] ✗ Gagal load feature: " .. featureName .. " | " .. tostring(feature))
        end
    end
end

Hub.Features = LoadedFeatures

-- ============================================================
-- LOAD UI
-- ============================================================
local Window = require(script.Parent.UI.Window)
Window.Create(GameConfig)

-- ============================================================
-- START SCHEDULER
-- ============================================================
Scheduler.Start()

-- ============================================================
-- CLEANUP FUNCTION (untuk re-execute)
-- ============================================================
Hub.Cleanup = function()
    print("[YourHub] Melakukan cleanup...")

    -- Stop scheduler
    if Scheduler.Stop then Scheduler.Stop() end

    -- Cleanup semua connections
    local Connections = require(script.Parent.Core.Connections)
    Connections.CleanupAll()

    -- Destroy UI
    if Window.Destroy then Window.Destroy() end

    -- Reset flags
    Flags.ResetAll()

    -- Clear cache
    if Cache.Clear then Cache.Clear() end

    print("[YourHub] ✓ Cleanup selesai.")
end

Hub.Loaded = true
print("[YourHub] ✓ Hub berhasil dimuat! Game: " .. gameName .. " | v" .. Hub.Version)
