# Cameras

Read this before adding or changing a camera, a shot, or anything that places itself from the camera. **Shot** is defined in `CONTEXT.md`.

Game cameras run on [Phantom Camera](https://phantom-camera.dev) (`addons/phantom_camera/`). The scene's one `Camera3D` renders, and a `PhantomCameraHost` child moves it every frame to the active **shot**: a `PhantomCamera3D` node placed where the camera should be. `game/solar_system/camera_rig.tscn` shows it with two shots: `Shot`, which pans and zooms, and `FocusShot`, which follows the open planet or bus.

- Put camera behaviour on the shot, in the inspector: follow a target with damping (Follow Mode), look at one (Look At Mode), orbit a target and stay out of walls (Third Person follow, a spring arm), frame several targets (Group follow). Don't move the `Camera3D` from a script; the host overwrites it the next frame.
- Change shots by raising one shot's `priority` above the others, or with `set_priority()` from a script. The host blends to it with that shot's `tween_resource`.
- Set `tween_on_load` off on a scene's first shot. `SceneFlow`'s fade already hides the cut, and the load blend starts from wherever the camera happened to be.
- Shake through `Feedback.shake`, never the plugin's noise (`noise` on a shot or a `PhantomCameraNoiseEmitter3D`): Feedback honours Reduce motion and the plugin's noise doesn't. Feedback owns the camera's `h_offset` and `v_offset`, so leave them at 0 on every shot and its `Camera3DResource`; the host only writes them when they differ between shots.
- Cast picking rays from the `Camera3D` (`%Camera`), not the shot: the camera is where the player looks from, including mid-blend.
- The host moves the camera in `_process` at `process_priority = 300`. Anything that places itself from the camera, such as UI that follows a planet through `unproject_position()`, sets a `process_priority` above 300, or it trails the camera by a frame and twitches when it pans.
- The plugin's updater is off (`phantom_camera/updater/updater_mode=0`) so the pinned version stays pinned.
