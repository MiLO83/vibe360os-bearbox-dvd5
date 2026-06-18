# BearBox Vibe Runtime

Initial WebXR runtime for Meta Quest Browser.

Run locally:

```bash
npm install
npm run patch
npm run dev -- --host 0.0.0.0
```

Open the HTTPS Vite URL in Quest Browser and use the Enter VR button.

Send a patch:

```bash
curl -k https://bearbox.local:5173/patch \
  -H 'content-type: application/json' \
  -d '{"op":"create","id":"blue-ring","geometry":{"kind":"torus","radius":1.8,"tube":0.06},"material":{"color":"#40f0ff"},"transform":{"position":[0,1.6,-5],"rotation":[0,0,0],"scale":[1,1,1]}}'
```
