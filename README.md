# Tastenklavier

Jede Taste ein Ton. Tastenklavier lebt in der Menüleiste deines Macs und macht aus allem, was du tippst, eine kleine Melodie, egal ob in Word, Mail oder im Browser. Dein Tipptempo bestimmt den Rhythmus.

- **9 Instrumente:** Klavier, E-Piano, Gitarre, Harfe, Marimba, Spieluhr, Trompete, Kuh und Katze
- **6 Songs:** Pop, Klassisch, Jazz, Blues, Melancholisch, Verträumt
- Leertaste setzt den Bass, Grossbuchstaben bekommen eine zweite Stimme, ein Punkt löst auf, ein Fragezeichen bleibt offen, Enter schliesst die Phrase.

## Installieren

1. Lade unter **Releases** die Datei `Tastenklavier.dmg` herunter und öffne sie.
2. Zieh **Tastenklavier** in den Ordner **Applications** (Programme).
3. Öffne Tastenklavier. macOS meldet beim ersten Mal, dass die App nicht geprüft werden konnte. Klick auf **Fertig**.
4. Öffne **Systemeinstellungen → Datenschutz & Sicherheit**, scrolle nach unten und klick bei Tastenklavier auf **Trotzdem öffnen**. Bestätige mit deinem Passwort.
5. Tastenklavier fragt nach dem Zugriff auf die Tastatur. Schalte es unter **Eingabeüberwachung** ein. Ein Ton bestätigt, dass alles klappt.

Danach findest du das Klaviertasten-Symbol oben rechts in der Menüleiste. Dort wählst du Instrument, Song und Lautstärke.

Voraussetzung: macOS 13 Ventura oder neuer, Apple-Chip oder Intel.

## Datenschutz

Tastenklavier muss Tastendrücke mithören, um Töne zu spielen. Es speichert nichts, sendet nichts und nutzt kein Internet. Der gesamte Quellcode liegt in diesem Repository.

## Hinweis zu Updates

Weil die App nicht mit einem Apple-Entwicklerzertifikat signiert ist, verlangt macOS nach einem Update eventuell erneut die Erlaubnis zur Eingabeüberwachung. Falls nach einem Update nichts klingt: In den Systemeinstellungen Tastenklavier aus der Liste entfernen (−) und neu einschalten.

## Selbst bauen

Die App wird automatisch von GitHub Actions gebaut (`.github/workflows/build.yml`). Lokal genügt ein Mac mit den Xcode Command Line Tools:

```
swiftc -O Sources/*.swift -o Tastenklavier
```

Die Instrumentenklänge stammen aus der General-MIDI-Klangbibliothek, die macOS mitbringt. Kuh und Katze werden per Formant-Synthese erzeugt.
