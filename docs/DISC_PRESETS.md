# Editable disc presets

Disc presets come in two layers:

- The built-in layer ships and updates with the app and holds the official presets.
- The user layer lives in the file below and stores only the user's additions, overrides and disabled settings:

```text
%LOCALAPPDATA%\DiscImageStudio\disc-presets.json
```

On first start the program places three editable presets in the user layer: "Custom CD Parameters", "Custom DVD Parameters" and "Custom Blu-ray Parameters". Built-in presets are never copied into the user file, so parameter corrections and new presets take effect automatically after an app update.

The entry point for adding a user preset is the Project Settings dialog: "Save These Parameters as a Preset" first confirms the name in a separate window and then appends the current parameters to the user layer; the New Project template list shows every non-manual preset in the catalog, grouped under "Recently Used", "CD", "DVD" and "Blu-ray".

The Project Settings dialog also lists the presets of the current disc family: choosing another preset overwrites the geometry parameters in the dialog, so a confirmation appears before switching, and cancelling keeps the original parameters and the current selection unchanged. Custom presets in both New Project and Project Settings can be deleted from a context menu, which writes back to the user layer immediately and refreshes the list; editing the JSON directly (adding, renaming, disabling) still requires restarting the program.

## Merge rules

- A user preset with a new `id` is appended after the built-in presets.
- A user preset with the same `id` as a built-in preset fully overrides that built-in preset.
- `disabledCdPresetIds`, `disabledDvdPresetIds` and `disabledBluRayPresetIds` can hide built-in or user presets you do not need.
- When a built-in preset is updated, parameters not overridden by a user entry with the same ID update automatically.

## Adding a DVD preset

Copy an existing object in the `dvdPresets` array and change the `id`, name and parameters. For example:

```json
{
  "id": "verbatim-dvd-r-azo-43533",
  "displayName": "Verbatim DVD-R AZO (43533) (measured)",
  "description": "Verified calibration parameters for Verbatim DVD-R AZO 43533: 23.9914606277-57.9648936579 mm, with 2,297,888 sectors and cubic track-pitch distribution.",
  "totalSectors": 2297888,
  "innerRadiusMm": 23.991460627731737,
  "outerRadiusMm": 57.964893657925366,
  "channelBitLengthNm": 133.3,
  "pitchLinear": -3.9256854319227684E-05,
  "pitchQuadratic": 6.964795915429256E-05,
  "pitchCubic": -4.670918950137523E-05
}
```

A DVD `totalSectors` must be greater than 0 and a multiple of 16 to satisfy ECC block and streaming-burn layout requirements. `channelBitLengthNm` is covered in the next section and is a reserved field.

This Verbatim DVD preset comes from the user-confirmed, verified `calibration-f2f851f7.calibration.json` and keeps the full parameter precision from that record.

`pitchLinear`, `pitchQuadratic` and `pitchCubic` are the three relative shape coefficients of the cubic track pitch, defaulting to 0 for compatibility with older presets. The model is `p(x)=p0*(1+pitchLinear*x+pitchQuadratic*x²+pitchCubic*x³)` with `x=(r-innerRadiusMm)/(outerRadiusMm-innerRadiusMm)`. The full polynomial has four terms; `p0` is computed automatically from the total track length, and the interface shows the actual µm value of all four terms. Track pitch must be strictly positive over the whole `0≤x≤1` interval — checking only the inner and outer boundaries is not enough. Changing any coefficient switches to the unsaved custom state, and reselecting a constant-track-pitch preset such as a built-in one restores zero coefficients.

## Adding a CD preset

Copy an existing object in the `cdPresets` array and change the `id`, name, sector count and inner/outer radii. For example:

```json
{
  "id": "cd-74",
  "displayName": "Standard 74-minute CD",
  "description": "ECMA-130/ISO/IEC 10149 standard speed of 1200 mm/s; 120 mm disc, approximately 74 minutes, with 333,000 sectors (24.5-56.8 mm).",
  "sectors": 333000,
  "innerRadiusMm": 24.5,
  "outerRadiusMm": 56.8,
  "linearVelocityMmPerSecond": 1200
}
```

## Adding a Blu-ray preset

Copy an existing object in the `bluRayPresets` array and change the `id`, name and parameters. For example:

```json
{
  "id": "bd-r-ritek-10x",
  "displayName": "Ritek BD-R 10x (measured)",
  "description": "Measured parameters: inner radius 23.988221 mm, outer radius 58.023235 mm, and 12,219,392 sectors.",
  "totalSectors": 12219392,
  "innerRadiusMm": 23.98822105616562,
  "outerRadiusMm": 58.023234731100764,
  "invertMapping": false
}
```

A BD `totalSectors` must be greater than 0, aligned to 32 and no greater than the single-layer capacity of 12,219,392; the outer radius must not exceed 60 mm. `invertMapping` is the preset 3T/6T polarity and can still be changed in the Design page's tone module after it is applied to a project.

The built-in `bd-r-verbatim-64099` (Verbatim BD-R (64099)) uses the saved "Verbatim 64099" preset from the user file `disc-presets.json`, keeping full precision: inner radius `23.987042157339335` mm, outer radius `57.987960341783236` mm, `12,219,392` sectors, `invertMapping: false`. The GUI and the command line use the same parameters.

## Fixed parameters and reserved fields

The scan velocity, start angle, image outer radius and DVD channel bit length are physical quantities fixed by the scheme; the interface offers no form for them, and generation always uses 1200 mm/s (ECMA-130), 0°, 57.5 mm and 133.3 nm.

They remain in the JSON as fields because these parameters were mandatory in older configuration files, so user files written by older versions must keep working. These values do not take part in the generation calculation.

## i18n compatibility fields

The format already reserves the optional `fallbackLanguage`, `displayNameResourceKey` and `descriptionResourceKey`. The current version still displays `displayName` and `description` directly; when multilingual resources are wired up later, resource keys will be resolved first with the existing text as the fallback, so the JSON structure will not need upgrading again. User presets do not need resource keys.

## Editing rules

- The current top level is `"schemaVersion": 4`, containing `cdPresets`, `dvdPresets`, `bluRayPresets`, the three disable lists and an optional `fallbackLanguage`. The program also accepts `"schemaVersion": 2` and `3`; a missing BD catalog is filled in from the built-in BD templates and the file is upgraded to 4 when saved.
- `id` must be unique within each preset group; `__manual__` is the reserved ID for the interface's "unsaved custom parameters" state and cannot be written into the JSON.
- Only the generation parameters listed in the template may be filled in; other fields are rejected so that image layout or calibration parameters cannot leak into disc presets.
- The radii, `linearVelocityMmPerSecond` and `channelBitLengthNm` must be finite values greater than 0, and the generated outer radius must be greater than the generated inner radius.
- The file accepts `//` and `/* ... */` comments and trailing commas in arrays.
- If the format or a parameter is invalid, the program points out the problem and keeps the last successfully loaded presets, and never overwrites the user file automatically.
