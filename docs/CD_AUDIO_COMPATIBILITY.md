# CD audio track formats, byte order and ghosting troubleshooting

## Files on disc and the data disc

Once a CD project has a files-on-disc folder selected on the Design or Export page, it switches to an ISO9660/Joliet data disc and the output suffix becomes `.iso`; clearing the folder path restores the WAV audio track. File position can be the inner or outer ring, defaulting to the inner ring, and the setting is saved with the project. The file-system metadata still sits at the start of the disc, and outer-ring mode places the file content at the end while the artwork keeps its original whole-disc coordinates instead of being squeezed into the remaining region.

```powershell
DiscImageStudio.exe cd-generate --input picture.png --output cd-image.iso `
  --data-dir "D:\files-on-disc" --volume-label CD_IMAGE --file-position outer
```

The ISO length is `sector count × 2048` and it is burned as a CD-ROM Mode 1 data disc. Instant burning inside the program uses the same ISO data stream; external burning software should use its burn-image function. The audio interleaving switch and the CUE apply only to audio track mode. The data disc's artwork area compensates for CD-ROM scrambling and position mapping separately, and the files on disc keep their original contents.

Instant burning of a CD data disc shares the DAO session and lead-out boundary checks with audio tracks, preserving the ATIP-calibrated sector count and the full file layout. The program encodes the ISO payload as Mode 1 raw sectors and sets the data track identifier; with the Ritek Medical Aqua Disc preset it still writes 359,845 data sectors and does not shorten the artwork or the files to match the smaller capacity the TAO interface reports. DAO keeps the audio track mode's restricted overburn check of at most 3 sectors, and going over that reports an error before writing.

The data track uses IMAPI's little-endian main-channel convention: EDC, P/Q error-correction codes and scrambling are added on the standard Mode 1 sector while the byte order of the sync header `00 FF…FF 00` is preserved. The adjacent-byte swap of CD-ROM physical encoding cancels out against the swap to little-endian; this also matches cdrdao's [RAW encoding and device byte-order conversion](https://github.com/cdrdao/cdrdao/blob/master/dao/dao.cc). The ISO layout inside the inner and outer rings and the physical coordinate mapping of the artwork do not change with that transport convention.

Design Projection, the tone thumbnail and Image Readback with valid `.iso.json` layout information mark the file area (including the file system) in yellow. The same-named metadata records the geometry, tone and file position; when moving an ISO it is best to move it too. The preview shows the mapping of the artwork payload, and the real disc result still needs burn verification.

## Recommended usage

New generation jobs output `cd-track.wav` by default and also generate `cd-track.cue`. The WAV is uncompressed PCM: 44.1 kHz, 16-bit, two channels, with little-endian data. Keep both files in the same directory, and update the filename inside the CUE whenever you move or rename them. The CUE is optional: clear "Also Export a CUE File" in the Export workspace, or pass `--cue false` on the command line, and only the WAV is written.

| Burning entry point | How to use it |
| --- | --- |
| cdrecord | `cdrecord dev=device speed=speed -audio "cd-track.wav"` — do not add `-swab` |
| ImgBurn | Open `cd-track.cue` in "Write image file to disc" |
| In-program streaming burn | Generates the same little-endian PCM data automatically, without a WAV header and without producing a complete temporary audio track |
| Legacy RAW workflow | Output can still be `.raw`; use `cdrecord -audio "cd-track.raw"` without `-swab` |

The output suffix determines the real format, and only `.wav` and `.raw` are accepted. You cannot turn legacy RAW into WAV by renaming it; it must be regenerated. A WAV's matching CUE uses `FILE "cd-track.wav" WAVE`, not `BINARY`. Unicode filenames use a UTF-8 CUE with a BOM, supporting spaces and Chinese. ImgBurn's author once verified Unicode filename support for this kind of CUE and noted that the early problem in 2.5.0.0 was fixed in 2.5.1.0. [ImgBurn author's note](https://forum.imgburn.com/topic/13526-unicode-filename-problem-in-cue-file/)

Command-line generation example (use your own measured settings for the geometry parameters):

```powershell
DiscImageStudio.exe cd-generate --input picture.png --output cd-track.wav --interleave true
```

`--cue` (default `true`) controls whether WAV output also writes a matching CUE; `.raw` output never writes a CUE.

A WAV's file length is `sector count × 2352 + 44`; the audio length, generation progress and streaming burn capacity remain `sector count × 2352`. The file header occupies no disc audio sectors and does not change the artwork geometry.

## Tone (dither, sRGB linearization, gray levels and brightness)

Each CD audio byte corresponds to roughly 6.8 µm of disc length; at normal viewing distance the eye integrates hundreds of bytes into a single tone. So "each byte has only two black or white patterns" is not the same as "the picture has only two colours" — midtones are reproduced by the black/white ratio of neighbouring bytes.

| Parameter | Meaning |
| --- | --- |
| Dither strength 0–100% | 0% outputs with the hard threshold at 128 (the old behaviour); 100% picks between adjacent levels byte by byte in proportion, and midtones form from the spatial ratio of black and white bytes |
| Gray levels (CD only) | 2 levels use `0x0D` / `0xAA`; 4 levels use `0x0D` / `0x10` / `0x63` / `0xAA` (`0x0D` is black, `0xAA` is white) |
| sRGB linearization (gamma) | Decodes through the sRGB transfer function before dithering; changes the density of black and white dots, not the output levels |
| Brightness | Shifts the gray levels as a whole, range −64…+64 (0..255 units) |

Command-line parameters (accepted by both `cd-generate` and `cd-preview-warp`):

```powershell
DiscImageStudio.exe cd-generate --input picture.png --output cd-track.wav `
  --tone-dither 1 --tone-levels 2 --tone-brightness 0 --tone-gamma false
```

The defaults are `--tone-dither 0 --tone-levels 2 --tone-brightness 0 --tone-gamma false`, byte-for-byte identical to older versions. New projects default to 75% / 2 levels in the "Tone" module of the Design page's right column; older projects without a `tone` section load at 0% and write the `tone` section when saved. The Export page keeps only output options and notes inside the output card that tone belongs to the Design page.

The dither phase is determined by the **logical byte index** (`globalByte`), not by screen coordinates. Delayed interleaving moves bytes around in the file, but readback still restores them through the same logical index, so generation, calibration projection and readback all see the same pattern. The calibration pattern (`GeneratePattern`) always uses a hard threshold and does not take part in dithering.

The `.json` next to the audio track records `toneDitherStrength`, `toneLevels`, `toneBrightness` and `toneSrgbLinearization`; when the Preview page loads an external audio track it synchronises these along with the geometry and interleaving.

Readback preview defaults to 1600 px with 16 samples per sector and **averages** all samples that land on the same pixel. Older versions were fixed at 900 px with 2 samples per sector and last-write-wins, so sparse sampling left white dots in the midtones that looked like newspaper halftone; with a higher sampling density the same disc shows continuous tone. The Preview page's "Design Projection" sets the measured geometry equal to the project geometry by default, so opening a project gives a neutral projection; the differences between the two geometries only appear once measured radii are entered.

## Confirmed problems

A user's real-disc comparison on 2026-09-12: the same existing RAW was fine with cdrecord's `-audio` and `speed`; adding `-swab` reproduced the ghosting. This confirms that existing RAW should be interpreted as cdrecord's default big-endian audio input.

Previously file export and streaming burn shared exactly the same `GenerateToStream` output, and the streaming path performed no byte-order conversion. But different input entry points have different conventions:

| Input | Requirement on the audio data |
| --- | --- |
| cdrecord headerless `-audio` | big-endian by default |
| cdrecord headerless `-audio -swab` | little-endian; the option declares that the input order needs swapping |
| cdrecord WAV | parses the file header and detects the audio byte order automatically |
| CUE `FILE ... BINARY` | little-endian; an existing big-endian RAW cannot be dropped into a BINARY CUE |
| IMAPI `AddTrack(IMAPI_CD_SECTOR_AUDIO, stream)` | the same sample layout as the data area of a 16-bit two-channel 44.1 kHz WAV, i.e. headerless little-endian PCM |

The cdrecord behaviour above and the BINARY definition come from the [official cdrecord manual](https://cdrtools.sourceforge.net/private/man/cdrecord/cdrecord.1.html); IMAPI's audio sample layout comes from [Microsoft's AUDIO sector definition](https://learn.microsoft.com/en-us/windows/win32/api/imapi2/ne-imapi2-imapi_cd_sector_type). ImgBurn's author also provided an example of successfully burning a `FILE ... WAVE` CUE. [ImgBurn WAVE CUE example](https://forum.imgburn.com/topic/25173-extract-only-session-two-from-audio-cd/page/2/)

The `AudioSectorType = 0` here is IMAPI's enumerated AUDIO value; it does not write the audio track as a physical Mode 0. `IRawCDImageCreator::AddTrack` currently supports only the AUDIO type. [Microsoft AddTrack documentation](https://learn.microsoft.com/en-us/windows/win32/api/imapi2/nf-imapi2-irawcdimagecreator-addtrack)

## Why two sets of contours form

The existing `CddaInterleaver` performs delay compensation for the target bytes. Swapping the two bytes of every 16-bit sample in the final output feeds bytes that belong at different delay positions into the encoding chain interleaved. The change therefore cannot be understood as an ordinary audio sample change, nor cancelled by swapping once before image sampling.

An integer-label permutation experiment against the existing delay table — after excluding head and tail padding — shows that the extra sample byte swap shifts even positions by `+73` target bytes and odd positions by `-73` after inverse mapping. That explains the double-contour mechanism; it is a derivation from the program's delay permutation model, not a complete drive CIRC model or a measurement of a physical disc.

The fix keeps the sampling and the delay table and picks the byte order at the 2352-byte whole-sector output boundary after compensation completes: big-endian for legacy RAW, little-endian for WAV and IMAPI. The WAV file header lets external tools identify the format and byte order, and the streaming interface still receives only the data area as its convention requires.

## Readback must cancel delayed interleaving

Delay compensation pushes logical byte i to file index `i + offset(i % 24)`: the interleave table is stored as a delay line of 28×D (D=4) frames with 24 bytes per frame, so the offset lies between 72 and 2592 (the frame delay plus the intra-frame column rotation). Laying bytes onto the spiral directly in file order rotates and shears the whole pattern — for the same image at 60,000 sectors and 900 px, about 17.5% of the drawn pixels disagree with the source image, which looks like a "slight distortion".

`cd-preview-track` therefore performs the inverse mapping by default (`--deinterleave`, default `true`): logical byte i reads file index `i + CddaInterleaveTable.FileOffsetFor(i % 24)`, which needs a 2592-byte look-ahead window. That table's forward delay and `CddaInterleaver` share `CddaInterleaveTable`, so the two sides cannot drift apart.

There is a cost at the tail: the delay line still holds the last few frames when the file ends, and those logical bytes were never written (1318–1332 bytes, less than one sector), so readback can only leave them blank. They sit at the outermost part of the audio track, and their share of the whole track falls as the sector count rises.

`cd-generate` now writes `<track>.json` next to the audio track (`format: cd-da-track-v1`, containing r0/r1/sector count/linear velocity/start angle/image outer radius/whether it is interleaved). The Preview workspace reads it when switching audio tracks and loads the calibration geometry and the interleaving switch, so an audio track produced on another machine can also be read back with the correct model.

## Calibration projection: source image and two geometries

`cd-preview-warp` is a fast counterpart to the readback path and the command the Preview workspace's "Calibration preview" mode calls: the input is a source image rather than an audio track, and the parameters are two geometries — the generation geometry decides where byte i samples the image, and the measured geometry decides where that byte is drawn on the disc (`--actual-r0`, `--actual-r1`, defaulting to 24.3 / 56.6 mm). When the two geometries are identical the projection is just the source image; when they differ the pattern shifts according to the measured disc, which is exactly the phenomenon radius calibration is looking for. The sector count, linear velocity, start angle and image outer radius are shared by both geometries, and the last three are fixed at 1200 mm/s, 0° and 57.5 mm.

Because it reads only the source image and never scans the whole audio track, refreshing after changing a radius or geometry costs the size of the image rather than the size of the audio track (about 845 MB for an 80-minute disc), which makes it suitable for trying parameters in calibration preview and then confirming the final disc with the readback simulation.

## Verification and boundaries

- RAW and WAV: for asymmetric patterns, with interleaving both on and off, the WAV data area is exactly the byte sequence of the legacy RAW after per-16-bit swapping; the length is unchanged.
- Streaming output: generated in a forward stream that forbids Seek/Position, the little-endian audio is byte-for-byte equal to the WAV data area and contains no file header.
- WAV preview: parses the RIFF `fmt ` / `data` chunks, skips unknown chunks and odd-length padding, bounds the read range and normalizes byte order; rejects non-PCM, non-44.1 kHz, non-16-bit or non-two-channel data. Results match the corresponding RAW preview at different sampling steps. The preview is still a mapping of file bytes and does not simulate complete physical CIRC/EFM, so it cannot replace a real-disc judgement.
- Readback consistency: the same source image generates interleaved and non-interleaved audio tracks, and `--deinterleave true` on the interleaved track matches reading the non-interleaved track in file order pixel for pixel, except for the pixels within one sector at the delay-line tail (at 900 px with the asymmetric test image the difference falls only inside the tail projection; a mutation test that shifts the frame delay by 24 bytes reports 245 mismatches).
- Calibration projection consistency: the same source image is first generated as an audio track with the generation geometry `(24.5, 56.8)`, then `cd-preview-warp`'s projection (measured = generated, and measured = `24.3/56.6`) is compared pixel by pixel against `cd-preview-track` read back with the matching geometry, and after thresholding they are identical (900 px); shrinking the measured radius shrinks the projected centroid radius, so the two geometries cannot be swapped by mistake.
- Windows memory experiment: feeding 300 asymmetric audio sectors into the existing `MsftRawCDImageCreator` and scanning the complete 2448-byte RAW result sectors shows every audio byte preserved unchanged. The generator does not swap bytes on the caller's behalf. The test creates no recording device and writes no disc.
- After this fix a user completed a real-disc trial on 2026-09-12 and reported no ghosting. That is a physical-disc result supplied by the user; the per-entry-point measurement details for streaming, cdrecord and ImgBurn were not recorded separately.

Microsoft's `WriteMedia` documentation does not describe its internal byte swapping; the conclusions above do not treat the memory experiment as an observation of swapping during device transfer. [Microsoft WriteMedia documentation](https://learn.microsoft.com/en-us/windows/win32/api/imapi2/nf-imapi2-idiscformat2rawcd-writemedia)
