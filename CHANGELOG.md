# Changelog

## Unreleased

## [1.3.4] - 2026-11-02

- Added Simplified Chinese, Traditional Chinese and English interfaces. Choose a language, or Use System Setting, under Settings → General → Language; save and restart the app to apply it, while cancelling leaves the preference unchanged. A Taiwan, Hong Kong, Macao or `zh-Hant` system locale uses Traditional Chinese, other Chinese locales use Simplified Chinese, and every other locale uses English. Navigation, workspaces, dialogs and application status messages share embedded translation resources; project data and numeric formatting are unchanged, and diagnostics returned by lower-level modules and the operating system keep their original language.
- In this English fork, the English text in the translation resources is this fork's existing wording. The lower-level modules, command-line help and built-in presets remain English at the source; built-in and manual preset names and the project file filter reach the Chinese interfaces through English-keyed entries in `Fork.json`, and English is the fallback language.
- Language and theme now follow the system by default. Missing or invalid preferences fall back to the system, while valid saved choices are kept. Settings are stored in `%LOCALAPPDATA%\DiscImageStudio\settings.json`; a corrupt file or one with a newer schema falls back to defaults, and settings are never written into `.discproj`.
- The title bar gains a permanent gear-and-Settings button on the right, available on the home page and in every workspace, and Ctrl+, still opens Settings. Long project names are truncated. The "…" menu provides "About..."; the duplicate Settings menu item and the former sidebar "About" entry are removed.
- Added the "General" and "Storage" settings categories. The Dark, Light and Use System Setting themes apply to all windows immediately after saving, including the code-drawn sidebar, segmented controls, disc canvas and job dock.
- Added default project location and cache location settings, which use the system Documents and temporary folders respectively when left blank. You can view the cache usage, clear this app's cache or open the application data folder. Clearing the cache deletes only the allow-listed cache images and sidecars, never project or exported files, and is disabled while a job is running.
- The maximum CD, DVD and Blu-ray preview resolution is unified at 8192×8192 for Design Projection, Image Readback and exported preview images; each disc family keeps its default preview size.
- Added language links at the top of every README and documentation on language configuration and maintaining translation resources ([docs/LOCALIZATION.md](docs/LOCALIZATION.md)). This fork's README stays English and carries upstream's Simplified Chinese and Traditional Chinese READMEs as `README.zh-CN.md` and `README.zh-TW.md`.
- The `ui-snapshot` developer command gained `--language zh-CN|zh-TW|en|system`, `--theme dark|light|system`, `--settings-dialog` and `--settings-view general|storage` to check layouts across languages, themes and settings categories. Settings dialog snapshots default to 760×600 and use a one-off settings file, so real preferences are untouched. Without `--language`, this fork's snapshots render in English.

## [1.3.3] - 2026-10-28

- Added the built-in Verbatim BD-R (64099) preset, using the radii, sector count and mapping polarity the user saved, available from both the GUI and the command line.
- Fixed the streaming burn source summary for Blu-ray calibration wrongly showing CD, and it now shows Blu-ray bit length, 3T/6T polarity and artwork range from the calibration record.
- The streaming burn dock now always shows device-written volume / total, the real-time rate and the matching speed multiplier; preparation, transfer, finalization and diagnostics go to the log. Transfer volume no longer overrides actual write progress, and the old rate is cleared on finalization or after a long gap with no new writes.
- BD calibration range mapping now uses the ordinary image generator's bounded parallel batching and reuses four-point geometry sampling, while keeping the original calibration callbacks, artwork range, polarity and ordered output. A custom mapping still has to opt in to parallelism explicitly.
- CD calibration reuses the image generator's four-point geometry sampling, and DVD calibration and codeword callbacks reuse the existing variable-track-pitch SIMD path; per-point scalar trigonometry, callback order and audio track interleaving are preserved, and constant-track-pitch DVD still uses the existing scalar fallback.
- CD file mode gained four-point sampling, computed from the independent physical position of each byte after the swap and CIRC mapping, while preserving file-area, palette-index, scrambling and disc-end boundary handling.

## [1.3.2] - 2026-10-27

- The Project Settings dialog can switch to another preset of the current disc family; the overwrite is confirmed first, and cancelling keeps the original parameters and the current selection unchanged.
- The theme blue is unified as `#3385FF` in dark and the accent as `#74C0FF` in light; the selected item of a segmented control now uses a theme-colour fill, its height aligns with the input boxes, and the drop-down arrow on the right of a combo box is reduced to a compact size.
- Custom ("Custom") presets can be deleted from a context menu in New Project and Project Settings, and deleting one also clears the matching recent-template record.
- The Design page zoom bar is now permanently docked at the bottom right, with new "−" and "+" buttons and a zoom range widened to 25%–1200% (previously it could only zoom in); "Fit to window" now uses a refresh icon. Ctrl/Alt + mouse wheel still zooms and the middle mouse button still pans.
- The gray caption on home page template cards now shows the disc family ("CD", "DVD", "Blu-ray").
- Fixed the preset-switch confirmation reacting to ordinary key presses, a preset saved after switching to Blu-ray keeping the old polarity, and the disc family not matching the next selection after deleting a recent preset.

## [1.3.1] - 2026-10-26

- CD gained a files-on-disc mode: with no folder selected the WAV audio track is kept, and once a folder is selected an ISO9660/Joliet Mode 1 data disc is generated; files can be placed on the inner or outer ring, and project saving, ISO export and streaming burn share the layout.
- CD Design Projection and Image Readback with layout information show the file area in yellow and keep full disc coordinates; Chinese directory and file names are supported, and on-disc content keeps its original bytes.
- CD data disc streaming burn now shares the DAO session and capacity-boundary handling with the audio track, fixing the Ritek Medical Aqua Disc preset wrongly reporting "insufficient remaining capacity"; the ATIP-calibrated 359,845 sectors and the existing end-of-disc limit are preserved.
- Added regressions for Mode 1 check codes, DAO data track identification, forward streaming and full inner/outer ring ISO restoration. CD data disc DAO has been verified in software and against a native memory image but has not yet been verified by burning a real disc; instant burning remains experimental.

## [1.3.0] - 2026-10-26

- All apps, disc modules and tools upgraded to .NET 10, and CI, EXE and MSIX packaging now use the .NET 10 SDK; the published self-contained EXE still needs no separate runtime install.
- The DVD / Blu-ray Design page gained a "Files on Disc" area where the folder and its inner-ring / outer-ring position can be chosen directly, sharing the setting with the Export page.
- The DVD and Blu-ray mixed files-and-artwork mode gained "File Position: inner ring / outer ring", defaulting to the inner ring; project saving, ISO export and streaming burn use the same layout. Outer-ring file mode keeps the file-system information it needs, and the artwork range automatically avoids the file area.
- DVD / Blu-ray Design Projection and Image Readback with layout information show the file area (including the file system) in yellow with a legend; the colour is used only in preview. For external images without matching layout information, the occupied file range is not guessed.

## [1.2.0] - 2026-10-26

### Project and design

- Restructured into five workspaces — Design, Preview, Export, Burn and Calibration Assistant — with CD, DVD and BD sharing the current project and disc parameters.
- Added `.discproj` project save and open, recent-project thumbnails, unsaved-change checks and Project Settings, plus the ability to save the current disc parameters as a user preset.
- Added a multi-layer design canvas that can import several images and move, scale, rotate, reorder and show/hide them; export and burning both use the high-resolution composite. The former automatic annular-copy entry point is removed, and layout is managed by the design canvas.
- Added the job dock, which collects the run log, job progress, cancellation entry point and output location; the Export and Burn pages show the current project source consistently.

### Tone, Blu-ray and calibration

- Tone moved to the Design page, supporting 0–100% dither strength, brightness adjustment, sRGB linearization and CD two-level / four-level grayscale. New projects default to 75% dither; older projects without tone settings keep their original binary mapping.
- Added optional tone parameters to the CD, DVD and BD production commands; CD/DVD use deterministic logical-byte dithering and BD processes at source-image resolution, with generation, streaming burn and Design Projection using consistent settings.
- The BD ISO gained matching JSON metadata recording disc geometry, artwork range, mapping polarity, tone and UDF timestamps; opening the ISO in the preview can restore the matching parameters automatically.
- Improved calibration fitting: the search range expands automatically and keeps widening for Blu-ray while the residual is still large; maximum deviation, outlier marking and an error threshold were added so results with excessive deviation are not applied.

### Compatibility and migration

- Projects and user presets now support CD/DVD/BD uniformly; reading compatibility is kept for project schema 1, preset schema 2/3 and existing CD audio tracks. Production commands keep their existing parameters, and the new tone parameters are all optional.
- The `ui-snapshot` developer screenshot command now numbers pages: 0 Home, 1 Design, 2 Preview, 3 Export, 4 Burn, 5 Calibration; the About window moved to `--about-dialog`, and `--live-processing` was removed.
- Blu-ray and direct burning remain experimental; the measured hardware coverage is in `docs/VALIDATION.md`, and automated tests are not treated as new real-disc validation.

## [1.1.0] - 2026-10-25

### Added

- Single-layer 25 GB BD-R experimental mode: source image layout, 3T/6T mapping and inversion, disc parameters and presets, live preview, ISO generation and the calibration assistant, available from both the GUI and the command line. Dual-layer discs are not supported yet, and real-disc light and shade still need verification.
- Blu-ray inner-ring files support UDF 2.01 and single files larger than 4 GiB; generation and streaming burn share the full disc geometry, segmented file layout and bounded data stream.
- Sequential recording without a spare area on a brand-new unformatted BD-R, keeping all 12,219,392 sectors. Capacity, blank state and start address are checked before burning starts; capacity is never reduced automatically and there is no automatic rewrite after a failure, and block timeouts plus cleanup diagnostics were added.
- CD, DVD and BD generation and live preview can enable black and white dithering and a separate sRGB gamma correction, both off by default. File generation, streaming burn and source image preview use consistent processing options.
- The calibration assistant supports photo perspective rectification, curve point tracing and fitting, parameter snapshots and write-back; DVD uses the cubic track-pitch model, a verified Verbatim DVD-R AZO (43533) preset is built in, and before/after photographs and records are included.
- Added the standalone black and white dither tool, the DVD grayscale probe tool and the Blu-ray byte probe tool, with usage notes and reproducible verification steps.

### Improvements and fixes

- Live preview supports CD/DVD/BD source image projection and readback of existing output, with a settable resolution, fit-to-window, 1:1 pixels, mouse zoom and pan; preset synchronisation, the browse command and DVD readback sample positions were fixed.
- CD/DVD use a unified two-level black and white mapping; black and white input keeps discrete pixels, and annular compositing re-dithers after scaling. Readback of older multi-level output still recognises the original gray levels.
- CD and DVD sampling gained SIMD with boundary fallback, and Blu-ray uses bounded parallel generation with integer SIMD; regression tests verify that scalar, parallel and streaming output agree.
- The Burn page shows a rate computed from device-confirmed written data, and device queries and burn operations are serialized; stale rates are not shown during preparation or finalization. Actual burning remains experimental.
- Fixed maximised-window bounds across multiple monitors, different DPI and taskbar positions, and unified the decimal precision of parameters; the home page and recent jobs support Blu-ray, and CD WAV output can choose whether to write a CUE sheet.
- Calibration records use schema 6 and do not accept older pattern records; the compatibility range for disc presets and existing audio tracks/images is described in the matching documents. Every conclusion about actual geometry and brightness still needs verification with the specific device and media.

### Open source and documentation

- Adopted GPL-3.0-or-later, compatible with the CD interleaving implementation derived from CDImage; the original author's copyright and acknowledgements were completed.
- The complete licences of the third-party components and of the HarmonyOS Sans font are kept; they can be viewed offline on the About page, and the single-file EXE contains the licence texts too.
- The README now lists ECMA-267, ECMA-359, ISO/IEC 30190:2021 and other standards with official links; tool entry points, validation documents, cache ignore rules and personal path examples were tidied up.

## [1.0.26] - 2026-09-12

- First GitHub Release: the Windows x64 single-file EXE bundles .NET, so it runs as soon as it is downloaded.
- Includes CD WAV + CUE / RAW audio track generation, the DVD artwork ISO and mixed data discs, plus the GUI, command line, live preview, annular compositing and editable disc presets.
- Includes byte-order fixes for CD WAV and streaming audio tracks while keeping compatibility with older RAW; real-disc user feedback confirmed there is no ghosting after the fix.
- Includes experimental CD/DVD direct burning. There is some real-disc feedback, but coverage across devices, discs and burn paths is still limited.
- Release binaries are built by GitHub Actions, which runs module regressions, the DVD self-test, final single-file RAW/WAV generation and a GUI screenshot check; the release notes give a SHA-256 checksum for the download.
- The version has a single source, and a release package is produced only after the version number and matching release notes change; pre-release versions and manual retries are supported, and the separate MSIX packaging flow is kept.

## Development history before the first GitHub release

The entries below are the accumulated development record. The verification state reflects the stage each entry belongs to; the current verification scope is governed by `docs/VALIDATION.md`.

- Added the GitHub Actions release policy: `Directory.Build.props` holds the single version, and only when a change merged into `main` modifies both the version and the release notes and the full version changes does CI — after CI and final single-file verification — automatically create the version tag, the self-contained Windows x64 EXE and a GitHub Release draft; alpha/beta/rc are supported, the release notes include a SHA-256, the maintainer reviews before publishing, and published artefacts are never overwritten. MSIX keeps a manual channel that reuses CI and reads the same version configuration by default.
- CD file output now defaults to standard WAV (44.1 kHz, 16-bit, two-channel PCM) and writes a `FILE ... WAVE` CUE alongside it: cdrecord can read the WAV directly and ImgBurn opens the matching CUE; legacy `.raw` keeps big-endian byte order. WAV is converted to little-endian after delayed interleaving completes, and CD streaming burn explicitly uses the same headerless little-endian PCM, fixing the mismatch with the IMAPI audio input convention. Audio track preview supports RIFF chunk parsing and byte-order normalization for WAV. Added regressions for asymmetric audio samples and for preserving Windows RAW image bytes.
- DVD streaming burn gained hybrid folder support: the ISO9660/Joliet layout is computed first, then a non-rewindable forward stream writes the inner-ring files, ECC alignment padding and the outer-ring artwork in order, without saving a complete temporary ISO.
- Raised the production intermediate image for annular compositing from 2048×2048 to 8192×8192, with 4096×4096 for saved previews and 2048×2048 for live preview; the run log now records the actual pixel size of each copy, so detail is no longer lost to a low-resolution intermediate.
- Added disc presets: CD 80/74 minute, 12 cm single-layer DVD, 8 cm single-layer Mini DVD; the generation page and the live preview page synchronise both ways, and a manual edit automatically switches to "Custom Parameters".
- Added the "Ritek Medical Aqua Disc (measured)" CD preset: 24.911275–57.931155 mm, 359,845 sectors.
- Added the "Verbatim CD-R AZO (43438) (measured)" CD preset: 24.837775–58.020875 mm, 359,848 sectors.
- Added the "Verbatim DVD-R AZO (43533) (measured)" DVD preset: 23.9968875–57.9779875 mm, 2,297,888 sectors.
- CD/DVD disc presets moved to layered JSON: the built-in layer updates with the app, while the user layer first creates custom CD/DVD parameters and stores only additions, same-ID overrides and disabled entries; presets contain only capacity and generation geometry and no longer mix in image canvas or measured calibration parameters. The format reserves a default text language and name/description resource keys, so adding i18n later will not break user JSON. The interface can open and reload the user layer, and an invalid edit shows a specific error and keeps the last valid preset.
- Decimal parameters of disc presets are now shown at their full actual precision instead of being truncated to a fixed 3 or 6 decimal places.
- Corrected the default scan velocity for the built-in CD presets, the GUI and the command line: the 1100 mm/s inherited from the older tool became 1200 mm/s, the lower bound of the ECMA-130 range, with regression checks for the standard range added.
- Added experimental streaming direct burning for CD and artwork-only DVD: the generator feeds Windows IMAPI2 continuously through a bounded 64 MiB memory buffer without saving a complete ISO/RAW; automated tests pass and real-disc verification is still outstanding.
- Fixed CD streaming burn returning `0xC0AA0502` on some recorders because of a redundant `DoNotFinalizeMedia` setting; session closing and buffer-underrun protection now use IMAPI2's safe defaults, and a `ReleaseMedia` error during cleanup can no longer mask the real first write error.
- CD streaming burn moved from Track-at-Once, which used 2 extra sectors and rejected audio tracks outright, to Raw CD/DAO: lead-in, Cooked R-W subchannel and lead-out are streamed in through the Windows RAW image builder, so the measured 359,845 sectors of content land exactly on the DAO legal boundary of the same disc; a restricted end-of-disc overburn of up to 3 DAO sectors is also allowed, and anything beyond that is still rejected before writing. When a device reports no speeds, it falls back to the stable ~16× setting confirmed acceptable on real hardware.
- The streaming burn interface gained reading and selecting the write speeds the current disc supports; automatic mode re-reads the CD/DVD media just before burning and picks the lowest available speed to reduce errors, a manual selection is left untouched, and the speed the device actually used is recorded during the burn.
- Reversed the dispersion black/white byte polarity based on real DVD results: black now uses `0xA5` and white uses `0x92` in the scrambled domain; this applies to both artwork-only and hybrid streaming burn.
- Raised the streaming burn's bounded memory buffer from 16 MiB to 64 MiB and the pre-fill before burning from 8 MiB to 32 MiB, giving 16× DVD writing more generation jitter margin.
- MSIX packaging now clears the RID build cache, checks for source changes during publishing, and verifies directly that the burning component inside the package has dropped the old `DoNotFinalizeMedia` setting, preventing a shipped package whose main app is updated but which embeds an old burning DLL.
- Added the separate `DiscImageStudio.Burning` abstraction layer, recorder enumeration, blank/capacity checks, second confirmation, progress and cancellation handling; the original image-file workflow is unchanged.
- Added the "Annular Copy (automatic count)" image processing mode: one source image is copied several times automatically and arranged in a ring towards the outer disc, with adjustable inner and outer safety margins.
- Corrected the annular copy layout: the copy count is still computed automatically, and when space runs out all copies are scaled down uniformly so they never distort, crop or overlap.
- Added the separate `DiscImageStudio.Imaging` image pre-processing layer, shared by CD and DVD and reusable by a future Blu-ray module.
- The standalone live preview page now supports both CD and DVD; the matching parameters synchronise both ways, and a parameter change refreshes automatically after a 450 ms debounce.
- The CD geometry preview now uses the same sampled average grayscale mode as DVD.
- The DVD interface and module now always use the fast texture algorithm, fast output and a clockwise (CW) spiral; the algorithm and direction selectors are no longer shown.
- Added PNG image loading and display inside the interface, and fixed the log box height being limited by the global text-box style.
- Fixed preview loading failing on .NET 9 WPF because loading a PNG through `StreamSource` wrongly enabled the ignore-URI-cache option.
- Fixed a crash in the signed MSIX when CD generation/preview wrote to the run log, caused by a conflict between WPF and invariant-region mode.
- Added the unified WPF GUI.
- Merged the CD-DA and DVD workflows while keeping the DVD engine isolated.
- Added the `DiscImageStudio.Core` optical disc module abstraction layer.
- Added the CD and DVD module adapters and reserved extension points for a future Blu-ray module.
- Added MSIX packaging, store assets, GitHub CI and release documentation.
