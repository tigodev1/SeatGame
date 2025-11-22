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

	-- Stop sitting animation
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			-- Stop any sitting animations
			for _, track in humanoid:GetPlayingAnimationTracks() do
				if track.Animation and track.Animation.AnimationId == "rbxassetid://2506281703" then
					track:Stop()
				end
			end
		end
	end
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

	-- Find the Seat part to use as anchor
	local seatPart = chairClone:FindFirstChild("Seat")
	if not seatPart then
		chairClone:Destroy()
		return
	end

	-- Unanchor and setup all parts
	for _, part in chairClone:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			part.CollisionGroup = "PlayerChair"
		end
	end

	-- Make sure the main seat part is also unanchored
	seatPart.Anchored = false
	seatPart.CanCollide = false

	-- Parent to character
	chairClone.Parent = character

	-- Position the chair below the player
	local offset = CFrame.new(0, -2, 0)
	seatPart.CFrame = humanoidRootPart.CFrame * offset

	-- Weld ALL chair parts to the main seat part to keep model together
	for _, part in chairClone:GetDescendants() do
		if part:IsA("BasePart") and part ~= seatPart then
			local partWeld = Instance.new("Weld")
			partWeld.Name = "ChairPartWeld"
			partWeld.Part0 = seatPart
			partWeld.Part1 = part
			partWeld.C0 = seatPart.CFrame:ToObjectSpace(part.CFrame)
			partWeld.C1 = CFrame.new()
			partWeld.Parent = part
		end
	end

	-- Create main weld to attach chair to player
	local mainWeld = Instance.new("Weld")
	mainWeld.Name = "ChairToPlayerWeld"
	mainWeld.Part0 = humanoidRootPart
	mainWeld.Part1 = seatPart
	mainWeld.C0 = CFrame.new(0, 0, 0)
	mainWeld.C1 = seatPart.CFrame:ToObjectSpace(humanoidRootPart.CFrame)
	mainWeld.Parent = seatPart

	-- Store reference
	playerChairs[player] = chairClone

	-- Animate the sitting pose
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		task.wait(0.1)

		-- Load sitting animation
		local sitAnim = Instance.new("Animation")
		sitAnim.AnimationId = "rbxassetid://2506281703"
		local sitTrack = humanoid:LoadAnimation(sitAnim)
		sitTrack.Priority = Enum.AnimationPriority.Action
		sitTrack.Looped = true
		sitTrack:Play()

		-- Store animation track in the chair for cleanup
		local animValue = Instance.new("ObjectValue")
		animValue.Name = "SitAnimationTrack"
		animValue.Value = sitTrack
		animValue.Parent = chairClone
	end
end

function SeatService:SwapPlayerChair(player)
	local equippedChairName = DataService:GetEquippedChair(player)
	attachChairToPlayer(player, equippedChairName)
end

function SeatService:RemovePlayerChair(player)
	removePlayerChair(player)
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
