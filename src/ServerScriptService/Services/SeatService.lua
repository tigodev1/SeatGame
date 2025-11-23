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
local DataService = nil

--// State
local playerChairs = {}
local playerConnections = {}
local playerAnimations = {}

--// Functions
local function findChairModel(chairName)
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
	if playerAnimations[player] then
		playerAnimations[player]:Stop()
		playerAnimations[player] = nil
	end

	if playerConnections[player] then
		for _, connection in playerConnections[player] do
			connection:Disconnect()
		end
		playerConnections[player] = nil
	end

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

	removePlayerChair(player)

	if not chairName or chairName == "None" then
		return
	end

	local chairModel = findChairModel(chairName)
	if not chairModel then return end

	local chairClone = chairModel:Clone()

	local anchorPart = chairClone:FindFirstChild("AnchorPart")
	local seatPart = chairClone:FindFirstChild("Seat")

	if not anchorPart or not seatPart then
		warn("Chair missing AnchorPart or Seat:", chairName)
		chairClone:Destroy()
		return
	end

	local allParts = {}
	for _, obj in chairClone:GetDescendants() do
		if obj:IsA("BasePart") then
			table.insert(allParts, obj)
		end
	end

	for _, obj in chairClone:GetChildren() do
		if obj:IsA("BasePart") then
			table.insert(allParts, obj)
		end
	end

	for _, part in allParts do
		part.Anchored = false
		part.CanCollide = false
		part.Massless = true
		part.CollisionGroup = "PlayerChair"
		pcall(function()
			part:SetNetworkOwner(player)
		end)
	end

	anchorPart.Anchored = false
	anchorPart.CanCollide = false
	anchorPart.Massless = true

	if seatPart:IsA("Seat") then
		seatPart.Disabled = true
	end
	seatPart.Anchored = false
	seatPart.CanCollide = false
	seatPart.Massless = true

	for _, part in allParts do
		if part ~= anchorPart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = anchorPart
			weld.Part1 = part
			weld.Parent = part
		end
	end

	local playerCFrame = humanoidRootPart.CFrame
	local lookVec = playerCFrame.LookVector
	local rotation = math.atan2(lookVec.X, lookVec.Z)

	anchorPart.CFrame = CFrame.new(playerCFrame.Position.X, playerCFrame.Position.Y - 2, playerCFrame.Position.Z) * CFrame.Angles(0, rotation, 0)

	chairClone.Parent = Workspace

	local weld = Instance.new("Weld")
	weld.Name = "ChairToPlayerWeld"
	weld.Part0 = humanoidRootPart
	weld.Part1 = anchorPart
	weld.C0 = humanoidRootPart.CFrame:ToObjectSpace(anchorPart.CFrame)
	weld.C1 = CFrame.new()
	weld.Parent = anchorPart

	humanoid:ChangeState(Enum.HumanoidStateType.Seated)

	local sitAnim = Instance.new("Animation")
	sitAnim.AnimationId = "rbxassetid://2506281703"
	local sitTrack = humanoid:LoadAnimation(sitAnim)
	sitTrack.Priority = Enum.AnimationPriority.Action
	sitTrack.Looped = true
	sitTrack:Play()

	local unseatConnection = humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Jumping or newState == Enum.HumanoidStateType.Freefall then
			humanoid:ChangeState(Enum.HumanoidStateType.Seated)
			if sitTrack and not sitTrack.IsPlaying then
				sitTrack:Play()
			end
		end
	end)

	playerChairs[player] = chairClone
	playerConnections[player] = {unseatConnection}
	playerAnimations[player] = sitTrack
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
	playerConnections[player] = nil
	playerAnimations[player] = nil
end

--// Knit Lifecycle
function SeatService:KnitInit()
	local PhysicsService = game:GetService("PhysicsService")
	pcall(function()
		PhysicsService:RegisterCollisionGroup("PlayerChair")
		PhysicsService:CollisionGroupSetCollidable("PlayerChair", "PlayerChair", false)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

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
	DataService = Knit.GetService("DataService")

	local chairEquippedEvent = SeatGame:WaitForChild("ChairEquipped")
	chairEquippedEvent.Event:Connect(function(player, chairName)
		self:SwapPlayerChair(player)
	end)
end

return SeatService
