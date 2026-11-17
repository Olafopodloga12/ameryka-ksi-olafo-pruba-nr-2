# Olafo Killer vs Pierogi 🥟🔪

Wieloosobowa gra przeglądarkowa 3D z mechaniką tag/survival, grafikami 2D (billboard sprites) w trójwymiarowej arenie i bezpośrednią komunikacją P2P przez **WebRTC (PeerJS Cloud)**.

## 🎮 Zasady gry

1. **Lobby**:
   - Jeden z graczy klika **"Stwórz Lobby"** i otrzymuje 6-znakowy kod pokoju.
   - Pozostali gracze wpisują swój nick oraz kod i klikają **"Dołącz"**.
   - Po dołączeniu min. 2 graczy, Host może kliknąć **"Rozpocznij Rundę!"**.
2. **Runda**:
   - Trwa 3-sekundowe odliczanie.
   - Gra losowo wybiera jednego gracza jako **Olafo Killera** 🔪, pozostali stają się **Pierogami** 🥟.
   - **Czas rundy**: 60 sekund.
   - **Olafo Killer**:
     - Porusza się szybciej (1.5x) i ma nieograniczony sprint.
     - Jego celem jest dotknięcie/złapanie wszystkich Pierogów przed upływem czasu.
   - **Pierogi**:
     - Muszą uciekać, chować się za przeszkodami i przetrwać 60 sekund.
     - Posiadają pasek staminy dla sprintu (Shift).
3. **Spectator Mode (Tryb obserwatora)**:
   - Złapany gracz zmienia się w poległego pieroga (`dead_pierog.png`) i przechodzi w tryb obserwatora (**👻 OBSERWUJESZ**).
   - Może swobodnie latać i rozglądać się kamerą po mapie (WASD / Strzałki).
4. **Koniec rundy i powrót**:
   - Wyświetla się ekran wyników z podsumowaniem.
   - Po 5 sekundach wszyscy gracze automatycznie wracają do lobby, gdzie można rozpocząć kolejną rundę!

## 🕹️ Sterowanie

- **W, A, S, D** lub **Strzałki** — Poruszanie się
- **Shift** — Sprint (szybszy bieg; zużywa staminę u Pierogów)
- **Kliknięcie na kod pokoju w lobby** — Automatyczne skopiowanie do schowka

## 🚀 Jak uruchomić?

Wystarczy dwukrotnie kliknąć:
👉 **`start_game.bat`**

Otworzy się okno konsoli oraz Twoja przeglądarka pod adresem:
`http://localhost:8080`

Możesz otworzyć grę w dwóch oknach/kartach przeglądarki (lub na innym komputerze w tej samej sieci/przez Internet), aby przetestować multiplayer!
