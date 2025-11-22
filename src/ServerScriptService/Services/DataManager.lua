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

local chairEquippedEvent = Instance.new("BindableEvent")
chairEquippedEvent.Name = "ChairEquipped"
chairEquippedEvent.Parent = SeatGame

--// Module
local DataManager = {}

--// Config
local PROFILE_STORE_NAME = "PlayerData"
local DEFAULT_DATA = {
	OwnedChairs = {
		Default = true,
	},
	EquippedChair = "Default",
}

--// Variables
local profileStore = ProfileStore.New(PROFILE_STORE_NAME, DEFAULT_DATA)
local profiles = {}

--// Studio Check
if game:GetService("RunService"):IsStudio() then
	local DataStoreService = game:GetService("DataStoreService")
	local success = pcall(function()
		DataStoreService:GetDataStore("_StudioAPICheck"):GetAsync("test")
	end)

	if not success then
		warn("========================================")
		warn("[DataManager] STUDIO API SERVICES NOT ENABLED!")
		warn("[DataManager] Data will NOT persist in Studio.")
		warn("[DataManager] To enable: Game Settings > Security > Enable Studio Access to API Services")
		warn("========================================")
	end
end

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

	return data.OwnedChairs[chairName] == true
end

function DataManager:AddChair(player, chairName)
	local profile = self:GetProfile(player)
	if not profile then
		return false
	end

	local data = profile.Data
	if not data then
		return false
	end

	if data.OwnedChairs[chairName] == false then
		data.OwnedChairs[chairName] = true

		pcall(function()
			profile:Save()
		end)

		return true
	end

	return false
end

function DataManager:SetEquippedChair(player, chairName)
	local profile = self:GetProfile(player)
	if not profile then return false end

	local data = profile.Data
	if not data then return false end

	if data.OwnedChairs[chairName] then
		data.EquippedChair = chairName

		-- Save to datastore
		pcall(function()
			profile:Save()
		end)

		-- Fire event to swap physical chair
		chairEquippedEvent:Fire(player, chairName)

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

		local seatModels = SeatGame:FindFirstChild("SeatModels")
		if seatModels then
			for _, seatModel in seatModels:GetChildren() do
				if seatModel:IsA("Model") then
					if profile.Data.OwnedChairs[seatModel.Name] == nil then
						profile.Data.OwnedChairs[seatModel.Name] = false
					end
				end
			end
		end

		if profile.Data.OwnedChairs["Default"] == nil then
			profile.Data.OwnedChairs["Default"] = true
		end

		profiles[player] = profile

		profile.OnSessionEnd:Connect(function()
			profiles[player] = nil
			player:Kick("Session released")
		end)

		if not player:IsDescendantOf(Players) then
			profile:EndSession()
		end
	else
		warn(`[DataManager] Failed to load profile for {player.Name}`)
		player:Kick("Failed to load data")
	end
end

local function onPlayerRemoving(player)
	local profile = profiles[player]
	if profile then
		pcall(function()
			profile:EndSession()
		end)

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
		if data then
			local ownedList = {}
			for chairName, isOwned in pairs(data.OwnedChairs) do
				if isOwned then
					table.insert(ownedList, chairName)
				end
			end
			return ownedList
		end
		return {"Default"}
	elseif action == "GetEquippedChair" then
		return DataManager:GetEquippedChair(player)
	elseif action == "SetEquippedChair" then
		local chairName = ...
		return DataManager:SetEquippedChair(player, chairName)
	elseif action == "UnlockChair" then
		local chairName = ...
		return DataManager:AddChair(player, chairName)
	end
	return nil
end

--// Initialize
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

print("✓ DataManager Initialized", {
	ProfileStore = PROFILE_STORE_NAME,
	DefaultChair = "Default",
	Remotes = "DataRemote"
})

return DataManager
