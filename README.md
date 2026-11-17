# Olafo Killer vs Pierogi 🥟🔪

Wieloosobowa gra przeglądarkowa 3D z mechaniką tag/survival, grafikami 2D (billboard sprites) w trójwymiarowej arenie i bezpośrednią komunikacją P2P przez **WebRTC (PeerJS Cloud)**.

## 🎮 Zasady gry

1. **Lobby**:
   - Jeden z graczy klika **"Stwórz Lobby"** i otrzymuje 6-znakowy kod pokoju.
   - Pozostali gracze wpisują swój nick oraz kod i klikają **"Dołącz"**.
   - Host może kliknąć **"Rozpocznij Rundę!"** (działa także solo do testów).
2. **Runda i Role**:
   - **Olafo Killer** 🔪:
     - **Widok trzecioosobowy (TPP) jak w Fortnite!** Kamera znajduje się tuż za prawym ramieniem, a myszką rozglądasz się i celujesz.
     - Klawisze **W, A, S, D** poruszają Olafo w kierunku, w którym patrzy kamera (W = do przodu, S = do tyłu, A/D = strafe).
     - Olafo jest szybszy i ma stały sprint.
     - **Uwaga na twaróg!** Jeśli wejdziesz w plamę twarogu zostawioną przez Pieroga, zostaniesz **drastycznie spowolniony (-55%)**!
   - **Pierogi** 🥟:
     - **Klasyczny widok z góry / izometryczny** (bez zmian).
     - Muszą uciekać, chować się za wysokimi ścianami i przetrwać 60 sekund.
     - **Umiejętność Twarogu [E]**: Pieróg może namalować na ziemi białą plamę twarogu (cooldown 5s). Każda plama leży na podłodze przez 12 sekund i spowalnia goniącego Olafo!
3. **Niewidoczność zza ścian (Line of Sight) i Cienie**:
   - Jeśli między Olafo a Pierogiem znajduje się ściana lub przeszkoda, gracz za ścianą jest **całkowicie niewidoczny** (zarówno postać, jak i nick).
   - Ściany rzucają długie, dynamiczne cienie na podłoże.
4. **Tryb Obserwatora (Spectator)**:
   - Złapany gracz zmienia się w poległego pieroga (`dead_pierog.png`) i może swobodnie latać kamerą po mapie.
5. **Koniec rundy i powrót**:
   - Po skończonej rundzie pojawia się ekran wyników, po czym po 5 sekundach wszyscy automatycznie wracają do lobby.

## 🕹️ Sterowanie

- **W, A, S, D** — Poruszanie się (dla Olafo względem celownika kamery)
- **Myszka** — Rozglądanie się kamerą TPP (dla Olafo, kliknij na ekran, aby zablokować kursor)
- **Shift** — Sprint
- **E** — **Rzucenie plamy twarogu na ziemię** (tylko Pieróg, cooldown 5s)
- **Kliknięcie na kod w lobby** — Skopiowanie do schowka

## 🚀 Jak uruchomić?

Uruchom plik:
👉 **`start_game.bat`** (lub otwórz w przeglądarce `http://localhost:8080`).
