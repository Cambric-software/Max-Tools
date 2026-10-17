# Branding assets

Source-of-truth brand files. Everything shipped is generated from these — do
not hand-edit a platform-specific icon.

## Files

| File | What it is |
|---|---|
| `cambric-logo.png` | The official Cambric mark (680x680, transparent). Also at the repository root. |
| `../../app/windows/runner/resources/app_icon.ico` | Max Tools app icon, 7 sizes (16–256). Feeds **both** the `.exe` icon and the window/tab icon. |
| `../../docs/favicon.ico`, `icon-32/192/512.png` | Download-page favicon and social preview. |
| `../../app/android/app/src/main/res/mipmap-*/ic_launcher.png` | Android launcher icons. |

## Two distinct marks

Do not confuse them:

- **Cambric logo** — the dark rounded square with the amber symbol. Publisher
  branding. Belongs to Cambric Software.
- **Max Tools icon** — the blue bolt. Product branding. This is what appears in
  the taskbar, the app window and the browser tab.

The download page shows the Cambric mark next to "Cambric Software"; the page
favicon and the application use the Max Tools bolt.

## Regenerating the app icon

The icon is a bolt on transparency with a vertical blue gradient drawn from
the app's brand colour `#3B82F6`. To change the colour or shape, edit the
generator and re-run it — do not paint into the `.ico` by hand, because the
16px and 32px frames must come from a downsampled master or they turn to mush.

Rendering rules that matter at small sizes:

- Draw large (1024+) and downsample with **Lanczos**; never upscale a small icon
- The arms must be thick, or the mark reads as a vertical smear at 16px
- Blur-then-threshold the silhouette to round the tips; needle-sharp points
  become an unreadable crack at taskbar size
- Keep the background fully transparent (`alpha == 0`) so it sits correctly on
  light and dark taskbars

## Adding new sizes

Windows reads the `.ico` for both the executable and the window class icon
(`Runner.rc` → `IDI_APP_ICON`, consumed by `win32_window.cpp`). Adding a size
means regenerating that single file — no CMake change required.