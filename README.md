# Olafo Killer vs Pierogi (Godot 4.7)

Trójwymiarowa gra multiplayer stworzona w **Godot Engine 4.7** (GDScript, Jolt Physics, ENet + wykrywanie kodem pokoju w sieci lokalnej/localhost) z grafikami billboardowymi 2D w laserowej arenie 3D.

## Zasady gry

1. **Menu i Lobby**:
   - Wpisz swój nick i kliknij **STWÓRZ LOBBY**, aby otrzymać 6-znakowy kod pokoju (kliknij na kod w lobby, aby skopiować).
   - Inni gracze mogą dołączyć klikając **DOŁĄCZ DO LOBBY** i wpisując **6-znakowy kod pokoju** (w LAN lub na tym samym komputerze) albo bezpośredni adres **IP:PORT** (np. `127.0.0.1:7777`).
   - Host klika **ROZPOCZNIJ RUNDĘ!** (działa również w trybie solo do testowania).
2. **Role w rundzie (60 sekund)**:
   - **OLAFO KILLER**:
     - Gra z **kamery trzecioosobowej (TPP)** z detekcją kolizji ścian (kamera nie przenika przez przeszkody ani ściany).
     - Może **przechodzić przez półprzezroczyste czerwone ściany laserowe**, które blokują Pierogi przed nieskończonym uciekaniem (loopowaniem) wokół przeszkód.
     - **Pistolet `[LPM / F / Spacja]`**: wystrzeliwuje pocisk energii eliminujący Pieroga jednym trafieniem (animacja pojawiajacego się pistoletu z odrzutem góra-dół, cooldown 4s).
   - **PIERÓG**:
     - Klasyczna **kamera z góry / izometryczna**, sprint ze staminą (`Shift`).
     - **Twaróg `[E]`**: zostawia na ziemi białą plamę twarogu na 12 sekund (cooldown 5s), która spowalnia Olafo o **58%**.
3. **Dodatki na mapie**:
   - Każda runda losuje nowe punkty startowe z 24 pozycji na arenie `50x50`.
   - Zlikwidowani gracze zamieniają się w `dead_pierog.png` i przechodzą w tryb obserwatora (**WASD + mysz + Spacja/Shift**).
   - W północno-wschodnim rogu mapy leży miniaturowy burger.

## Sterowanie

- **W, A, S, D / Strzałki** — Ruch (Olafo względem kamery, Pieróg w układzie mapy)
- **Myszka** — Obrót kamery (Olafo TPP i Obserwator)
- **Shift** — Sprint
- **E** — Plama twarogu (Pieróg)
- **LPM / F / Spacja** — Strzał z pistoletu (Olafo)
- **ESC** — Pauza / odblokowanie kursora
