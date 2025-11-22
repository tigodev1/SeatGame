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

	-- Jump to unseat from current chair
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	task.wait(0.1)

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

	-- Find the AnchorPart and Seat part
	local anchorPart = chairClone:FindFirstChild("AnchorPart")
	local seatPart = chairClone:FindFirstChild("Seat")

	if not anchorPart or not seatPart then
		warn("Chair missing AnchorPart or Seat:", chairName)
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

	-- Parent chair to character
	chairClone.Parent = character

	-- Weld all chair parts to the AnchorPart FIRST
	for _, part in chairClone:GetDescendants() do
		if part:IsA("BasePart") and part ~= anchorPart then
			local partWeld = Instance.new("WeldConstraint")
			partWeld.Part0 = anchorPart
			partWeld.Part1 = part
			partWeld.Parent = part
		end
	end

	-- Teleport player to Seat position to sit them on the seat
	task.wait(0.1)
	humanoidRootPart.CFrame = seatPart.CFrame
	task.wait(0.1)

	-- Raycast to find ground under player
	local playerPosition = humanoidRootPart.Position
	local rayOrigin = playerPosition + Vector3.new(0, 5, 0)
	local rayDirection = Vector3.new(0, -100, 0)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {character, chairClone}

	local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	local groundY = raycastResult and raycastResult.Position.Y or (playerPosition.Y - 3)

	-- Position AnchorPart on the ground at player X,Z
	local anchorPosition = Vector3.new(playerPosition.X, groundY, playerPosition.Z)
	-- Keep the player's facing direction
	local lookDirection = humanoidRootPart.CFrame.LookVector
	local anchorCFrame = CFrame.new(anchorPosition) * CFrame.Angles(0, math.atan2(lookDirection.X, lookDirection.Z), 0)
	anchorPart.CFrame = anchorCFrame

	-- Weld AnchorPart to player's HumanoidRootPart so chair follows movement
	local anchorWeld = Instance.new("Weld")
	anchorWeld.Name = "ChairToPlayerWeld"
	anchorWeld.Part0 = humanoidRootPart
	anchorWeld.Part1 = anchorPart
	-- Calculate the offset from player to anchor
	anchorWeld.C0 = humanoidRootPart.CFrame:ToObjectSpace(anchorPart.CFrame)
	anchorWeld.C1 = CFrame.new(0, 0, 0)
	anchorWeld.Parent = anchorPart

	-- Store reference
	playerChairs[player] = chairClone
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
