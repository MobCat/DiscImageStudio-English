# DVD NRZI image constraint solver

This project treats 16 consecutive DVD data sectors as one ECC block and searches for readable user data that satisfies a two-dimensional image or an explicit NRZI pit/land constraint.

Fixed conventions:

- Single-layer disc Data Zone with Sector Information `0x00`;
- A DVD-R Data Frame's RSV is six `0x00` bytes;
- Only the ECC block's starting LBA is supplied; subsequent sectors use `LBA + 1 ... LBA + 15` automatically;
- `PSN = PSN offset + LBA`, with a default offset of `0x30000`;
- On equal absolute DSV, Stream 1 wins;
- `pit = 0 = black`, `land = 1 = white`;
- Each run outputs 32768 bytes, i.e. 16 consecutive 2048-byte payloads.

The encoding chain covers ID, IED, all-zero RSV, EDC, data scrambling, RS-PC PO/PI, PO row interleaving, the EFMPlus main and substitute tables, SYNC/DSV control and NRZI conversion.

The separate [grayscale probe tool](../tools/DvdGrayProbe/README.md) uses `FastDispersionImageWriter.WriteScrambledCodewordPatternStream` to specify the scrambled Q directly in the same payload-codeword-centre coordinate system and then write `P = Q XOR mask`. That interface bypasses the fixed grayscale bands and is suitable for testing candidate codewords such as `64/E4` and discrete dither sets; the palette of ordinary image generation is unaffected. Fast generation does not replay the whole disc's ECC/EFM and does not predict optical brightness. Regression tests perform a complete ECC/EFM replay on a small mixed-codeword sample and separately verify the actual payload, geometry, parallel consistency and cancellation.

## Build and self-test

Building needs Windows and the .NET 10 SDK; running a non-self-contained build directly needs the .NET 10 Windows Desktop Runtime:

```powershell
dotnet build DvdImageSolver.slnx --configuration Release
dotnet run --project src/DvdImageSolver --configuration Release -- selftest
```

The self-test covers:

- sampling of the ECMA-267 modulation table;
- ID, IED, RSV and EDC;
- scrambling XOR round-trip;
- zero remainders for the 208 PI rows and 172 PO columns;
- count, determinism and RLL(2,10) data run lengths of the 619008 physical NRZI levels;
- precomputed gray level, end level and DSV increment of 16-bit codewords under both pit and land initial levels;
- codeword replay gray level, SYNC selection, final state/DSV/level of random SYNC frames agreeing with the bit-by-bit encoder;
- the dual-stream EFMPlus prefix state agreeing exactly with the bit-by-bit encoder whenever no substitute SYNC replay is needed;
- the state-control final boundary agreeing with the full DVD forward encoding without materialising the 619008-bit level array during the solve;
- the dispersion mode's `0x92/0xA5` scrambled-domain mapping, the de-scrambled ISO payload and the final boundary agreeing with the full encoding;
- the minimal ISO9660 descriptors, path table, root directory, payload LBA and template substitution results.
- the radius-calibration PNG preview and contiguous multi-ECC-block raw image output.
- isolation protection for inner-ring ISO9660/Joliet files, Unicode subdirectories and outer-ring artwork data.

## Target file

A target file uses characters to represent physical NRZI levels:

```text
0 or P    pit, black
1 or L    land, white
?         unconstrained
```

Spaces and underscores are ignored. The file must contain one of the following:

- 38688 symbols: constrain one physical sector, whose position in the ECC block is given by `--target-sector 0..15`;
- 619008 symbols: constrain the complete ECC block.

SYNC, RLL, EDC and ECC constrain which patterns are achievable, so an arbitrary bit-by-bit image usually has no zero-error solution. `full` mode aims at the mismatching NRZI bits; an image's `state-control` mode thresholds the target to black or white, first computing whether the pit/land majority direction is wrong and then computing the gray-level distance from the actual land count to pure black 0 or pure white 16. The search objective only uses the controllable payload codewords, while final visibility counts all channel codewords.

`dispersion` mode does not control the absolute pit/land majority but uses EFMPlus transition density to form a two-level black and white texture. After scrambling, the bytes are `Q=0xA5/0x92` and every state representation is fixed at 5/2 transitions respectively. Image brightness 0–127 maps to A5 and 128–255 maps to 92, with preview brightness 0/255. Newly generated images no longer use 66 or B9 as a distinct gray level. Inverting the whole NRZI pattern does not move the transition positions.

For an already dithered fully opaque grayscale image containing only `0/255` (all black or all white allowed), generation and the calibration preview use nearest-pixel sampling and keep each pixel's original level; ordinary continuous grayscale, colour or translucent images still use bilinear sampling. The main app's CD/DVD annular compositing first performs high-quality scaling and rotation on discrete black and white input and then re-dithers to two levels, so continuous grayscale produced by scaling is not banded directly and loses its mixed gradation. The binary objectives of `full` and `state-control` keep their original sampling rules.

## Image mapping

PNG, JPEG, BMP, TIFF or GIF can be supplied directly:

```powershell
dotnet run --project src/DvdImageSolver --configuration Release -- solve `
  --image picture.png `
  --total-sectors 2295104 `
  --iso-output solved-disc.iso `
  --output payload.bin `
  --lba 0 `
  --psn-offset 0x30000 `
  --inner-radius-mm 24 `
  --outer-radius-mm 58 `
  --channel-bit-nm 133.3 `
  --start-angle-deg 0 `
  --spiral-direction ccw `
  --image-threshold 128 `
  --alpha-threshold 1 `
  --iterations 10000 `
  --constraint-output mapped-target.txt `
  --channel-output channel.bin
```

Here `--total-sectors` is the total number of 2048-byte data blocks the disc reports; the alias `--total-blocks` is also accepted. Together with 38688 channel bits per sector and `--channel-bit-nm` it determines the total track length. The program then solves back for the track-pitch scale from the inner and outer radii and the track-pitch curve.

### Cubic track pitch varying with radius

DVD generation, streaming output, image preview, ISO readback and the calibration assistant all share `DvdTrackGeometry`. With normalised radius `x=(r-ri)/(ro-ri)`, the local track pitch is:

```text
p(x) = a0 + a1*x + a2*x² + a3*x³                 [mm]
     = p0 * (1 + c1*x + c2*x² + c3*x³)
dr/dθ = p(x)/(2π)
```

The full cubic polynomial has four coefficients. The inputs `--pitch-linear`, `--pitch-quadratic` and `--pitch-cubic` are three dimensionless relative coefficients `c1,c2,c3`; the constant term `a0=p0` is solved automatically from the fixed total track length, and the other three terms are `ai=p0*ci`. The four terms therefore satisfy the length constraint from the capacity and the inner and outer radii rather than all being independent. The interface shows all four terms in μm, and the coefficients' variable is `x`, not an absolute radius in mm.

Track length uses `L=∫sqrt(1+(2πr/p(r))²)dr` and angle uses `θ(r)=∫2π/p(r)dr`; a varying track pitch can no longer compute the angle with the constant-pitch `(r-ri)/b`. The program verifies that track pitch is strictly positive across the whole generated band, including interior extrema of the polynomial. When all three coefficients are zero the original constant-track-pitch model is used, and old parameters and presets default to zero when these fields are omitted.

For example, append `--pitch-linear 0.02 --pitch-quadratic -0.03 --pitch-cubic 0.015` to the original `solve` command. This is only a format example, not a measured value for any disc. `calibrate` uses the same options to specify the generation curve and additionally specifies the actual curve with `--actual-pitch-linear`, `--actual-pitch-quadratic` and `--actual-pitch-cubic`; the `--generated-pitch-*` aliases are also accepted. `simulate`'s `--pitch-*` refers to the actual disc curve.

The JSON written next to the image and the preview records the relative coefficients and the track-pitch base value, and a calibration session saves the relative coefficients, the inner and outer radii, the sector count and the bit length, which is enough to rebuild all four terms. The photo's overall rotation remains a separately fitted quantity.

Coordinate and sampling conventions:

- The image centre corresponds to the disc centre, the image's short side corresponds to the outer diameter, and the extra area on the long side is kept;
- The track starts at 0° at the inner radius, with 0° pointing to the right of the image; the default is counter-clockwise in the mathematical sense and `--spiral-direction cw` switches to clockwise;
- Image black maps to pit and white maps to land; gray levels below `--image-threshold` count as black;
- Transparent areas whose alpha is below `--alpha-threshold` impose no constraint;
- `--lba` counts from the track's first data block as zero, and the program maps only the 16 consecutive sectors starting at that LBA;
- `--constraint-output` is optional and exports the generated 619008-symbol linear constraint for inspection.

## Solving

```powershell
dotnet run --project src/DvdImageSolver --configuration Release -- solve `
  --target target.txt `
  --output payload.bin `
  --lba 0 `
  --psn-offset 0x30000 `
  --initial-state 1 `
  --initial-dsv 0 `
  --initial-level land `
  --target-sector 0 `
  --iterations 10000 `
  --mutation-bytes 4 `
  --seed 1 `
  --channel-output channel.bin
```

Important parameters:

- `--lba`: the starting LBA of the ECC block, not a count of 16 LBAs;
- `--psn-offset`: decimal or `0x` hexadecimal, default `0x30000`;
- `--initial-state`: EFMPlus state 1 to 4;
- `--initial-dsv`: the accumulated DSV before entering the current ECC block;
- `--initial-level`: the physical state `pit` or `land` before entering the current block;
- `--seed-payload`: an optional 32768-byte initial solution; without it a deterministic random initial solution is generated;
- `--initial zero`: use an all-zero initial payload instead;
- `--channel-output`: additionally output the final NRZI levels, packed MSB-first in groups of 8.

`--target` and `--image` are mutually exclusive. Image mode must also supply `--total-sectors` or `--total-blocks`.

### State-control codeword gray-level solving mode

The original algorithm, which does not restrict payload positions, is kept as `--algorithm full`, with the alias `exact` also accepted. The old spatial control byte-pool algorithm has been removed; the new mode is enabled with these parameters:

```powershell
dotnet run --project src/DvdImageSolver --configuration Release -- solve `
  --image picture.png `
  --total-sectors 2297888 `
  --output payload.bin `
  --algorithm state-control `
  --bridge-bytes 2 `
  --beam-width 8 `
  --retry-beam-width 32 `
  --retry-frame-fraction 0.25 `
  --batch-frames 8 `
  --batch-candidates 4 `
  --search-lanes 1 `
  --iterations 3
```

state-control treats each 91-byte Sync Frame as one solving segment. EDC, PI, PO, fixed fields and SYNC are still generated exactly and take part in propagating the state, DSV and pit/land boundary; they do not take part in the free-byte search objective but do take part in the final whole-disc visibility score. The program computes the optimal black/white byte pair from `EFMPlus state × input level × current accumulated DSV`. At a target position each active stream only tries the black or white byte matching its current exact state, and each prefix keeps only the best-scoring `--beam-width` paths. Every free segment containing image targets also uses the first and last `--bridge-bytes` payload bytes as control positions, but a control position likewise only chooses among the current DSV byte pairs instead of enumerating all 256 values.

At start-up the program precomputes, for all 65536 16-bit codewords under both the initial pit and land levels:

- the number of lands among the 16 NRZI positions, i.e. 17 gray levels from 0 to 16;
- the pit/land state after the codeword ends;
- the exact DSV increment;
- the leading and trailing zero counts, for RLL boundary checks.

For every possible EFMPlus representation of a byte pair the program computes both the gray-level error and the `|DSV|` after writing that codeword, with the joint cost `worst gray error × 16 + worst output |DSV|`. One gray level is therefore still worth more than 15 DSV units, but the direction and magnitude of the current DSV can change the choice between bytes with similar gray levels. Byte pairs for the commonly used DSV range -256..256 are precomputed; anything outside that range is computed exactly on demand and never truncated. The bytes here are the recording-frame bytes after scrambling and before EFMPlus; the raw payload written into the ISO goes through the scrambling XOR inverse mapping, so its numeric values are not necessarily limited to these.

Inner candidates are scored per EFMPlus codeword and do not expand the 16 channel levels. Each beam path stores Stream 1 and Stream 2 together and never discards one of them early. The SYNC main/sub codes, Stream 1 tie-breaking, accumulated DSV and final boundary are still replayed codeword by codeword with the original encoder's integer rules; the surviving sequence of each Sync Frame is also recomputed with the complete 91-byte word-level encoder so that a substitute SYNC is handled when DSV would overflow. The final result only undergoes a codeword-level majority, gray-level and boundary review; bit-by-bit data is expanded only when `--channel-output` is explicitly requested.

The state-control search uses a strict lexicographic objective: first minimise the free payload's `controlled-majority-error`, then compare `controlled-gray-error` only when the majority-misjudged count is equal, and compare the boundary and DSV only when those are equal too. The primary `majority-error`/`score` in the console and JSON describes the visibility error over all final channel codewords: each Sync Frame contains 2 SYNC codewords and 91 data codewords, and for one ECC block under an opaque image the denominator is fixed at `416 × 93 = 38688`. The primary `gray-error` likewise covers those 38688 codewords. The free-byte search score is stored separately as `controlledScore` and `controlledGrayScore`; all errors are better when lower.

Each outer pass first computes each Sync Frame's controlled majority/gray error exactly from the current full ECC block, then chooses the worst `--retry-frame-fraction` (default 0.25) of frames. It first treats those frames as one cross-block warm-start candidate to escape the random initial solution quickly; no matter how good the local EFM score is, the candidate is accepted only after EDC, PO and PI have been updated and the whole block has been replayed exactly. Candidate ECC updates reuse the current recording frames: only sectors whose payload changed, the affected PO columns and the PI rows are rebuilt, and the self-test confirms byte for byte that this matches a full ECC rebuild. The candidates are then grouped into small batches of `--batch-frames` (default 8), each of which generates and rechecks `--batch-candidates` (default 4) different EFM sequences in parallel. Acceptance requires a strict improvement in the whole-block controlled score. A failed batch is split into successively smaller groups down to a single frame; when a single frame fails, `--retry-beam-width` (default 32) can try once more. A split only continues along the first successful branch, so the whole split tree is not enumerated. A pass stops early when no candidate is accepted. `--retry-frame-fraction 0` processes every erroneous frame in each pass, and `--retry-beam-width 0` disables the single-frame wide-beam retry.

Larger `--beam-width`, `--retry-beam-width` and `--batch-candidates` make it likelier to find a candidate that still holds after ECC feedback, but run time grows roughly with the number of candidate rechecks. A larger `--batch-frames` gives a stronger local improvement per attempt but is more likely to be rejected at whole-block acceptance because of PO/PI feedback; smaller is steadier but needs more full rebuilds. `--iterations`, or `--iterations-per-block` in range mode, is the number of closed-loop passes and defaults to 3. The compatibility alias `--algorithm control` still works; the old `--frame-candidates`, `--parallel-candidates`, `--parallelism`, `--word-candidates` and `--control-bytes` are rejected. `--mutation-bytes` belongs to `full` mode only.

`--search-lanes 1..8` reduces the near-50% error caused by local minima. Lane 1 uses the supplied initial payload and keeps strictly monotonic acceptance; the other lanes restart from independent deterministic payloads derived from `--seed` and may temporarily accept candidates with a worse whole-block exact score, following an annealing temperature from `--initial-temperature` to `--final-temperature`, to cross obstacles created by PO/PI. Every lane always keeps its own best history after exact full-ECC replay, all lanes run in parallel, and the winner is chosen by controlled majority, then gray, then final `|DSV|`, so exploration can never make the final output worse than lane 1. The default of 1 adds no cost. For quality first, try `--search-lanes 4 --iterations-per-block 10` on a small number of sectors; an independent restart changes payloads that the image does not constrain, so keep 1 when specific payload content must be preserved.

`full/exact` means the variable payload positions are unrestricted; it does not mean enumerating the `256^32768` space or guaranteeing a global optimum. An image is first thresholded pixel by pixel with `--image-threshold`; state-control then takes a black/white majority vote over the image samples inside each 16-bit payload codeword, so the target is only pure black 0 or pure white 16, with an 8:8 tie decided by the sample at the codeword centre. The solve first minimises the number of codewords whose actual majority direction is wrong, then uses the distance from the land count to 0/16 as the gray-level error. It does not match the individual bit pattern at each of the 16 positions; if an exact per-channel-bit match is required, use `full`.

### Dispersion single-byte texture mode

`--algorithm dispersion` (alias `byte-pool`) generates the payload directly in the scrambled domain without running a random search:

```text
image brightness   0..127 -> Q = 0xA5 -> fixed 5 transitions -> preview 0
image brightness 128..255 -> Q = 0x92 -> fixed 2 transitions -> preview 255
ISO payload P = Q XOR sector scrambler byte
```

Each payload codeword samples the image at the disc-surface centre of its 16 channel bits and is then banded by the fixed intervals above, so this mode is unaffected by `--constraint-step` or `--image-threshold`; `--image-threshold` only controls the `full/state-control` binary target. ID, IED, all-zero RSV, EDC, PI, PO and SYNC are still generated to the standard; the program does not expand the 619008 NRZI bits but replays codeword by codeword through the complete recording frames, passing the final EFMPlus state, DSV and pit/land exactly into the next ECC block.

#### Tone dithering

The two textures are black and white by themselves, but the image's midtones can mix them proportionally on each payload byte:

```powershell
--tone-dither 1 --tone-levels 2 --tone-brightness 0
```

- `--tone-dither 0..1`: 0 keeps the original `--image-threshold` hard threshold; 1 dithers the threshold byte by byte so gray levels are reproduced through the spatial ratio of black and white codewords.
- `--tone-levels`: DVD has only two textures, so only 2 is accepted.
- `--tone-brightness -64..64`: shifts the gray levels as a whole.

The dither phase is determined by the logical payload byte index and is independent of preview sampling; `simulate` classifies only by `0xA5/0x92` when reading the ISO, so the readback simulation naturally reflects the dithering. With these parameters omitted the output is byte-for-byte identical to older versions.

When all you need is a burnable image as fast as possible and the final EFMPlus boundary is not required, add `--fast-output true`. Fast output still samples the image at the same payload codeword centres and produces the same 2048-byte sectors as ordinary dispersion mode; the difference is that it derives the ISO bytes `P` from `Q` directly with a precomputed 32 KiB scrambler mask, without building Data Frames, EDC, PI, PO or Recording Frames and without replaying EFMPlus, DSV or pit/land state. `exactEccEfmReplay` in the JSON will then be `false` and `finalBoundary` will be `null`. This does not omit any data needed for burning: the recorder still generates those derived fields itself from the 2048-byte sectors.

```powershell
& ".\src\DvdImageSolver\bin\Release\net10.0-windows\DvdImageSolver.exe" solve `
  --image target.png `
  --total-sectors 2297888 `
  --iso-output "R:\full-disc-fast.iso" `
  --fill-sectors 2297888 `
  --lba 0 `
  --psn-offset 0x30000 `
  --inner-radius-mm 24 `
  --outer-radius-mm 58 `
  --channel-bit-nm 133.3 `
  --algorithm dispersion `
  --fast-output true `
  --fast-parallelism 0 `
  --initial zero
```

`--fast-parallelism 0` generates independent ECC block payloads in parallel across logical processors and then writes them into the image in LBA order; it can also be set to `1..64` to limit CPU use. Parallelism changes neither byte selection nor output order.

When hardware acceleration is available, fast file output and streaming output enable four-point double-precision SIMD sampling by default. Each group still uses four actual payload codeword centres and never treats a position across SYNC/ECC as a consecutive evenly spaced sample. Cubic track pitch shares one segment lookup between the inversions of the same segment and vectorises the original four Newton/Hermite evaluations; crossing segments and boundaries falls back to scalar geometry. Fully opaque black and white images use vector sine and cosine, while points near a half-pixel boundary or the image edge are recomputed on the original scalar path; ordinary grayscale, colour and translucent images keep the original scalar trigonometry and interpolation and only the cubic track-pitch geometry is accelerated. Constant track pitch, analytic pattern callbacks and machines without SIMD hardware keep scalar sampling. The four-point path for constant track pitch shows a performance regression in current measurements, so it is not enabled yet. `double` is used throughout; no single-precision coordinates or approximate spiral formulas are used.

When calling the generation API, set `MultiBlockSolveOptions.UseSimdSampling = false` to use the scalar reference path, which makes performance and output comparison easy; the default is `true` and no existing GUI or command-line parameter needs changing. Regressions cover payload/count consistency between the two sampling paths, cubic track-pitch segment boundaries, half-pixel boundaries, the alpha threshold, both spiral directions and parallel output order. Throughput should be timed on the actual payload bytes for the same input and LBA range; the speed-up of the trigonometry alone does not represent the speed-up of the whole disc.

For constant track pitch the fast inverse cache stores the radial integral, radius squared and track-pitch coefficients that stay fixed once solving completes, and reuses the same square root in one Newton correction. That path keeps the original `double` operation order, division and boundary behaviour and uses neither approximate integrals nor multiplication by a reciprocal instead of division. An independent legacy-formula regression compares radius, angle and short-spiral boundaries bit for bit; performance comparisons must use independent engines from before and after the optimisation, because both sides of the `UseSimdSampling` switch use this scalar optimisation.

`payload-transition-class-error=0` means every controlled payload byte was correctly assigned to the two-level `0xA5/0x92` class; it does not mean the fixed fields, ECC and SYNC have the same transition density. `dispersionPool.levels` in the output JSON records the two input ranges, the Q bytes, the transition counts and the nominal preview brightness; those preview values are not the same as real-disc reflectivity.

The output consists of:

- `payload.bin`: 16 2048-byte sectors concatenated in order;
- `payload.bin.json`: PSN, initial/final boundary state, errors, iteration counts and elapsed time;
- an optional `channel.bin`: the 77376-byte packed NRZI levels.

## Outputting a burnable ISO

`solve` can output only the ISO, or additionally keep the 32768-byte payload:

```powershell
dotnet run --project src/DvdImageSolver --configuration Release -- solve `
  --image picture.png `
  --total-sectors 2295104 `
  --iso-output solved-disc.iso `
  --lba 0 `
  --iterations 10000
```

Image mode reuses `--total-sectors` directly as the ISO's logical sector count. With a text constraint, `--iso-sectors` must be given separately:

```powershell
--target target.txt --iso-output solved-disc.iso --iso-sectors 2295104
```

A newly created image contains a minimal ISO9660 file system and a `SOLVED.BIN` file, and the 16 solved 2048-byte sectors are written to `--lba ... --lba+15`. When the LBA is 0 those data live in the ISO9660 system area, so the program also places a visible copy of `SOLVED.BIN` in the file system's data area. On NTFS, which supports sparse files, the new image uses sparse storage where possible; its logical length is still `total-sectors × 2048`, and the holes a burning tool reads are all zero.

You can also replace 16 consecutive sectors inside an existing ISO:

```powershell
dotnet run --project src/DvdImageSolver --configuration Release -- solve `
  --image picture.png `
  --total-sectors 2295104 `
  --iso-template original.iso `
  --iso-output solved-disc.iso `
  --lba 32 `
  --iterations 10000
```

The template size must be a multiple of 2048; in image mode its sector count must also equal `--total-sectors`. Replacing sectors already allocated to directories, files or UDF/ISO metadata corrupts the original file system, so template mode should target a reserved region or an extent already occupied by the intended file. Creating a minimal ISO refuses to overwrite the fixed ISO9660 volume descriptor sectors 16 and 17.

The ISO holds 2048-byte user data, not the 619008-bit raw channel stream. A standard DVD recorder regenerates ID, EDC, ECC, EFMPlus and NRZI itself, so the actual pattern also depends on whether the drive follows the same encoding choices and on whether the initial state, DSV and pit/land passed to the solver match the real burn boundary.

### Filling the whole disc or a specified sector count

When `--fill-sectors` exceeds 16, the program solves contiguous ECC blocks one after another starting at `--lba` and passes each block's final state, DSV and pit/land on to the next. The sector count must be a multiple of 16. For a disc with 2297888 sectors the whole-disc command is:

```powershell
dotnet run --project src/DvdImageSolver --configuration Release -- solve `
  --image picture.png `
  --total-sectors 2297888 `
  --iso-output full-disc.iso `
  --fill-sectors 2297888 `
  --lba 0 `
  --psn-offset 0x30000 `
  --inner-radius-mm 24 `
  --outer-radius-mm 58 `
  --channel-bit-nm 133.3 `
  --constraint-step 16 `
  --algorithm state-control `
  --bridge-bytes 2 `
  --beam-width 8 `
  --retry-beam-width 32 `
  --retry-frame-fraction 0.25 `
  --batch-frames 8 `
  --batch-candidates 4 `
  --search-lanes 1 `
  --iterations-per-block 3 `
  --initial-state 1 `
  --initial-dsv 0 `
  --initial-level land
```

For only the first 1600 sectors, change it to:

```powershell
--fill-sectors 1600
```

The output file then contains sectors 1600 from LBA 0 to 1599; `--total-sectors` still describes the whole disc's capacity and is used to compute the track geometry. If `--lba` is not 0 the output also keeps the preceding all-zero sectors, so the image length is `(lba + fill-sectors) × 2048`.

Range mode overwrites every specified sector, including the ISO9660 descriptors, so the output is a directly burnable raw 2048-byte-per-sector image rather than a mountable ISO9660 file system. `--constraint-step` is the image sampling interval for the free payload search; state-control takes a majority vote over the binary samples falling inside the same payload codeword. The final visibility score is not limited by that sparse step — it resamples the image at the centre of every 16-bit channel codeword and includes the derived, fixed and SYNC codewords. To maximise the light/dark contrast on the disc surface with a binary image, `--constraint-step 16` is recommended, giving one target per payload codeword; `32` is a faster compromise with half the density, and `256` constrains only about 1/16 of the payload codewords, so the overall majority error usually ends up near random. The whole disc has 143618 ECC blocks, so measure speed and quality on 160 to 1600 sectors before a full run.

Dispersion mode always samples the image at every payload codeword centre and ignores the sparse-search meaning of `--constraint-step`, so that parameter can be omitted.

## Mixed file-and-artwork mode

Supplying `--data-dir` enables mixed mode. The program writes that directory and its subdirectories recursively as a standard ISO9660 + Joliet file system. `--file-position inner` (the default) places the files on the inner ring with the artwork outside them; `--file-position outer` places the file content at the end of the disc and the artwork after the leading metadata and before the files. The artwork start and end boundaries are aligned to 16-sector ECC blocks, the whole-disc geometry is always preserved, and the remaining artwork area is never stretched to fill the disc. The resulting ISO opens like an ordinary data disc in Windows and similar systems, and the Joliet directory preserves Chinese filenames.

```powershell
dotnet run --project src/DvdImageSolver --configuration Release -- solve `
  --image picture.png `
  --data-dir ".\disc-files" `
  --file-position outer `
  --iso-output hybrid-disc.iso `
  --total-sectors 2297888 `
  --volume-label MY_DISC `
  --inner-radius-mm 24 `
  --outer-radius-mm 58
```

Mixed mode defaults to `--algorithm dispersion --fast-output true`, which suits generating the whole outer ring directly. `--fast-output false` can also be given explicitly: the program then encodes and replays all the inner-ring data blocks first to obtain the EFMPlus state, DSV and pit/land entering the outer ring, and then draws the artwork with exact boundaries. Exact replay takes longer as the inner-ring data volume grows.

The "Files on Disc" area on the GUI Design page can select a folder and switch "File Position: inner ring / outer ring"; the Export page shares the setting. The option is saved with the project and is also used for streaming burn. The streaming path always uses fast dispersion: it scans the directory and fixes the layout first, then emits metadata, file area and artwork area in disc order without creating a complete temporary ISO; in outer-ring mode it writes the artwork first and then the files. If a source file changes size after the layout is fixed, streaming write refuses to continue. The preview marks the file-system area in yellow, and that colour never enters the written data.

This mode does not accept `--lba` or `--fill-sectors`; both are computed automatically from the file layout and disc capacity. `--drawing-start-lba N` leaves extra space after the default artwork start, but must stay inside the drawable area and, together with `--psn-offset`, align to 16 sectors. `--file-position outer` must be used together with `--data-dir`.

The current ISO9660 writer supports recursive directories and Joliet Unicode names; a single file cannot exceed 4 GiB, and to avoid link cycles and accidental references to data outside the directory, reparse points and symbolic links are not accepted inside `--data-dir`.

## Radius calibration preview

The calibration program borrows the CD version's forward projection approach: it samples in order along global channel positions, reading the target image at each position on the "spiral assumed at generation time" and then projecting it onto the "guessed actual spiral". When several track samples land on the same output pixel they are averaged, which preserves the real phase accumulated from the track-pitch difference while avoiding the bubble-like moiré that per-output-pixel nearest-track inversion produces.

```powershell
dotnet run --project src/DvdImageSolver --configuration Release -- calibrate `
  --image picture.png `
  --output calibration-preview.png `
  --total-sectors 2297888 `
  --generated-inner-radius-mm 24 `
  --generated-outer-radius-mm 58 `
  --actual-inner-radius-mm 24.2 `
  --actual-outer-radius-mm 57.8 `
  --channel-bit-nm 133.3 `
  --spiral-direction ccw `
  --image-threshold 128 `
  --alpha-threshold 1 `
  --preview-size 2048 `
  --samples-per-sector 16
```

`--samples-per-sector` controls the forward projection density, ranges from 1–4096 and defaults to 16; a DVD sector has about 5.16 mm of track length, so 16 is one sample roughly every 0.32 mm. Raising it to 32 or 64 reduces empty pixels and improves detail, with an approximately linear cost in time. The preview offers no arbitrary rotation offset parameter; generation and the actual spiral share the 0° start, and overall rotation does not affect radius calibration. Besides the preview, `calibration-preview.png.json` is written with `mappingMode` set to `forward-channel-splat-average`, recording the sampling density, both track pitches, the total turn count and the track length. It does not include the solver's residual error or differences in recorder implementation.

Calibration previews the whole disc by default. If only part of the image was generated, give the same `--lba` and `--fill-sectors` as the solve command, and the unwritten disc area stays transparent.

## Readback simulation of a generated ISO

`calibrate` takes the source image as input and describes the ideal result of "written with the generation geometry, read back with the measured geometry"; it uses the same two-level boundary of 128 as generation, and `--image-threshold` is kept as a compatibility parameter that does not change that preview. `simulate` instead reads the generated ISO image itself: every sampled payload byte is de-scrambled and classified as `0xA5/0x92`, shown as 0/255 respectively, and then the codeword centres are projected onto the disc surface through the spiral of the measured radii. To inspect older multi-level images, readback still shows `0x66` as 0 and `0xB9` as 85; those values are not used for new image generation. This is the same closed loop as the cdimage calibration dialog — the generation geometry is already fixed inside the ISO, so the simulation needs only one set of measured geometry parameters.

```powershell
dotnet run --project src/DvdImageSolver --configuration Release -- simulate `
  --iso drawing.iso `
  --output readback-preview.png `
  --inner-radius-mm 24.2 `
  --outer-radius-mm 57.8 `
  --preview-size 2048 `
  --samples-per-sector 16
```

When `--total-sectors`, `--lba` and `--fill-sectors` are omitted, they are read from the `drawing.iso.json` written by the solve command (the artwork start LBA and the artwork sector count); without a sidecar they fall back to the whole ISO file starting at LBA 0. `--samples-per-sector` controls how many payload bytes are sampled per sector (1–2048, default 16). Bytes that after scrambling are not in the two-level code table or the legacy-compatible values 66/B9 are skipped and not counted. A file-system prefix can accidentally hit the code table, so the artwork range from the sidecar should be used to exclude it; the ISO itself stores no PI/PO error-correction codes. `readback-preview.png.json` is likewise written next to the output with `mappingMode` set to `payload-scramble-classify-splat`, recording the classification hit count, the track pitch and the total turn count.

The sample position is the codeword centre: the generation side's `FastDispersionImageWriter` places the image target at the codeword centre using `PayloadDirectChannelOffset + 8` (half of a 16-bit codeword), and the readback side uses the same position, so the projections in the two directions cannot differ by 8 channel bits (about 1 µm of track length). Apart from that, readback and generation share the same spiral, direction and scrambler mask, so when the generation parameters and the preview parameters agree the readback image reproduces the generated image sample for sample.

When switching ISO, the Preview workspace reads `imageMapping.totalSectors`, `innerRadiusMm` and `outerRadiusMm` from the sidecar and loads the calibration geometry: an externally imported image is therefore not squeezed into a thin ring by reusing the previous disc size, and the user's later adjustments start from that parameter set.

## The Preview workspace's two modes

The input switch on the Preview page exposes both paths above, and they share the debounce, cancellation and export actions:

- **Image Readback** (readback simulation, `simulate`) takes a generated ISO as input, has only one set of measured geometry parameters, and shows the bytes actually written in the image.
- **Design Projection** (calibration preview, the default, `calibrate`) takes the source image as input and has the generation and measured geometry pair. It never reads the ISO, so refreshing after a parameter change is much faster; the price is that the picture is the source image projected through the measured geometry and does not represent the codewords actually present in the image — neither the solver's error nor the file-system prefix appears in it.

Calibration preview takes the Design page composite directly as input, the same source used to generate the image, so the pattern on both sides agrees.

## Forward encoding only

```powershell
dotnet run --project src/DvdImageSolver --configuration Release -- encode `
  --input payload.bin `
  --output channel.bin `
  --lba 0 `
  --psn-offset 0x30000 `
  --initial-state 1 `
  --initial-dsv 0 `
  --initial-level land
```

The first PSN must be a multiple of 16; otherwise the program refuses to encode, because the input does not start on an ECC block boundary.

## Regenerating the modulation tables

`Encoding/EfmPlusTables.Generated.cs` is generated by mechanically extracting ECMA-267 Annex G. To regenerate it from the specification PDF:

```powershell
python tools/generate_efm_tables.py ECMA-267.pdf src/DvdImageSolver/Encoding/EfmPlusTables.Generated.cs
```
