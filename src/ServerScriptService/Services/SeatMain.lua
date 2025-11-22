--!strict

--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

--// Instances
local SeatGame = ReplicatedStorage:WaitForChild("SeatGame")
local SeatModels = SeatGame:WaitForChild("SeatModels")
local SeatsPlacing = Workspace:WaitForChild("SeatsPlacing")

--// Variables
local occupiedSeats: {[string]: number} = {}

--// Functions
local function findAvailableSeatPosition(): Folder?
	local seatPositions = SeatsPlacing:GetChildren()

	table.sort(seatPositions, function(a, b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)

	for _, positionFolder in ipairs(seatPositions) do
		if not occupiedSeats[positionFolder.Name] then
			return positionFolder
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

	seatClone.Parent = workspace

	local modelCFrame, modelSize = seatClone:GetBoundingBox()
	local yOffset = modelSize.Y / 2

	local targetCFrame = CFrame.new(
		anchorPoint.Position.X,
		anchorPoint.Position.Y + yOffset,
		anchorPoint.Position.Z
	)
	seatClone:PivotTo(targetCFrame)

	occupiedSeats[seatPosition.Name] = player.UserId

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
	for positionName, userId in pairs(occupiedSeats) do
		if userId == player.UserId then
			occupiedSeats[positionName] = nil

			local position = SeatsPlacing:FindFirstChild(positionName)
			if position then
				for _, obj in ipairs(workspace:GetChildren()) do
					if obj:IsA("Model") and obj:FindFirstChild("Seat") then
						local seat = obj:FindFirstChildWhichIsA("Seat")
						if seat and seat.Occupant and seat.Occupant.Parent == player.Character then
							obj:Destroy()
							break
						end
					end
				end
			end

			break
		end
	end
end

--// Initialize
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
