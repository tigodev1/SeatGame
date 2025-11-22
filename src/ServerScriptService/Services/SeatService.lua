--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoidRootPart or not humanoid then return end

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

	-- Find the Seat part
	local seatPart = chairClone:FindFirstChild("Seat")
	if not seatPart then
		chairClone:Destroy()
		return
	end

	-- Setup all parts in the chair
	for _, part in chairClone:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			part.CollisionGroup = "PlayerChair"

			-- Set network ownership to prevent shaking
			pcall(function()
				part:SetNetworkOwner(player)
			end)
		end
	end

	-- Unanchor the seat part
	seatPart.Anchored = false
	seatPart.CanCollide = false

	-- Parent chair to workspace
	chairClone.Parent = Workspace

	-- Position chair on the ground near the player
	local playerPosition = humanoidRootPart.Position
	local rayOrigin = playerPosition + Vector3.new(0, 10, 0)
	local rayDirection = Vector3.new(0, -50, 0)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {character, chairClone}

	local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	local groundY = raycastResult and raycastResult.Position.Y or playerPosition.Y

	-- Position the chair on the ground
	local chairPosition = Vector3.new(playerPosition.X, groundY, playerPosition.Z)
	seatPart.CFrame = CFrame.new(chairPosition)

	-- Weld all chair parts to the seat part
	for _, part in chairClone:GetDescendants() do
		if part:IsA("BasePart") and part ~= seatPart then
			local partWeld = Instance.new("WeldConstraint")
			partWeld.Part0 = seatPart
			partWeld.Part1 = part
			partWeld.Parent = part
		end
	end

	-- Anchor the seat so it stays on the ground
	seatPart.Anchored = true

	-- Teleport player to the chair
	local sitPosition = seatPart.CFrame * CFrame.new(0, 2, 0)
	humanoidRootPart.CFrame = sitPosition

	-- Weld player to the chair
	local playerWeld = Instance.new("Weld")
	playerWeld.Name = "PlayerToChairWeld"
	playerWeld.Part0 = seatPart
	playerWeld.Part1 = humanoidRootPart
	playerWeld.C0 = CFrame.new(0, 2, 0)
	playerWeld.C1 = CFrame.new(0, 0, 0)
	playerWeld.Parent = humanoidRootPart

	-- Store reference
	playerChairs[player] = chairClone

	-- Play sitting animation
	task.spawn(function()
		task.wait(0.1)

		local sitAnim = Instance.new("Animation")
		sitAnim.AnimationId = "rbxassetid://2506281703"
		local sitTrack = humanoid:LoadAnimation(sitAnim)
		sitTrack.Priority = Enum.AnimationPriority.Action
		sitTrack.Looped = true
		sitTrack:Play()

		-- Store animation track
		local animValue = Instance.new("ObjectValue")
		animValue.Name = "SitAnimationTrack"
		animValue.Value = sitTrack
		animValue.Parent = chairClone
	end)
end

function SeatService:SwapPlayerChair(player)
	local equippedChairName = DataService:GetEquippedChair(player)
	attachChairToPlayer(player, equippedChairName)
end

function SeatService:RemovePlayerChair(player)
	removePlayerChair(player)

	-- Remove weld from player
	local character = player.Character
	if character then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			local weld = humanoidRootPart:FindFirstChild("PlayerToChairWeld")
			if weld then
				weld:Destroy()
			end
		end

		-- Stop sitting animation
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			for _, track in humanoid:GetPlayingAnimationTracks() do
				if track.Animation and track.Animation.AnimationId == "rbxassetid://2506281703" then
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
