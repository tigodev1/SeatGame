--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

task.spawn(function()
	pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
	end)
end)

--// Instances
local screenGui = script.Parent
local canvas = screenGui:WaitForChild("Canvas")
local buttonContainer = canvas:WaitForChild("ButtonContainer")
local inventoryButton = buttonContainer:WaitForChild("InventoryButton")
local spinButton = buttonContainer:WaitForChild("SpinButton")
local inventoryFrame = canvas:WaitForChild("Inventory")
local inventoryCloseButton = inventoryFrame:WaitForChild("CloseButton")
local spinningFrame = canvas:WaitForChild("SpinningFrame")
local spinningCloseButton = spinningFrame:WaitForChild("CloseButton")
local spinContainer = spinningFrame:WaitForChild("SpinContainer")
local spinList = spinContainer:WaitForChild("List")
local picker = spinContainer:WaitForChild("Picker")
local spinActionButton = spinningFrame:WaitForChild("Spin")
local list = inventoryFrame:WaitForChild("List")
local chairTemplate = script:WaitForChild("ChairTemplate")
local spinTemplate = script:WaitForChild("SpinTemplate")

local seatGame = ReplicatedStorage:WaitForChild("SeatGame")
local seatModels = seatGame:WaitForChild("SeatModels")
local soundsFolder = seatGame:WaitForChild("Sounds")
local hoverSound = soundsFolder:WaitForChild("Hover")
local clickSound = soundsFolder:WaitForChild("Click")
local rollSound = soundsFolder:WaitForChild("Roll")
local rngModule = require(seatGame.Modules.RNGModule)

--// Variables
local isInventoryOpen = false
local isSpinning = false
local buttonSizes = {}
local rollSoundInstance = nil

--// Config
local SPIN_DURATION = 4
local SLOWDOWN_TIME = 1

--// Sound System
local function playSound(sound)
	local clone = sound:Clone()
	clone.Parent = SoundService
	clone:Play()
	task.delay(sound.TimeLength, function()
		clone:Destroy()
	end)
end

--// Button Animation System
local function scaleUDim2(udim2, scale)
	return UDim2.new(
		udim2.X.Scale * scale,
		udim2.X.Offset * scale,
		udim2.Y.Scale * scale,
		udim2.Y.Offset * scale
	)
end

local function setupButtonAnimation(button)
	buttonSizes[button] = button.Size

	button.MouseEnter:Connect(function()
		playSound(hoverSound)
		TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = scaleUDim2(buttonSizes[button], 1.05)
		}):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = buttonSizes[button]
		}):Play()
	end)

	button.MouseButton1Down:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = scaleUDim2(buttonSizes[button], 0.95)
		}):Play()
	end)

	button.MouseButton1Up:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = scaleUDim2(buttonSizes[button], 1.05)
		}):Play()
	end)
end

--// Viewport Setup
local function createViewportCamera(viewport)
	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return camera
end

local function setupChairInViewport(viewport, chairModel, rotating)
	local camera = createViewportCamera(viewport)
	local clone = chairModel:Clone()
	clone.Parent = viewport

	local cframe, size = clone:GetBoundingBox()
	local distance = math.max(size.X, size.Y, size.Z) * 1.3

	camera.CFrame = CFrame.new(cframe.Position + Vector3.new(distance, distance * 0.3, distance))
	camera.CFrame = CFrame.lookAt(camera.CFrame.Position, cframe.Position)

	if rotating then
		local angle = 0
		RunService.RenderStepped:Connect(function(dt)
			if clone and clone.Parent then
				angle = angle + (dt * 50)
				local rotatedCFrame = CFrame.new(cframe.Position) * CFrame.Angles(0, math.rad(angle), 0)
				clone:PivotTo(rotatedCFrame)
			end
		end)
	end
end

--// Display Creation
local function createChairDisplay(chairModel)
	local template = chairTemplate:Clone()
	template.Visible = true

	local viewport = template:FindFirstChild("ViewportFrame")
	local nameLabel = template:FindFirstChild("Name")

	if viewport then
		setupChairInViewport(viewport, chairModel, true)
	end

	if nameLabel then
		nameLabel.Text = chairModel.Name
	end

	template.Parent = list
end

local function createSpinDisplay(chairModel)
	local template = spinTemplate:Clone()
	template.Visible = true

	local viewport = template:FindFirstChild("ViewportFrame")
	local nameLabel = template:FindFirstChild("Name")
	local rarityFrame = template:FindFirstChild("Rarity")

	if viewport then
		setupChairInViewport(viewport, chairModel, false)
	end

	if nameLabel then
		nameLabel.Text = chairModel.Name
	end

	if rarityFrame then
		local rarity = rngModule:GetSeatRarity(chairModel)
		rarityFrame.BackgroundColor3 = rngModule:GetRarityColor(rarity)
	end

	return template
end

--// Population Functions
local function populateInventory()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for _, chairModel in seatModels:GetChildren() do
		if chairModel:IsA("Model") then
			createChairDisplay(chairModel)
		end
	end
end

local function populateSpinList()
	for _, child in spinList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local models = seatModels:GetChildren()
	local selectedSeats = {}

	for i = 1, 10 do
		selectedSeats[i] = models[math.random(1, #models)]
	end

	for loop = 1, 4 do
		for _, model in ipairs(selectedSeats) do
			local display = createSpinDisplay(model)
			display.Parent = spinList
		end
		if loop < 4 then
			task.wait()
		end
	end

	spinList.CanvasPosition = Vector2.new(0, 0)
end

--// Spin System
local function performSpin()
	if isSpinning then return end
	isSpinning = true
	playSound(clickSound)

	local wonSeat = rngModule:GetWeightedRandom()
	if not wonSeat then
		isSpinning = false
		return
	end

	for _, child in spinList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local models = seatModels:GetChildren()
	local winningIndex = math.random(30, 45)

	for i = 1, 50 do
		local modelToUse = i == winningIndex and wonSeat or models[math.random(1, #models)]
		local display = createSpinDisplay(modelToUse)
		display.LayoutOrder = i
		display.Name = "SpinItem_" .. i
		display.Parent = spinList

		if i % 10 == 0 then
			task.wait()
		end
	end

	task.wait(0.5)
	spinList.CanvasPosition = Vector2.new(0, 0)

	local pickerCenter = picker.AbsolutePosition.X + (picker.AbsoluteSize.X / 2)
	local winningItem = spinList:FindFirstChild("SpinItem_" .. winningIndex)

	if not winningItem then
		isSpinning = false
		return
	end

	local winningItemCenter = winningItem.AbsolutePosition.X + (winningItem.AbsoluteSize.X / 2)
	local targetScroll = winningItemCenter - pickerCenter

	rollSoundInstance = rollSound:Clone()
	rollSoundInstance.Parent = SoundService
	rollSoundInstance.Looped = true
	rollSoundInstance:Play()

	local startTime = os.clock()

	local connection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime

		if elapsed >= SPIN_DURATION then
			connection:Disconnect()
			spinList.CanvasPosition = Vector2.new(targetScroll, 0)

			if rollSoundInstance then
				rollSoundInstance:Stop()
				rollSoundInstance:Destroy()
				rollSoundInstance = nil
			end

			print("Won seat:", wonSeat.Name)
			task.wait(1.5)
			isSpinning = false
			return
		end

		local timeRemaining = SPIN_DURATION - elapsed
		local progress = elapsed / SPIN_DURATION
		local scrollProgress

		if timeRemaining > SLOWDOWN_TIME then
			scrollProgress = progress
		else
			local slowdownRatio = SLOWDOWN_TIME / SPIN_DURATION
			local beforeSlowdown = 1 - slowdownRatio
			local slowdownProgress = (progress - beforeSlowdown) / slowdownRatio
			local slowdownEase = 1 - math.pow(1 - slowdownProgress, 4)
			scrollProgress = beforeSlowdown + (slowdownEase * slowdownRatio)
		end

		spinList.CanvasPosition = Vector2.new(scrollProgress * targetScroll, 0)

		if rollSoundInstance then
			if timeRemaining > SLOWDOWN_TIME then
				rollSoundInstance.PlaybackSpeed = 1.8
			else
				local slowdownProgress = (SLOWDOWN_TIME - timeRemaining) / SLOWDOWN_TIME
				rollSoundInstance.PlaybackSpeed = 1.8 - (slowdownProgress * 1.4)
			end
		end
	end)
end

--// Toggle Functions
local function closeInventory()
	isInventoryOpen = false
	inventoryFrame.Visible = false
end

local function closeSpinning()
	spinningFrame.Visible = false
end

local function toggleInventory()
	playSound(clickSound)
	isInventoryOpen = not isInventoryOpen
	inventoryFrame.Visible = isInventoryOpen

	if isInventoryOpen then
		populateInventory()
		spinningFrame.Visible = false
	end
end

local function toggleSpinning()
	playSound(clickSound)
	spinningFrame.Visible = not spinningFrame.Visible
	inventoryFrame.Visible = false

	if spinningFrame.Visible then
		populateSpinList()
	end
end

--// Initialize
inventoryFrame.Visible = false
spinningFrame.Visible = false

setupButtonAnimation(inventoryButton)
setupButtonAnimation(spinButton)
setupButtonAnimation(spinActionButton)
setupButtonAnimation(inventoryCloseButton)
setupButtonAnimation(spinningCloseButton)

inventoryButton.MouseButton1Click:Connect(toggleInventory)
spinButton.MouseButton1Click:Connect(toggleSpinning)
spinActionButton.MouseButton1Click:Connect(performSpin)
inventoryCloseButton.MouseButton1Click:Connect(function()
	playSound(clickSound)
	closeInventory()
end)
spinningCloseButton.MouseButton1Click:Connect(function()
	playSound(clickSound)
	closeSpinning()
end)
