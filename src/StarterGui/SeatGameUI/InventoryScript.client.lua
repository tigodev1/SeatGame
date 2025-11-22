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
	local distance = 5

	camera.CFrame = CFrame.new(cframe.Position + Vector3.new(distance, distance/3, distance))
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
	local spinItems = {}

	for i = 1, 50 do
		local randomModel = models[math.random(1, #models)]
		table.insert(spinItems, randomModel)
	end

	for _, model in ipairs(spinItems) do
		local display = createSpinDisplay(model)
		display.Parent = spinList
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

	populateSpinList()
	task.wait(0.1)

	local children = spinList:GetChildren()
	local validChildren = {}
	for _, child in ipairs(children) do
		if child:IsA("GuiObject") then
			table.insert(validChildren, child)
		end
	end

	if #validChildren == 0 then
		isSpinning = false
		return
	end

	local targetIndex = math.random(40, 45)
	local targetChild = validChildren[targetIndex]

	local winDisplay = createSpinDisplay(wonSeat)
	winDisplay.Parent = spinList
	winDisplay.LayoutOrder = targetIndex

	local targetPosition = targetChild.AbsolutePosition.X - spinList.AbsolutePosition.X
	local tweenInfo = TweenInfo.new(
		5,
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(spinList, tweenInfo, {
		CanvasPosition = Vector2.new(targetPosition - (spinList.AbsoluteSize.X / 2), 0)
	})

	tween:Play()
	tween.Completed:Wait()

	print("Won seat:", wonSeat.Name)
	task.wait(1)

	isSpinning = false
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
	if spinningFrame.Visible then
		populateSpinList()
		inventoryFrame.Visible = false
	end
end

--// Initialize
inventoryFrame.Visible = false
spinningFrame.Visible = false
inventoryButton.MouseButton1Click:Connect(toggleInventory)
spinButton.MouseButton1Click:Connect(toggleSpinning)
spinActionButton.MouseButton1Click:Connect(performSpin)
