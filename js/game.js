// ============================================================
// game.js — Game state machine, round logic, host authority
// ============================================================
import * as THREE from '../lib/three.module.js';
import { Player } from './player.js';

// Game states
export const GameState = {
    LOBBY: 'LOBBY',
    COUNTDOWN: 'COUNTDOWN',
    PLAYING: 'PLAYING',
    RESULTS: 'RESULTS'
};

// Kill distance threshold
const KILL_DISTANCE = 1.6;
const ROUND_TIME = 60; // seconds
const COUNTDOWN_TIME = 3;
const RESULT_TIME = 5;

// Spawn positions across the large 50x50 arena
const SPAWN_POSITIONS = [
    { x: -18, z: -18 },
    { x:  18, z: -18 },
    { x: -18, z:  18 },
    { x:  18, z:  18 },
    { x:   0, z: -18 },
    { x:   0, z:  18 },
    { x: -18, z:   0 },
    { x:  18, z:   0 },
];

export class Game {
    constructor(network, ui, scene) {
        this.network = network;
        this.ui = ui;
        this.scene = scene;

        this.state = GameState.LOBBY;
        this.players = new Map(); // id -> Player
        this.playerInfos = [];    // [{id, name}] lobby player list
        this.localPlayer = null;
        this.myRole = 'pierog';    // 'killer' or 'pierog'
        this.killerId = null;

        this.roundTimer = ROUND_TIME;
        this.countdownTimer = COUNTDOWN_TIME;
        this.resultTimer = RESULT_TIME;
        this.totalPierogi = 0;
        this.alivePierogi = 0;

        // Textures (loaded externally)
        this.textureKiller = null;
        this.texturePierog = null;
        this.textureDead = null;

        // Input
        this.keys = {};

        // Camera ref (set from main.js)
        this.camera = null;
        this.cameraOffset = { x: 0, y: 14, z: 10 };

        // Fortnite TPP Camera for Olafo Killer
        this.tppYaw = 0;
        this.tppPitch = 0.08;
        this.tppDistance = 3.2;
        this.tppShoulder = 0.55; // over-the-shoulder offset
        this.tppHeight = 1.8;

        // Pierog Twarog Skill [E]
        this.twarogPuddles = [];
        this.twarogCooldown = 0;
        this.TWAROG_COOLDOWN_TIME = 5.0;
        this._twarogTexture = null;

        // Network tick timer
        this.netTickTimer = 0;
        this.netTickInterval = 1 / 20; // 20 Hz

        // Spectator camera
        this.isSpectating = false;
        this.spectatorYaw = 0;
        this.spectatorPitch = -0.5;
        this.spectatorPos = { x: 0, y: 10, z: 0 };

        // Line-of-sight & wall occlusion
        this.wallMeshes = [];
        this.raycaster = new THREE.Raycaster();

        this._setupNetworkHandlers();
    }

    setObstacleMeshes(meshes) {
        this.wallMeshes = meshes || [];
    }

    setTextures(killer, pierog, dead) {
        this.textureKiller = killer;
        this.texturePierog = pierog;
        this.textureDead = dead;
    }

    setCamera(camera) {
        this.camera = camera;
        // Properly initialize cameraOffset as a simple object
        this.cameraOffset = { x: 0, y: 10, z: 8 };
    }

    // === NETWORK HANDLERS ===

    _setupNetworkHandlers() {
        // Player joined (host only)
        this.network.onPlayerJoined = (peerId, name) => {
            this._addPlayerInfo(peerId, name);
            this._broadcastLobbyState();
        };

        // Player left
        this.network.onPlayerLeft = (peerId) => {
            this._removePlayerInfo(peerId);
            if (this.state === GameState.PLAYING || this.state === GameState.COUNTDOWN) {
                this._removeGamePlayer(peerId);
            }
            this._broadcastLobbyState();
        };

        // Game messages
        this.network.onGameMessage = (type, data, fromId) => {
            this._handleMessage(type, data, fromId);
        };

        // Disconnected (client lost connection to host)
        this.network.onDisconnected = () => {
            this._cleanupGame();
            this.ui.showScreen('menu');
            this.ui.showMenuError('Połączenie z hostem zostało utracone');
        };
    }

    _handleMessage(type, data, fromId) {
        switch (type) {
            case 'lobby-state':
                // Client receives lobby state from host
                this.playerInfos = data.players;
                this.ui.updatePlayerList(this.playerInfos, 'olafo-' + this.network.roomCode);
                break;

            case 'start-countdown':
                // Both host and clients
                this._startCountdown(data);
                break;

            case 'start-round':
                // Round actually starts
                this._onRoundStart(data);
                break;

            case 'player-input':
                // Host receives input from a client
                if (this.network.isHost && this.state === GameState.PLAYING) {
                    const player = this.players.get(fromId);
                    if (player && player.alive) {
                        player.setTargetPosition(data.x, data.z);
                        // Also directly set for server-side position tracking
                        player.position.x = data.x;
                        player.position.z = data.z;
                    }
                }
                break;

            case 'game-state':
                // Client receives authoritative game state from host
                if (!this.network.isHost && this.state === GameState.PLAYING) {
                    this._applyGameState(data);
                }
                break;

            case 'player-killed':
                // A player was killed
                this._onPlayerKilled(data.victimId, data.killerName, data.victimName);
                break;

            case 'twarog-spawn':
                // Someone spawned a twarog puddle on the ground
                this._createTwarogMesh(data.id, data.x, data.z, data.radius, data.duration);
                if (this.network.isHost) {
                    this.network.broadcast('twarog-spawn', data);
                }
                break;

            case 'round-end':
                // Round ended
                this._onRoundEnd(data);
                break;
        }
    }

    // === LOBBY MANAGEMENT ===

    _addPlayerInfo(peerId, name) {
        // Don't add duplicates
        if (!this.playerInfos.find(p => p.id === peerId)) {
            this.playerInfos.push({ id: peerId, name: name });
        }
    }

    _removePlayerInfo(peerId) {
        this.playerInfos = this.playerInfos.filter(p => p.id !== peerId);
    }

    _broadcastLobbyState() {
        // Include host in the list
        const allPlayers = [
            { id: this.network.myId, name: this.network.myName },
            ...this.playerInfos
        ];
        this.network.broadcast('lobby-state', { players: allPlayers });

        // Update local UI
        this.ui.updatePlayerList(allPlayers, this.network.myId);
        this.ui.showStartButton(this.network.isHost);
    }

    initLobby() {
        this.state = GameState.LOBBY;
        this.playerInfos = [];

        if (this.network.isHost) {
            // Host is the first player
            this.ui.setRoomCode(this.network.roomCode);
            this._broadcastLobbyState();
        }
    }

    // === ROUND START ===

    startRound() {
        if (!this.network.isHost) return;

        const allPlayers = [
            { id: this.network.myId, name: this.network.myName },
            ...this.playerInfos
        ];

        if (allPlayers.length < 1) return;

        // Randomly pick a killer
        const killerIndex = Math.floor(Math.random() * allPlayers.length);
        const killerInfo = allPlayers[killerIndex];

        // Assign spawn positions
        const assignments = allPlayers.map((p, i) => ({
            id: p.id,
            name: p.name,
            isKiller: p.id === killerInfo.id,
            spawnX: SPAWN_POSITIONS[i % SPAWN_POSITIONS.length].x,
            spawnZ: SPAWN_POSITIONS[i % SPAWN_POSITIONS.length].z
        }));

        const startData = {
            assignments,
            killerId: killerInfo.id,
            roundTime: ROUND_TIME
        };

        // Start countdown for all
        this.network.broadcast('start-countdown', startData);
        // Also start locally
        this._startCountdown(startData);
    }

    _startCountdown(data) {
        this.state = GameState.COUNTDOWN;
        this.countdownTimer = COUNTDOWN_TIME;
        this._roundData = data;

        // Show game screen
        this.ui.showScreen('game');
        this.ui.hideHUD();

        // Create player objects
        this._createPlayers(data.assignments);

        // Show countdown
        this.ui.showCountdown(3);
    }

    _createPlayers(assignments) {
        // Clear existing
        this.players.forEach(p => p.destroy());
        this.players.clear();
        this.localPlayer = null;
        this.isSpectating = false;

        for (const a of assignments) {
            const isLocal = (a.id === this.network.myId);
            const player = new Player(
                a.id, a.name, a.isKiller,
                this.scene,
                this.textureKiller, this.texturePierog, this.textureDead
            );
            player.isLocal = isLocal;
            player.setPosition(a.spawnX, a.spawnZ);
            this.players.set(a.id, player);

            if (isLocal) {
                this.localPlayer = player;
                this.myRole = a.isKiller ? 'killer' : 'pierog';
            }

            if (a.isKiller) {
                this.killerId = a.id;
            }
        }

        this.totalPierogi = assignments.filter(a => !a.isKiller).length;
        this.alivePierogi = this.totalPierogi;
    }

    _onRoundStart() {
        this.state = GameState.PLAYING;
        this.roundTimer = ROUND_TIME;

        this.ui.hideCountdown();
        this.ui.showHUD(this.myRole === 'killer');
        this.ui.updateTimer(this.roundTimer);
        this.ui.updateAliveCount(this.alivePierogi, this.totalPierogi);
    }

    // === GAME UPDATE ===

    update(dt) {
        switch (this.state) {
            case GameState.COUNTDOWN:
                this._updateCountdown(dt);
                break;
            case GameState.PLAYING:
                this._updatePlaying(dt);
                this._updateLineOfSight();
                break;
            case GameState.RESULTS:
                this._updateResults(dt);
                break;
        }

        // Update camera
        this._updateCamera(dt);
    }

    // Line-of-sight: Olafo / players cannot see survivors behind walls
    _updateLineOfSight() {
        if (!this.localPlayer || !this.localPlayer.alive || this.isSpectating) {
            this.players.forEach(p => p.setVisible(true));
            return;
        }

        if (!this.wallMeshes || this.wallMeshes.length === 0) return;

        const myPos = this.localPlayer.position;
        const origin = new THREE.Vector3(myPos.x, 1.2, myPos.z);

        this.players.forEach((other) => {
            if (other === this.localPlayer) return;

            const target = new THREE.Vector3(other.position.x, 1.2, other.position.z);
            const dir = new THREE.Vector3().subVectors(target, origin);
            const dist = dir.length();

            // Very close proximity (touching / around 1m)
            if (dist < 1.0) {
                other.setVisible(true);
            } else {
                dir.normalize();
                this.raycaster.set(origin, dir);
                this.raycaster.far = dist;

                const intersects = this.raycaster.intersectObjects(this.wallMeshes, false);
                if (intersects.length > 0 && intersects[0].distance < (dist - 0.3)) {
                    // Wall occludes the player
                    other.setVisible(false);
                } else {
                    // Direct line of sight
                    other.setVisible(true);
                }
            }
        });
    }

    _updateCountdown(dt) {
        this.countdownTimer -= dt;

        const num = Math.ceil(this.countdownTimer);
        if (num > 0) {
            this.ui.showCountdown(num);
        }

        if (this.countdownTimer <= 0) {
            // Start the round
            if (this.network.isHost) {
                this.network.broadcast('start-round', {});
            }
            this._onRoundStart();
        }
    }

    _updatePlaying(dt) {
        // Update local player
        if (this.localPlayer && this.localPlayer.alive) {
            // Pass tppYaw for Olafo so WASD moves in Fortnite camera direction
            this.localPlayer.updateLocal(dt, this.keys, this.myRole === 'killer' ? this.tppYaw : null);

            // Update stamina UI
            if (this.myRole === 'pierog') {
                this.ui.updateStamina(this.localPlayer.stamina);
            }
        }

        // Update twarog skill cooldown
        if (this.twarogCooldown > 0) {
            this.twarogCooldown -= dt;
            if (this.twarogCooldown < 0) this.twarogCooldown = 0;
        }
        if (this.myRole === 'pierog') {
            this.ui.updateTwarogCooldown(this.twarogCooldown, this.TWAROG_COOLDOWN_TIME);
        }

        // Update twarog puddles and check slowdown on Olafo Killer
        this._updateTwarogPuddles(dt);

        // Update remote players (interpolation)
        this.players.forEach((player) => {
            if (!player.isLocal) {
                player.updateRemote(dt);
            }
        });

        // Network tick — send position or check kills
        this.netTickTimer += dt;
        if (this.netTickTimer >= this.netTickInterval) {
            this.netTickTimer = 0;

            if (this.network.isHost) {
                // Host: check kills and broadcast state
                this._hostCheckKills();
                this._hostBroadcastState();
            } else {
                // Client: send input to host
                if (this.localPlayer && this.localPlayer.alive) {
                    const pos = this.localPlayer.getNetPosition();
                    this.network.sendToHost('player-input', pos);
                }
            }
        }

        // Update round timer (host authoritative)
        if (this.network.isHost) {
            this.roundTimer -= dt;
            this.ui.updateTimer(this.roundTimer);

            if (this.roundTimer <= 0) {
                // Time's up — Pierogi win!
                this._endRound('pierogi');
            }
        }
    }

    // === TWAROG MECHANIC ===

    spawnTwarog(x, z) {
        const id = 'twarog_' + Math.random().toString(36).substring(2, 9);
        const radius = 2.4;
        const duration = 12.0;

        this._createTwarogMesh(id, x, z, radius, duration);

        const payload = { id, x, z, radius, duration };
        if (this.network.isHost) {
            this.network.broadcast('twarog-spawn', payload);
        } else {
            this.network.sendToHost('twarog-spawn', payload);
        }
    }

    _createTwarogMesh(id, x, z, radius, duration) {
        // Prevent duplicate creation
        if (this.twarogPuddles.find(p => p.id === id)) return;

        const tex = this._getTwarogTexture();
        const geo = new THREE.PlaneGeometry(radius * 2, radius * 2);
        const mat = new THREE.MeshStandardMaterial({
            map: tex,
            transparent: true,
            opacity: 0.95,
            roughness: 0.9,
            metalness: 0.05,
            depthWrite: false
        });

        const mesh = new THREE.Mesh(geo, mat);
        mesh.rotation.x = -Math.PI / 2;
        mesh.rotation.z = Math.random() * Math.PI * 2; // random rotation
        mesh.position.set(x, 0.025, z); // slightly above ground to prevent z-fighting
        mesh.receiveShadow = true;
        this.scene.add(mesh);

        this.twarogPuddles.push({
            id,
            mesh,
            x,
            z,
            radius,
            life: duration,
            maxLife: duration
        });
    }

    _getTwarogTexture() {
        if (this._twarogTexture) return this._twarogTexture;

        const canvas = document.createElement('canvas');
        canvas.width = 256;
        canvas.height = 256;
        const ctx = canvas.getContext('2d');

        ctx.clearRect(0, 0, 256, 256);

        // Radial gradient base
        const grad = ctx.createRadialGradient(128, 128, 15, 128, 128, 115);
        grad.addColorStop(0, 'rgba(255, 255, 255, 0.98)');
        grad.addColorStop(0.65, 'rgba(250, 250, 245, 0.92)');
        grad.addColorStop(0.85, 'rgba(240, 240, 230, 0.55)');
        grad.addColorStop(1, 'rgba(240, 240, 230, 0)');

        ctx.fillStyle = grad;
        ctx.beginPath();
        const points = 16;
        for (let i = 0; i < points; i++) {
            const angle = (i / points) * Math.PI * 2;
            const r = 90 + Math.sin(angle * 4 + 1) * 14 + Math.cos(angle * 2) * 8;
            const px = 128 + Math.cos(angle) * r;
            const py = 128 + Math.sin(angle) * r;
            if (i === 0) ctx.moveTo(px, py);
            else ctx.lineTo(px, py);
        }
        ctx.closePath();
        ctx.fill();

        // Twarog curds / lumps (organic dots)
        for (let j = 0; j < 55; j++) {
            const angle = Math.random() * Math.PI * 2;
            const dist = Math.random() * 75;
            const cx = 128 + Math.cos(angle) * dist;
            const cy = 128 + Math.sin(angle) * dist;
            const cr = 2.5 + Math.random() * 4.5;

            ctx.fillStyle = (j % 2 === 0) ? '#ffffff' : '#f7f5e4';
            ctx.beginPath();
            ctx.arc(cx, cy, cr, 0, Math.PI * 2);
            ctx.fill();
        }

        const tex = new THREE.CanvasTexture(canvas);
        tex.colorSpace = THREE.SRGBColorSpace;
        this._twarogTexture = tex;
        return tex;
    }

    _updateTwarogPuddles(dt) {
        if (!this.twarogPuddles.length) {
            const killer = this.players.get(this.killerId);
            if (killer) killer.isSlowed = false;
            if (this.myRole === 'killer') this.ui.showSlowedBanner(false);
            return;
        }

        // 1. Age and fade puddles
        for (let i = this.twarogPuddles.length - 1; i >= 0; i--) {
            const p = this.twarogPuddles[i];
            p.life -= dt;

            // Fade out in last 2 seconds
            if (p.life < 2.0) {
                p.mesh.material.opacity = Math.max(0, (p.life / 2.0) * 0.95);
            }

            if (p.life <= 0) {
                this.scene.remove(p.mesh);
                this.twarogPuddles.splice(i, 1);
            }
        }

        // 2. Check collision with Olafo Killer
        const killer = this.players.get(this.killerId);
        if (killer && killer.alive) {
            let isSlowed = false;
            for (const p of this.twarogPuddles) {
                const dist = Math.hypot(killer.position.x - p.x, killer.position.z - p.z);
                if (dist < p.radius) {
                    isSlowed = true;
                    break;
                }
            }

            killer.isSlowed = isSlowed;
            if (this.myRole === 'killer') {
                this.ui.showSlowedBanner(isSlowed);
            }
        }
    }

    _hostCheckKills() {
        const killer = this.players.get(this.killerId);
        if (!killer || !killer.alive) return;

        this.players.forEach((player) => {
            if (player.id === this.killerId) return;
            if (!player.alive) return;

            const dx = killer.position.x - player.position.x;
            const dz = killer.position.z - player.position.z;
            const dist = Math.sqrt(dx * dx + dz * dz);

            if (dist < KILL_DISTANCE) {
                // Kill!
                const killerName = killer.name;
                const victimName = player.name;

                player.kill();
                this.alivePierogi--;

                // Broadcast kill event
                this.network.broadcast('player-killed', {
                    victimId: player.id,
                    killerName,
                    victimName
                });

                // Also handle locally
                this._onPlayerKilled(player.id, killerName, victimName);

                // Check if all pierogi are dead
                if (this.alivePierogi <= 0) {
                    this._endRound('killer');
                }
            }
        });
    }

    _hostBroadcastState() {
        const playerStates = {};
        this.players.forEach((player, id) => {
            playerStates[id] = {
                x: player.position.x,
                z: player.position.z,
                alive: player.alive
            };
        });

        this.network.broadcast('game-state', {
            players: playerStates,
            timer: this.roundTimer,
            alivePierogi: this.alivePierogi
        });
    }

    _applyGameState(data) {
        // Apply positions from host
        for (const [id, state] of Object.entries(data.players)) {
            const player = this.players.get(id);
            if (player) {
                if (!player.isLocal) {
                    player.setTargetPosition(state.x, state.z);
                }
                if (!state.alive && player.alive) {
                    player.kill();
                }
            }
        }

        // Update timer and alive count
        this.roundTimer = data.timer;
        this.alivePierogi = data.alivePierogi;
        this.ui.updateTimer(this.roundTimer);
        this.ui.updateAliveCount(this.alivePierogi, this.totalPierogi);
    }

    _onPlayerKilled(victimId, killerName, victimName) {
        const victim = this.players.get(victimId);
        if (victim && victim.alive) {
            victim.kill();
        }

        this.ui.addKillFeedEntry(killerName, victimName);

        // If I was killed
        if (victimId === this.network.myId) {
            this.ui.triggerRedFlash();
            this.isSpectating = true;
            this.ui.showSpectator();

            // Set spectator camera position
            if (this.localPlayer) {
                this.spectatorPos.x = this.localPlayer.position.x;
                this.spectatorPos.z = this.localPlayer.position.z;
                this.spectatorPos.y = 8;
            }
        }

        this.alivePierogi = 0;
        this.players.forEach(p => {
            if (p.id !== this.killerId && p.alive) this.alivePierogi++;
        });
        this.ui.updateAliveCount(this.alivePierogi, this.totalPierogi);
    }

    _endRound(winner) {
        if (this.state !== GameState.PLAYING) return;
        this.state = GameState.RESULTS;
        this.resultTimer = RESULT_TIME;

        const data = {
            winner,
            roundTime: ROUND_TIME - this.roundTimer,
            alivePierogi: this.alivePierogi,
            totalPierogi: this.totalPierogi
        };

        if (this.network.isHost) {
            this.network.broadcast('round-end', data);
        }
        this._showResults(data);
    }

    _onRoundEnd(data) {
        if (this.state === GameState.RESULTS) return;
        this.state = GameState.RESULTS;
        this.resultTimer = RESULT_TIME;
        this._showResults(data);
    }

    _showResults(data) {
        let title, subtitle, titleColor;

        if (data.winner === 'killer') {
            title = '🔪 OLAFO KILLER WYGRYWA!';
            subtitle = 'Wszystkie pierogi zostały złapane!';
            titleColor = '#ff4444';
        } else {
            title = '🥟 PIEROGI WYGRYWAJĄ!';
            subtitle = 'Pierogi przetrwały cały czas!';
            titleColor = '#ffcc00';
        }

        const stats = `
            <p>Czas rundy: ${Math.floor(data.roundTime)}s</p>
            <p>Pierogi, które przeżyły: ${data.alivePierogi}/${data.totalPierogi}</p>
        `;

        this.ui.showResults(title, subtitle, stats, titleColor);
    }

    _updateResults(dt) {
        this.resultTimer -= dt;
        if (this.resultTimer <= 0) {
            // Return to lobby
            this._cleanupGame();
            this.ui.hideResults();
            this.ui.hideHUD();
            this.ui.showScreen('lobby');
            this.state = GameState.LOBBY;

            if (this.network.isHost) {
                this._broadcastLobbyState();
            }
        }
    }

    // === CAMERA ===

    _updateCamera(dt) {
        if (!this.camera) return;

        if (this.isSpectating) {
            // Free camera for spectators
            const speed = 12;
            if (this.keys['KeyW'] || this.keys['ArrowUp']) {
                this.spectatorPos.x -= Math.sin(this.spectatorYaw) * speed * dt;
                this.spectatorPos.z -= Math.cos(this.spectatorYaw) * speed * dt;
            }
            if (this.keys['KeyS'] || this.keys['ArrowDown']) {
                this.spectatorPos.x += Math.sin(this.spectatorYaw) * speed * dt;
                this.spectatorPos.z += Math.cos(this.spectatorYaw) * speed * dt;
            }
            if (this.keys['KeyA'] || this.keys['ArrowLeft']) {
                this.spectatorYaw += 2 * dt;
            }
            if (this.keys['KeyD'] || this.keys['ArrowRight']) {
                this.spectatorYaw -= 2 * dt;
            }

            this.camera.position.set(
                this.spectatorPos.x,
                this.spectatorPos.y,
                this.spectatorPos.z
            );
            this.camera.lookAt(
                this.spectatorPos.x - Math.sin(this.spectatorYaw) * 5,
                0,
                this.spectatorPos.z - Math.cos(this.spectatorYaw) * 5
            );
        } else if (this.localPlayer) {
            if (this.myRole === 'killer') {
                // Fortnite Over-The-Shoulder TPP Camera for Olafo Killer
                const cosP = Math.cos(this.tppPitch);
                const sinP = Math.sin(this.tppPitch);
                const sinY = Math.sin(this.tppYaw);
                const cosY = Math.cos(this.tppYaw);

                const camX = this.localPlayer.position.x - sinY * (this.tppDistance * cosP) + cosY * this.tppShoulder;
                const camY = this.localPlayer.position.y + this.tppHeight + sinP * this.tppDistance;
                const camZ = this.localPlayer.position.z - cosY * (this.tppDistance * cosP) - sinY * this.tppShoulder;

                this.camera.position.set(camX, camY, camZ);

                // Aim target 25 units ahead
                const lookDist = 25;
                const targetX = this.localPlayer.position.x + sinY * (lookDist * cosP);
                const targetY = this.localPlayer.position.y + this.tppHeight - sinP * lookDist;
                const targetZ = this.localPlayer.position.z + cosY * (lookDist * cosP);

                this.camera.lookAt(targetX, targetY, targetZ);
            } else {
                // Pieróg: Classic Top-Down / Isometric camera unchanged
                const targetX = this.localPlayer.position.x + this.cameraOffset.x;
                const targetY = this.cameraOffset.y;
                const targetZ = this.localPlayer.position.z + this.cameraOffset.z;

                const smoothing = 6;
                this.camera.position.x += (targetX - this.camera.position.x) * Math.min(smoothing * dt, 1);
                this.camera.position.y += (targetY - this.camera.position.y) * Math.min(smoothing * dt, 1);
                this.camera.position.z += (targetZ - this.camera.position.z) * Math.min(smoothing * dt, 1);

                this.camera.lookAt(
                    this.localPlayer.position.x,
                    0,
                    this.localPlayer.position.z
                );
            }
        }
    }

    // === INPUT ===

    onMouseMove(movementX, movementY) {
        if (this.state === GameState.PLAYING && this.myRole === 'killer' && this.localPlayer && this.localPlayer.alive) {
            this.tppYaw -= movementX * 0.003;
            this.tppPitch -= movementY * 0.003;
            // Clamp pitch (cannot look fully up or fully down)
            this.tppPitch = Math.max(-0.45, Math.min(0.65, this.tppPitch));
        }
    }

    onKeyDown(code) {
        this.keys[code] = true;

        // Pieróg paints twaróg puddle with 'E'
        if (code === 'KeyE') {
            if (this.myRole === 'pierog' && this.localPlayer && this.localPlayer.alive && this.state === GameState.PLAYING) {
                if (this.twarogCooldown <= 0) {
                    this.spawnTwarog(this.localPlayer.position.x, this.localPlayer.position.z);
                    this.twarogCooldown = this.TWAROG_COOLDOWN_TIME;
                }
            }
        }
    }

    onKeyUp(code) {
        this.keys[code] = false;
    }

    // === CLEANUP ===

    destroy() {
        this._cleanupGame();
    }

    _cleanupGame() {
        this.players.forEach(p => p.destroy());
        this.players.clear();
        this.localPlayer = null;
        this.isSpectating = false;

        // Clean all twarog puddles
        this.twarogPuddles.forEach(p => {
            if (p.mesh && p.mesh.parent) {
                p.mesh.parent.remove(p.mesh);
            }
        });
        this.twarogPuddles = [];
        this.twarogCooldown = 0;
        this.ui.showSlowedBanner(false);
    }

    _removeGamePlayer(peerId) {
        const player = this.players.get(peerId);
        if (player) {
            player.destroy();
            this.players.delete(peerId);

            if (!player.isKiller && player.alive) {
                this.alivePierogi--;
                this.ui.updateAliveCount(this.alivePierogi, this.totalPierogi);

                // If this was the last pierog
                if (this.network.isHost && this.alivePierogi <= 0) {
                    this._endRound('killer');
                }
            }
        }
    }
}
