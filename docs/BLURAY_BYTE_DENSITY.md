# Single-layer BD-R: transition density by byte and bit period

2026-10-24. Based on the supplied ISO/IEC 30190:2021, in particular 13.15–13.18 and Figures 40/41, and on numerical experiments with this project's EDC, scrambling, LDC/BIS, DC and 17PP encoding chain. Single-layer discs only.

**When total transition density is the objective, bit-constructed patterns are worth using.** The best repeating-byte baseline reaches about **19.20% / 38.61%** over a complete cluster; after accounting for physical interleaving and DC-segment boundaries the bit-period schemes measured here reach **15.95% / 43.37%**. The density difference between the two ends grows from 19.41 to 27.42 percentage points, about 41% more. These are results from digital encoding; real-disc reflective brightness and the black/white direction are not yet established. Current artwork uses the **3T / 6T count bias** below as chosen by the user, not the density extremes on this page.

## Wiring artwork through 3T / 6T counts

Using complete clusters of the same 958,272 channel bits, count the **absolute number** of complete gaps between adjacent modulation ONEs that are exactly 3T or 6T. Both marks and spaces count; this is neither the NRZI level duty cycle nor a ranking of `target runs / all runs`.

| Default image end | Scrambled-domain Q | Baseline cluster target runs | Target run share | Target count range over four addresses |
|---|---|---:|---:|---:|
| Dark (0–127), 3T biased | `AA` | 265,136 | 85.4164% | 264,946–265,186 |
| Light (128–255), 6T biased | `44` | 116,575 | 62.6862% | 116,470–116,659 |

Both take the highest target count among all 256 repeating bytes at the baseline PSN `0x100000`. `22` has the highest 6T share at 62.7744%, but only 116,402 6T gaps, which is fewer than `44`, so the count scheme picks `44`. Rechecking at the four addresses `0x100000`, `0x234560`, `0x6D3A00` and `0xCA73E0`, `44` has a mean 6T count of 116,559.5, slightly above `11` at 116,526.5 and `22` at 116,457; that does not mean it is optimal at every address.

Production `BluRayRunLengthMapping` uses a threshold of 128 to choose `AA` / `44`, and the black/white direction can be inverted; `BluRayImagePayloadMapping` samples by image position, and the streaming generator cancels the scrambling before outputting the host payload. Image edges, EDC, ECC, BIS, DC and sync introduce other run lengths, so "3T / 6T biased" is not the same as pure 3T / 6T. The default dark/light assignment is an invertible image convention and has not been calibrated against real-disc reflective brightness.

The numbers above use the current greedy DC diagnostic model; the raw counts are in `Cluster.RunCounts` in `all-bytes.json`. The architecture regression verifies the count bias at both the start and end of the disc through complete RUB encoding, and checks the scrambling and ECC positions of a mixed image. See the [Blu-ray notes](ADDING_BLURAY.md) for the command line and usage.

## Measurement conventions

- Transition density = number of modulation ONEs / number of channel bits. A ONE means one NRZI transition; you cannot substitute the proportion of ONEs among NRZI levels.
- Q is the **target payload after scrambling**. The host payload should be written as `Q XOR scrambler mask`; cycling raw host bytes directly loses the target pattern.
- Pure 17PP results have no DC, ECC, BIS or sync; they are computed exactly with independent standard tables and finite-state cycling.
- A complete cluster is generated from 65,536 host bytes and counts `496 × 1932 = 958272` channel bits, including EDC, LDC parity, BIS, DC and sync; run-in/out/Guard3 are excluded, but the level and DSV at the end of run-in are used.
- The default PSN is `0x100000` with zero address flags and user control data. Candidates are additionally verified at `0x234560`, `0x6D3A00` and `0xCA73E0`.
- Primary results use the current greedy DC diagnostic algorithm, which leaves future control bits at zero for now. It does not guarantee agreement with a recorder's decisions; all-zero, all-one and fixed-seed random DC are extra sensitivity experiments, not actual burning recipes.

## Baseline over all 256 bytes

Repeating one Q byte continuously, the steady state without DC/ECC has only four densities:

| Pure 17PP density | Byte count |
|---|---:|
| 1/6 = 16.6667% | 28 |
| 1/4 = 25% | 92 |
| 1/3 = 33.3333% | 100 |
| 5/12 = 41.6667% | 36 |

Of these, **80 bytes change band after an odd bit offset**. DC bit insertion changes the two-bit parsing phase, so you cannot rank on that bare encoding table alone.

| Q | Pure 17PP | Complete cluster (greedy) | Complete-cluster range over four PSNs | Test use |
|---|---:|---:|---:|---|
| `09` | 16.6667% | 19.1997% | 19.1962–19.2080% | lowest repeating byte in the scan |
| `11` | 16.6667% | 19.4820% | 19.4447–19.4820% | pure encoding is all 6T; long-run control |
| `22` | 16.6667% | 19.3505% | 19.3242–19.3510% | also in the robust low-density group |
| `3D` | 41.6667% | 38.4602% | 38.4428–38.4739% | robust high-density byte |
| `7A` | 41.6667% | 38.5486% | 38.5409–38.5525% | robust high-density byte |
| `9E` | 41.6667% | 38.6143% | 38.6014–38.6260% | highest repeating byte in the scan |
| `00` | 33.3333% | 32.8615% | 32.8412–32.8668% | common input control |
| `FF` | 33.3333% | 32.5332% | 32.5332–32.5639% | does not differ much from `00` |

`55/AA` complete clusters are about 32.30% / 32.39%, so they suit neither density extreme. Without cancelling the scrambling, all 14 constant host candidates measured land at about 29.37–29.67% and the original differences mostly disappear.

All results: [CSV](../artifacts/bluray-byte-density/all-bytes.csv), [readable table](../artifacts/bluray-byte-density/all-bytes.md), [256-byte density chart](../artifacts/bluray-byte-density/all-bytes-density.png).

## Finer-grained reachable patterns

17PP encodes with variable-length rules over 2/4/6/8 input bits plus the previous modulation bit and special substitution rules. A byte is only a carrier and cannot be treated as an independent codeword.

| Raw periodic bit string | Period length | Byte packing sketch | Pure 17PP density | Steady-state runs |
|---|---:|---|---:|---|
| `0001` | 4 | `11` | 16.6667% | all 6T |
| `00111101` | 8 | `3D` | 41.6667% | three 2T, two 3T |
| `001111` | 6 | `3C F3 CF` | 44.4444% | three 2T, one 3T |
| `0000101101110010` | 16 | `0B 72` | **12.5%** | all 8T |
| `0111011110` | 10 | `77 9D E7 79 DE` | **46.6667%** | six 2T, one 3T |

Ordinary 17PP data runs are 2T–8T with at most six consecutive 2T. The density lower bound for a long data stretch is therefore `1/8` and the upper bound is `7/(6×2+3)=7/15`; the 16-bit and 10-bit patterns above reach them respectively. Sync contains 9T, so those bounds cannot be applied directly to any short window that includes sync.

Both extreme periods degrade to 29.1667% / 33.3333% at an odd bit phase. The 6-bit `001111` is 44.4444% at both phases, but its bare NRZI duty cycle is 4/9 or its complement, so DC control has to balance it. Among searches over periods of at most 16 bits it is the highest-density pattern that is robust at both even and odd phases.

The packing sketch only shows how to express the period. **Neither these host bytes nor a loop over Q in the original payload order (ignoring interleaving) may be cycled directly.** For example, filling Q in payload order for the 6-bit period gives only about 33.43–34.39% over a complete cluster; arranging it in physical ECC order reaches about 40.64–40.75%.

## DC compensation and complete-cluster results

Each frame has 155 ECC bytes, i.e. 1240 raw bits; the first 25 are data bits and one DC bit is inserted after every 45 data bits, 28 in total. Let `j=8×EccColumn+bitWithinByte`, where bit 0 is the MSB:

```text
DCbefore(j) = j < 25 ? 0 : 1 + floor((j - 25) / 45)

Reserved DC slot:
index = RecordingFrame × 1268 + j + DCbefore(j)
Qbit = pattern[(index + phase) % period]

Restart per DC data segment:
index = j < 25 ? j : (j - 25) % 45
Qbit = pattern[(index + phase) % period]
```

After DC insertion, every segment starts on an even input bit, so restarting the period keeps the two-bit parsing phase. The reserved-slot scheme only reserves positions; the DC bit values are still chosen by the encoder/recorder. EDC, BIS and parity cannot be controlled arbitrarily either and are generated normally.

After constructing Q at these physical positions, scatter it back to the matching payload bytes and cancel the scrambling. The project's existing `Map(luminance, position)` already provides RecordingFrame/EccColumn; generating eight bits bit by bit within a single call is enough, and the return value need not be restricted to a fixed byte.

| Recommended bit pattern | Construction | Phase | Complete cluster (greedy) | Four-PSN range | Range under the other three DC strategies |
|---|---|---:|---:|---:|---:|
| 16-bit `0000101101110010` | DC-segment restart | 2 | **15.9500%** | 15.9405–15.9500% | 15.9278–17.0720% |
| 6-bit `001111` | reserved DC slot | 3 | **40.8172%** | 40.8158–40.8315% | 41.0010–41.4603% |
| 10-bit `0111011110` | DC-segment restart | 4 | **43.3670%** | 43.3662–43.3713% | 42.1870–43.3904% |

Phase starts at 0 and is the periodic offset added to the coordinates above. Every cluster restarts from the coordinate origin; these phases apply only to that construction and are not the same as moving the whole physical signal by that many bits.

Across all phases the 6-bit scheme gives 40.7929–40.8172% over a complete cluster, so phase matters little. The extreme 16-bit and 10-bit schemes still need their chosen phase; a wrong phase can fall back to about 30%–32%. The DC sensitivity interval is only the range of these measured strategies, not a guaranteed interval for any recorder.

In the recommended low mode, **52.65% of complete inter-transition runs are 8T**; in the recommended high mode **79.14% are 2T**. That gives a more concrete real-disc comparison than average density alone. Both sit near 50% NRZI level share in the greedy model, so bit values 0/1 cannot be read directly as visual black and white.

![Complete-cluster density comparison](../artifacts/bluray-byte-density/fine-pattern-comparison.png)

## First-round real-disc candidates

It is worth comparing the following solid blocks on the same disc, at the same burning speed and under the same viewing conditions, repeated at the inner, middle and outer radii:

1. Sparse end: 16-bit period, DC-segment restart, phase 2.
2. High-density end: 10-bit period, DC-segment restart, phase 4.
3. Robust high-density control: 6-bit period, reserved DC slot, phase 3.
4. Byte baselines: `09`, `11`, `9E`; `00` can serve as an ordinary input control.

Compare the actual light and dark, and its stability as the viewing angle changes, with large blocks first, then move on to mixing regions and mapping images. Alternating the two modes byte by byte changes the encoding context, and its density or brightness should not be assumed to be the linear average of the two ends. These density-extreme candidates have not been burned to a real disc, and they are not used by the current default black and white mapping.

## Verification and reproduction

- An independent Python implementation transcribed from standard Figure 41 is bit-for-bit identical to C# for 256 four-byte vectors and 298 period vectors.
- Exhaustively testing all 131,068 raw bit strings of length 2–16 with both preceding bits gives 262,136 exact cycling evaluations; 14,694 two-bit rotation equivalence classes were verified. The phase-robust optimum above is limited to that search range.
- The complete chain is scanned over all 256 bytes; synthetic frames additionally check 8 DC masks × 31 sync positions × 2 previous-frame terminations per byte.
- Fine patterns cover 176 pattern/layout/phase combinations plus 120 address-recheck clusters. Every cluster verifies that its 65,536 controllable Q bytes land at the real ECC positions matching the target.
- Cluster length, run-count conservation and RLL spacing checks pass; the fast cluster scan and the complete RUB path agree. Pure data has no complete runs outside 2T–8T; clusters containing sync may contain 9T.

Tools and commands are in [BluRayByteProbe](../tools/BluRayByteProbe/README.md). The raw results are in `artifacts/bluray-byte-density/`, where the artifacts directory is ignored by the repository rules; the scripts can rebuild the results. Production already uses the 3T / 6T count mapping described separately on this page.
