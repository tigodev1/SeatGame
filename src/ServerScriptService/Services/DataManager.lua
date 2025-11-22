--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules
local SeatGame = ReplicatedStorage:WaitForChild("SeatGame")
local ProfileStore = require(SeatGame.Modules.ProfileStore)

--// Remotes
local remoteFunction = Instance.new("RemoteFunction")
remoteFunction.Name = "DataRemote"
remoteFunction.Parent = SeatGame

--// Module
local DataManager = {}

--// Config
local PROFILE_STORE_NAME = "PlayerData"
local DEFAULT_DATA = {
	OwnedChairs = {"Default"},
	EquippedChair = "Default",
}

--// Variables
local profileStore = ProfileStore.New(PROFILE_STORE_NAME, DEFAULT_DATA)
local profiles = {}

--// Functions
function DataManager:GetProfile(player)
	return profiles[player]
end

function DataManager:GetData(player)
	local profile = profiles[player]
	if profile then
		return profile.Data
	end
	return nil
end

function DataManager:OwnsChair(player, chairName)
	local data = self:GetData(player)
	if not data then return false end

	return table.find(data.OwnedChairs, chairName) ~= nil
end

function DataManager:AddChair(player, chairName)
	local data = self:GetData(player)
	if not data then return false end

	if not table.find(data.OwnedChairs, chairName) then
		table.insert(data.OwnedChairs, chairName)
		return true
	end

	return false
end

function DataManager:SetEquippedChair(player, chairName)
	local data = self:GetData(player)
	if not data then return false end

	if table.find(data.OwnedChairs, chairName) then
		data.EquippedChair = chairName
		return true
	end

	return false
end

function DataManager:GetEquippedChair(player)
	local data = self:GetData(player)
	if data then
		return data.EquippedChair
	end
	return "Default"
end

local function onPlayerAdded(player)
	local profile = profileStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player:IsDescendantOf(Players) == false
		end
	})

	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profiles[player] = profile

		profile:ListenToRelease(function()
			profiles[player] = nil
			player:Kick("Session released")
		end)

		if player:IsDescendantOf(Players) then
			print(`Profile loaded for {player.Name}`)
		else
			profile:EndSession()
		end
	else
		player:Kick("Failed to load data")
	end
end

local function onPlayerRemoving(player)
	local profile = profiles[player]
	if profile then
		profile:EndSession()
		profiles[player] = nil
	end
end

--// Remote Handler
remoteFunction.OnServerInvoke = function(player, action, ...)
	if action == "OwnsChair" then
		local chairName = ...
		return DataManager:OwnsChair(player, chairName)
	elseif action == "GetOwnedChairs" then
		local data = DataManager:GetData(player)
		return data and data.OwnedChairs or {"Default"}
	elseif action == "GetEquippedChair" then
		return DataManager:GetEquippedChair(player)
	end
	return nil
end

--// Initialize
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

return DataManager
