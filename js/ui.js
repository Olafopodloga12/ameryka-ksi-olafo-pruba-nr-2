// ============================================================
// ui.js — UI Manager: screen switching, HUD updates, kill feed
// ============================================================

export class UI {
    constructor() {
        // Screens
        this.screenMenu = document.getElementById('screen-menu');
        this.screenLobby = document.getElementById('screen-lobby');
        this.screenGame = document.getElementById('screen-game');

        // Menu elements
        this.nicknameInput = document.getElementById('nickname-input');
        this.btnCreate = document.getElementById('btn-create');
        this.btnJoinShow = document.getElementById('btn-join-show');
        this.joinSection = document.getElementById('join-section');
        this.roomCodeInput = document.getElementById('room-code-input');
        this.btnJoin = document.getElementById('btn-join');
        this.menuError = document.getElementById('menu-error');
        this.menuStatus = document.getElementById('menu-status');

        // Lobby elements
        this.roomCodeText = document.getElementById('room-code-text');
        this.playerCount = document.getElementById('player-count');
        this.playerList = document.getElementById('player-list');
        this.btnStart = document.getElementById('btn-start');
        this.lobbyStatus = document.getElementById('lobby-status');
        this.btnLeave = document.getElementById('btn-leave');

        // Game HUD
        this.hud = document.getElementById('hud');
        this.hudTimer = document.getElementById('hud-timer');
        this.hudRole = document.getElementById('hud-role');
        this.hudAlive = document.getElementById('hud-alive');
        this.hudStaminaContainer = document.getElementById('hud-stamina-container');
        this.hudStaminaBar = document.getElementById('hud-stamina-bar');
        this.killFeed = document.getElementById('kill-feed');
        this.spectatorBanner = document.getElementById('spectator-banner');

        // Twarog Skill & Slow effects
        this.twarogSkill = document.getElementById('hud-twarog-skill');
        this.twarogCooldownBar = document.getElementById('hud-twarog-cooldown-bar');
        this.twarogLabel = document.getElementById('hud-twarog-label');
        this.slowedBanner = document.getElementById('hud-slowed-banner');

        // Olafo Gun Skill
        this.gunSkill = document.getElementById('hud-gun-skill');
        this.gunCooldownBar = document.getElementById('hud-gun-cooldown-bar');
        this.gunLabel = document.getElementById('hud-gun-label');

        // Overlays
        this.countdownOverlay = document.getElementById('countdown-overlay');
        this.countdownNumber = document.getElementById('countdown-number');
        this.resultOverlay = document.getElementById('result-overlay');
        this.resultTitle = document.getElementById('result-title');
        this.resultSubtitle = document.getElementById('result-subtitle');
        this.resultStats = document.getElementById('result-stats');
        this.resultTimer = document.getElementById('result-timer');

        // Red flash
        this.redFlash = document.getElementById('red-flash');

        // Set random nickname
        this.nicknameInput.value = 'Gracz' + Math.floor(Math.random() * 999);
    }

    // Screen switching
    showScreen(name) {
        this.screenMenu.classList.remove('active');
        this.screenLobby.classList.remove('active');
        this.screenGame.classList.remove('active');

        switch (name) {
            case 'menu': this.screenMenu.classList.add('active'); break;
            case 'lobby': this.screenLobby.classList.add('active'); break;
            case 'game': this.screenGame.classList.add('active'); break;
        }
    }

    // Menu helpers
    getNickname() {
        return this.nicknameInput.value.trim() || 'Gracz' + Math.floor(Math.random() * 999);
    }

    getRoomCode() {
        return this.roomCodeInput.value.trim().toUpperCase();
    }

    showJoinSection() {
        this.joinSection.classList.remove('hidden');
    }

    showMenuError(msg) {
        this.menuError.textContent = msg;
        this.menuError.classList.remove('hidden');
        setTimeout(() => this.menuError.classList.add('hidden'), 4000);
    }

    showMenuStatus(msg) {
        this.menuStatus.textContent = msg;
        this.menuStatus.classList.remove('hidden');
    }

    hideMenuStatus() {
        this.menuStatus.classList.add('hidden');
    }

    // Lobby helpers
    setRoomCode(code) {
        this.roomCodeText.textContent = code;
    }

    updatePlayerList(players, hostId) {
        this.playerList.innerHTML = '';
        this.playerCount.textContent = players.length;

        players.forEach(p => {
            const li = document.createElement('li');
            li.textContent = p.name;
            if (p.id === hostId) {
                const badge = document.createElement('span');
                badge.className = 'host-badge';
                badge.textContent = 'HOST';
                li.appendChild(badge);
            }
            this.playerList.appendChild(li);
        });
    }

    showStartButton(show) {
        if (show) {
            this.btnStart.classList.remove('hidden');
            this.lobbyStatus.textContent = 'Możesz rozpocząć rundę!';
        } else {
            this.btnStart.classList.add('hidden');
            this.lobbyStatus.textContent = 'Czekam na rozpoczęcie rundy przez Hosta...';
        }
    }

    // HUD helpers
    showHUD(isKiller) {
        this.hud.classList.remove('hidden');
        this.hudRole.className = 'hud-role ' + (isKiller ? 'killer' : 'pierog');
        this.hudRole.textContent = isKiller ? '🔪 OLAFO KILLER' : '🥟 PIERÓG';

        if (isKiller) {
            this.hudStaminaContainer.classList.add('hidden');
            if (this.twarogSkill) this.twarogSkill.classList.add('hidden');
            if (this.gunSkill) this.gunSkill.classList.remove('hidden');
        } else {
            this.hudStaminaContainer.classList.remove('hidden');
            if (this.twarogSkill) this.twarogSkill.classList.remove('hidden');
            if (this.gunSkill) this.gunSkill.classList.add('hidden');
        }

        if (this.slowedBanner) this.slowedBanner.classList.add('hidden');
        this.spectatorBanner.classList.add('hidden');
    }

    hideHUD() {
        this.hud.classList.add('hidden');
        if (this.slowedBanner) this.slowedBanner.classList.add('hidden');
        if (this.gunSkill) this.gunSkill.classList.add('hidden');
    }

    updateTwarogCooldown(remaining, total) {
        if (!this.twarogSkill) return;
        if (remaining <= 0) {
            this.twarogLabel.textContent = 'TWARÓG [E]: GOTOWY';
            this.twarogCooldownBar.style.width = '100%';
            this.twarogSkill.classList.add('ready');
        } else {
            this.twarogLabel.textContent = `TWARÓG [E]: ${remaining.toFixed(1)}s`;
            const pct = Math.max(0, Math.min(100, ((total - remaining) / total) * 100));
            this.twarogCooldownBar.style.width = `${pct}%`;
            this.twarogSkill.classList.remove('ready');
        }
    }

    updateGunCooldown(remaining, total) {
        if (!this.gunSkill) return;
        if (remaining <= 0) {
            this.gunLabel.textContent = 'PISTOLET [LPM / F]: GOTOWY';
            this.gunCooldownBar.style.width = '100%';
            this.gunSkill.classList.add('ready');
        } else {
            this.gunLabel.textContent = `PISTOLET [LPM / F]: ${remaining.toFixed(1)}s`;
            const pct = Math.max(0, Math.min(100, ((total - remaining) / total) * 100));
            this.gunCooldownBar.style.width = `${pct}%`;
            this.gunSkill.classList.remove('ready');
        }
    }

    showSlowedBanner(isSlowed) {
        if (!this.slowedBanner) return;
        if (isSlowed) {
            this.slowedBanner.classList.remove('hidden');
        } else {
            this.slowedBanner.classList.add('hidden');
        }
    }

    updateTimer(seconds) {
        this.hudTimer.textContent = Math.ceil(seconds);
        if (seconds <= 10) {
            this.hudTimer.style.color = '#ff4444';
        } else {
            this.hudTimer.style.color = '#fff';
        }
    }

    updateAliveCount(alive, total) {
        this.hudAlive.textContent = `Pierogi: ${alive}/${total}`;
    }

    updateStamina(fraction) {
        this.hudStaminaBar.style.width = (fraction * 100) + '%';
        if (fraction < 0.3) {
            this.hudStaminaBar.style.background = 'linear-gradient(90deg, #ff4444, #ff8844)';
        } else {
            this.hudStaminaBar.style.background = 'linear-gradient(90deg, #00cc44, #88ff44)';
        }
    }

    // Spectator
    showSpectator() {
        this.spectatorBanner.classList.remove('hidden');
    }

    // Kill feed
    addKillFeedEntry(killerName, victimName) {
        const entry = document.createElement('div');
        entry.className = 'kill-feed-entry';
        entry.innerHTML = `<span class="killer-name">${killerName}</span> 🔪 <span class="victim">${victimName}</span>`;
        this.killFeed.appendChild(entry);

        // Remove after 4 seconds
        setTimeout(() => {
            if (entry.parentNode) entry.parentNode.removeChild(entry);
        }, 4000);
    }

    // Countdown
    showCountdown(number) {
        this.countdownOverlay.classList.remove('hidden');
        this.countdownNumber.textContent = number;
        // Re-trigger animation
        this.countdownNumber.style.animation = 'none';
        // Force reflow
        void this.countdownNumber.offsetWidth;
        this.countdownNumber.style.animation = 'countdown-pop .9s ease-out';
    }

    hideCountdown() {
        this.countdownOverlay.classList.add('hidden');
    }

    // Red flash
    triggerRedFlash() {
        this.redFlash.classList.remove('hidden');
        this.redFlash.style.animation = 'none';
        void this.redFlash.offsetWidth;
        this.redFlash.style.animation = 'flash .4s ease-out forwards';
        setTimeout(() => this.redFlash.classList.add('hidden'), 500);
    }

    // Results
    showResults(title, subtitle, stats, titleColor) {
        this.resultTitle.textContent = title;
        this.resultTitle.style.color = titleColor || '#fff';
        this.resultSubtitle.textContent = subtitle;
        this.resultStats.innerHTML = stats;
        this.resultOverlay.classList.remove('hidden');

        let countdown = 5;
        this.resultTimer.textContent = countdown;
        const interval = setInterval(() => {
            countdown--;
            this.resultTimer.textContent = countdown;
            if (countdown <= 0) clearInterval(interval);
        }, 1000);
    }

    hideResults() {
        this.resultOverlay.classList.add('hidden');
    }
}
