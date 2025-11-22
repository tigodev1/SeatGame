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
	local distance = 7

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

	for i = 1, 10 do
		local randomModel = models[math.random(1, #models)]
		local display = createSpinDisplay(randomModel)
		display.Parent = spinList
		print("Created seat", i, randomModel.Name)
	end

	spinList.CanvasPosition = Vector2.new(0, 0)
	print("Total seats in list:", #spinList:GetChildren())
end

local function getItemUnderPicker()
	local pickerCenter = picker.AbsolutePosition.X + (picker.AbsoluteSize.X / 2)

	for _, child in spinList:GetChildren() do
		if child:IsA("GuiObject") and child.Visible then
			local itemLeft = child.AbsolutePosition.X
			local itemRight = itemLeft + child.AbsoluteSize.X

			if pickerCenter >= itemLeft and pickerCenter <= itemRight then
				return child:FindFirstChild("Name")
			end
		end
	end

	return nil
end

local function performSpin()
	if isSpinning then return end
	isSpinning = true

	populateSpinList()
	task.wait(0.5)

	local duration = 3
	local elapsed = 0
	local maxScroll = spinList.AbsoluteCanvasSize.X - spinList.AbsoluteSize.X
	local targetScroll = math.random(maxScroll * 0.3, maxScroll * 0.7)

	print("Starting spin - Max scroll:", maxScroll, "Target:", targetScroll)
	print("Seats visible before spin:", #spinList:GetChildren())

	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		elapsed = elapsed + dt

		if elapsed >= duration then
			connection:Disconnect()

			print("Seats visible after spin:", #spinList:GetChildren())

			local wonLabel = getItemUnderPicker()
			if wonLabel then
				print("Won seat:", wonLabel.Text)
			end

			task.wait(1)
			isSpinning = false
			return
		end

		local progress = elapsed / duration
		local eased = 1 - math.pow(1 - progress, 3)
		local currentScroll = eased * targetScroll

		spinList.CanvasPosition = Vector2.new(currentScroll, 0)
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
