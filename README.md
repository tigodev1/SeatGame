# SeatGame
The Random Seat Game - Spin to collect rare seats!

## 🎮 Game Concept

Join the game → instantly sitting

- **No walking, no tutorial—just vibes**
- Press the Spin Button to get random seats
- Common seats appear often, rare ones become legends
- Equip and swap seats anytime
- Collect & store in your inventory
- Flex with rarity tags, effects, and cosmetics

## 🛠️ Setup Instructions

This project uses [Rojo](https://rojo.space/) to sync the filesystem with Roblox Studio.

### Prerequisites
- Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/)
- Install the Rojo plugin in Roblox Studio

### Getting Started

1. **Build the project:**
   ```bash
   rojo build -o SeatGame.rbxl
   ```

2. **Open in Roblox Studio:**
   - Open `SeatGame.rbxl` in Roblox Studio

3. **Live Sync (for development):**
   ```bash
   rojo serve
   ```
   Then connect from Roblox Studio using the Rojo plugin.

## 📁 Project Structure

```
src/
├── ServerScriptService/
│   └── Services/
│       └── SeatMain.lua          # Main seating system
├── ReplicatedStorage/
│   └── SeatGame/
│       └── SeatModels/
│           └── Default.model.json # Default seat model
└── Workspace/
    └── SeatsPlacing/
        ├── 1-8/                   # Numbered seat positions
        │   └── Seat/
        │       └── AnchorPoint    # Position marker
```

## 🎯 Current Features (v0.1)

- ✅ Players auto-seated when joining
- ✅ Seats placed at designated anchor points
- ✅ Jump/movement disabled while seated
- ✅ Support for 8 concurrent players
- ✅ Default seat model

## 🚧 Coming Soon

- Spin button to get random seats
- Multiple seat rarities (Common, Rare, Epic, Legendary)
- Inventory system
- Seat equipping system
- Visual effects and cosmetics
- Rarity indicators

## 📝 Notes

- The game uses 8 pre-defined seat positions (expandable)
- Seats automatically anchor to the baseplate
- Players cannot jump or move when seated
- Default seat is a simple grey chair with backrest
