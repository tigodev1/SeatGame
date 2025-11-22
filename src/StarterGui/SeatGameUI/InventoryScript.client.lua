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
local function setupButtonAnimation(button)
	buttonSizes[button] = button.Size

	button.MouseEnter:Connect(function()
		playSound(hoverSound)
		TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = buttonSizes[button] * 1.05
		}):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = buttonSizes[button]
		}):Play()
	end)

	button.MouseButton1Down:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = buttonSizes[button] * 0.95
		}):Play()
	end)

	button.MouseButton1Up:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = buttonSizes[button] * 1.05
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
	local winningPosition = 28
	local itemCount = 0

	for loop = 1, 4 do
		for i = 1, 10 do
			itemCount = itemCount + 1
			local modelToUse = itemCount == winningPosition and wonSeat or models[math.random(1, #models)]
			local display = createSpinDisplay(modelToUse)
			display.LayoutOrder = itemCount
			display.Parent = spinList
		end
		if loop < 4 then
			task.wait()
		end
	end

	spinList.CanvasPosition = Vector2.new(0, 0)
	task.wait(0.3)

	local targetChild = nil
	for _, child in spinList:GetChildren() do
		if child:IsA("GuiObject") and child.LayoutOrder == winningPosition then
			targetChild = child
			break
		end
	end

	if not targetChild then
		isSpinning = false
		return
	end

	task.wait(0.2)

	local itemWidth = targetChild.AbsoluteSize.X
	local containerWidth = spinContainer.AbsoluteSize.X
	local targetPosition = (winningPosition - 1) * itemWidth
	local finalScroll = targetPosition - (containerWidth / 2) + (itemWidth / 2)

	rollSoundInstance = rollSound:Clone()
	rollSoundInstance.Parent = SoundService
	rollSoundInstance.Looped = true
	rollSoundInstance:Play()

	local duration = 5
	local startTime = tick()

	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime

		if elapsed >= duration then
			connection:Disconnect()
			spinList.CanvasPosition = Vector2.new(finalScroll, 0)

			if rollSoundInstance then
				rollSoundInstance:Stop()
				rollSoundInstance:Destroy()
				rollSoundInstance = nil
			end

			print("Won seat:", wonSeat.Name)
			task.wait(1)
			isSpinning = false
			return
		end

		local progress = elapsed / duration
		local eased

		if progress < 0.7 then
			eased = (progress / 0.7) * 0.85
		else
			local slowPart = (progress - 0.7) / 0.3
			eased = 0.85 + (1 - math.pow(1 - slowPart, 5)) * 0.15
		end

		spinList.CanvasPosition = Vector2.new(eased * finalScroll, 0)

		if rollSoundInstance then
			local speed = 1 - eased
			rollSoundInstance.PlaybackSpeed = 0.5 + (speed * 1.5)
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
