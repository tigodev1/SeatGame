--// RNG Module
local RNGModule = {}

--// Configuration
RNGModule.SeatChances = {
	["Default"] = 100,
	["Common"] = 50,
	["Uncommon"] = 25,
	["Rare"] = 10,
	["Epic"] = 5,
	["Legendary"] = 1,
}

RNGModule.RarityColors = {
	["Default"] = Color3.fromRGB(150, 150, 150),
	["Common"] = Color3.fromRGB(255, 255, 255),
	["Uncommon"] = Color3.fromRGB(85, 255, 85),
	["Rare"] = Color3.fromRGB(85, 170, 255),
	["Epic"] = Color3.fromRGB(170, 85, 255),
	["Legendary"] = Color3.fromRGB(255, 170, 0),
}

--// Functions
function RNGModule:GetTotalWeight()
	local total = 0
	for _, weight in pairs(self.SeatChances) do
		total = total + weight
	end
	return total
end

function RNGModule:GetWeightedRandom()
	local totalWeight = self:GetTotalWeight()
	local random = Random.new()
	local roll = random:NextNumber(0, totalWeight)

	local currentWeight = 0
	for seatName, weight in pairs(self.SeatChances) do
		currentWeight = currentWeight + weight
		if roll <= currentWeight then
			return seatName
		end
	end

	return "Default"
end

function RNGModule:GetSeatChance(seatName)
	local weight = self.SeatChances[seatName]
	if not weight then return 0 end

	local totalWeight = self:GetTotalWeight()
	local percentage = (weight / totalWeight) * 100
	return math.floor(percentage * 100) / 100
end

function RNGModule:GetRarityColor(seatName)
	return self.RarityColors[seatName] or Color3.fromRGB(255, 255, 255)
end

function RNGModule:SetSeatChance(seatName, chance)
	self.SeatChances[seatName] = chance
end

function RNGModule:GetAllSeats()
	local seats = {}
	for seatName, _ in pairs(self.SeatChances) do
		table.insert(seats, seatName)
	end
	return seats
end

function RNGModule:GetSeatsByRarity()
	local sorted = {}
	for seatName, weight in pairs(self.SeatChances) do
		table.insert(sorted, {Name = seatName, Weight = weight})
	end

	table.sort(sorted, function(a, b)
		return a.Weight < b.Weight
	end)

	return sorted
end

function RNGModule:SimulateRolls(amount)
	local results = {}
	for seatName, _ in pairs(self.SeatChances) do
		results[seatName] = 0
	end

	for i = 1, amount do
		local result = self:GetWeightedRandom()
		results[result] = results[result] + 1
	end

	return results
end

return RNGModule
