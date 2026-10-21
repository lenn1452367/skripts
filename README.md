# Scripts

A collection of scripts and project notes. The folders below group files by
their target platform and purpose.

## Project structure

```text
skripts/
├── README.md
├── Windows11/
│   └── UpdateScreen/
│       ├── FakeUpdate.py
│       ├── ImperialMarch.ps1
│       └── InputLock.ps1
└── Zielbeschreibungstexte_skripte/
    └── FakeUpdateMitMusikwiedergabe.txt
```

## `Windows11/`

### `UpdateScreen/`

A Windows demo that displays a simulated update screen, plays music in the
background, and temporarily blocks keyboard and mouse input. It does not
install updates or change Windows system settings.

Run `FakeUpdate.py` with Python on Windows to start the demo. Press
**Ctrl+Alt+Shift+Q** to restore input and close it. Use only on a computer you
own or are authorized to test.

- **`FakeUpdate.py`** — Creates the full-screen update-style window and starts
  the audio and input-lock PowerShell scripts. Its percentage indicator is
  simulated.
- **`ImperialMarch.ps1`** — Synthesizes and plays the Imperial March. It can
  also be run separately; by default, it repeats until stopped. The
  `Wiederholungen` parameter controls the number of plays, and `Tempo` adjusts
  the speed.
- **`InputLock.ps1`** — Blocks keyboard and mouse input while the demo is
  running, except for the **Ctrl+Alt+Shift+Q** exit shortcut. It releases the
  input hooks when that shortcut is pressed.
