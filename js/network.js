// ============================================================
// network.js — PeerJS networking, lobby management
// ============================================================

export class Network {
    constructor() {
        this.peer = null;
        this.connections = new Map(); // peerId -> DataConnection
        this.isHost = false;
        this.roomCode = '';
        this.myId = '';
        this.myName = '';
        this.hostConn = null; // connection to host (if client)

        // Callbacks
        this.onPlayerJoined = null;   // (peerId, name) => {}
        this.onPlayerLeft = null;     // (peerId) => {}
        this.onGameMessage = null;    // (type, data, fromId) => {}
        this.onConnected = null;      // () => {}
        this.onError = null;          // (msg) => {}
        this.onDisconnected = null;   // () => {}
    }

    // Generate a random 6-char room code
    _generateCode() {
        const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        let code = '';
        for (let i = 0; i < 6; i++) {
            code += chars[Math.floor(Math.random() * chars.length)];
        }
        return code;
    }

    // Create a lobby as host
    createLobby(nickname) {
        return new Promise((resolve, reject) => {
            if (typeof Peer === 'undefined') {
                return reject(new Error('Biblioteka PeerJS nie załadowała się poprawnie'));
            }

            this.roomCode = this._generateCode();
            this.isHost = true;
            this.myName = nickname;
            const peerId = 'olafo-' + this.roomCode;

            let resolved = false;
            const timer = setTimeout(() => {
                if (!resolved) {
                    resolved = true;
                    reject(new Error('Przekroczono limit czasu łączenia z serwerem PeerJS. Sprawdź połączenie z Internetem.'));
                }
            }, 10000);

            try {
                this.peer = new Peer(peerId, { debug: 1 });
            } catch (e) {
                clearTimeout(timer);
                return reject(e);
            }

            this.peer.on('open', (id) => {
                if (resolved) return;
                resolved = true;
                clearTimeout(timer);
                this.myId = id;
                console.log('[Host] Peer opened with ID:', id);
                resolve(this.roomCode);
            });

            this.peer.on('connection', (conn) => {
                this._handleIncomingConnection(conn);
            });

            this.peer.on('error', (err) => {
                console.error('[Host] Peer error:', err);
                if (err.type === 'unavailable-id') {
                    // Room code collision, try again
                    this.peer.destroy();
                    this.roomCode = this._generateCode();
                    const newPeerId = 'olafo-' + this.roomCode;
                    this.peer = new Peer(newPeerId, { debug: 1 });
                    this.peer.on('open', (id) => {
                        if (resolved) return;
                        resolved = true;
                        clearTimeout(timer);
                        this.myId = id;
                        resolve(this.roomCode);
                    });
                    this.peer.on('connection', (conn) => {
                        this._handleIncomingConnection(conn);
                    });
                } else {
                    if (this.onError) this.onError(err.message || 'Błąd połączenia');
                    if (!resolved) {
                        resolved = true;
                        clearTimeout(timer);
                        reject(err);
                    }
                }
            });

            this.peer.on('disconnected', () => {
                console.log('[Host] Disconnected from signaling server');
                // Try to reconnect
                if (!this.peer.destroyed) this.peer.reconnect();
            });
        });
    }

    // Join a lobby as client
    joinLobby(roomCode, nickname) {
        return new Promise((resolve, reject) => {
            if (typeof Peer === 'undefined') {
                return reject(new Error('Biblioteka PeerJS nie załadowała się poprawnie'));
            }

            this.roomCode = roomCode.toUpperCase();
            this.isHost = false;
            this.myName = nickname;
            const hostPeerId = 'olafo-' + this.roomCode;

            let resolved = false;
            const timer = setTimeout(() => {
                if (!resolved) {
                    resolved = true;
                    if (this.peer) this.peer.destroy();
                    reject(new Error('Nie udało się połączyć z pokojem ' + this.roomCode + ' (limit czasu)'));
                }
            }, 10000);

            try {
                this.peer = new Peer(undefined, { debug: 1 });
            } catch (e) {
                clearTimeout(timer);
                return reject(e);
            }

            this.peer.on('open', (id) => {
                this.myId = id;
                console.log('[Client] My peer ID:', id);

                // Connect to host
                const conn = this.peer.connect(hostPeerId, {
                    reliable: true,
                    metadata: { name: nickname }
                });

                conn.on('open', () => {
                    if (resolved) return;
                    resolved = true;
                    clearTimeout(timer);
                    this.hostConn = conn;
                    console.log('[Client] Connected to host');

                    // Send join message
                    conn.send({
                        type: 'join',
                        name: nickname,
                        id: this.myId
                    });

                    this._setupClientConnection(conn);
                    resolve();
                });

                conn.on('error', (err) => {
                    console.error('[Client] Connection error:', err);
                    if (!resolved) {
                        resolved = true;
                        clearTimeout(timer);
                        reject(new Error('Nie można połączyć się z lobby'));
                    }
                });
            });

            this.peer.on('error', (err) => {
                console.error('[Client] Peer error:', err);
                if (!resolved) {
                    resolved = true;
                    clearTimeout(timer);
                    if (err.type === 'peer-unavailable') {
                        reject(new Error('Nie znaleziono pokoju o kodzie: ' + this.roomCode));
                    } else {
                        reject(new Error(err.message || 'Błąd połączenia'));
                    }
                }
            });
        });
    }

    // Handle incoming connection (host side)
    _handleIncomingConnection(conn) {
        console.log('[Host] Incoming connection from:', conn.peer);

        conn.on('open', () => {
            this.connections.set(conn.peer, conn);

            conn.on('data', (data) => {
                if (data.type === 'join') {
                    console.log('[Host] Player joined:', data.name);
                    if (this.onPlayerJoined) {
                        this.onPlayerJoined(conn.peer, data.name);
                    }
                } else {
                    // Forward game messages
                    if (this.onGameMessage) {
                        this.onGameMessage(data.type, data, conn.peer);
                    }
                }
            });

            conn.on('close', () => {
                console.log('[Host] Player disconnected:', conn.peer);
                this.connections.delete(conn.peer);
                if (this.onPlayerLeft) this.onPlayerLeft(conn.peer);
            });

            conn.on('error', (err) => {
                console.error('[Host] Connection error with', conn.peer, err);
                this.connections.delete(conn.peer);
                if (this.onPlayerLeft) this.onPlayerLeft(conn.peer);
            });
        });
    }

    // Setup client connection to host
    _setupClientConnection(conn) {
        conn.on('data', (data) => {
            if (this.onGameMessage) {
                this.onGameMessage(data.type, data, 'host');
            }
        });

        conn.on('close', () => {
            console.log('[Client] Connection to host lost');
            this.hostConn = null;
            if (this.onDisconnected) this.onDisconnected();
        });

        conn.on('error', (err) => {
            console.error('[Client] Connection error:', err);
        });
    }

    // Send message to host (client) or to all clients (host)
    broadcast(type, data) {
        const msg = { type, ...data };

        if (this.isHost) {
            // Send to all connected peers
            for (const [peerId, conn] of this.connections) {
                if (conn.open) {
                    try {
                        conn.send(msg);
                    } catch (e) {
                        console.error('Failed to send to', peerId, e);
                    }
                }
            }
        }
    }

    // Send message to host only (client)
    sendToHost(type, data) {
        if (!this.isHost && this.hostConn && this.hostConn.open) {
            try {
                this.hostConn.send({ type, ...data });
            } catch (e) {
                console.error('Failed to send to host:', e);
            }
        }
    }

    // Send to specific peer (host only)
    sendToPeer(peerId, type, data) {
        if (this.isHost) {
            const conn = this.connections.get(peerId);
            if (conn && conn.open) {
                try {
                    conn.send({ type, ...data });
                } catch (e) {
                    console.error('Failed to send to', peerId, e);
                }
            }
        }
    }

    // Disconnect and cleanup
    disconnect() {
        if (this.peer) {
            this.peer.destroy();
            this.peer = null;
        }
        this.connections.clear();
        this.hostConn = null;
        this.isHost = false;
        this.roomCode = '';
    }

    // Get connected peer count
    getConnectionCount() {
        return this.connections.size;
    }
}
