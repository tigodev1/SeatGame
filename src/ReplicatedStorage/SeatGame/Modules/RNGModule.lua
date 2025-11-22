--// RNG Module
local RNGModule = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Configuration
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
	return seatModels:GetChildren()
end

function RNGModule:GetSeatRarity(seatModel)
	local important = seatModel:FindFirstChild("Important")
	if not important then return "Common" end

	local rarity = important:FindFirstChild("Rarity")
	if not rarity then return "Common" end

	return rarity.Value
end

function RNGModule:GetSeatsByRarity(rarityName)
	local seats = {}
	local models = self:GetSeatModels()

	for _, model in ipairs(models) do
		if model:IsA("Model") then
			local rarity = self:GetSeatRarity(model)
			if rarity == rarityName then
				table.insert(seats, model)
			end
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
