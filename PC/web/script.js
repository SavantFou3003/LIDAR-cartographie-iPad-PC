const canvas = document.getElementById('three-canvas');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(window.devicePixelRatio);
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x020611);

const camera = new THREE.PerspectiveCamera(60, 1, 0.05, 50);
camera.position.set(0, 0, 2.5);

const ambient = new THREE.AmbientLight(0x1f4fff, 0.6);
scene.add(ambient);
const pointLight = new THREE.PointLight(0x0ff0fc, 1.2);
pointLight.position.set(5, 5, 5);
scene.add(pointLight);

const MAX_POINTS = 20000;
const geometry = new THREE.BufferGeometry();
const positions = new Float32Array(MAX_POINTS * 3);
const colors = new Float32Array(MAX_POINTS * 3);
geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
geometry.setDrawRange(0, 0);

const material = new THREE.PointsMaterial({
    size: 0.015,
    vertexColors: true,
    transparent: true,
    opacity: 0.95,
    depthWrite: false
});

const pointCloud = new THREE.Points(geometry, material);
scene.add(pointCloud);

const statusPill = document.getElementById('ws-status');
const logWindow = document.getElementById('log-window');
const statPoints = document.getElementById('stat-points');
const statTimestamp = document.getElementById('stat-timestamp');
const statFps = document.getElementById('stat-fps');

let ws;
let lastFrame = performance.now();
let frameCounter = 0;
let fpsAccumulator = 0;

function resizeRenderer() {
    const width = canvas.clientWidth;
    const height = canvas.clientHeight;
    renderer.setSize(width, height, false);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
}

window.addEventListener('resize', resizeRenderer);
resizeRenderer();

function animate() {
    requestAnimationFrame(animate);
    const now = performance.now();
    const delta = now - lastFrame;
    lastFrame = now;
    fpsAccumulator += delta;
    frameCounter += 1;
    if (fpsAccumulator >= 1000) {
        statFps.textContent = (frameCounter * 1000 / fpsAccumulator).toFixed(1);
        fpsAccumulator = 0;
        frameCounter = 0;
    }
    pointCloud.rotation.y += 0.0005 * delta;
    renderer.render(scene, camera);
}

animate();

function connectWebSocket() {
    ws = new WebSocket('ws://localhost:9000');
    ws.onopen = () => {
        updateStatus(true);
        appendLog('Connexion WebSocket établie.');
    };
    ws.onmessage = (event) => {
        try {
            const data = JSON.parse(event.data);
            if (Array.isArray(data.points)) {
                updatePointCloud(data.points);
                statTimestamp.textContent = data.receivedAt ? new Date(data.receivedAt).toLocaleTimeString() : '--';
                statPoints.textContent = data.points.length;
                appendLog(`Points reçus: ${data.points.length}`);
            }
        } catch (error) {
            console.error('JSON invalide', error);
        }
    };
    ws.onclose = () => {
        updateStatus(false);
        appendLog('Connexion WebSocket perdue. Nouvelle tentative...');
        setTimeout(connectWebSocket, 2000);
    };
    ws.onerror = (error) => {
        console.error('WebSocket error', error);
    };
}

function updateStatus(isConnected) {
    statusPill.textContent = isConnected ? 'Connecté' : 'Déconnecté';
    statusPill.style.background = isConnected ? 'rgba(24, 206, 148, 0.3)' : 'rgba(206, 24, 82, 0.3)';
    statusPill.style.borderColor = isConnected ? '#18ce94' : '#ff5b81';
}

function appendLog(message) {
    const entry = document.createElement('div');
    entry.className = 'log-entry';
    entry.textContent = `[${new Date().toLocaleTimeString()}] ${message}`;
    logWindow.appendChild(entry);
    logWindow.scrollTop = logWindow.scrollHeight;
    const maxEntries = 150;
    while (logWindow.childElementCount > maxEntries) {
        logWindow.removeChild(logWindow.firstChild);
    }
}

function updatePointCloud(points) {
    const count = Math.min(points.length, MAX_POINTS);
    for (let i = 0; i < count; i += 1) {
        const baseIndex = i * 3;
        const point = points[i];
        positions[baseIndex] = point.x;
        positions[baseIndex + 1] = point.y;
        positions[baseIndex + 2] = point.z;
        const gray = Math.min(1, Math.max(0, point.gray ?? 0.5));
        colors[baseIndex] = gray;
        colors[baseIndex + 1] = gray + 0.1;
        colors[baseIndex + 2] = 1 - gray * 0.5;
    }
    geometry.setDrawRange(0, count);
    geometry.attributes.position.needsUpdate = true;
    geometry.attributes.color.needsUpdate = true;
}

connectWebSocket();
