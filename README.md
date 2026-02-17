# Editor Pilot Mode for Godot Engine 4.7+

Pilot any scene directly in the Godot 3D editor. Press `Shift+R` to drop into your scene and walk around.


https://github.com/user-attachments/assets/dc2ad8b2-e6f8-4dd4-98f3-5fbf16eb33e0



## Features

- Spawns a character at the editor camera position and takes over the 3D viewport
- Hides editor UI for an unobstructed view
- Comes with a default first-person `CharacterBody3D` (WASD + mouse look + jump)
- Fully customizable and compatible with any scene that includes a `Camera3D`

## How to install

1. Copy the contents of this repository into `addons/editor-pilot-mode/` in your Godot project.
2. Enable the plugin in **Project > Project Settings > Plugins**.

## How to use

1. Open any 3D scene in the editor.
2. Press `Shift+R` to enter pilot mode.
3. Move with `WASD`, look with the mouse, jump with `Space`.
4. Press `Shift+R` or `Escape` to exit.

The shortcut can be changed in **Editor > Editor Settings > Shortcuts** under *Pilot Mode*.

## Using a custom scene

By default the plugin spawns its built-in character. To use your own:

1. Go to **Project > Project Settings** and find `addons/pilot_mode/scene/path`.
2. Set it to the path of your `.tscn` file.

Your scene root must be a `Node3D` (or derived type) and contain at least one `Camera3D`.

### Tool scripts required

Any scripts attached to your piloted scene **must** use the `@tool` annotation. Without it, the editor won't execute the script logic and the scene will appear inert during pilot mode.

### Physics-based scenes

If your scene relies on physics (e.g. `RigidBody3D`, `VehicleBody3D`), you may need to enable the physics server in the editor:

```gdscript
PhysicsServer3D.set_active(true)
```

> [!WARNING]
> Activating the physics server lets physics run inside the editor. This means rigid bodies can fall, collisions resolve, and nodes may move from their authored positions — **changes made by physics while piloting will persist in the scene**. Consider using this only in test scenes, or undo any unintended modifications after exiting pilot mode.
