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

	-- Configure all parts in the chair
	for _, part in chairClone:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			part.CollisionGroup = "PlayerChair"
			pcall(function()
				part:SetNetworkOwner(player)
			end)
		end
	end

	-- Weld all chair parts to AnchorPart
	for _, part in chairClone:GetDescendants() do
		if part:IsA("BasePart") and part ~= anchorPart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = anchorPart
			weld.Part1 = part
			weld.Parent = part
		end
	end

	-- Parent chair to workspace
	chairClone.Parent = Workspace

	-- Find ground position under player
	local playerPos = humanoidRootPart.Position
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character, chairClone}

	local rayResult = Workspace:Raycast(playerPos + Vector3.new(0, 5, 0), Vector3.new(0, -100, 0), rayParams)
	local groundY = rayResult and rayResult.Position.Y or (playerPos.Y - 3)

	-- Get player's facing direction
	local lookVec = humanoidRootPart.CFrame.LookVector
	local rotation = math.atan2(lookVec.X, lookVec.Z)

	-- Position AnchorPart on ground at player's X,Z
	anchorPart.CFrame = CFrame.new(playerPos.X, groundY, playerPos.Z) * CFrame.Angles(0, rotation, 0)

	-- Wait a frame for physics to settle
	task.wait()

	-- Teleport player to Seat to sit them down
	humanoidRootPart.CFrame = seatPart.CFrame

	-- Wait for player to be seated
	task.wait(0.1)

	-- NOW weld the AnchorPart to player (after they're seated)
	local weld = Instance.new("Weld")
	weld.Name = "ChairToPlayerWeld"
	weld.Part0 = humanoidRootPart
	weld.Part1 = anchorPart
	weld.C0 = humanoidRootPart.CFrame:ToObjectSpace(anchorPart.CFrame)
	weld.C1 = CFrame.new()
	weld.Parent = anchorPart

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
