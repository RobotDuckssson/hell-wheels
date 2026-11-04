# Hell Wheels

Futuristic street racing between skyscrapers at dusk – neon, rain and flying traffic. Six car types, a damage model with parts flying off, several tracks, three difficulty levels and a built-in track editor.

Built with **Godot 4.7** (Forward+).

## Getting started
1. Open Godot and choose **Import**.
2. Select `project.godot` in this folder and click **Import & Edit**.
3. Press **F5**.

## Game modes
- **First to the finish** – race 1, 2, 3 or 5 laps. Wrecked cars respawn after about three seconds.
- **Last one standing** – everyone starts spread out on the track, half of them facing the wrong way. Ram the others; wrecked is wrecked. After 2.5 minutes sudden death starts and every car loses health until one remains.

**Difficulty:** Easy (5 opponents), Medium (6) and Hard (7, fast and aggressive).

## Tracks
All tracks run high among the skyscrapers on pillars 30–50 m above the street. Yellow stripes and a JUMP sign mark the ramps – go at least 60 km/h to clear the gap. Where there is no railing you can fall off; you are put back on the track after a few seconds.

## Cars
| Car | Character |
|---|---|
| VEKTOR | All-rounder |
| STILETT | Fastest, most fragile |
| MASTODONT | Armoured truck – slow, heavy, almost unstoppable |
| GETING | Small and nimble, best grip, breaks easily |
| KAB-9 | Taxi – tough with good grip |
| RAPTOR | Muscle car – strong engine, likes to drift |

Hard crashes cost health; ramming with your front hurts you less than being hit. At 75, 50 and 25 % health parts come loose, the paint darkens, the car starts smoking and finally burns. At zero it explodes.

## Controls
| Action | Keyboard | Gamepad |
|---|---|---|
| Throttle | W / Up | Right trigger |
| Brake / reverse | S / Down | Left trigger |
| Steer | A D / Arrows | Left stick |
| Drift | Space | B |
| Boost | Shift | A |
| Reset to track | R | Y |
| Change camera | C | X |
| Pause | Esc / P | Start |

If the game runs slowly, choose **GRAFIK: LÅG** (graphics: low) in the menu.

## Track editor
Choose **BANEDITOR** (track editor) in the menu. Left-click empty space to add a point, left-click a line to insert one, drag to move, right-drag / wheel to pan and zoom, Delete removes the selected point. Each point has height and curve radius; each segment can be a tunnel, have no railings, or contain a jump. Saved tracks appear in the menu with a ★.

## Swapping in your own car models
Put a `.glb`, `.gltf` or `.fbx` named after the car in `models/` (e.g. `models/vektor.glb`), facing −Z. Stats and models are configured in `scripts/car_types.gd`.

## Credits
Car models: [Kenney Car Kit](https://kenney.nl/assets/car-kit) (CC0).
