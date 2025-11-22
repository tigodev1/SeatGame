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

### Getting the Code in VS Code

1. **Open VS Code** and open the terminal (Ctrl+` or Terminal → New Terminal)

2. **Clone the repository:**
   ```bash
   git clone https://github.com/tigodev1/SeatGame.git
   cd SeatGame
   ```

3. **Switch to the game branch:**
   ```bash
   git checkout claude/rng-seat-game-01SESGcnieiiXLjA5sNuvgaL
   ```

4. **Pull latest changes:**
   ```bash
   git pull
   ```

### Using the Scripts in Roblox Studio

1. Open your Roblox Studio place
2. Copy the Lua scripts from the `src/` folder into your game:
   - `src/ServerScriptService/Services/SeatMain.lua` → ServerScriptService > Services (create a folder called "Services")
3. Set up the workspace structure as shown in the Project Structure section below
4. Copy the seat model data into ReplicatedStorage

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
