import * as THREE from 'three';
import { VRButton } from 'three/examples/jsm/webxr/VRButton.js';

const canvas = document.querySelector('#world');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.xr.enabled = true;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x05060a);

const cameraRig = new THREE.Group();
scene.add(cameraRig);

const camera = new THREE.PerspectiveCamera(70, window.innerWidth / window.innerHeight, 0.01, 200);
camera.position.set(0, 1.6, 0);
cameraRig.add(camera);

const floor = new THREE.Mesh(
  new THREE.CircleGeometry(20, 96),
  new THREE.MeshStandardMaterial({ color: 0x10151f, roughness: 0.85 })
);
floor.rotation.x = -Math.PI / 2;
scene.add(floor);

const hemi = new THREE.HemisphereLight(0x90c7ff, 0x101018, 1.2);
scene.add(hemi);

const sun = new THREE.DirectionalLight(0xffffff, 1.8);
sun.position.set(2, 6, 4);
scene.add(sun);

const objects = new Map();
const torus = new THREE.Mesh(
  new THREE.TorusGeometry(1.3, 0.055, 24, 160),
  new THREE.MeshBasicMaterial({ color: 0x40f0ff })
);
torus.position.set(0, 1.6, -4);
scene.add(torus);
objects.set('welcome-ring', torus);

const xrButton = VRButton.createButton(renderer);
document.body.appendChild(xrButton);
document.querySelector('#enter-xr').addEventListener('click', () => xrButton.click());

function createMesh(patch) {
  let geometry;
  if (patch.geometry?.kind === 'box') {
    geometry = new THREE.BoxGeometry(...(patch.geometry.size ?? [1, 1, 1]));
  } else if (patch.geometry?.kind === 'sphere') {
    geometry = new THREE.SphereGeometry(patch.geometry.radius ?? 0.5, 32, 16);
  } else {
    geometry = new THREE.TorusGeometry(patch.geometry?.radius ?? 1, patch.geometry?.tube ?? 0.05, 20, 96);
  }

  const color = new THREE.Color(patch.material?.color ?? '#ffffff');
  const material = new THREE.MeshBasicMaterial({ color });
  const mesh = new THREE.Mesh(geometry, material);
  applyTransform(mesh, patch.transform ?? {});
  return mesh;
}

function applyTransform(mesh, transform) {
  if (transform.position) mesh.position.fromArray(transform.position);
  if (transform.rotation) mesh.rotation.fromArray(transform.rotation);
  if (transform.scale) mesh.scale.fromArray(transform.scale);
}

function applyPatch(patch) {
  if (!patch || !patch.op || !patch.id) return;

  if (patch.op === 'create') {
    if (objects.has(patch.id)) scene.remove(objects.get(patch.id));
    const mesh = createMesh(patch);
    objects.set(patch.id, mesh);
    scene.add(mesh);
  }

  if (patch.op === 'update' && objects.has(patch.id)) {
    const mesh = objects.get(patch.id);
    if (patch.material?.color && mesh.material?.color) mesh.material.color.set(patch.material.color);
    if (patch.transform) applyTransform(mesh, patch.transform);
  }

  if (patch.op === 'delete' && objects.has(patch.id)) {
    const mesh = objects.get(patch.id);
    scene.remove(mesh);
    mesh.geometry?.dispose?.();
    mesh.material?.dispose?.();
    objects.delete(patch.id);
  }
}

function connectPatchSocket() {
  const scheme = window.location.protocol === 'https:' ? 'wss' : 'ws';
  const url = `${scheme}://${window.location.host}/patch-ws`;
  const socket = new WebSocket(url);
  socket.addEventListener('message', (event) => {
    try {
      applyPatch(JSON.parse(event.data));
    } catch (error) {
      console.error('Invalid vibe patch', error);
    }
  });
  socket.addEventListener('close', () => setTimeout(connectPatchSocket, 2000));
}

window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
});

connectPatchSocket();

renderer.setAnimationLoop((time) => {
  torus.rotation.y = time * 0.0005;
  renderer.render(scene, camera);
});
