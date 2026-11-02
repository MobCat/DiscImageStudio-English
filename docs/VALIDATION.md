# Validation notes

This page lists the reproducible checks for the current source. Automated regressions verify the algorithms, file layouts and application workflows; the actual burning result still depends on the recorder, its firmware and the disc.

## Local validation

Most recent full architecture regression: 2026-10-28, covering the interface fixes, the calibration generation optimisation and the Verbatim BD-R (64099) preset (commits `3088802`, `49a0e4d`, `46e2c53`), on Windows with .NET SDK 10.0.400 (runtime 10.0.11) in the Release configuration. The full solution build (0 warnings, 0 errors) and the whole architecture regression passed; the test entry point runs the project's own EXE harness directly and does not use `dotnet test`.

After calibration burning finished, the generation-optimisation build, the full architecture regression and the DVD engine self-test were completed. Once the Verbatim preset was added, the build and the full architecture regression passed again, verifying that the GUI and CLI agree on radii, sector count and polarity, along with preset merging and command-line overrides. The v1.3.3 version/changelog check and the 45 release-tooling checks passed; no new performance timing or real-disc burn conclusions were added.

The new regressions that passed include: the BD calibration parallel switch, default ordered callbacks, polarity and artwork range, batch ordering and cancellation; four-point sampling coordinate-bit agreement, interleaving and byte order for CD calibration; scalar/SIMD byte agreement for the inner and outer rings of CD file mode; and coordinate, index, per-byte output and parallel tail-batch agreement for DVD sample parsing and codeword sampling.

Run these from the repository root:

```powershell
dotnet restore DiscImageStudio.slnx
dotnet build DiscImageStudio.slnx --configuration Release --no-restore
dotnet run --project tests/DiscImageStudio.ArchitectureTests --configuration Release --no-build
dotnet run --project src/DvdImageSolver --configuration Release --no-build -- selftest
dotnet run --project src/DiscImageStudio.App --configuration Release --no-build -- selftest
./tests/Test-ReleaseTooling.ps1
```

The architecture regression covers:

- CD/DVD: black and white mapping, dithering, sRGB gamma, file/streaming consistency, SIMD/scalar sampling consistency.
- CD file mode: independent reading of ISO9660/Joliet Chinese file names, inner and outer ring positions and project saving, file-area preview, raw sector geometry, file and forward-stream output consistency.
- CD data DAO: Mode 1 EDC and all P/Q check equations, main-channel byte order, lead-in and pre-gap addresses, data track Q identification and CRC, forward seek and short reads, full inner/outer ring ISO restoration; the Ritek preset's 359,845 sectors are preserved, and a simulated recorder verifies the capacity limit shared with audio tracks. The native IMAPI test only builds an in-memory image and never creates a recording device.
- BD: 17PP/EDC/Reed-Solomon, 3T/6T mapping and polarity, artwork range zeroing, UDF 2.01, files larger than 4 GiB, sidecar round-trip and rejection of invalid boundaries.
- DVD/BD file position: default inner-ring compatibility, independent parsing of outer-ring ISO9660/Joliet and UDF directories, Chinese file contents, full disc coordinates, non-seekable streams matching file output, capacity and cancellation protection, and the position option round-tripping in a project.
- Three-state model: project schema 2 round-trip and schema 1 upgrade, preset schema 4 merging with older schemas, `ProjectSession` BD apply/capture.
- Burning: operation mutual exclusion, progress, sequential writing, timeouts, cancellation and resource cleanup, all through simulated interfaces rather than a real recorder.
- Streaming burn display: only device-confirmed writes advance progress, CD audio/data, DVD and BD speed conversion, unknown or invalid rates, the 3-second expiry, finalization and end-of-run cleanup, transfer-log throttling and protection against late events.
- Calibration burn source: CD/DVD/BD labels agreeing with the saved parameters, BD bit length, polarity and artwork range, cross-family switching, speed queries, and the simulated burn request and confirmation text.
- Calibration: cubic track pitch, BD artwork range and polarity, photo rectification, curve fitting, session save and restore, disc-family preset synchronisation and parameter precision.
- Preview and windows: CD/DVD/BD projection and readback, multi-monitor and taskbar boundaries.
- File-area preview: inner and outer ring Design Projection and sidecar-backed Image Readback highlighted in yellow, DVD cubic track-pitch boundaries, no highlight for artwork-only or invalid layout information, wrong-directory/capacity hints, and clearing on switch and reset. The yellow overlay does not change the ISO data.

The GUI can produce screenshots off-screen with the existing command:

```powershell
dotnet run --project src/DiscImageStudio.App --configuration Release --no-build -- ui-snapshot --output artifacts/validation/home.png --tab 0
dotnet run --project src/DiscImageStudio.App --configuration Release --no-build -- ui-snapshot --output artifacts/validation/export-bd.png --tab 3 --project sample.discproj
dotnet run --project src/DiscImageStudio.App --configuration Release --no-build -- ui-snapshot --output artifacts/validation/preview-bd.png --tab 2 --project sample.discproj --live-input image.png --live-disc bd --live-mode calibrate
dotnet run --project src/DiscImageStudio.App --configuration Release --no-build -- ui-snapshot --output artifacts/validation/burn-bd.png --tab 4 --project sample.discproj --burn-source calibration --burn-progress write
```

`--burn-progress` accepts `write`, `buffer` and `finalize` and uses simulated progress to build the interface without starting a real burn. On 2026-10-28 the BD calibration wide layout and the 800×650 narrow window, plus the preparation and finalization states, were checked; the bottom written amount, rate, speed multiplier and progress bar were all visible. A DVD engine self-test also ran at that time; no real-disc burning was performed.

The `build` workflow additionally runs the DVD self-test on the module catalog, a two-sector CD output check and a home page screenshot. See the [release guide](RELEASING.md) for the extra checks on the published single-file EXE.

This round also checked the Design Projection for both file positions on DVD and BD plus the outer-ring Export page and outer-ring Image Readback, 8 off-screen screenshots in total; the DVD/application self-tests and the 45 release-tooling regressions passed.

The file-selection entry point on the Design page was additionally checked in 7 interface states — DVD, BD, CD, no folder selected, 18 layers, a narrow window and a short window — where the layer list scrolls internally in the wide layout, the file selection area stays reachable, and the build has 0 warnings and 0 errors.

v1.3.0 additionally passed `Build-Release.ps1`'s .NET 10 self-contained single-file verification: the isolated directory holds only the EXE, and the burning-interface build info, DVD self-test, two-sector RAW/WAV/CUE, CUE-disabled path and WPF interface rendering all passed. The result bundles .NET / Windows Desktop 10.0.11 and keeps the complete upstream licence notices alongside it.

v1.3.2 passed the full architecture regression, the DVD engine and application module self-tests, and the 45 release-tooling checks. The new regressions verify that the polarity stays consistent between saved presets and project confirmation after a Blu-ray switch, and that cross-family selection and geometry stay synchronised after deleting a recent preset; canvas zoom covers the 25%–1200% bounds, the plus/minus buttons and the fit-to-window reset. 4 off-screen screenshots were also checked: new CD, Blu-ray and DVD Project Settings plus the 18-layer Design page.

## Real-disc validation boundaries

This round's file-position and preview changes did not include real-disc burning. Automated tests do not prove a device's write strategy, the actual reflected brightness or the burning success rate; Blu-ray remains experimental.

v1.3.1's CD data disc DAO has also not been burned to a real disc yet; it has passed the full architecture regression, standalone single-file EXE start-up, audio track/CUE, inner and outer ring ISO file contents, and Image Readback verification.

The recorded DVD cubic track-pitch photographs and parameters are in the [before/after comparison in the README](../README.md#calibration-assistant). The historical audit of the physical models is in [PHYSICAL_MODEL_AUDIT.md](PHYSICAL_MODEL_AUDIT.md); its conclusions keep the dates and code baselines they state and cannot replace validation of the current source.

Future real-disc records should include the version or commit, the recorder and firmware, the disc model, the preset parameters, the speed, the generation/burn entry point and the original photographs, so that a result obtained on one device is not generalised to every disc.
