# Blu-ray mode (single-layer BD-R)

The Blu-ray implementation lives in `src/DiscImageStudio.BluRay`, references the media-agnostic Core and `src/DiscImageStudio.Iso`, and does not depend on the CD/DVD encoders. Following ISO/IEC 30190:2021, the current scope is **120 mm, single-layer 25 GB BD-R**; dual-layer, BDXL, BD-RE and Blu-ray video authoring are not supported.

## Where it sits in the app

Blu-ray is not a sixth workspace but the project's third media family (CD / DVD / BD). With a BD project open:

- **Design**: the canvas and composite are laid out by the BD generated outer radius; the "Files on Disc" area in the left column selects a folder and its inner-ring / outer-ring position and stays in sync with the Export page; the tone module in the right column supports 2 levels, sRGB linearization, brightness and 3T/6T polarity.
- **Preview**: Design Projection renders the 3T/6T category map from the generation/measured geometry, the tone and the polarity; Image Readback classifies the ISO's AA/44 payload bytes directly without applying the polarity, and shows the category map rather than reflective brightness.
- **Export**: generates a complete BD ISO (artwork only or UDF 2.01 files); after a folder is selected the files can go on the inner or outer ring, defaulting to the inner ring. The position is saved with the project and recorded in the `<iso>.json` sidecar in the same directory.
- **Burn**: feeds the same ISO stream straight into MMC sequential writing without saving a complete image; the job dock supports progress and cancellation.
- **Calibration**: a BD target covers the complete data area and saves the sectors, radii, polarity, artwork start and end, and the ISO timestamp; fitting uses a constant track pitch and lands back on the BD parameters.

BD presets live with the CD/DVD ones in `bluRayPresets` of `disc-presets.json` (schema 4). Three are built in: "Standard 25 GB single-layer BD", "Ritek BD-R 10x" and "Verbatim BD-R (64099)"; user presets can be saved at the bottom of the Project Settings dialog.

## Capacity and geometry

- Single-layer capacity is 12,219,392 2048-byte user sectors, i.e. 25,025,314,816 bytes; 32 sectors form one 65,536-byte cluster.
- The project partition's sector count must be a positive multiple of 32 and no greater than the single-layer capacity; the outer radius must not exceed 60 mm.
- Generation and burning share the total sector count; burning always declares the full disc capacity, and unused sectors outside the files and metadata carry a zero payload.
- Nominal track pitch 0.320 µm, channel bit length 74.5 nm, start angle 0°.

## Generation and the ISO

`BluRayIsoGenerator` first plans the UDF 2.01 directory and file extents, then allocates a 32-sector-aligned artwork range. Inner-ring mode puts the file partition at the front, while outer-ring mode puts it ahead of the end-of-disc reserved area; the leading recognition information, anchors and trailing backup information still occupy their specified positions. The output length is always `TotalSectors × 2048`.

- No folder selected: artwork-only over the whole data area, with no file system. This `.iso` can be read back by this program, but ordinary file-system tools cannot browse it.
- Folder selected: UDF 2.01 is written, supporting single files larger than 4 GiB; `--file-position inner|outer` selects the file position, defaulting to `inner`, and `outer` must be combined with `--data-dir`. Files, padding, artwork and end-of-disc metadata are written in one forward stream.
- The output path must lie outside the source folder and must not overwrite the source image. Cancelling or failing keeps any existing ISO.
- After successful generation `<iso>.json` is written (`format: bd-r-image-v1`): total sectors, inner and outer radii, artwork start/end and radii, 3T/6T polarity, `ToneProfile`, volume label, UDF timestamps, source image and generation time. Selecting that ISO in the preview restores these parameters automatically; an external ISO without a sidecar can still be read back with the current project geometry.

Files use ordinary user bytes and cannot undergo artwork de-scrambling; the artwork keeps the original whole-disc sector addresses and whole-disc geometry and never stretches the remaining artwork area across the whole disc. The UDF partition covers only the region occupied by the file system, and the artwork is not marked as free space for the file system. The actually drawable area is determined jointly by the file occupancy and the end-of-disc reserved area. The GUI's Design Projection and sidecar-backed Image Readback show the file area (including the file system) in yellow with a legend; an external ISO without layout information does not have its file range guessed.

`BluRayIsoGenerator.Prepare` scans the folder first and plans the UDF 2.01 directory and file extents. Inner-ring layout aligns the end of the files up to 32 sectors, and outer-ring layout aligns the start of the file partition down to 32 sectors. 288 sectors are reserved at the end of the disc for backup volume descriptors and anchors. This file-system API keeps an empty volume when no folder is specified; at least one complete artwork cluster must remain, and the minimum test capacity is 640 sectors.

Files and streaming share the forward write path. If the source files or directory contents change after planning, further use of the expired layout is refused. File lengths use 64-bit fields, large files are split into allocation extents of at most `0x3ffff800` bytes, and reads are sequential with a 128 KiB buffer; individual file size is limited by the disc's remaining capacity rather than by 4 GiB. DVD's ISO9660/Joliet path is unchanged.

The UDF implementation follows [ECMA-167](https://ecma-international.org/publications-and-standards/standards/ecma-167/) and [ECMA TR/112-4 (UDF 2.01)](https://ecma-international.org/wp-content/uploads/ECMA_TR-112-4_1st_edition_december_2023.pdf) and writes closed read-only volumes. It is intended for data discs and provides no Blu-ray video authoring.

## Tone and polarity

BD tone is applied once at source-image resolution: sRGB linearization → brightness offset → byte-level dithering → 128 threshold binarisation. Generation, burning and preview share that binary raster and do not hash each of the roughly 25 billion payload bytes.

`BluRayRunLengthMapping` only performs the last step: dark areas are written with the 3T-biased `AA` and light areas with the 6T-biased `44`; `InvertMapping` swaps the two ends. It is an image mapping convention and promises neither pure 3T/6T nor measured optical polarity. The actual light/dark direction has to be observed with a calibration disc; the polarity field is stored independently of `ToneProfile`.

## 3T / 6T count mapping and extension

The image path decodes with `BluRayImageLoader`, composites onto a transparent white background, and samples through `BluRayImagePayloadMapping`. The image keeps its aspect ratio, the longest side maps to the disc's outer diameter, and blank areas are white. Sample positions include each frame's EDC placeholder, LDC interleaving, BIS insertion, DC bits, sync and run-in; what the 2:3 modulation rate computes is the nominal byte centre, not the exact boundary of variable-length 17PP codewords.

The built-in `BluRayRunLengthMapping` first splits at 128 and then returns `AA` or `44` in the scrambled domain. The choice is based on how many times adjacent modulation ONEs are separated by exactly 3T or 6T in a complete cluster of the same 958,272 channel bits, counting both marks and spaces, not on the duty cycle of one level. In the 256 repeating-byte scan at baseline PSN `0x100000`, `AA` has 265,136 3T gaps and `44` has 116,575 6T gaps, the highest target counts respectively; rechecking four addresses keeps a strong bias but does not guarantee first place at every address. See [byte analysis](BLURAY_BYTE_DENSITY.md#wiring-artwork-through-3t--6t-counts) for details.

Implementing `IBluRayLuminanceMapping.Map` replaces the strategy, returning the chosen scrambled-domain byte for a source-image brightness and nominal byte position. For non-image experiments you can instead implement `IBluRayPayloadMapping.FillScrambledPayload` to fill the sector's 2048 user byte positions with data and hand it to `BluRayStreamingGenerator`; the callback receives the nominal sector, the PSN and the disc parameters.

`BluRayDiscModule` takes the image decoding delegate through its constructor and so stays independent of WPF; the app's CLI uses `BluRayImageLoader.Load`. Generating images through the module API directly must supply that delegate too. `BluRayConstantByteMapping` is still used only for explicit numeric experiments. Images and calibration both produce files or feed the recorder through `BluRayIsoGenerator`.

Candidate selection is described in [byte and bit-period density analysis](BLURAY_BYTE_DENSITY.md). `tools/BluRayByteProbe` reproduces the complete-cluster statistics for all 256 bytes and for fine-grained periods; periodic bit strings belong to other experimental strategies, and the current count mapping uses repeating bytes. The analysis still does not specify real-disc black/white polarity.

## Command line

```powershell
# Show single-layer disc parameters, or export them as JSON
dotnet run --project src/DiscImageStudio.App -- bd-info --output bd-parameters.json

# Artwork-only ISO (1024 sectors is only for quick functional checks, not a real whole-disc configuration)
dotnet run --project src/DiscImageStudio.App -- bd-generate --input image.png --output bd-test.iso --total-sectors 1024 --invert true

# Full-capacity ISO with UDF inner-ring files
dotnet run --project src/DiscImageStudio.App -- bd-generate --input image.png --output bd-image.iso --data-dir C:\Files --volume-label BD_IMAGE

# Tone: dither, brightness, sRGB linearization
dotnet run --project src/DiscImageStudio.App -- bd-generate --input image.png --output bd-tone.iso --tone-dither 0.75 --tone-gamma true --tone-brightness -4

# Raw payload probe and single ECC cluster diagnostics
dotnet run --project src/DiscImageStudio.App -- bd-probe --byte 0xA6 --sectors 32 --output bd-probe.bin
dotnet run --project src/DiscImageStudio.App -- bd-encode --input bd-probe.bin --psn 0x100000 --output bd-ecc.bin
```

`bd-generate`'s `--preset` accepts `bd-r-sl-25gb`, `bd-r-ritek-10x` or `bd-r-verbatim-64099`; `--total-sectors`, `--r0`, `--r1` and `--start-angle` override the matching values. `--invert` accepts `true`/`false`. `bd-generate` no longer accepts the old `--start-sector` / `--sectors` slice parameters; slicing remains only in `bd-probe`.

`bd-probe`'s `--byte` is 0..255 or `0x00`..`0xFF`, and the range is aligned to 32. `bd-encode` requires exactly 65,536 input bytes and outputs a 76,880-byte ECC cluster without 17PP, DC control or a file system, so it cannot be used as a burnable image.

## Encoding chain

| Part | ISO/IEC 30190:2021 |
| --- | --- |
| 2048-byte payload + 4-byte EDC | §13.2–13.3 |
| 16-bit LFSR, seed derived from PSN bits 19..5; reset per data frame | §13.4 |
| LDC RS(248,216), 304 codewords and interleaving | §13.5–13.8 |
| Addresses, RS(9,5), BIS RS(62,30) and multiplexing | §13.9–13.14 |
| 17PP, DC control and sync frames | §13.15–13.17 |
| Recording unit spacing | §14 |
| Nominal track pitch 0.320 µm | §15.4.3 |
| Single-layer PSN 0x00100000..0x00CA73FF | §17 |
| Single-layer data area 381,856 clusters | §19 |

Pattern tests write the **de-scrambled user payload**. The actual drive computes the EDC and then scrambles the complete 2052-byte data frame; EDC, error correction, addresses and sync cannot be overwritten arbitrarily by a byte probe.

`BluRayRecordingFrameEncoder` accepts the 28 DC control bits explicitly supplied by the caller. `BluRayRecordingUnitEncoder` additionally provides a diagnostic simulation containing run-in, 496 frames, run-out and an optional Guard3, representing each modulation bit / NRZI level with one byte. The automatic strategy is explicitly named `BluRayGreedyDcControlEncoder`: it makes a look-ahead greedy choice with undecided future bits set to 0, so once later control bits are settled the earlier locally best choice may change; `SuboptimalDcControlDecisions` reports that case. The strategy is experimental, does not guarantee the final DC optimality the standard requires, and does not promise agreement with a recorder's actual bit sequence. The CLI's `bd-encode` exports only the deterministic ECC stage and does not output this diagnostic simulation as a burnable image.

`BluRayTrackGeometry` uses an independent constant-pitch spiral, solving the effective track pitch from the total track length corresponding to the manual total sector count and the inner and outer radii; the last sector reaches the configured outer radius. Viewed from the data side, a sampling trajectory at fixed disc coordinates spirals outward clockwise (§9.8, §15.3); the screen transform reverses the Y axis only once. Each recording unit spans `2760 + 496 × 1932 + 1104 = 962136` channel bits at a bit length of 74.5 nm. `bd-probe`'s local range uses the geometry of the full total capacity. The trailing Guard3 is not part of each recording unit's repeating span.

The default 24–58 mm is a nominal geometry, not a measured parameter of any particular disc. Built-in streaming burn matches the `sector → PSN` model by leaving the BD-R unformatted and allocating no defect-management spare area. The actual radii, positions and optical contrast still need real-disc calibration; external software burning the ISO should also use the no-spare-area approach.

## Streaming burn without a spare area

For an unformatted BD-R, `IDiscFormat2Data` may report a usable capacity of 11,826,176 sectors under the default spare-area scheme, which is 768 MiB less than the raw 12,219,392 sectors. The Blu-ray channel sends `WRITE(10)` sequentially from LBA 0 through `IDiscRecorder2Ex.SendCommandSendDataToDevice`, 32 sectors (64 KiB) at a time, with a 200-second per-command timeout to allow for first-write initialisation. Buffers respect the adapter's address alignment and maximum transfer limit. This channel never calls the data-burning interface's `Write`, `FORMAT UNIT` or any spare-area allocation.

The public `IWriteEngine2` interface has no settable command timeout, so query and cache-flush timeouts cannot extend the wait inside `WriteSection`. The current explicit command channel reports the failing command's LBA, sector count, actual elapsed time, HRESULT and Sense. A timeout means the device-side result may be indeterminate, and the program does not automatically resend that range.

The failure log also keeps the timings of the last 8 successful writes, separately totalling source-stream read waits, device command waits and cumulatively confirmed data volume. With no valid Sense it explicitly shows "no valid device Sense data returned"; an all-zero response cannot be interpreted as the disc having no errors. `0x8007048F` means Windows reports the device is not connected. If a command marked with a 200-second timeout fails within milliseconds and the device then re-enumerates, the device connection, firmware and USB events need investigating; it cannot be put down simply to insufficient waiting time. All device queries and burn operations on this instance are queued so that an unfinished query cannot overlap writing.

After exclusively locking the disc, the program reads the current profile, disc information, format capacity and track information over MMC. It must be a blank, unformatted single-layer BD-R SRM whose first track starts at 0 and whose raw writable capacity is complete; unknown, used or already formatted layouts are rejected, and the total sector count is never reduced automatically. The sector count configured in the interface is converted at 2048 bytes into the same request length, covering the UDF prefix, the artwork area and the trailing metadata; a smaller manual capacity still writes the same number of sectors.

When writing completes, the cache is flushed, the track is closed and the disc is finalized with the BD-R finalize function 6. Cancellation takes effect once the current device command finishes; a cancellation or write failure only flushes the cache and releases the device as best it can, and never finalizes an incomplete image as a successful product. Each unlock is marked complete only on success, a failed one is retried once, errors stay in the diagnostics, and count-paired operations that already succeeded are not repeated. Once finalization starts the program waits for the command to complete. No-spare-area mode has no spare capacity for bad-block remapping; after an interruption the same disc usually cannot be written again.

The BD real-time rate is computed from write commands the recorder has confirmed accepting, includes the effect of the device cache, and is not the instantaneous laser speed on the disc surface; final success is still determined by the cache flush and finalization completing. The nominal user-data rate at 4× is 18 MB/s (1× = 4.5 MB/s), the interface uses decimal MB/s, and the requested multiplier cannot substitute for actual throughput; automatic mode still picks the lowest configuration the current disc reports.

The device-reported setting is recorded immediately before writing; the setting and the real-time throughput are kept separately. During writing a diagnostic window is recorded every 10 seconds and after the final block, separating source-stream read time (including waits and copies) from WRITE command time (including transfer and device waits), and recording the average confirmed acceptance rate. Low-frequency logging adds no device queries and does not rewrite progress or extend the rate's validity; source-stream read time must not be taken as the production thread's pure computation time, and command time alone cannot separate USB transfer from disc writing.

Image streaming uses bounded batches of up to 8 worker threads and 16 clusters (1 MiB), writing out in the original order once computation finishes. The built-in 3T/6T threshold mapping and the scrambling XOR use integer SIMD, position calculation keeps its original precision, and verified disc parameters are no longer rechecked for every byte. Immutable raster images enable parallelism automatically and the built-in calibration pattern explicitly declares its sampling as thread-safe; custom sampling callbacks stay serial by default. Pre-buffering can only absorb speed differences temporarily — sustained burning still requires the feed rate to exceed the selected device speed.

Protocol and workflow tests use only fake devices and a 1024-sector (2 MiB) UDF data stream; the full 12,219,392 sectors is verified only for capacity and geometry metadata, without generating a whole-disc ISO. Physical burning results still need real-disc verification.

Implementation references: [Microsoft's send-data and command-timeout interface](https://learn.microsoft.com/en-us/windows/win32/api/imapi2/nf-imapi2-idiscrecorder2ex-sendcommandsenddatatodevice), [libburn's MMC implementation](https://dev.lovelyhq.com/libburnia/libburn/src/branch/master/libburn/mmc.c), [libburn's write timeouts](https://dev.lovelyhq.com/libburnia/libburn/src/branch/master/libburn/spc.h).

## Verification scope

Automated checks cover 17PP/EDC/Reed-Solomon, complete RUB replay, image mapping, parallel generation, ISO/UDF, files larger than 4 GiB, sequential burn commands, the artwork range, the sidecar and cancellation. The on-disk UDF test uses only 1024 sectors and a maximum ISO of 2 MiB; the large-file test first enables and verifies the sparse attribute, then creates a logical source file larger than 4 GiB (allocating under 1 MiB in practice), streams it sequentially into a stream that verifies and discards the data, and never writes a large ISO. Real disc capacity is verified mathematically only. The tests never access a real recording device and do not prove the visible brightness or polarity on a real disc surface.
