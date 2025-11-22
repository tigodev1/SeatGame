--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

--// Disable Reset
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
local spinningFrame = canvas:WaitForChild("SpinningFrame")
local spinContainer = spinningFrame:WaitForChild("SpinContainer")
local spinList = spinContainer:WaitForChild("List")
local picker = spinContainer:WaitForChild("Picker")
local spinActionButton = spinningFrame:WaitForChild("Spin")
local list = inventoryFrame:WaitForChild("List")
local chairTemplate = script:WaitForChild("ChairTemplate")
local spinTemplate = script:WaitForChild("SpinTemplate")

local seatGame = ReplicatedStorage:WaitForChild("SeatGame")
local seatModels = seatGame:WaitForChild("SeatModels")
local rngModule = require(seatGame.Modules.RNGModule)

--// Variables
local isInventoryOpen = false
local isSpinning = false

--// Functions
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
	local maxSize = math.max(size.X, size.Y, size.Z)
	local distance = maxSize * 1.8

	camera.CFrame = CFrame.new(cframe.Position + Vector3.new(distance, distance * 0.4, distance))
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

	if viewport then
		setupChairInViewport(viewport, chairModel, false)
	end

	if nameLabel then
		nameLabel.Text = chairModel.Name
	end

	return template
end

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

local function performSpin()
	if isSpinning then return end
	isSpinning = true

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

	local duration = 5
	local startTime = tick()

	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime

		if elapsed >= duration then
			connection:Disconnect()
			spinList.CanvasPosition = Vector2.new(finalScroll, 0)
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
	end)
end

local function toggleInventory()
	isInventoryOpen = not isInventoryOpen
	inventoryFrame.Visible = isInventoryOpen

	if isInventoryOpen then
		populateInventory()
		spinningFrame.Visible = false
	end
end

local function toggleSpinning()
	spinningFrame.Visible = not spinningFrame.Visible
	inventoryFrame.Visible = false

	if spinningFrame.Visible then
		populateSpinList()
	end
end

--// Initialize
inventoryFrame.Visible = false
spinningFrame.Visible = false
inventoryButton.MouseButton1Click:Connect(toggleInventory)
spinButton.MouseButton1Click:Connect(toggleSpinning)
spinActionButton.MouseButton1Click:Connect(performSpin)
