# Taschenwart

Ein Addon für **World of Warcraft: Forever**, das bei vollen Taschen hilft: Droppt etwas, das mehr wert ist als das billigste Item in deinen Taschen, fragt Taschenwart, ob das billige Item dafür weggeworfen werden soll.

- Greift **nur bei vollen Taschen** ein.
- Fragt **immer nach**, bevor etwas weggeworfen wird.
- Handwerkswaren, Berufswerkzeuge, Reagenzien, Verbrauchsgüter und Questgegenstände bleiben geschützt.
- Berufe und Klassen sind pro Charakter einstellbar.

> Stand: Version 0.1.3, gebaut für den Forever-Client 1.60.1 (Interface 16001).

## Installation

1. Das Repository als ZIP herunterladen (**Code → Download ZIP**) und entpacken.
2. Den Ordner in `Taschenwart` umbenennen, falls er anders heißt (z. B. `Taschenwart-main`). In dem Ordner müssen `Taschenwart.toc` und `Taschenwart.lua` direkt liegen.
3. Den Ordner verschieben nach:
   - Windows: `World of Warcraft\_forever_\Interface\AddOns\`
   - Mac: `/Applications/World of Warcraft/_forever_/Interface/AddOns/`
4. Das Spiel komplett neu starten.
5. In der Charakterauswahl unter **AddOns** den Haken bei *Taschenwart* setzen.

### Aktualisieren

Den alten Ordner `Taschenwart` durch den neuen ersetzen und im Spiel `/reload` eingeben. Die Einstellungen bleiben erhalten.

## Einrichtung

Mit `/taschenwart` (oder kurz `/twart`) öffnest du die Optionen.

| Option | Bedeutung | Standard |
|---|---|---|
| Addon aktiv | Schaltet Taschenwart ein oder aus | an |
| Alle Handwerkswaren behalten | Aus = nur Materialien der angehakten Berufe bleiben geschützt | an |
| Verbrauchsgüter behalten | Essen, Tränke usw. werden nie vorgeschlagen | an |
| Alle Reagenzien behalten | Aus = nur Reagenzien der angehakten Klassen bleiben geschützt | an |
| Items ohne Händlerwert behalten | Items, die kein Händler kauft, werden nie vorgeschlagen | an |
| Für Questgegenstände immer Platz anbieten | Bei Quest-Drops wird das billigste Item angeboten, auch ohne Goldwert | an |
| Auktionshauspreise nutzen | Nimmt den höheren Wert aus Händler- und Auktionspreis (benötigt Auctionator) | an |
| Wegwerfen höchstens bis Qualität | Klick wechselt zwischen Schlecht, Verbreitet, Selten, Rar | Verbreitet |

### Berufe einstellen

1. Haken bei **Alle Handwerkswaren behalten** entfernen.
2. Unter **Meine Berufe** die eigenen Berufe anhaken.

Dann bleiben nur noch die Materialien dieser Berufe geschützt, z. B. Erz bei Schmiedekunst oder Leder bei Lederverarbeitung. Allgemeine Materialien, die keinem Beruf zugeordnet sind, bleiben immer geschützt.

### Klassen-Reagenzien einstellen

1. Haken bei **Alle Reagenzien behalten** entfernen.
2. Unter **Reagenzien behalten für Klasse** die eigene Klasse anhaken.

Mit *Schamane* bleibt z. B. das Ankh geschützt, eine Rune der Teleportation dagegen nicht. Reagenzien, die das Addon nicht kennt, bleiben immer geschützt.

## Benutzung

Sind die Taschen voll und im Beutefenster liegt etwas Wertvolleres, erscheint ein Fenster mit drei Knöpfen:

- **Wegwerfen** – zerstört das angezeigte Item und nimmt den Loot automatisch auf.
- **Behalten** – nichts passiert; für diesen Drop wird nicht noch einmal gefragt.
- **Nie wegwerfen** – das Item wird dauerhaft von Vorschlägen ausgenommen.

Verglichen wird immer der Wert des **ganzen Stapels** (Einzelpreis × Anzahl).

### Befehle

| Befehl | Wirkung |
|---|---|
| `/taschenwart` | Optionen öffnen oder schließen |
| `/taschenwart test` | Zeigt im Chat, welches Item gerade vorgeschlagen würde (löscht nichts) |
| `/taschenwart an` / `aus` | Addon ein- oder ausschalten |

## Was nie vorgeschlagen wird

- Questgegenstände und Schlüssel
- der Ruhestein
- Berufswerkzeuge (Kürschnermesser, Spitzhacke, Schmiedehammer, Angelruten usw.)
- Items auf der „Nie wegwerfen"-Liste
- Items, deren Daten das Spiel noch nicht geladen hat

## Problemlösung

**Das Addon wird als „veraltet" angezeigt.**
Im Spiel `/run print(select(4, GetBuildInfo()))` eingeben und die ausgegebene Zahl in `Taschenwart.toc` in der Zeile `## Interface:` eintragen.

**„Das Spiel hat das Wegwerfen blockiert."**
Blizzard erlaubt das Zerstören von Items nur nach einem echten Klick. Tritt die Meldung trotz Klick auf, bitte ein Issue mit der Fehlermeldung anlegen.

**Ein Item wird vorgeschlagen, das geschützt sein sollte.**
Im Fenster auf **Nie wegwerfen** klicken und den Item-Namen als Issue melden, damit es fest eingetragen wird.

## Bekannte Einschränkungen

- Vollautomatisches Wegwerfen ohne Klick ist technisch nicht möglich.
- Die Zuordnung von Materialien zu Berufen und von Reagenzien zu Klassen ist grob und beruht auf Item-IDs aus WoW Classic.
- Liegt dasselbe Item in mehreren Stapeln, wird jeder Stapel einzeln bewertet.
- Das Addon wurde bisher nur gegen eine nachgebaute Spiel-API getestet, nicht in allen Spielsituationen.
