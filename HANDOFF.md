# Handoff: Siuuu Striker

Date: 2026-10-07. Next session starts here.

## GitHub

The repo created at the first step of this game is https://github.com/sanjaymaverick-cmd/football

- Owner `sanjaymaverick-cmd`, name `football`, public.
- Created 2026-10-07. Remote: `https://github.com/sanjaymaverick-cmd/football`. Do not create a second repo.
- `D:\work Dir\football` is the working copy of that repo. Do not commit or push unless the user asks.

## What this is

Portrait Android football game for about a 10-year-old. Godot 4.7, mobile renderer. The player swipes the ball. Screen-up shoots toward the goal. The bow of the swipe curls the ball. There is no joystick.

Control frame: Y-up, right-handed, goal is -Z. Screen-right is world +X. Screen-up is world -Z. A positive bow (path to the right of the chord) is positive `curl_pixels`, which sets negative `angular_velocity.y`. With velocity along -Z, that cross product bends the ball to +X.

## Hard rules

- Leave `Gemini_Generated_Image_ys2or9ys2or9ys2o.png` alone. It is the user's concept art.
- The SIUUU sound stays a synthetic placeholder. Do not clone a real player's voice.
- Do not add gameplay the user did not ask for.
- Do not ignore `*.import`. `.gitignore` already ignores `.godot/`, `build/`, `*.apk`, and `*.aab`.
- `build/.gdignore` keeps export output out of the Godot import scan.
- Prebuilt debug APK only (`gradle_build/use_gradle_build=false`), arm64-v8a only. Install with `adb install -r -t` because the debug APK is testOnly.
- Do not re-download the Godot 4.7 export templates. They are already unpacked.
- Do not recreate the debug keystore.
- Empty drop folders are not auto-loaded. Unknown Mixamo, Megascans, or Sketchfab files will have the wrong scale and facing.

## Machine

- Godot: `C:\Users\BHAGWAN\AppData\Local\Temp\godot47\Godot_v4.7-stable_win64_console.exe` (v4.7.stable.official.5b4e0cb0f)
- Templates: `%APPDATA%\Godot\export_templates\4.7.stable\`
- Editor settings: `%APPDATA%\Godot\editor_settings-4.7.tres` (keystore, JDK, SDK)
- Debug keystore: `%APPDATA%\Godot\keystores\debug.keystore`, alias `androiddebugkey`, storepass and keypass `android`
- JDK 21: `C:\Program Files\Java\jdk-21.0.12` (`keytool` is not on PATH)
- Android SDK: `%LOCALAPPDATA%\Android\Sdk`
- adb: `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`
- Tablet: Lenovo TB336FU, serial `HA2BDA3D`, arm64-v8a, Android 16. The adb daemon often dies. If the first `adb devices` is empty, start the server and list again. `INSTALL_FAILED_USER_RESTRICTED` means the user must accept the USB install prompt.
- Package `com.sanjaymaverick.siuuustriker`. Activity `com.sanjaymaverick.siuuustriker/com.godot.game.GodotAppLauncher`.
- Export preset name: `Android`. Output: `build/SiuuuStriker.apk`.

## Verify, export, install

```
& "C:\Users\BHAGWAN\AppData\Local\Temp\godot47\Godot_v4.7-stable_win64_console.exe" --headless --path "D:\work Dir\football" --import
& "C:\Users\BHAGWAN\AppData\Local\Temp\godot47\Godot_v4.7-stable_win64_console.exe" --headless --path "D:\work Dir\football" --script res://tests/smoke.gd
& "C:\Users\BHAGWAN\AppData\Local\Temp\godot47\Godot_v4.7-stable_win64_console.exe" --headless --path "D:\work Dir\football" --export-debug "Android" "D:\work Dir\football\build\SiuuuStriker.apk"
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s HA2BDA3D install -r -t "D:\work Dir\football\build\SiuuuStriker.apk"
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s HA2BDA3D shell am start -n com.sanjaymaverick.siuuustriker/com.godot.game.GodotAppLauncher
```

New `.jpg`, `.hdr`, `.gltf`, and `.gdshader` files are invisible to a headless game run until `--import`. A headless run does not show the 3D view. `tests/smoke.gd` is the proof. It must print `SMOKE_OK` and exit 0.

Smoke notes that are easy to break:

- It extends `SceneTree`. Adding the scene inside `_initialize` defers `_ready`, so boot checks run at `frames == 2`.
- Force the viewport to 1080×1920. A square headless window hides portrait clipping.
- `SceneTree._process` returns bool. Return false to keep running. There is no `bool()` constructor.
- `class_name` scripts need an editor `--import` before the class cache exists. That cache is gitignored.
- `apply_central_impulse` is not visible on `linear_velocity` until the next physics tick.
- Godot 4 typed arrays reject `var freqs: Array[float] = [1.0] if cond else [3.0]`. Use an untyped array.
- Quitting mid-loop can print a harmless 2-instance ObjectDB leak.

Last smoke on Jolt, 2026-10-07: `SMOKE_OK`. Curl right about +158, left about -158, straight 0. Shot vz about -27, vy about 7.3, spin y about -7.9. Magnus 70 frames: spin -8 moved x about +0.82, spin +8 moved x about -0.85. Super shot x = 0, vz about -76. Score 150, combo 2, then wall of 3 at (-5.2, 0.11, -1.2). Keeper dive right x about 3.0 with negative roll. Dive left x about -3.0 with positive roll. Fast ball at 60 m/s into the crossbar rebounded: z about -7.47, vz about +24. It did not tunnel.

## What is already in the game

Main scene `res://scenes/main.tscn`. Viewport 1080×1920, window override 540×960, stretch `canvas_items` expand, handheld orientation portrait, touch and mouse emulate each other, gravity (0, -9.8, 0), 120 physics ticks, MSAA 4×, ETC2/ASTC.

`project.godot` uses `3d/physics_engine="Jolt Physics"`. This is the engine built into Godot 4.7. Do not install the Asset Library `godot-jolt` plugin. That extension is the old one and is the wrong install for 4.7. The official Android templates already contain Jolt.

Ball (`scripts/ball_controller.gd`, `BallController`): mass 0.43, `continuous_cd` on, linear damp replace 0.05, angular damp replace 0.4, friction 0.8, bounce 0.4. Grass friction 0.9, bounce 0.15, absorbent on. Collision layers: 1 world, 2 ball, 3/4 score and targets. Score zone is a sensor.

Shot numbers, unchanged on purpose: min swipe 40 px, impulse 6 to 13.5, lift 2.2 to 3.4 from how upright the swipe is, `spin_per_pixel` 0.05, max spin 9, `magnus_coefficient` 0.036, super-shot forward multiplier 2.5 with spin cleared. Magnus runs only in the air, via `apply_central_force(angular_velocity.cross(linear_velocity) * magnus_coefficient)`. A SIUUU shot skips Magnus and plays the fire trail.

Keeper (`scripts/goalkeeper.gd`): READY, REACT 0.16s, DIVE 0.48s, HOLD 0.28s, RECOVER 0.42s. He commits. He does not track after the dive. Prediction under-reads late curl so a heavy hook can beat him. SIUUU sends him the wrong way and low. Assign one `global_transform`. Setting `rotation` after `global_position` on an `AnimatableBody3D` zeroes x. Positive rotation.x tips the head toward +Z. Positive rotation.z tips the head toward -X, so a dive to +X uses a negative roll. Home is about (0, 0.82, -10.32).

Camera (`scripts/camera_controller.gd`): looks at the goal mouth `(0, 1.28, -11)`, not at the ball. fov 84, far 180. During a shot it barely follows Z so both posts stay in the portrait frame. Call `snap_to_ball()` when the spot changes.

Set pieces advance only after a goal (`scripts/game_manager.gd`): central wall of 2 at (0, 0.11, 1.5), left wall of 3 at (-5.2, 0.11, -1.2), right wall of 4 at (5.0, 0.11, -0.4), long wall of 5 at (0.8, 0.11, 3.4), tight angle wall of 6 at (-6.2, 0.11, -5.5), then cycle. A miss resets the ball and the keeper. The wall stays. Out of play: y < -1, z < -16, z > 8, or |x| > 12. `_reset_play` returns immediately unless `_resetting`, so a pending timer cannot double-advance.

Audio (`scripts/crowd_audio.gd`): synthetic ambience loop and cheers. The wav files in `audio/` stay as scene references. The game manager overrides players at runtime.

## Art that is wired

CC0 credit lives as a comment in `scripts/stadium.gd`. Poly Haven asked that it stay clear the assets came from them.

- Pitch: AmbientCG Grass001 2K (color, OpenGL normal, roughness, AO) through `shaders/pitch_grass.gdshader`. World-space XZ, tile about 2 m (`uv_scale` 0.5), mowing stripes along Z every 3.2 m. `NORMAL_MAP` is sampled without `hint_normal`. Grass001 is short turf, not meadow grass. Tool leftovers and the DirectX normal sit in `assets/ambientcg/Grass001/unused/` behind `.gdignore`.
- Sky: Poly Haven `suburban_football_field` 2k HDR as a `PanoramaSkyMaterial`. The old radius-90 sky sphere is not built when the HDR loads, because the camera is inside that sphere and it would hide the sky. Sun energy is about 1.05 when the HDR is on. Ambient and reflections come from the sky. Tone mapping is milder than the old untextured look (contrast about 1.08, saturation about 1.12).
- Ball visual: Poly Haven `football_1k.gltf`. Keep `football_inflated` only. The glTF parks it beside the deflated ball, so `stadium.gd` recenters it and scales the longest side to 0.22 m, matching the collision sphere. The white primitive sphere and the stripe torus are hidden. Collision stays the sphere. Clear `owner` before `add_child` or Godot warns. Rigid body rotation drives the mesh. Do not counter-rotate it.
- If a texture or the model fails to load, the code falls back to the procedural turf, the blue sky dome, or the white sphere.

Stands, crowd, boards, floodlights, the keeper, and the wall are still primitive meshes. Shirt colors on the wall cycle yellow, red, blue, white, green.

## Drop folders (empty, not loaded)

- `assets/mixamo/` — characters and animation. Needs an Adobe login. Export FBX binary, 60 fps, with skin, no keyframe reduction. Expected first file: `assets/mixamo/keeper.fbx`, with idle, a kick, and a dive. Do not retarget until a file is actually there. Measure the model's front. Do not hard-code `rotation.y = PI`.
- `assets/megascans/` — environments and props from Fab. Needs an Epic login. Do not scrape.
- `assets/sketchfab/` — only files the user downloads that are clearly CC0 or CC-BY. Licenses vary. Do not download through OAuth from here.

## Deliberately not done

- Bezier or other scripted flight into the top corner. The user was shown that arcade option. Shots still follow the swipe. Add a locked curve only if they ask for it.
- Shot-feel retune. A flick and a whip still land in the same 6 to 13.5 impulse band. Magnus stays at 0.036 with no spin decay. Lift does not read topspin dip or backspin hang. Wall and keeper contact is still box collision. The user has said the swipe physics feel bad. Do not change these numbers unless they ask again.
- Forward+ renderer. The mobile renderer is the right one for the TB336FU.
- Real keeper, wall, stand, and crowd meshes. Those wait on the drop folders.

## Last device state

The Jolt build was exported, installed on `HA2BDA3D`, and launched (`am start` exit 0) on 2026-10-07. That APK includes the Grass001 pitch, the Poly Haven sky and ball, and Jolt. The user has not yet said how that build feels.

## If you change play

Run smoke before calling it done. After a goal, the next kick must move. A miss must not. Both posts and the ball must stay inside the portrait frame from the central spot and from the tight-angle spot (-6.2, 0.11, -5.5). A fast ball must still rebound off the crossbar (`tests/smoke.gd` phase 11). Export and `adb install -r -t` only when the user wants it on the tablet, or when they are already waiting on a device build.
