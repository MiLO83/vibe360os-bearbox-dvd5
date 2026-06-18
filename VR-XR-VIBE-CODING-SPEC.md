# VR/XR Vibe Coding Environment

Goal: use a Meta Quest headset as the main spatial workstation for building
and mutating live "Vibes/Programs": 360 degree 3D worlds that can be edited
while they are running.

## Core Direction

Start with a browser-native WebXR app served from the Linux box.

- Quest runs the experience in Quest Browser.
- The Linux server hosts the app, asset library, code workspace, and Codex CLI.
- ChatGPT/Codex edits files on the server.
- The running world receives updates through a local websocket/dev server.
- Real administration happens through SSH keys; VNC is only for browser/GUI work.

This avoids native Quest build/deploy loops while still giving full VR.

## First Version

Use `immersive-vr` as the default WebXR mode.

Do not start with passthrough AR. In WebXR, `immersive-ar` behaves differently:
alpha controls camera blending, normal skyboxes/backgrounds do not work the same
way, and the session mode cannot be switched after entering XR.

Initial capabilities:

- full 360 degree Three.js world
- controller ray interaction
- hand/controller menu panel
- teleport plus smooth locomotion
- live object creation from JSON scene patches
- runtime material/color/position/scale edits
- asset upload folder on the server
- Codex CLI available in a terminal/VNC session
- browser-based ChatGPT available over VNC

## Runtime Editing Model

The running world should not rely on arbitrary code injection for the first
pass. Use a structured scene patch protocol:

```json
{
  "op": "create",
  "id": "neon-gate-01",
  "type": "mesh",
  "geometry": { "kind": "torus", "radius": 1.6, "tube": 0.08 },
  "material": { "kind": "emissive", "color": "#40f0ff" },
  "transform": {
    "position": [0, 1.6, -4],
    "rotation": [0, 0, 0],
    "scale": [1, 1, 1]
  }
}
```

The app can safely apply these patches without reloading the whole session.
Later, add controlled script modules for advanced behavior.

## Server Components

- Ubuntu Server LTS
- Node.js LTS
- Vite dev server or a small custom WebSocket server
- Three.js app workspace
- Codex CLI
- Git and GitHub CLI
- optional VNC desktop with browser
- NVIDIA/CUDA for local AI/audio/graphics workloads outside the headset

Suggested ports:

- `22`: SSH
- `5173`: Vite/WebXR app
- `8787`: websocket scene patch service
- VNC only through SSH tunnel, not public

## Quest Workflow

1. Put Quest and Linux box on the same LAN.
2. Open `https://server-name.local:5173` in Quest Browser.
3. Enter VR from an explicit button.
4. Use Codex/ChatGPT on the server to modify the scene.
5. Changes stream to the headset as JSON patches.
6. For deeper code changes, hot module reload updates the desktop preview; Quest
   may need a browser refresh depending on cache behavior.

Use Quest Browser first. Avoid PWA mode until the app is stable because PWA
caching can hide whether the newest build is actually running.

## VR Architecture Requirements

- Use a `cameraRig` group containing camera, controllers, teleport reticle, and
  locomotion state.
- Move the rig, not the XR camera directly.
- Use `local-floor` reference space.
- Set native WebXR framebuffer scale with `XRWebGLLayer.getNativeFramebufferScaleFactor`.
- Keep VR rendering direct: `renderer.render(scene, camera)`.
- Do not depend on screen-space postprocessing in VR.
- Use emissive meshes, transparent rings, particles, and 3D geometry for glow
  and shockwave-style effects.
- Position generated objects around eye height, usually near `y = 1.6`.
- Keep UI panels as canvas textures on world-space planes.

## AR/Passthrough Later

Add passthrough as a separate mode, not a toggle inside VR.

- VR button: request `immersive-vr`
- AR button: request `immersive-ar`

Every AR material/shader needs an alpha plan:

- alpha `0`: show camera passthrough
- alpha `1`: show rendered object/background

## Security Notes

The Dr. Watson decoy terminal is personality, not protection.

Real controls:

- SSH keys only
- password SSH disabled
- root SSH disabled
- firewall blocks VNC from the LAN/WAN
- VNC only through SSH tunnel
- Codex runs as the admin/dev user, not as root

## Build Order

1. Build the Linux install/refresh disc.
2. Install server packages, SSH hardening, Codex CLI, GitHub CLI, VNC.
3. Install the Dr. Watson decoy terminal.
4. Scaffold the WebXR app with Three.js and Vite.
5. Add Quest controller locomotion and panel UI.
6. Add websocket scene patching.
7. Add ChatGPT/Codex workflow docs and repo templates.
8. Add optional CUDA-backed local tools after the base loop works.
