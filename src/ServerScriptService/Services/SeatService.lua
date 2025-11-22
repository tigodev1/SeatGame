--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--// Knit
local Knit = require(ReplicatedStorage.Packages.Knit)

--// Instances
local SeatGame = ReplicatedStorage:WaitForChild("SeatGame")
local SeatModels = SeatGame:WaitForChild("SeatModels")

--// Create Service
local SeatService = Knit.CreateService {
	Name = "SeatService",
	Client = {},
}

--// References
local DataService = nil -- Will be set in KnitStart

--// State
local playerChairs = {} -- [player] = chairModel

--// Functions
local function findChairModel(chairName)
	-- Search through all rarity folders to find the chair
	for _, folder in ipairs(SeatModels:GetChildren()) do
		if folder:IsA("Folder") then
			local model = folder:FindFirstChild(chairName)
			if model and model:IsA("Model") then
				return model
			end
		end
	end
	return nil
end

local function removePlayerChair(player)
	local existingChair = playerChairs[player]
	if existingChair and existingChair.Parent then
		existingChair:Destroy()
	end
	playerChairs[player] = nil
end

local function attachChairToPlayer(player, chairName)
	local character = player.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	-- Remove any existing chair
	removePlayerChair(player)

	-- If chairName is nil or "None", just remove the chair (normal walking)
	if not chairName or chairName == "None" then
		return
	end

	-- Find and clone the chair model
	local chairModel = findChairModel(chairName)
	if not chairModel then return end

	local chairClone = chairModel:Clone()
	chairClone.Parent = character

	-- Find the Seat part to use as anchor
	local seatPart = chairClone:FindFirstChild("Seat")
	if not seatPart then
		chairClone:Destroy()
		return
	end

	-- Make all parts non-collidable with the player
	for _, part in chairClone:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true

			-- Set collision group to not collide with player
			part.CollisionGroup = "PlayerChair"
		end
	end

	-- Position the chair below the player
	local offset = CFrame.new(0, -2, 0) -- Adjust Y offset to position chair under player

	-- Create weld to attach chair to player
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = humanoidRootPart
	weld.Part1 = seatPart
	weld.Parent = seatPart

	-- Position the chair model
	chairClone:PivotTo(humanoidRootPart.CFrame * offset)

	-- Store reference
	playerChairs[player] = chairClone

	-- Animate the sitting pose
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		-- Load sitting animation
		local sitAnim = Instance.new("Animation")
		sitAnim.AnimationId = "rbxassetid://2506281703" -- Roblox default sit animation
		local sitTrack = humanoid:LoadAnimation(sitAnim)
		sitTrack:Play()

		-- Store animation track for cleanup
		chairClone:SetAttribute("SitAnimationTrack", sitTrack)
	end
end

function SeatService:SwapPlayerChair(player)
	local equippedChairName = DataService:GetEquippedChair(player)
	attachChairToPlayer(player, equippedChairName)
end

function SeatService:RemovePlayerChair(player)
	removePlayerChair(player)

	-- Stop sitting animation
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			-- Stop any sitting animations
			for _, track in humanoid:GetPlayingAnimationTracks() do
				if track.Animation.AnimationId == "rbxassetid://2506281703" then
					track:Stop()
				end
			end
		end
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)

		-- Get equipped chair and attach it
		local equippedChairName = DataService:GetEquippedChair(player)
		if equippedChairName and equippedChairName ~= "None" then
			attachChairToPlayer(player, equippedChairName)
		end
	end)

	if player.Character then
		task.wait(0.5)
		local equippedChairName = DataService:GetEquippedChair(player)
		if equippedChairName and equippedChairName ~= "None" then
			attachChairToPlayer(player, equippedChairName)
		end
	end
end

local function onPlayerRemoving(player)
	removePlayerChair(player)
	playerChairs[player] = nil
end

--// Knit Lifecycle
function SeatService:KnitInit()
	-- Setup collision group for chairs
	local PhysicsService = game:GetService("PhysicsService")
	pcall(function()
		PhysicsService:CreateCollisionGroup("PlayerChair")
		PhysicsService:CollisionGroupSetCollidable("PlayerChair", "PlayerChair", false)
	end)

	-- Initialize player lifecycle
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- Count total chair models across all rarity folders
	local totalModels = 0
	for _, folder in ipairs(SeatModels:GetChildren()) do
		if folder:IsA("Folder") then
			for _, model in ipairs(folder:GetChildren()) do
				if model:IsA("Model") then
					totalModels = totalModels + 1
				end
			end
		end
	end

	print("✓ SeatService Initialized", {
		SeatModels = totalModels,
		Movement = "Free movement with chairs attached"
	})
end

function SeatService:KnitStart()
	-- Get DataService reference
	DataService = Knit.GetService("DataService")

	-- Listen for chair equip events
	local chairEquippedEvent = SeatGame:WaitForChild("ChairEquipped")
	chairEquippedEvent.Event:Connect(function(player, chairName)
		self:SwapPlayerChair(player)
	end)
end

return SeatService
