# Scripts

A collection of scripts and project notes. The folders below group files by
their target platform and purpose.

## Project structure

```text
skripts/
├── README.md
├── Linux/
│   └── cozy_amber_theme.zip
└── Windows11/
    └── UpdateScreen.zip
```

## `Windows11/UpdateScreen.zip`

A Windows demo with a simulated update screen and accompanying music. The
keyboard and mouse are temporarily locked while the demo runs. It does not
install updates or change Windows system settings.

After extracting the archive:

- **`FakeUpdate.py`** — Starts the simulated update screen and the related
  PowerShell scripts. The percentage indicator is simulated.
- **`ImperialMarch.ps1`** — Synthesizes and plays the music; it can also be run
  separately.
- **`InputLock.ps1`** — Locks the keyboard and mouse while the demo is running.
  Press **Ctrl+Alt+Shift+Q** to release the input lock and close the demo.

Run only on a computer you own or are explicitly authorized to use.

## `Linux/cozy_amber_theme.zip`

An installation package for a warm Cozy Amber design for Xfce. It configures
components including the GTK theme, window decorations, icons, panel,
terminal, and shell. Run `install.sh` to install the design or `uninstall.sh`
to restore the previous setup.

After extracting the archive:

- **`install.sh`**, **`uninstall.sh`**, **`verify.sh`** — Install, remove, and
  verify the design.
- **`config/`** — Central color palette and settings.
- **`lib/`** — Shared helper functions used by the installation scripts.
- **`scripts/`** — Individual setup steps for the desktop components.
- **`templates/`** — Templates for generated configuration files.
- **`tools/`** — Utilities for generating, adjusting, and checking files.
- **`cozy-amber-xfce/`** — Directory for Xfce theme files.
- **`README.md`** — Detailed package and usage information.
