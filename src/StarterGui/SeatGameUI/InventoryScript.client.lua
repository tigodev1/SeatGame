--!strict

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Instances
local screenGui = script.Parent :: ScreenGui
local canvas = screenGui:WaitForChild("Canvas") :: Frame
local buttonContainer = canvas:WaitForChild("ButtonContainer") :: Frame
local inventoryButton = buttonContainer:WaitForChild("Inventory") :: TextButton
local inventoryFrame = canvas:WaitForChild("Inventory") :: Frame
local list = inventoryFrame:WaitForChild("List") :: ScrollingFrame
local chairTemplate = script:WaitForChild("ChairTemplate") :: Frame

local seatGame = ReplicatedStorage:WaitForChild("SeatGame")
local seatModels = seatGame:WaitForChild("SeatModels")

--// Variables
local isInventoryOpen = false

--// Functions
local function createViewportCamera(viewport: ViewportFrame): Camera
	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return camera
end

local function setupChairInViewport(viewport: ViewportFrame, chairModel: Model)
	local camera = createViewportCamera(viewport)

	local clone = chairModel:Clone()
	clone.Parent = viewport

	local cframe, size = clone:GetBoundingBox()
	local distance = size.Magnitude * 1.5

	camera.CFrame = CFrame.new(cframe.Position + Vector3.new(distance, distance/2, distance)) * CFrame.Angles(0, math.rad(45), 0)
	camera.CFrame = CFrame.lookAt(camera.CFrame.Position, cframe.Position)
end

local function createChairDisplay(chairModel: Model)
	local template = chairTemplate:Clone()
	template.Visible = true

	local viewport = template:FindFirstChild("ViewportFrame") :: ViewportFrame
	local nameLabel = template:FindFirstChild("Name") :: TextLabel

	if viewport then
		setupChairInViewport(viewport, chairModel)
	end

	if nameLabel then
		nameLabel.Text = chairModel.Name
	end

	template.Parent = list
end

local function populateInventory()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for _, chairModel in ipairs(seatModels:GetChildren()) do
		if chairModel:IsA("Model") then
			createChairDisplay(chairModel)
		end
	end
end

local function toggleInventory()
	isInventoryOpen = not isInventoryOpen
	inventoryFrame.Visible = isInventoryOpen

	if isInventoryOpen then
		populateInventory()
	end
end

--// Initialize
inventoryButton.Activated:Connect(toggleInventory)
inventoryFrame.Visible = false
