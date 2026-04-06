## 2026-03-16

Made **DOORS Entity Spawner V2** a standalone repository because it's cleaner.

### Additions
- Added `Clear` method
- Added `Unload` method
- Added a new example with client syncing

### Changes
- Refactored most of the code
- `getgenv().vynixu_SpawnerLoaded` → `getgenv()._internal_vynixu_entity_spawner`
- `Run` method now supports second argument `<boolean> copyEntity`
- Slightly improved error / warning output handling
- Entity muted upon being banished through crucifixion

## 2026-04-06

### Additions
- Added a new config option `IgnoreHiding` under Damage; makes entities detect players while in hiding spots.

### Changes
- Make use of character PrimaryPart, rather than Collision(Part) specifically
