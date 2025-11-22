--!strict

--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

--// Instances
local SeatGame = ReplicatedStorage:WaitForChild("SeatGame")
local SeatModels = SeatGame:WaitForChild("SeatModels")
local SeatsPlacing = Workspace:WaitForChild("SeatsPlacing")

--// Functions
local function findAvailableSeatPosition(): Folder?
	local seatPositions = SeatsPlacing:GetChildren()

	table.sort(seatPositions, function(a, b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)

	for _, positionFolder in ipairs(seatPositions) do
		local important = positionFolder:FindFirstChild("Important")
		if important then
			local occupant = important:FindFirstChild("Occupant") :: StringValue
			if occupant and occupant.Value == "" then
				return positionFolder
			end
		end
	end

	return nil
end

local function createSeatAtPosition(seatPosition: Folder, player: Player): Seat?
	local seatFolder = seatPosition:FindFirstChild("Seat")
	if not seatFolder then
		return nil
	end

	local anchorPoint = seatFolder:FindFirstChild("AnchorPoint") :: BasePart
	if not anchorPoint then
		return nil
	end

	local defaultSeat = SeatModels:FindFirstChild("Default")
	if not defaultSeat then
		return nil
	end

	local seatClone = defaultSeat:Clone()
	local seatPart = seatClone:FindFirstChild("Seat") :: Seat

	if not seatPart or not seatPart:IsA("Seat") then
		seatClone:Destroy()
		return nil
	end

	seatClone.Parent = seatFolder

	local modelCFrame, modelSize = seatClone:GetBoundingBox()
	local yOffset = modelSize.Y / 2

	local targetCFrame = anchorPoint.CFrame * CFrame.new(0, yOffset, 0)
	seatClone:PivotTo(targetCFrame)

	local important = seatPosition:FindFirstChild("Important")
	if important then
		local occupant = important:FindFirstChild("Occupant") :: StringValue
		if occupant then
			occupant.Value = player.Name
		end
	end

	return seatPart
end

local function setupPlayerControls(player: Player, seatPart: Seat)
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	humanoid.Died:Connect(function()
		humanoid.Health = humanoid.MaxHealth
	end)

	local connection: RBXScriptConnection
	connection = humanoid.StateChanged:Connect(function(oldState, newState)
		if newState ~= Enum.HumanoidStateType.Seated then
			if seatPart and seatPart.Parent then
				task.wait()
				seatPart:Sit(humanoid)
			else
				connection:Disconnect()
			end
		end
	end)

	character:SetAttribute("SeatConnection", true)
end

local function seatPlayer(player: Player)
	local character = player.Character
	if not character then
		player.CharacterAdded:Wait()
		character = player.Character
	end

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

	local seatPosition = findAvailableSeatPosition()
	if not seatPosition then
		return
	end

	local seatPart = createSeatAtPosition(seatPosition, player)
	if not seatPart then
		return
	end

	task.wait(0.1)

	humanoidRootPart.CFrame = seatPart.CFrame + Vector3.new(0, 2, 0)
	task.wait(0.1)
	seatPart:Sit(humanoid)

	setupPlayerControls(player, seatPart)
end

--// Handlers
local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		seatPlayer(player)
	end)

	if player.Character then
		task.wait(0.5)
		seatPlayer(player)
	end
end

local function onPlayerRemoving(player: Player)
	for _, position in ipairs(SeatsPlacing:GetChildren()) do
		local important = position:FindFirstChild("Important")
		if important then
			local occupant = important:FindFirstChild("Occupant") :: StringValue
			if occupant and occupant.Value == player.Name then
				occupant.Value = ""

				local seatFolder = position:FindFirstChild("Seat")
				if seatFolder then
					for _, obj in ipairs(seatFolder:GetChildren()) do
						if obj:IsA("Model") then
							obj:Destroy()
							break
						end
					end
				end

				break
			end
		end
	end
end

--// Initialize
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
