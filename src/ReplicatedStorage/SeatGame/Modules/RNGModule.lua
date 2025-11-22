--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Module
local RNGModule = {}

--// Config
RNGModule.RarityWeights = {
	["Common"] = 70,
	["Rare"] = 25,
	["Legendary"] = 5,
}

RNGModule.RarityColors = {
	["Common"] = Color3.fromRGB(255, 255, 255),
	["Rare"] = Color3.fromRGB(85, 170, 255),
	["Legendary"] = Color3.fromRGB(255, 170, 0),
}

--// Functions
function RNGModule:GetSeatModels()
	local seatGame = ReplicatedStorage:WaitForChild("SeatGame")
	local seatModels = seatGame:WaitForChild("SeatModels")
	local allModels = {}

	-- Get all models from rarity folders (exclude Miscellaneous)
	for _, folder in ipairs(seatModels:GetChildren()) do
		if folder:IsA("Folder") and folder.Name ~= "Miscellaneous" then
			for _, model in ipairs(folder:GetChildren()) do
				if model:IsA("Model") then
					table.insert(allModels, model)
				end
			end
		end
	end

	return allModels
end

function RNGModule:GetSeatRarity(seatModel)
	-- Rarity is determined by parent folder name
	local parent = seatModel.Parent
	if parent and parent:IsA("Folder") then
		local rarityName = parent.Name
		if self.RarityWeights[rarityName] then
			return rarityName
		end
	end
	return "Common"
end

function RNGModule:GetSeatsByRarity(rarityName)
	local seatGame = ReplicatedStorage:WaitForChild("SeatGame")
	local seatModels = seatGame:WaitForChild("SeatModels")
	local rarityFolder = seatModels:FindFirstChild(rarityName)

	if not rarityFolder then return {} end

	local seats = {}
	for _, model in ipairs(rarityFolder:GetChildren()) do
		if model:IsA("Model") then
			table.insert(seats, model)
		end
	end

	return seats
end

function RNGModule:GetWeightedRandom()
	local totalWeight = 0
	for _, weight in pairs(self.RarityWeights) do
		totalWeight = totalWeight + weight
	end

	local random = Random.new()
	local roll = random:NextNumber(0, totalWeight)

	local currentWeight = 0
	for rarityName, weight in pairs(self.RarityWeights) do
		currentWeight = currentWeight + weight
		if roll <= currentWeight then
			local seatsInRarity = self:GetSeatsByRarity(rarityName)
			if #seatsInRarity > 0 then
				local randomIndex = random:NextInteger(1, #seatsInRarity)
				return seatsInRarity[randomIndex]
			end
		end
	end

	local commonSeats = self:GetSeatsByRarity("Common")
	if #commonSeats > 0 then
		return commonSeats[1]
	end

	return nil
end

function RNGModule:GetRarityChance(rarityName)
	local weight = self.RarityWeights[rarityName]
	if not weight then return 0 end
	return weight
end

function RNGModule:GetRarityColor(rarityName)
	return self.RarityColors[rarityName] or Color3.fromRGB(255, 255, 255)
end

return RNGModule
