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
        this.isSlowed = false; // slowed down by twarog

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
            this._createGunMesh();
        }

        // Direction facing (for shooting/aiming in top-down mode)
        this.facingDir = { x: 0, z: 1 };
    }

    _createGunMesh() {
        // Gun pivot group centered at body height
        this.gunPivot = new THREE.Group();
        this.gunPivot.position.set(0, 1.0, 0);

        // Internal sub-group for gun rotation/aim and recoil kick
        this.gunMesh = new THREE.Group();
        this.gunPivot.add(this.gunMesh);

        // Gun body (receiver / frame)
        const bodyGeo = new THREE.BoxGeometry(0.12, 0.16, 0.38);
        const bodyMat = new THREE.MeshStandardMaterial({
            color: 0x242830,
            roughness: 0.3,
            metalness: 0.85
        });
        const body = new THREE.Mesh(bodyGeo, bodyMat);
        body.position.set(0, 0, 0);
        this.gunMesh.add(body);

        // Gun barrel
        const barrelGeo = new THREE.CylinderGeometry(0.045, 0.045, 0.32, 12);
        const barrelMat = new THREE.MeshStandardMaterial({
            color: 0x111317,
            roughness: 0.15,
            metalness: 0.95
        });
        const barrel = new THREE.Mesh(barrelGeo, barrelMat);
        barrel.rotation.x = Math.PI / 2;
        barrel.position.set(0, 0.04, 0.3);
        this.gunMesh.add(barrel);

        // Gun grip (handle)
        const gripGeo = new THREE.BoxGeometry(0.1, 0.22, 0.12);
        const gripMat = new THREE.MeshStandardMaterial({
            color: 0x3d2010,
            roughness: 0.75,
            metalness: 0.1
        });
        const grip = new THREE.Mesh(gripGeo, gripMat);
        grip.rotation.x = -0.35;
        grip.position.set(0, -0.13, -0.06);
        this.gunMesh.add(grip);

        // Muzzle flash mesh
        const flashGeo = new THREE.SphereGeometry(0.18, 8, 8);
        const flashMat = new THREE.MeshBasicMaterial({
            color: 0xffaa00,
            transparent: true,
            opacity: 0.95
        });
        this.muzzleFlash = new THREE.Mesh(flashGeo, flashMat);
        this.muzzleFlash.position.set(0, 0.04, 0.52);
        this.muzzleFlash.visible = false;
        this.gunMesh.add(this.muzzleFlash);

        // Muzzle flash point light
        this.muzzleLight = new THREE.PointLight(0xff6600, 0, 4);
        this.muzzleLight.position.set(0, 0.04, 0.55);
        this.gunMesh.add(this.muzzleLight);

        // Offset the gun to the right side of Olafo
        this.gunMesh.position.set(0.62, 0, 0.3);

        // Initially hidden until shot is fired
        this.gunPivot.visible = false;
        this.group.add(this.gunPivot);

        // Animation state
        this.gunShootTimer = 0;
        this.gunShootDuration = 0.55;
    }

    // Trigger visual gunshot: model appears, tilts up & down (recoil kick), then hides
    triggerGunShot(dirX, dirZ) {
        if (!this.gunPivot) return;
        this.gunPivot.visible = true;
        this.gunShootTimer = this.gunShootDuration;

        // Yaw to face bullet direction
        const yaw = Math.atan2(dirX, dirZ);
        this.gunPivot.rotation.y = yaw;

        // Initial flash
        if (this.muzzleFlash) this.muzzleFlash.visible = true;
        if (this.muzzleLight) this.muzzleLight.intensity = 3.5;
    }

    _updateGunAnimation(dt) {
        if (!this.gunPivot || this.gunShootTimer <= 0) return;

        this.gunShootTimer -= dt;
        if (this.gunShootTimer <= 0) {
            this.gunShootTimer = 0;
            this.gunPivot.visible = false;
            if (this.muzzleFlash) this.muzzleFlash.visible = false;
            if (this.muzzleLight) this.muzzleLight.intensity = 0;
            if (this.gunMesh) {
                this.gunMesh.rotation.x = 0;
                this.gunMesh.position.set(0.62, 0, 0.3);
            }
            return;
        }

        const elapsed = this.gunShootDuration - this.gunShootTimer;

        // Flash lasts for first 0.08s
        if (elapsed > 0.08) {
            if (this.muzzleFlash) this.muzzleFlash.visible = false;
            if (this.muzzleLight) this.muzzleLight.intensity = 0;
        }

        // Recoil kick up and down:
        // 0.0s - 0.12s: kicks UP (pitch angle tilts up by ~36 deg / -0.63 rad) and back
        // 0.12s - 0.36s: rotates back DOWN to level
        // 0.36s - 0.55s: lowers slightly before disappearing
        if (elapsed <= 0.12) {
            const p = elapsed / 0.12;
            this.gunMesh.rotation.x = -0.65 * Math.sin(p * (Math.PI / 2));
            this.gunMesh.position.z = 0.3 - 0.14 * p;
        } else if (elapsed <= 0.36) {
            const p = (elapsed - 0.12) / 0.24;
            this.gunMesh.rotation.x = -0.65 * Math.cos(p * (Math.PI / 2));
            this.gunMesh.position.z = (0.3 - 0.14) + 0.14 * p;
        } else {
            const p = (elapsed - 0.36) / (this.gunShootDuration - 0.36);
            this.gunMesh.rotation.x = 0.25 * p;
            this.gunMesh.position.y = -0.15 * p;
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

    // Update movement for local player (classic top-down view)
    updateLocal(dt, keys) {
        if (!this.alive) return;

        // Raw input axes: W/S (Z axis), A/D (X axis)
        let inputX = 0, inputZ = 0;
        if (keys['KeyW'] || keys['ArrowUp']) inputZ -= 1;
        if (keys['KeyS'] || keys['ArrowDown']) inputZ += 1;
        if (keys['KeyA'] || keys['ArrowLeft']) inputX -= 1;
        if (keys['KeyD'] || keys['ArrowRight']) inputX += 1;

        const dx = inputX;
        const dz = inputZ;

        // Store facing direction for shooting when moving
        if (dx !== 0 || dz !== 0) {
            this.facingDir = { x: dx, z: dz };
        }

        // Normalize diagonal movement
        const len = Math.sqrt(dx * dx + dz * dz);
        let moveX = dx;
        let moveZ = dz;
        if (len > 0) { moveX /= len; moveZ /= len; }

        // Sprint
        this.isSprinting = keys['ShiftLeft'] || keys['ShiftRight'];
        let speed = this.baseSpeed;

        if (this.isKiller) {
            if (this.isSprinting) speed *= this.sprintMultiplier;
            // Twarog puddle slowdown
            if (this.isSlowed) {
                speed *= 0.42; // 58% speed reduction!
            }
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
        const targetVX = moveX * speed;
        const targetVZ = moveZ * speed;
        const smoothing = 12;
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

        // Update visual gun animation (recoil kick up & down)
        this._updateGunAnimation(dt);
    }

    // Update for remote players (interpolation)
    updateRemote(dt) {
        const lerpSpeed = 10;
        this.position.x += (this.targetPosition.x - this.position.x) * Math.min(lerpSpeed * dt, 1);
        this.position.z += (this.targetPosition.z - this.position.z) * Math.min(lerpSpeed * dt, 1);
        this.group.position.set(this.position.x, 0, this.position.z);

        // Update visual gun animation on remote killer too!
        this._updateGunAnimation(dt);
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
