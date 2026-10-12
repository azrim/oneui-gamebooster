# Samsung Game Booster — KernelSU/Magisk module

Restores the Samsung gaming stack — **Game Booster** (gametools), **Game Optimization Service**
(GOS) and **Game Launcher** — as system apps on One UI ROMs where they were debloated.

Many custom One UI ROMs strip these apps but leave their permission XMLs and the
`gamemanager.jar` framework behind, so simply installing the APKs by hand force-closes:
they are **privileged system apps** that must live in `/system/priv-app` (and be signed with
the platform key). This module puts them back the systemless way.

## What it installs

| App | Package | Location |
|---|---|---|
| Game Booster | `com.samsung.android.game.gametools` | `/system/priv-app/GameTools_Dream/` |
| Game Optimization Service | `com.samsung.android.game.gos` | `/system/priv-app/GameOptimizationService/` |
| Game Launcher | `com.samsung.android.game.gamehome` | `/system/app/GameHome/` |

The APKs are fetched from the **Galaxy Store** (same method UN1CA uses) and from **APKMirror**
for GOS, at build time — no proprietary binaries are stored in this repository.

### One build, any ROM

`customize.sh` reads `ro.build.version.sdk` and picks the build that matches the ROM:

| ROM Android | gametools | GOS |
|---|---|---|
| API ≥ 35 (Android 15/16, One UI 7/8) | 8.x | 4.4.00.8 |
| API 33–34 (Android 13/14, One UI 5/6) | 5.x | 4.4.00.8 |
| API 29–32 (Android 10–12) | 5.x | 4.0.06 |

Game Launcher is shared (its `minSdk` covers everything).

## Requirements

- A **KernelSU** (or Magisk) rooted Samsung device.
- **A KernelSU metamodule.** Since KernelSU v3, a module's `system/` directory is **not mounted
  unless a metamodule is installed** — install one such as
  [Hybrid-Mount](https://github.com/Hybrid-Mount/meta-hybrid_mount) or
  [meta-overlayfs](https://github.com/KernelSU-Modules-Repo/meta-overlayfs) first.
- The ROM must still ship `framework/gamemanager.jar` (`SemGameManager`). Almost every Samsung
  One UI ROM does.
- The ROM must be Samsung-signed (all firmware-based One UI ROMs are). ROMs that re-sign their
  apps with their own key will not grant the Game Launcher its signature permissions.

## Install

1. Install the module zip in the KernelSU app → **Modules → Install from storage**.
2. Reboot.
3. Open a game — the Game Booster panel should appear.

## Build

```bash
./build.sh            # -> dist/samsung_gamebooster-v<date>.zip
VERSION=2.1 ./build.sh
```

Requires `bash`, `curl`, `python3`, `zip`. The script:

1. Resolves Galaxy Store download URIs (`scripts/galaxy_store.sh`, a port of UN1CA's
   `GET_GALAXY_STORE_DOWNLOAD_URL`) for gametools and gamehome, and pulls GOS from
   APKMirror (`scripts/apkmirror.sh`).
2. Generates the permission allowlists (`scripts/gen_perms.py`) from the downloaded APKs.
3. Assembles `module/` + the APKs and zips the result into `dist/`.

> **GOS** is a system component and is **not on the Galaxy Store**. APK mirrors sit behind
> Cloudflare and return `403` to datacenter IPs (including GitHub Actions runners), so the two
> GOS builds are **vendored as assets of the [`gos-vendor` release](../../releases/tag/gos-vendor)**
> in this repo and fetched from there (`GOS_MODERN_URL` / `GOS_LEGACY_URL` / `GOS_VENDOR_BASE`
> override the sources). `scripts/vendor_gos.sh` refreshes them.

### Permissions

The module ships **additive** allowlist files (`privapp-permissions-samsung-gamebooster.xml`,
`signature-permissions-samsung-gamebooster.xml`). Their file names are unique to this module, so
the platform **merges** them with whatever allowlist the ROM already ships instead of replacing it.
`gen_perms.py` emits the union of the privileged permissions the bundled APKs request, so
`ro.control_privapp_permissions=enforce` never trips. To refresh the privileged-permission list
from a device:

```bash
scripts/dump_privileged_perms.sh <adb-serial>
```

## Credits

- [UN1CA](https://github.com/salvogiangri/UN1CA) by salvogiangri — the Galaxy Store download method.
- [APKMirror](https://www.apkmirror.com/) — the GOS builds.
- [Hybrid-Mount](https://github.com/Hybrid-Mount/meta-hybrid_mount) — the KernelSU metamodule used for testing.
- Samsung for the apps themselves (not affiliated).

## License

GPL-3.0. The bundled scripts are provided as-is, with no warranty.
