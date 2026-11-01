# dotfiles

Personal configuration files and scripts.

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/53a7e1ab-e1f5-4003-a227-97ff675f01a1" />

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/e6366b3a-a23f-4977-98b3-985facb5e231" />


## Contents

- **[niri](.config/niri/)**: Configuration for the [Niri](https://github.com/YaLTeR/niri) scrollable-tiling Wayland compositor (`config.kdl`) and helper scripts (`brightness.sh`, `volume.sh`).
- **[fuzzel](.config/fuzzel/)**: Configuration for the [Fuzzel](https://codeberg.org/dnkl/fuzzel) Wayland application launcher (`fuzzel.ini`).
- **[veila](.config/veila/)**: Configuration for the [Veila](https://github.com/naurissteins/Veila) screen locker (`config.toml`).
- **[celluloid](.config/celluloid/) / [mpv](.config/mpv/)**:
  - `hold-to-speedup.lua`: YouTube-style playback speed script that pauses on spacebar tap and ramps to 2x speed while holding the spacebar.
- **[.bashrc](.bashrc)**: Interactive bash shell configuration and environment variables.

## Structure

```text
dotfiles/
├── .bashrc
├── .config/
│   ├── celluloid/
│   │   └── scripts/
│   │       └── hold-to-speedup.lua
│   ├── fuzzel/
│   │   └── fuzzel.ini
│   ├── mpv/
│   │   └── scripts/
│   │       └── hold-to-speedup.lua
│   ├── niri/
│   │   ├── config.kdl
│   │   └── scripts/
│   │       ├── brightness.sh
│   │       └── volume.sh
│   └── veila/
│       └── config.toml
├── .gitignore
├── LICENSE
└── README.md
```

## License

[MIT](LICENSE)
