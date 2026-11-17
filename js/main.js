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
        this.scene.background = new THREE.Color(0x121324);
        this.scene.fog = new THREE.FogExp2(0x121324, 0.015);

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

        // Ambient Light (atmospheric, dark so shadows look prominent!)
        const ambient = new THREE.AmbientLight(0xffffff, 0.45);
        this.scene.add(ambient);

        // Sun / Main Shadow Casting Directional Light
        const dirLight = new THREE.DirectionalLight(0xffedd4, 1.1);
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

        // Secondary rim/fill light (cool blue accent)
        const fillLight = new THREE.DirectionalLight(0x3a5585, 0.35);
        fillLight.position.set(-25, 20, -25);
        this.scene.add(fillLight);

        // Dynamic light following the player
        this.playerLight = new THREE.PointLight(0xffeedd, 1.2, 18, 1.5);
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

        // Ground floor
        const floorGeo = new THREE.PlaneGeometry(arenaSize, arenaSize);
        const floorMat = new THREE.MeshStandardMaterial({
            color: 0x182c20, // dark moss green
            roughness: 0.85,
            metalness: 0.05
        });
        const floor = new THREE.Mesh(floorGeo, floorMat);
        floor.rotation.x = -Math.PI / 2;
        floor.receiveShadow = true;
        this.scene.add(floor);

        // Grid lines across the large floor
        const grid = new THREE.GridHelper(arenaSize, 50, 0xe94560, 0x223d2e);
        grid.position.y = 0.01;
        this.scene.add(grid);

        // Outer Boundary Walls
        const outerWallMat = new THREE.MeshStandardMaterial({
            color: 0x0c2540,
            roughness: 0.5,
            metalness: 0.3
        });
        const wallHeight = 3.5;
        const wallThickness = 1.0;
        const offset = ARENA_HALF + (wallThickness / 2);

        this._createWall(arenaSize + wallThickness * 2, wallHeight, wallThickness, 0, wallHeight / 2, -offset, outerWallMat);
        this._createWall(arenaSize + wallThickness * 2, wallHeight, wallThickness, 0, wallHeight / 2, offset, outerWallMat);
        this._createWall(wallThickness, wallHeight, arenaSize, -offset, wallHeight / 2, 0, outerWallMat);
        this._createWall(wallThickness, wallHeight, arenaSize, offset, wallHeight / 2, 0, outerWallMat);

        // Inner Obstacles & Walls (maze/rooms)
        const obsMatA = new THREE.MeshStandardMaterial({
            color: 0x3d2459, // deep purple
            roughness: 0.45,
            metalness: 0.2
        });
        const obsMatB = new THREE.MeshStandardMaterial({
            color: 0x1f3c58, // deep navy
            roughness: 0.45,
            metalness: 0.2
        });
        const trimMat = new THREE.MeshBasicMaterial({ color: 0xffcc00 });

        OBSTACLES.forEach((obs, index) => {
            const h = 3.2; // Taller than players (2.0) to cast shadows and fully block sight
            const geo = new THREE.BoxGeometry(obs.w, h, obs.d);
            const mat = (index % 2 === 0) ? obsMatA : obsMatB;
            const mesh = new THREE.Mesh(geo, mat);
            mesh.position.set(obs.x, h / 2, obs.z);
            mesh.castShadow = true;
            mesh.receiveShadow = true;
            this.scene.add(mesh);
            this.wallMeshes.push(mesh);

            // Styling cap on top of walls
            const capGeo = new THREE.BoxGeometry(obs.w * 0.95, 0.1, obs.d * 0.95);
            const cap = new THREE.Mesh(capGeo, trimMat);
            cap.position.set(obs.x, h + 0.05, obs.z);
            this.scene.add(cap);
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

        // Mouse controls for Olafo Fortnite TPP camera
        const canvasContainer = document.getElementById('game-canvas-container');
        let isMouseDown = false;

        window.addEventListener('mousedown', (e) => {
            isMouseDown = true;
            // Lock pointer when playing as Olafo Killer for full Fortnite mouse feel
            if (this.game && this.game.state === 'PLAYING' && this.game.myRole === 'killer') {
                if (document.pointerLockElement !== document.body) {
                    try {
                        document.body.requestPointerLock();
                    } catch (err) {}
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
