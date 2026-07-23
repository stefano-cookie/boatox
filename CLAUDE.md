# boatox

Gioco 3D low-poly per PC: navigazione arcade (WASD) + progressione gestionale. Parti da una barchetta, arrivi allo yacht raccogliendo boe, pescando, gareggiando e potenziando la barca. Il design completo è in `docs/GDD.md` — è la fonte di verità per ogni decisione di gameplay.

## Stack

- **Godot 4.7.1** (`/Applications/Godot.app`), rendering Forward+
- **GDScript tipizzato** (niente C#)
- Asset 3D/audio esterni: solo CC0 o CC-BY, sempre registrati in `assets/CREDITS.md`

## Comandi

```sh
# Apri l'editor
/Applications/Godot.app/Contents/MacOS/Godot --path . -e &

# Lancia il gioco
/Applications/Godot.app/Contents/MacOS/Godot --path .

# Playtest con tutto al massimo (flotta, upgrade, Bova; corsari restano ostili).
# Usa il salvataggio separato save_maxed.json: quello vero non si tocca.
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --maxed

# Import/validazione headless (dopo aver aggiunto asset o su CI)
/Applications/Godot.app/Contents/MacOS/Godot --path . --headless --import
```

## Struttura

- `scenes/` — scene `.tscn`, una cartella per feature (es. `scenes/boat/`), script co-locati con la scena che li usa
- `scripts/` — solo codice condiviso non legato a una scena (utility, resource script)
- `autoload/` — singleton registrati in Project Settings (es. `game_state.gd`, `economy.gd`)
- `assets/` — modelli, texture, audio; i file `.import` si committano
- `docs/` — `GDD.md` (design), `ROADMAP.md` (milestone), `BACKLOG.md` (idee post-beta)

## Convenzioni GDScript

- Sempre tipizzato: `var speed: float = 0.0`, ritorni tipizzati, `@onready var x: Node3D = ...`
- File e cartelle `snake_case`, classi `PascalCase` con `class_name`, segnali al passato (`buoy_collected`)
- Indentazione a tab (default Godot)
- Comunicazione tra sistemi via segnali o autoload, mai percorsi assoluti fragili (`get_node("/root/Main/...")`)
- Valori di bilanciamento (prezzi, velocità, curve) mai hardcoded nei nodi: vivono in `Resource` (`.tres`) o costanti in autoload, così si bilancia senza toccare le scene

## Workflow

- Ogni sessione di sviluppo termina con una **build giocabile**: Stefano è direttore e tester, il suo feedback guida l'iterazione successiva
- Le milestone (M0→M4) sono in `docs/ROADMAP.md`: non si inizia una milestone se la precedente non è giocabile
- **Anti scope-creep**: ogni idea nuova emersa durante lo sviluppo va in `docs/BACKLOG.md`, non nel codice
- Git: Claude non committa mai — prepara `git add` preciso e propone il titolo del commit (conventional commit, in inglese); Stefano committa
- Parametri "da tarare giocando" (camera, guida, meteo) vanno esposti come `@export` così si regolano dall'Inspector senza toccare codice
