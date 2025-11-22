--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Knit
local Knit = require(ReplicatedStorage.Packages.Knit)

--// Modules
local SeatGame = ReplicatedStorage:WaitForChild("SeatGame")
local ProfileStore = require(SeatGame.Modules.ProfileStore)

--// Create Service
local DataService = Knit.CreateService {
	Name = "DataService",
	Client = {},
}

--// Config
local PROFILE_STORE_NAME = "PlayerData"
local DEFAULT_DATA = {
	OwnedChairs = {
		Default = true,
	},
	EquippedChair = "Default",
	Rolls = 0,
}

--// Variables
local profileStore = ProfileStore.New(PROFILE_STORE_NAME, DEFAULT_DATA)
local profiles = {}

local chairEquippedEvent = Instance.new("BindableEvent")
chairEquippedEvent.Name = "ChairEquipped"
chairEquippedEvent.Parent = SeatGame

--// Studio Check
if game:GetService("RunService"):IsStudio() then
	local DataStoreService = game:GetService("DataStoreService")
	local success = pcall(function()
		DataStoreService:GetDataStore("_StudioAPICheck"):GetAsync("test")
	end)

	if not success then
		warn("========================================")
		warn("[DataService] STUDIO API SERVICES NOT ENABLED!")
		warn("[DataService] Data will NOT persist in Studio.")
		warn("[DataService] To enable: Game Settings > Security > Enable Studio Access to API Services")
		warn("========================================")
	end
end

--// Server Methods
function DataService:GetProfile(player)
	return profiles[player]
end

function DataService:GetData(player)
	local profile = profiles[player]
	if profile then
		return profile.Data
	end
	return nil
end

function DataService:OwnsChair(player, chairName)
	local data = self:GetData(player)
	if not data then return false end

	return data.OwnedChairs[chairName] == true
end

function DataService:AddChair(player, chairName)
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

function DataService:SetEquippedChair(player, chairName)
	local profile = self:GetProfile(player)
	if not profile then return false end

	local data = profile.Data
	if not data then return false end

	if chairName == "None" or data.OwnedChairs[chairName] then
		data.EquippedChair = chairName

		pcall(function()
			profile:Save()
		end)

		chairEquippedEvent:Fire(player, chairName)

		return true
	end

	return false
end

function DataService:GetEquippedChair(player)
	local data = self:GetData(player)
	if data then
		return data.EquippedChair
	end
	return "Default"
end

function DataService:IncrementRolls(player)
	local profile = self:GetProfile(player)
	if not profile then return false end

	local data = profile.Data
	if not data then return false end

	data.Rolls = (data.Rolls or 0) + 1

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rollsStat = leaderstats:FindFirstChild("Rolls")
		if rollsStat then
			rollsStat.Value = data.Rolls
		end
	end

	pcall(function()
		profile:Save()
	end)

	return true
end

function DataService:GetRolls(player)
	local data = self:GetData(player)
	if data then
		return data.Rolls or 0
	end
	return 0
end

function DataService.Client:OwnsChair(player, chairName)
	return self.Server:OwnsChair(player, chairName)
end

function DataService.Client:GetOwnedChairs(player)
	local data = self.Server:GetData(player)
	if data then
		local ownedList = {}
		for chairName, isOwned in pairs(data.OwnedChairs) do
			if isOwned then
				table.insert(ownedList, chairName)
			end
		end
		print(string.format("[DataService] GetOwnedChairs for %s: %d chairs", player.Name, #ownedList))
		return ownedList
	end
	warn(string.format("[DataService] No data for player %s, returning Default only", player.Name))
	return {"Default"}
end

function DataService.Client:GetEquippedChair(player)
	return self.Server:GetEquippedChair(player)
end

function DataService.Client:SetEquippedChair(player, chairName)
	return self.Server:SetEquippedChair(player, chairName)
end

function DataService.Client:UnlockChair(player, chairName)
	return self.Server:AddChair(player, chairName)
end

function DataService.Client:IncrementRolls(player)
	return self.Server:IncrementRolls(player)
end

--// Player Lifecycle
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
			for _, folder in ipairs(seatModels:GetChildren()) do
				if folder:IsA("Folder") then
					for _, seatModel in ipairs(folder:GetChildren()) do
						if seatModel:IsA("Model") then
							if profile.Data.OwnedChairs[seatModel.Name] == nil then
								profile.Data.OwnedChairs[seatModel.Name] = false
							end
						end
					end
				end
			end
		end

		if profile.Data.OwnedChairs["Default"] == nil then
			profile.Data.OwnedChairs["Default"] = true
		end

		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player

		local rollsStat = Instance.new("IntValue")
		rollsStat.Name = "Rolls"
		rollsStat.Value = profile.Data.Rolls or 0
		rollsStat.Parent = leaderstats

		profiles[player] = profile

		profile.OnSessionEnd:Connect(function()
			profiles[player] = nil
			player:Kick("Session released")
		end)

		if not player:IsDescendantOf(Players) then
			profile:EndSession()
		end
	else
		warn(`[DataService] Failed to load profile for {player.Name}`)
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

--// Knit Lifecycle
function DataService:KnitInit()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	print("✓ DataService Initialized", {
		ProfileStore = PROFILE_STORE_NAME,
		DefaultChair = "Default",
		Communication = "Knit"
	})
end

function DataService:KnitStart()
end

return DataService
