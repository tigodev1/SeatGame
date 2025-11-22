local ReplicatedStorage = game:GetService("ReplicatedStorage")

local screenGui = script.Parent
local canvas = screenGui:FindFirstChild("Canvas")
if not canvas then return end

local buttonContainer = canvas:FindFirstChild("ButtonContainer")
if not buttonContainer then return end

local inventoryButton = buttonContainer:FindFirstChild("Inventory")
if not inventoryButton then return end

local inventoryFrame = canvas:FindFirstChild("Inventory")
if not inventoryFrame then return end

local list = inventoryFrame:FindFirstChild("List")
if not list then return end

local chairTemplate = script:FindFirstChild("ChairTemplate")
if not chairTemplate then return end

local seatGame = ReplicatedStorage:WaitForChild("SeatGame", 10)
if not seatGame then return end

local seatModels = seatGame:WaitForChild("SeatModels", 10)
if not seatModels then return end

local isInventoryOpen = false

local function createViewportCamera(viewport)
	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return camera
end

local function setupChairInViewport(viewport, chairModel)
	local camera = createViewportCamera(viewport)

	local clone = chairModel:Clone()
	clone.Parent = viewport

	local cframe, size = clone:GetBoundingBox()
	local distance = size.Magnitude * 1.5

	camera.CFrame = CFrame.new(cframe.Position + Vector3.new(distance, distance/2, distance)) * CFrame.Angles(0, math.rad(45), 0)
	camera.CFrame = CFrame.lookAt(camera.CFrame.Position, cframe.Position)
end

local function createChairDisplay(chairModel)
	local template = chairTemplate:Clone()
	template.Visible = true

	local viewport = template:FindFirstChild("ViewportFrame")
	local nameLabel = template:FindFirstChild("Name")

	if viewport then
		setupChairInViewport(viewport, chairModel)
	end

	if nameLabel then
		nameLabel.Text = chairModel.Name
	end

	template.Parent = list
end

local function populateInventory()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") or child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for _, chairModel in seatModels:GetChildren() do
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

inventoryFrame.Visible = false
inventoryButton.MouseButton1Click:Connect(toggleInventory)
