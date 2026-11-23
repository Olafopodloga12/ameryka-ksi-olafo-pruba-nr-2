// ============================================================
// main.js — Entry point, 3D scene setup, game loop & UI wiring
// ============================================================
import * as THREE from '../lib/three.module.js';
import { UI } from './ui.js';
import { Network } from './network.js';
import { Game } from './game.js';
import { OBSTACLES, ARENA_HALF } from './player.js';

class App {
    constructor() {
        console.log('[App] Initializing Olafo Killer vs Pierogi...');
        this.ui = new UI();
        this.network = new Network();
        this.clock = new THREE.Clock();

        this.scene = null;
        this.camera = null;
        this.renderer = null;
        this.game = null;
        this.wallMeshes = [];
        this.playerLight = null;

        this.textures = {
            killer: this._createFallbackTexture('#ff4444', 'OLAFO'),
            pierog: this._createFallbackTexture('#ffcc00', 'PIERÓG'),
            dead: this._createFallbackTexture('#888888', 'DEAD')
        };

        // 1. Bind UI events immediately so buttons ALWAYS work!
        this._bindEvents();

        // 2. Initialize 3D Engine & Game
        try {
            this._initThree();
            this._initGame();
            this._animate();
        } catch (e) {
            console.error('[App] Failed to init 3D engine:', e);
        }

        // 3. Load actual PNG assets in background
        this._loadTextures().then(() => {
            console.log('[App] Assets loaded successfully.');
            if (this.game) {
                this.game.setTextures(this.textures.killer, this.textures.pierog, this.textures.dead);
            }
        });
    }

    // Creates an instant fallback canvas texture so sprites exist even if images take time to load
    _createFallbackTexture(color, label) {
        const canvas = document.createElement('canvas');
        canvas.width = 128;
        canvas.height = 128;
        const ctx = canvas.getContext('2d');
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.arc(64, 64, 50, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#ffffff';
        ctx.font = 'bold 20px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(label, 64, 64);
        const tex = new THREE.CanvasTexture(canvas);
        tex.colorSpace = THREE.SRGBColorSpace;
        return tex;
    }

    // Initialize Three.js scene, camera, lights and map
    _initThree() {
        const container = document.getElementById('game-canvas-container');

        // Scene
        this.scene = new THREE.Scene();
        this.scene.background = new THREE.Color(0x0a0c16); // Laser theme dark cyber-blue
        this.scene.fog = new THREE.FogExp2(0x0a0c16, 0.018);

        // Camera
        const aspect = window.innerWidth / window.innerHeight;
        this.camera = new THREE.PerspectiveCamera(60, aspect, 0.1, 200);
        this.camera.position.set(0, 14, 11);
        this.camera.lookAt(0, 0, 0);

        // Renderer with soft shadow maps
        this.renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
        this.renderer.setSize(window.innerWidth, window.innerHeight);
        this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
        this.renderer.shadowMap.enabled = true;
        this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
        container.appendChild(this.renderer.domElement);

        // Ambient Light
        const ambient = new THREE.AmbientLight(0x223355, 0.6);
        this.scene.add(ambient);

        // Main Directional Light (Neon tinted)
        const dirLight = new THREE.DirectionalLight(0xff0055, 0.85);
        dirLight.position.set(30, 45, 25);
        dirLight.castShadow = true;
        dirLight.shadow.mapSize.width = 2048;
        dirLight.shadow.mapSize.height = 2048;
        dirLight.shadow.camera.near = 1;
        dirLight.shadow.camera.far = 120;
        const d = 35;
        dirLight.shadow.camera.left = -d;
        dirLight.shadow.camera.right = d;
        dirLight.shadow.camera.top = d;
        dirLight.shadow.camera.bottom = -d;
        dirLight.shadow.bias = -0.0005;
        this.scene.add(dirLight);

        // Secondary laser cyan rim light
        const fillLight = new THREE.DirectionalLight(0x00f0ff, 0.6);
        fillLight.position.set(-25, 20, -25);
        this.scene.add(fillLight);

        // Dynamic light following the player (cyber neon)
        this.playerLight = new THREE.PointLight(0xff0055, 1.4, 20, 1.4);
        this.playerLight.position.set(0, 3, 0);
        this.scene.add(this.playerLight);

        // Build 3D Arena
        this._buildArena();

        // Handle Resize
        window.addEventListener('resize', () => {
            const w = window.innerWidth;
            const h = window.innerHeight;
            this.camera.aspect = w / h;
            this.camera.updateProjectionMatrix();
            this.renderer.setSize(w, h);
        });
    }

    _buildArena() {
        this.wallMeshes = [];
        const arenaSize = 50;

        // Ground floor (dark laser arena grid floor)
        const floorGeo = new THREE.PlaneGeometry(arenaSize, arenaSize);
        const floorMat = new THREE.MeshStandardMaterial({
            color: 0x070913,
            roughness: 0.6,
            metalness: 0.2
        });
        const floor = new THREE.Mesh(floorGeo, floorMat);
        floor.rotation.x = -Math.PI / 2;
        floor.receiveShadow = true;
        this.scene.add(floor);

        // Laser grid across the floor (laser cyan and neon red matching menu grid)
        const grid = new THREE.GridHelper(arenaSize, 50, 0xff0055, 0x00f0ff);
        grid.position.y = 0.01;
        grid.material.opacity = 0.45;
        grid.material.transparent = true;
        this.scene.add(grid);

        // Ambient 3D Laser beams traversing the arena
        this._createArenaLaserBeams();

        // Outer Boundary Walls (High-tech cyber borders with neon glow)
        const outerWallMat = new THREE.MeshStandardMaterial({
            color: 0x0b1326,
            roughness: 0.35,
            metalness: 0.5
        });
        const wallHeight = 3.5;
        const wallThickness = 1.0;
        const offset = ARENA_HALF + (wallThickness / 2);

        this._createWall(arenaSize + wallThickness * 2, wallHeight, wallThickness, 0, wallHeight / 2, -offset, outerWallMat);
        this._createWall(arenaSize + wallThickness * 2, wallHeight, wallThickness, 0, wallHeight / 2, offset, outerWallMat);
        this._createWall(wallThickness, wallHeight, arenaSize, -offset, wallHeight / 2, 0, outerWallMat);
        this._createWall(wallThickness, wallHeight, arenaSize, offset, wallHeight / 2, 0, outerWallMat);

        // Outer neon laser strips on top of perimeter walls
        const borderTrimMat = new THREE.MeshBasicMaterial({ color: 0xff0055 });
        this._createNeonStrip(arenaSize, 0.08, 0.08, 0, wallHeight + 0.04, -offset, borderTrimMat);
        this._createNeonStrip(arenaSize, 0.08, 0.08, 0, wallHeight + 0.04, offset, borderTrimMat);
        this._createNeonStrip(0.08, 0.08, arenaSize, -offset, wallHeight + 0.04, 0, borderTrimMat);
        this._createNeonStrip(0.08, 0.08, arenaSize, offset, wallHeight + 0.04, 0, borderTrimMat);

        // Inner Obstacles & Walls (dark cyber blocks with laser neon edges)
        const obsMatA = new THREE.MeshStandardMaterial({
            color: 0x101528,
            roughness: 0.3,
            metalness: 0.6
        });
        const obsMatB = new THREE.MeshStandardMaterial({
            color: 0x0a1020,
            roughness: 0.3,
            metalness: 0.6
        });
        const neonCyanMat = new THREE.MeshBasicMaterial({ color: 0x00f0ff });
        const neonRedMat = new THREE.MeshBasicMaterial({ color: 0xff0055 });

        OBSTACLES.forEach((obs, index) => {
            const h = 3.2;
            const geo = new THREE.BoxGeometry(obs.w, h, obs.d);
            const mat = (index % 2 === 0) ? obsMatA : obsMatB;
            const mesh = new THREE.Mesh(geo, mat);
            mesh.position.set(obs.x, h / 2, obs.z);
            mesh.castShadow = true;
            mesh.receiveShadow = true;
            this.scene.add(mesh);
            this.wallMeshes.push(mesh);

            // Laser edge cap on top of walls
            const trimMat = (index % 2 === 0) ? neonCyanMat : neonRedMat;
            const capGeo = new THREE.BoxGeometry(obs.w * 0.98, 0.08, obs.d * 0.98);
            const cap = new THREE.Mesh(capGeo, trimMat);
            cap.position.set(obs.x, h + 0.04, obs.z);
            this.scene.add(cap);
        });

        // Corner Burger relaxing on the ground
        this._createCornerBurger();
    }

    _createCornerBurger() {
        const burgerGroup = new THREE.Group();

        // 1. Bottom Bun
        const bottomBunGeo = new THREE.CylinderGeometry(0.75, 0.68, 0.22, 20);
        const bunMat = new THREE.MeshStandardMaterial({
            color: 0xdf9b52, // Golden bun
            roughness: 0.6,
            metalness: 0.05
        });
        const bottomBun = new THREE.Mesh(bottomBunGeo, bunMat);
        bottomBun.position.y = 0.11;
        bottomBun.castShadow = true;
        bottomBun.receiveShadow = true;
        burgerGroup.add(bottomBun);

        // 2. Juicy Patty (Meat)
        const pattyGeo = new THREE.CylinderGeometry(0.8, 0.8, 0.2, 20);
        const pattyMat = new THREE.MeshStandardMaterial({
            color: 0x4a2412, // Dark grilled brown
            roughness: 0.8,
            metalness: 0.1
        });
        const patty = new THREE.Mesh(pattyGeo, pattyMat);
        patty.position.y = 0.28;
        patty.castShadow = true;
        burgerGroup.add(patty);

        // 3. Melted Cheese slice (square sticking out at angles)
        const cheeseGeo = new THREE.BoxGeometry(1.22, 0.05, 1.22);
        const cheeseMat = new THREE.MeshStandardMaterial({
            color: 0xffb800, // Rich cheddar yellow
            roughness: 0.4,
            metalness: 0.1
        });
        const cheese = new THREE.Mesh(cheeseGeo, cheeseMat);
        cheese.rotation.y = Math.PI / 4;
        cheese.position.y = 0.38;
        cheese.castShadow = true;
        burgerGroup.add(cheese);

        // 4. Fresh Lettuce (wavy green layer)
        const lettuceGeo = new THREE.CylinderGeometry(0.86, 0.82, 0.08, 16);
        const lettuceMat = new THREE.MeshStandardMaterial({
            color: 0x44bb22, // Crisp green
            roughness: 0.7,
            metalness: 0.05
        });
        const lettuce = new THREE.Mesh(lettuceGeo, lettuceMat);
        lettuce.position.y = 0.44;
        burgerGroup.add(lettuce);

        // 5. Tomato slices
        const tomatoMat = new THREE.MeshStandardMaterial({
            color: 0xdd2211,
            roughness: 0.3,
            metalness: 0.1
        });
        const tomatoA = new THREE.Mesh(new THREE.CylinderGeometry(0.42, 0.42, 0.07, 16), tomatoMat);
        tomatoA.position.set(-0.25, 0.51, 0.15);
        burgerGroup.add(tomatoA);

        const tomatoB = new THREE.Mesh(new THREE.CylinderGeometry(0.42, 0.42, 0.07, 16), tomatoMat);
        tomatoB.position.set(0.28, 0.51, -0.15);
        burgerGroup.add(tomatoB);

        // 6. Top Bun (Dome)
        const topBunGeo = new THREE.SphereGeometry(0.8, 20, 14, 0, Math.PI * 2, 0, Math.PI * 0.5);
        const topBun = new THREE.Mesh(topBunGeo, bunMat);
        topBun.scale.set(1, 0.58, 1);
        topBun.position.y = 0.53;
        topBun.castShadow = true;
        burgerGroup.add(topBun);

        // 7. Sesame seeds on top bun
        const seedMat = new THREE.MeshBasicMaterial({ color: 0xfff6df });
        for (let i = 0; i < 22; i++) {
            const seedGeo = new THREE.SphereGeometry(0.025, 6, 6);
            seedGeo.scale(1, 0.4, 2);
            const seed = new THREE.Mesh(seedGeo, seedMat);
            const radius = 0.15 + Math.random() * 0.5;
            const angle = Math.random() * Math.PI * 2;
            const sx = Math.cos(angle) * radius;
            const sz = Math.sin(angle) * radius;
            const sy = 0.54 + Math.sqrt(Math.max(0, 0.8 * 0.8 - sx * sx - sz * sz)) * 0.56;
            seed.position.set(sx, sy, sz);
            seed.rotation.y = Math.random() * Math.PI;
            seed.rotation.x = 0.2;
            burgerGroup.add(seed);
        }

        // 8. Warm appetizing light on the burger
        const burgerLight = new THREE.PointLight(0xffaa33, 1.0, 3.5);
        burgerLight.position.set(0, 0.9, 0);
        burgerGroup.add(burgerLight);

        // Make burger much smaller (dużo mniejszy!)
        burgerGroup.scale.set(0.38, 0.38, 0.38);

        // Position the burger tucked right in the corner of the arena, tilted slightly as it relaxes
        burgerGroup.position.set(22.8, 0, -22.8);
        burgerGroup.rotation.y = 0.6;
        burgerGroup.rotation.z = 0.04; // Slightly tilted relaxing angle
        this.scene.add(burgerGroup);
    }

    _createNeonStrip(w, h, d, x, y, z, mat) {
        const geo = new THREE.BoxGeometry(w, h, d);
        const mesh = new THREE.Mesh(geo, mat);
        mesh.position.set(x, y, z);
        this.scene.add(mesh);
    }

    _createArenaLaserBeams() {
        this.arenaLaserBeams = [];
        const beamMatRed = new THREE.MeshBasicMaterial({
            color: 0xff0055,
            transparent: true,
            opacity: 0.85
        });
        const beamMatCyan = new THREE.MeshBasicMaterial({
            color: 0x00f0ff,
            transparent: true,
            opacity: 0.75
        });

        // Add criss-crossing aesthetic laser beams above the arena floor
        const beamConfigs = [
            { y: 1.6, z: -10, angle: 0.25, mat: beamMatRed, speed: 0.4 },
            { y: 2.1, z: 8, angle: -0.35, mat: beamMatCyan, speed: -0.3 },
            { y: 1.2, z: 16, angle: 0.15, mat: beamMatRed, speed: 0.5 },
            { y: 2.4, z: -18, angle: -0.2, mat: beamMatCyan, speed: -0.4 }
        ];

        beamConfigs.forEach((cfg, idx) => {
            const beamGeo = new THREE.CylinderGeometry(0.04, 0.04, 52, 8);
            const beam = new THREE.Mesh(beamGeo, cfg.mat);
            beam.rotation.z = Math.PI / 2;
            beam.rotation.y = cfg.angle;
            beam.position.set(0, cfg.y, cfg.z);
            this.scene.add(beam);
            this.arenaLaserBeams.push({ mesh: beam, baseZ: cfg.z, speed: cfg.speed });
        });
    }

    _createWall(w, h, d, x, y, z, mat) {
        const geo = new THREE.BoxGeometry(w, h, d);
        const mesh = new THREE.Mesh(geo, mat);
        mesh.position.set(x, y, z);
        mesh.castShadow = true;
        mesh.receiveShadow = true;
        this.scene.add(mesh);
        this.wallMeshes.push(mesh);
    }

    async _loadTextures() {
        const loader = new THREE.TextureLoader();

        const loadTex = (path) => new Promise((resolve) => {
            loader.load(
                path,
                (texture) => {
                    texture.colorSpace = THREE.SRGBColorSpace;
                    resolve(texture);
                },
                undefined,
                (err) => {
                    console.warn('[App] Could not load texture from', path, err);
                    resolve(null);
                }
            );
        });

        const [killer, pierog, dead] = await Promise.all([
            loadTex('assets/olafo_killer.png'),
            loadTex('assets/pierog.png'),
            loadTex('assets/dead_pierog.png')
        ]);

        if (killer) this.textures.killer = killer;
        if (pierog) this.textures.pierog = pierog;
        if (dead) this.textures.dead = dead;
    }

    _initGame() {
        if (!this.scene) return;
        this.game = new Game(this.network, this.ui, this.scene);
        this.game.setCamera(this.camera);
        this.game.setTextures(this.textures.killer, this.textures.pierog, this.textures.dead);
        this.game.setObstacleMeshes(this.wallMeshes);
    }

    _bindEvents() {
        console.log('[App] Binding UI button events...');

        // Toggle join section
        this.ui.btnJoinShow.addEventListener('click', () => {
            console.log('[App] btnJoinShow clicked');
            this.ui.joinSection.classList.toggle('hidden');
            if (!this.ui.joinSection.classList.contains('hidden')) {
                this.ui.roomCodeInput.focus();
            }
        });

        // Copy room code to clipboard on click
        this.ui.roomCodeText.addEventListener('click', () => {
            const code = this.ui.roomCodeText.textContent;
            if (code && navigator.clipboard) {
                navigator.clipboard.writeText(code).then(() => {
                    const original = this.ui.roomCodeText.textContent;
                    this.ui.roomCodeText.textContent = 'SKOPIOWANO!';
                    setTimeout(() => {
                        this.ui.roomCodeText.textContent = original;
                    }, 1200);
                }).catch(() => {});
            }
        });

        // Create lobby
        this.ui.btnCreate.addEventListener('click', () => {
            console.log('[App] btnCreate clicked');
            this._createLobby();
        });

        // Join lobby
        this.ui.btnJoin.addEventListener('click', () => {
            console.log('[App] btnJoin clicked');
            this._joinLobby();
        });

        // Enter key listeners
        this.ui.roomCodeInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') this._joinLobby();
        });

        this.ui.nicknameInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                if (!this.ui.joinSection.classList.contains('hidden')) {
                    this.ui.roomCodeInput.focus();
                } else {
                    this._createLobby();
                }
            }
        });

        // Start round (host only)
        this.ui.btnStart.addEventListener('click', () => {
            console.log('[App] btnStart clicked');
            if (this.game) {
                this.game.startRound();
            }
        });

        // Leave lobby
        this.ui.btnLeave.addEventListener('click', () => {
            console.log('[App] btnLeave clicked');
            this._leaveLobby();
        });

        // Keyboard controls
        window.addEventListener('keydown', (e) => {
            if (this.game) {
                this.game.onKeyDown(e.code);
            }
        });

        window.addEventListener('keyup', (e) => {
            if (this.game) {
                this.game.onKeyUp(e.code);
            }
        });

        // Mouse controls:
        let isMouseDown = false;
        window.addEventListener('mousedown', (e) => {
            isMouseDown = true;
            if (this.game && this.game.state === 'PLAYING' && this.game.myRole === 'killer') {
                if (document.pointerLockElement !== document.body) {
                    try {
                        document.body.requestPointerLock();
                    } catch (err) {}
                }
                if (e.button === 0) {
                    this.game.shootGun();
                }
            }
        });

        window.addEventListener('mouseup', () => {
            isMouseDown = false;
        });

        window.addEventListener('mousemove', (e) => {
            if (!this.game) return;
            if (document.pointerLockElement === document.body || isMouseDown) {
                this.game.onMouseMove(e.movementX || 0, e.movementY || 0);
            }
        });
    }

    async _createLobby() {
        const nickname = this.ui.getNickname();
        if (!nickname) {
            this.ui.showMenuError('Wpisz nick!');
            return;
        }

        this.ui.showMenuStatus('Tworzenie pokoju WebRTC...');
        this.ui.btnCreate.disabled = true;

        try {
            const roomCode = await this.network.createLobby(nickname);
            if (!this.game) this._initGame();
            if (this.game) this.game.initLobby();
            this.ui.showScreen('lobby');
            this.ui.setRoomCode(roomCode);
        } catch (err) {
            console.error('Failed to create lobby:', err);
            this.ui.showMenuError('Błąd połączenia: ' + (err.message || err));
        } finally {
            this.ui.btnCreate.disabled = false;
            this.ui.hideMenuStatus();
        }
    }

    async _joinLobby() {
        const nickname = this.ui.getNickname();
        const roomCode = this.ui.getRoomCode();

        if (!nickname) {
            this.ui.showMenuError('Wpisz swój nick!');
            return;
        }
        if (!roomCode || roomCode.length < 4) {
            this.ui.showMenuError('Wpisz poprawny 6-znakowy kod pokoju!');
            return;
        }

        this.ui.showMenuStatus('Łączenie z pokojem ' + roomCode + '...');
        this.ui.btnJoin.disabled = true;

        try {
            await this.network.joinLobby(roomCode, nickname);
            if (!this.game) this._initGame();
            if (this.game) this.game.initLobby();
            this.ui.showScreen('lobby');
            this.ui.setRoomCode(roomCode);
        } catch (err) {
            console.error('Failed to join lobby:', err);
            this.ui.showMenuError(typeof err === 'string' ? err : err.message || 'Nie udało się dołączyć');
        } finally {
            this.ui.btnJoin.disabled = false;
            this.ui.hideMenuStatus();
        }
    }

    _leaveLobby() {
        if (this.game) {
            this.game.destroy();
        }
        this.network.disconnect();
        this.ui.showScreen('menu');
        this._initGame();
    }

    _animate() {
        requestAnimationFrame(() => this._animate());
        const dt = Math.min(this.clock.getDelta(), 0.1);
        if (this.game) {
            this.game.update(dt);

            // Update dynamic player light
            if (this.playerLight && this.game.localPlayer && this.game.localPlayer.alive) {
                this.playerLight.position.set(
                    this.game.localPlayer.position.x,
                    2.5,
                    this.game.localPlayer.position.z
                );
            }

            // Animate ambient arena laser beams
            if (this.arenaLaserBeams && this.arenaLaserBeams.length) {
                const time = this.clock.getElapsedTime();
                this.arenaLaserBeams.forEach(item => {
                    item.mesh.position.z = item.baseZ + Math.sin(time * item.speed) * 4.0;
                });
            }
        }
        if (this.renderer && this.scene && this.camera) {
            this.renderer.render(this.scene, this.camera);
        }
    }
}

// Bootstrap
function bootstrap() {
    console.log('[Bootstrap] Initializing App...');
    try {
        window.app = new App();
    } catch (e) {
        console.error('[Bootstrap] Error creating App:', e);
        const errDiv = document.getElementById('menu-error');
        if (errDiv) {
            errDiv.textContent = 'Błąd inicjalizacji: ' + e.message;
            errDiv.classList.remove('hidden');
        }
    }
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', bootstrap);
} else {
    bootstrap();
}
