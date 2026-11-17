// ============================================================
// player.js — Player class with billboard sprites, movement
// ============================================================
import * as THREE from '../lib/three.module.js';

// Arena boundaries (50x50 arena, walls at ±25)
export const ARENA_HALF = 24.2;

// Obstacles & walls placed across the large arena
export const OBSTACLES = [
    // Central pillars
    { x: -3.5, z: -3.5, w: 2.5, d: 2.5 },
    { x:  3.5, z: -3.5, w: 2.5, d: 2.5 },
    { x: -3.5, z:  3.5, w: 2.5, d: 2.5 },
    { x:  3.5, z:  3.5, w: 2.5, d: 2.5 },

    // Central cross barriers
    { x: 0, z: -11, w: 7, d: 1.5 },
    { x: 0, z:  11, w: 7, d: 1.5 },
    { x: -11, z: 0, w: 1.5, d: 7 },
    { x:  11, z: 0, w: 1.5, d: 7 },

    // North-West Zone
    { x: -14, z: -15, w: 12, d: 1.5 },
    { x: -18, z: -8,  w: 1.5, d: 10 },
    { x: -8,  z: -6,  w: 1.5, d: 6 },
    { x: -14, z: -4,  w: 2.5, d: 2.5 },
    { x: -20, z: -18, w: 3,   d: 3 },

    // North-East Zone
    { x:  14, z: -15, w: 12, d: 1.5 },
    { x:  18, z: -8,  w: 1.5, d: 10 },
    { x:  8,  z: -6,  w: 1.5, d: 6 },
    { x:  14, z: -4,  w: 2.5, d: 2.5 },
    { x:  20, z: -18, w: 3,   d: 3 },

    // South-West Zone
    { x: -14, z:  15, w: 12, d: 1.5 },
    { x: -18, z:  8,  w: 1.5, d: 10 },
    { x: -8,  z:  6,  w: 1.5, d: 6 },
    { x: -14, z:  4,  w: 2.5, d: 2.5 },
    { x: -20, z:  18, w: 3,   d: 3 },

    // South-East Zone
    { x:  14, z:  15, w: 12, d: 1.5 },
    { x:  18, z:  8,  w: 1.5, d: 10 },
    { x:  8,  z:  6,  w: 1.5, d: 6 },
    { x:  14, z:  4,  w: 2.5, d: 2.5 },
    { x:  20, z:  18, w: 3,   d: 3 },

    // Outer corner hiding spots
    { x: -7,  z: -20, w: 4, d: 1.5 },
    { x:  7,  z: -20, w: 4, d: 1.5 },
    { x: -7,  z:  20, w: 4, d: 1.5 },
    { x:  7,  z:  20, w: 4, d: 1.5 }
];

export class Player {
    constructor(id, name, isKiller, scene, textureKiller, texturePierog, textureDead) {
        this.id = id;
        this.name = name;
        this.isKiller = isKiller;
        this.alive = true;
        this.scene = scene;

        // Position & movement
        this.position = new THREE.Vector3(0, 0, 0);
        this.velocity = new THREE.Vector3(0, 0, 0);
        this.targetPosition = new THREE.Vector3(0, 0, 0); // for interpolation (remote players)
        this.isLocal = false;

        // Speed
        this.baseSpeed = isKiller ? 8.5 : 6.0;
        this.sprintMultiplier = 1.6;
        this.stamina = 1.0;
        this.maxStamina = 1.0;
        this.staminaDrain = 0.3;   // per second
        this.staminaRegen = 0.15;  // per second
        this.isSprinting = false;

        // Store textures
        this.textureKiller = textureKiller;
        this.texturePierog = texturePierog;
        this.textureDead = textureDead;

        // Create billboard sprite
        this._createSprite();

        // Name label
        this._createNameLabel();

        // Killer glow
        if (isKiller) {
            this._createKillerAura();
        }
    }

    _createSprite() {
        const texture = this.isKiller ? this.textureKiller : this.texturePierog;
        const material = new THREE.SpriteMaterial({
            map: texture,
            transparent: true,
            alphaTest: 0.1
        });
        this.sprite = new THREE.Sprite(material);

        // Calculate aspect ratio from texture
        const img = texture.image;
        const aspect = img ? img.width / img.height : 1;
        const height = 2.0;
        this.sprite.scale.set(height * aspect, height, 1);
        this.sprite.position.y = height / 2;

        this.group = new THREE.Group();
        this.group.add(this.sprite);
        this.scene.add(this.group);
    }

    _createNameLabel() {
        const canvas = document.createElement('canvas');
        canvas.width = 256;
        canvas.height = 64;
        const ctx = canvas.getContext('2d');

        ctx.font = 'bold 28px Poppins, sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';

        // Background
        ctx.fillStyle = 'rgba(0,0,0,0.5)';
        const textWidth = ctx.measureText(this.name).width;
        ctx.roundRect(128 - textWidth/2 - 10, 10, textWidth + 20, 44, 8);
        ctx.fill();

        // Text
        ctx.fillStyle = this.isKiller ? '#ff4444' : '#ffcc00';
        ctx.fillText(this.name, 128, 32);

        const texture = new THREE.CanvasTexture(canvas);
        const material = new THREE.SpriteMaterial({ map: texture, transparent: true });
        this.nameSprite = new THREE.Sprite(material);
        this.nameSprite.scale.set(3, 0.75, 1);
        this.nameSprite.position.y = 2.6;
        this.group.add(this.nameSprite);
    }

    _createKillerAura() {
        const geometry = new THREE.RingGeometry(0.8, 1.2, 32);
        const material = new THREE.MeshBasicMaterial({
            color: 0xff0000,
            transparent: true,
            opacity: 0.3,
            side: THREE.DoubleSide
        });
        this.aura = new THREE.Mesh(geometry, material);
        this.aura.rotation.x = -Math.PI / 2;
        this.aura.position.y = 0.05;
        this.group.add(this.aura);
    }

    // Set spawn position
    setPosition(x, z) {
        this.position.set(x, 0, z);
        this.targetPosition.set(x, 0, z);
        this.group.position.set(x, 0, z);
    }

    // Update movement for local player
    updateLocal(dt, keys) {
        if (!this.alive) return;

        // Direction from input
        let dx = 0, dz = 0;
        if (keys['KeyW'] || keys['ArrowUp']) dz = -1;
        if (keys['KeyS'] || keys['ArrowDown']) dz = 1;
        if (keys['KeyA'] || keys['ArrowLeft']) dx = -1;
        if (keys['KeyD'] || keys['ArrowRight']) dx = 1;

        // Normalize diagonal movement
        const len = Math.sqrt(dx * dx + dz * dz);
        if (len > 0) { dx /= len; dz /= len; }

        // Sprint
        this.isSprinting = keys['ShiftLeft'] || keys['ShiftRight'];
        let speed = this.baseSpeed;

        if (this.isKiller) {
            // Killer always sprints
            if (this.isSprinting) speed *= this.sprintMultiplier;
        } else {
            // Pierog has limited stamina
            if (this.isSprinting && this.stamina > 0 && len > 0) {
                speed *= this.sprintMultiplier;
                this.stamina -= this.staminaDrain * dt;
                if (this.stamina < 0) this.stamina = 0;
            } else {
                this.isSprinting = false;
                this.stamina += this.staminaRegen * dt;
                if (this.stamina > this.maxStamina) this.stamina = this.maxStamina;
            }
        }

        // Apply velocity with smoothing
        const targetVX = dx * speed;
        const targetVZ = dz * speed;
        const smoothing = 10;
        this.velocity.x += (targetVX - this.velocity.x) * Math.min(smoothing * dt, 1);
        this.velocity.z += (targetVZ - this.velocity.z) * Math.min(smoothing * dt, 1);

        // Move
        this.position.x += this.velocity.x * dt;
        this.position.z += this.velocity.z * dt;

        // Collide with arena walls
        this.position.x = Math.max(-ARENA_HALF, Math.min(ARENA_HALF, this.position.x));
        this.position.z = Math.max(-ARENA_HALF, Math.min(ARENA_HALF, this.position.z));

        // Collide with obstacles
        this._collideWithObstacles();

        // Update group position
        this.group.position.set(this.position.x, 0, this.position.z);
    }

    // Update for remote players (interpolation)
    updateRemote(dt) {
        const lerpSpeed = 10;
        this.position.x += (this.targetPosition.x - this.position.x) * Math.min(lerpSpeed * dt, 1);
        this.position.z += (this.targetPosition.z - this.position.z) * Math.min(lerpSpeed * dt, 1);
        this.group.position.set(this.position.x, 0, this.position.z);
    }

    // Set target for remote interpolation
    setTargetPosition(x, z) {
        this.targetPosition.set(x, 0, z);
    }

    // Obstacle collision (AABB)
    _collideWithObstacles() {
        const playerRadius = 0.4;

        for (const obs of OBSTACLES) {
            const halfW = obs.w / 2 + playerRadius;
            const halfD = obs.d / 2 + playerRadius;

            const relX = this.position.x - obs.x;
            const relZ = this.position.z - obs.z;

            if (Math.abs(relX) < halfW && Math.abs(relZ) < halfD) {
                // Find the smallest overlap axis
                const overlapX = halfW - Math.abs(relX);
                const overlapZ = halfD - Math.abs(relZ);

                if (overlapX < overlapZ) {
                    this.position.x = obs.x + Math.sign(relX) * halfW;
                } else {
                    this.position.z = obs.z + Math.sign(relZ) * halfD;
                }
            }
        }
    }

    // Kill this player
    kill() {
        this.alive = false;
        // Switch to dead sprite
        if (this.textureDead) {
            this.sprite.material.map = this.textureDead;
            this.sprite.material.needsUpdate = true;
            if (this.textureDead.image && this.textureDead.image.height) {
                const aspect = this.textureDead.image.width / this.textureDead.image.height;
                this.sprite.scale.set(2.0 * aspect, 2.0, 1);
            }
        }
        // Fade out after a moment
        setTimeout(() => {
            this.sprite.material.opacity = 0.4;
            if (this.nameSprite) this.nameSprite.material.opacity = 0.4;
            if (this.aura) this.aura.visible = false;
        }, 1000);
    }

    // Visibility (Line-of-Sight)
    setVisible(visible) {
        if (this.group) {
            this.group.visible = visible;
        }
    }

    // Remove from scene
    destroy() {
        this.scene.remove(this.group);
    }

    // Get position data for networking
    getNetPosition() {
        return { x: this.position.x, z: this.position.z };
    }
}
