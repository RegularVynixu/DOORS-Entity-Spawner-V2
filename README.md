# DOORS Entity Spawner V2

An improved version of my original **DOORS Entity Spawner**.

It allows you to summon custom, fully configurable client-sided entities and experiment with your own mechanics or gamemodes for DOORS.

DOORS Entity Spawner V2 is open source, completely free to use and it still offers more configurations and flexibility than the in-game DOORS admin panel.

[Watch the trailer here!](https://www.youtube.com/watch?v=H41Ru15gQ88)

## Features

* Custom entities
* Fully configurable behavior
* Movement settings (speed, delay, reversed)
* Damage and death handling
* Rebounding mechanics (ambush, blitz)
* Light interaction (flicker, break, restore)
* Environmental effects (earthquake, camera shake)
* Crucifix support
* Debug callbacks to control entity behaviour and player/environment interactions

## Limitations

* Entities are clientsided only
* Multiplayer experiences/game modes require manual client syncing
* Health is managed client-sided, so any server-side health updates may break immersion

## Usage

### Creating an entity template:

```lua
local MyEntity = Spawner:Create({
    Entity = {
        Name = "Template Entity",
        Asset = "https://github.com/RegularVynixu/Utilities/blob/main/DOORS%20Entity%20Spawner/Models/Rush.rbxm?raw=true",
        HeightOffset = 0
    },
    Movement = {
        Speed = 100,
        Delay = 2,
        Reversed = false
    },
    Damage = {
        Enabled = true,
        Range = 40,
        Amount = 125
    },
    Rebounding = {
        Enabled = true,
        Type = "Ambush", -- "Blitz"
        Min = 2,
        Max = 4,
        Delay = 2
    },
    Lights = {
        Flicker = {
            Enabled = true,
            Duration = 1
        },
        Shatter = true,
        Repair = false
    },
    Earthquake = {
        Enabled = true
    },
    CameraShake = {
        Enabled = true,
        Values = {1.5, 20, 0.1, 1}, -- Magnitude, Roughness, FadeIn, FadeOut
        Range = 100
    },
    Crucifixion = {
        Type = "Curious", -- "Guiding"
        Enabled = true,
        Range = 40,
        Resist = false,
        Break = true
    },
    Death = {
        Type = "Guiding", -- "Curious"
        Hints = {"Death", "Hints", "Go", "Here"},
        Cause = ""
    }
})
```

### Utilising the debug callbacks:

```lua
MyEntity:SetCallback("OnSpawned", function()
    print("Entity has spawned")
end)

MyEntity:SetCallback("OnStartMoving", function()
    print("Entity has started moving")
end)

MyEntity:SetCallback("OnEnterRoom", function(room: Model, firstTime: boolean)
    if firstTime == true then
        print("Entity has entered room: ".. room.Name.. " for the first time")
    else
        print("Entity has entered room: ".. room.Name.. " again")
    end
end)

MyEntity:SetCallback("OnLookAt", function(lineOfSight: boolean)
	if lineOfSight == true then
		print("Player is looking at entity")
	else
		print("Player view is obstructed by something")
	end
end)

MyEntity:SetCallback("OnRebounding", function(startOfRebound: boolean)
    if startOfRebound == true then
        print("Entity has started rebounding")
	else
        print("Entity has finished rebounding")
	end
end)

MyEntity:SetCallback("OnDespawning", function()
    print("Entity is despawning")
end)

MyEntity:SetCallback("OnDespawned", function()
    print("Entity has despawned")
end)

MyEntity:SetCallback("OnDamagePlayer", function(newHealth: number)
	if newHealth <= 0 then
		print("Entity has killed the player")
	else
		print("Entity has damaged the player")
	end
end)
```

### Running your entity in-game:

```lua
MyEntity:Run(true) -- creates & runs a copy of your entity template
```
