# Review of the CD / DVD generation physical model

Review date: 2026-09-21. The subject was the `DiscImageStudio-GitHub` working copy at the time (including the not-yet-committed calibration implementation), baseline commit `6c55a18`. This round did only standard cross-checking, source auditing and independent numerical verification; no generator, preset or burning behaviour was changed.

## Conclusion

No calculation error was found in the basic spiral formulas or the DVD sector length. The current model, however, cannot accurately predict the angle on a real disc surface from nominal standard parameters: the default CD parameters have a geometric consistency problem; single-curve calibration at fixed linear density absorbs density error into the radii; and neither the finite-stream boundary of CD interleaving nor the reference timing enters the geometric model. There is also no check that the type of recordable disc matches the generation model.

This audit alone cannot determine the sole cause of the bowing on any particular real disc, and the DVD bit length should not simply be changed to a different nominal value as a fix.

## Standards basis and scope

- Official [ECMA-359, 1st edition, 2004](https://ecma-international.org/wp-content/uploads/ECMA-359_1st_edition_december_2004.pdf): single-layer DVD-R, mainly checking §§10.7–10.9, 18–23 and 24.2. The original pages 28, 29, 52 and 56 of the PDF were checked.
- Official [ECMA-267, 3rd edition, 2001](https://ecma-international.org/wp-content/uploads/ECMA-267_3rd_edition_april_2001.pdf): DVD-ROM, mainly checking §§10.6 and 18–21. It cannot replace the rules for all recordable media.
- Official [ECMA-130, 2nd edition, 1996](https://ecma-international.org/wp-content/uploads/ECMA-130_2nd_edition_june_1996.pdf): CD-ROM geometry and the common CIRC encoding reference, §§8.6, 11.3–11.4, 19.4 and Annex C. An audio track is not the same as a CD-ROM data track.
- Official [ECMA-394, 1st edition, 2010](https://ecma-international.org/wp-content/uploads/ECMA-394_1st_edition_december_2010.pdf): CD-R, multi-speed recording, pre-groove and Red Book compatibility, §§1.2 and 2.4–2.5. That document states some geometric requirements by reference to the Red Book and does not restate the complete CD geometry table directly.

The key ECMA-359 constraints are below; all are standard requirements and cannot be read as measured values for any particular disc:

| Item | Constraint | Clause |
|---|---|---|
| Data start radius | 23.9–24.0 mm | 10.7.1.2, stated as a 48.0 mm diameter with −0.2/+0.0 mm tolerance |
| 12 cm disc data end radius | no more than 58.0 mm | 10.7.1.2 |
| Average track pitch | 0.74 ± 0.01 μm | 10.8 |
| Local track-pitch deviation | maximum ±0.03 μm relative to 0.74 μm | 10.8 |
| Average channel bit length | 133.3 ± 1.4 nm | 10.9 |
| First PSN of the data area | 0x030000, physical sectors contiguous with no gaps | 24.2 |

ECMA-267's lower bound for the data start diameter differs from DVD-R's: §10.6.1 gives 48.0 mm with a −0.4/+0.0 mm tolerance. The start tolerances of the two standards must not be mixed.

## Parts confirmed correct

A DVD sector holds `13 × 2 × (32 + 1456) = 38688` channel bits, i.e. 619008 bits per 16-sector ECC block. `DvdEccBlockEncoder.cs:8` uses the correct value; no general length miscalculation was found in the sector offset, sync frames or PO row interleaving.

The current track length is:

```text
CD:  L = (N / 75) × v                         [mm]
DVD: L = N × 38688 × channelBitLengthNm × 10^-6 [mm]
```

`CdDiscParameters.cs:59–75` uses the equal-pitch area approximation, while `ArchimedeanSpiral.cs:33–70,115–120` uses the exact arc length. The approximate relations are `pitch = π(ro²−ri²)/L` and `θ = 2L(r−ri)/(ro²−ri²)`. The whole-disc angle difference between the CD approximation and the exact spiral is about 0.000135°, which cannot explain a bow visible to the eye. No error was found in the DVD exact-arc-length inverse solve, the nanometre-to-millimetre conversion, or the default image coordinate direction.

DVD-R linking serves specific incremental-append situations; §24.2 states explicitly that sectors are contiguous. There is no basis for appending a supposedly hidden gap to every ECC block.

## Finding 1: the default CD 80-minute preset's parameter combination is implausible

`src/DiscImageStudio.Core/Presets/built-in-disc-presets.json:6–12` uses 359849 sectors, 24.5–56.8 mm and 1200 mm/s at the same time. Solving back through the actual generation formulas:

| Preset | Implied track pitch (μm) |
|---|---:|
| CD 80-minute default | 1.432856 |
| CD 74-minute default | 1.548384 |
| Ritek Aqua CD measured-radius preset | 1.492598 |
| Verbatim CD measured-radius preset | 1.500257 |
| DVD 12 cm default | 0.739837 |
| Verbatim DVD-R measured-radius preset | 0.738304 |

ECMA-130 §11.3 gives a track pitch range of 1.5–1.7 μm, and §11.4 gives a reference scan velocity range of 1200–1400 mm/s. The CD80 default combination clearly cannot serve as a general accurate preset within that geometric range. Its 24.5 mm start also cannot be equated directly with the §8.6 user data area start (24.8–25.0 mm).

This is a check of the software's parameter combination, not a judgement that the user's CD-R discs are out of spec. Presets marked as measured still fix the scan velocity at 1200 mm/s, which does not mean the linear density was measured too. User-measured radii must not be altered just to fall inside the standard range.

## Finding 2: standard tolerances are far larger than the cumulative angular accuracy artwork needs

`ImageTargetMapper.cs:58–77` and `FastDispersionImageWriter.cs:345–365` solve for a constant track pitch from the capacity, the two radii and a fixed bit length. The DVD defaults produce about 45956.06 turns. The standard allows local track-pitch variation, and 58 mm is an upper bound, so these inputs can only form an initial model.

Numerical sensitivity (each row changes one input with everything else held constant, as a model comparison):

- Changing the DVD bit length by 10 ppm changes the whole-disc cumulative angle by about 165.44°.
- Changing the DVD bit length from 133.33 to 133.3 nm changes the cumulative angle by about 10.34037 turns.
- Increasing the DVD inner or outer radius by 0.001 mm changes the cumulative angle by about −201.76°.

Those values are model phase differences, not measured errors on a real disc. 133.33 nm is inside the standard tolerance; 133.3 nm is also not the truly exact bit length of every disc. Blindly substituting a nominal value can change the generation result significantly.

## Finding 3: a single radial line cannot independently confirm the radii and the linear density

`CalibrationTarget.cs:468–473` fixes the linear velocity / bit length, and `CalibrationCrossFitter.cs:73` fits only the two radii and the overall rotation; the current flow does not use the concentric circles' source-radius correspondence.

An independent counter-example: with the generation model for DVD `(ri=24, ro=58, bit=133.33)`, assume the real model is `(24,58,133.3)`. Keeping the fitted bit length at 133.33 and changing only the candidate radii to about `(24.00540257,58.01305620)`, then adjusting the overall rotation, reproduces the same bowed line almost exactly across 25–57 mm (maximum phase residual about 2.04×10^-10 rad from an exact 2049-point arc-length computation). The candidate lies inside the default ±0.02 mm search range. This is a forward verification of an analytically constructed candidate; it does not claim the current optimiser necessarily returns that candidate.

A low residual can therefore simply be reinterpreting a bit-length error as a radius error. The current feature produces useful compensation parameters, but the result should be read as "equivalent parameters under the fixed-linear-density assumption". Confirming the true physical radii and density requires adding rings of known source radius, known data positions or an independent boundary measurement; merely opening one more fitted parameter still does not fix the lack of information.

## Finding 4: the CD interleaving compensation has a finite-stream boundary effect, and the physical timing origin is unverified

The delay table in `CddaInterleaver.cs:8–16` matches the data paths of ECMA-130 Figure C.4 and is not an incorrect repeated interleaving. An independent label simulation fed the existing compensated PCM into the standard forward CIRC's 24 data paths: all 20856 steady-state data positions agreed in a 10-sector test, but the combined result lags the target pattern by 111 frames overall.

Two things must be kept strictly apart:

- **A definite finite-stream phenomenon:** initialisation produces 1332 zero placeholder bytes; 1332 target bytes scattered across the last 108 frames are never emitted. The Flush in `CddaInterleaver.cs:46–55` handles only the sector tail and does not drain the ring buffer on whole-sector input. This affects the pattern boundary.
- **A conditional physical offset:** the 111 frames is the combined delay under the Figure C.4 reference timing, about 15.102 ms, or about 18.122 mm of arc length at 1200 mm/s. Unless it is cancelled by the timing origin of the burning chain, the angular difference varies with radius and cannot be removed with the start angle alone. Its relation to ATIP, INDEX 01 and the real disc's data start has not been measured, so it must not be claimed directly as a confirmed real-disc offset.

`CdTrackGenerator.cs:229–246` samples by `globalByte` without the timing above, and geometric calibration likewise excludes that encoding stage. The existing compatibility notes already state that the preview does not simulate complete CIRC/EFM. End-to-end physical timing verification is still needed; agreement between generation and preview from the same source does not by itself prove the position on the disc surface is correct.

## Finding 5: the recordable media type is not matched to the model

`WindowsImapiBurner.cs:151–166,377–390` checks only IMAPI support, blank state and capacity, and never queries the actual physical media type. The generator, however, uses a single-layer ID (`DvdDataFrameBuilder.cs:41`) and a single-layer one-way spiral.

This lacks active rejection of different physical formats such as dual-layer DVD and DVD-RAM. IMAPI being able to write to some media does not mean the current artwork model applies; whether writing can actually start still depends on the device and its state. Dual-layer layer switching, the second layer's direction and its bit length are not modelled.

Microsoft's [CurrentPhysicalMediaType](https://learn.microsoft.com/en-us/windows/win32/api/imapi2/nf-imapi2-idiscformat2data-get_currentphysicalmediatype) and the [physical media enumeration](https://learn.microsoft.com/en-us/windows/win32/api/imapi2/ne-imapi2-imapi_media_physical_type) can be used for the matching check.

## Suggested order of fixes

1. Add an implied track-pitch check to presets, distinguishing standard initial values, measured values and values obtained by compensation; deal with the CD80 default combination first. State clearly which data position the start and end radii refer to, and separate the artwork crop range from the track anchor.
2. Verify the joint timing of CD interleaving, the audio track start and the burning chain; then correct the sampling offset and the head/tail strategy while keeping the final sector count unchanged.
3. Add an independent radial or data-position constraint to calibration. Only if the measured residual still shows systematic local bowing should a varying-track-pitch/phase correction model be evaluated.
4. Check before writing that the actual media type and capacity match the selected model.

No real-disc burning or optical brightness measurement was performed here. Verification covered the standard text and original pages, formula recomputation, exact-spiral numerical comparison, the parameter-unidentifiability counter-example and the CIRC data-path label simulation; these checks are not extended or claimed to be a complete optical simulation or real-disc accuracy certification.

The audit reproduction material is in `tmp/standards-audit/` at the working copy root: `circ-audit.py`, `circ-audit-result.json`, `geometry-audit.py`, `geometry-audit-result.json`, plus extracted text and key original pages of the two user PDFs.
