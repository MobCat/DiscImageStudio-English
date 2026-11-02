# Interface localization

Click the permanent gear-and-"Settings" button at the top right, then under "General → Language" choose Use System Setting, 简体中文, 繁體中文 or English; save and restart the app to apply it. The Settings button appears on the home page and in every workspace, and Ctrl+, also opens it; the "…" menu keeps only the About entry. Cancel, Escape or closing the settings window does not save the language. Changing the language does not restart the app automatically, and it neither closes the project nor interrupts jobs.

`language` in `settings.json` is `system`, `zh-CN`, `zh-TW` or `en`. Language and theme both follow the system by default; a missing, empty or unsupported language also falls back to following the system, and valid language and theme choices in existing settings are kept. Following the system uses the system UI language at startup: `zh-TW`, `zh-HK`, `zh-MO`, `zh-Hant` and explicit `zh-Hant-*` use Traditional Chinese; `zh-CN`, `zh-SG`, `zh-Hans` and every other Chinese locale use Simplified Chinese; English, Japanese, French and every other non-Chinese locale use English. A change to the system language while the app is running needs a restart to take effect. The theme follows the Windows app colour mode to choose dark or light. The language is independent of `.discproj`; project names, user preset names, layer names, file paths and numeric parsing rules are never translated.

## Adding and maintaining text

Translations live in `src/DiscImageStudio.App/Localization/Catalogs/*.json` and are embedded in the assembly at build time, with no extra runtime dependency. Every key carries `zh-CN`, `zh-TW` and `en` text. Traditional Chinese is a separate resource using Taiwan terms such as 「設定」「專案」「檔案」「燒錄」; user data is never converted at run time:

```json
{
  "示例 {0}": { "zh-CN": "示例 {0}", "zh-TW": "範例 {0}", "en": "Example {0}" }
}
```

In C#, use `L.T("source text")`, and for interpolation `L.F($"示例 {value}")`, whose resource key is its .NET composite format `示例 {0}`; use `L.Format(key, arguments)` when an explicit resource key is needed. A translation may reorder the arguments but must keep their indices and format specifiers. XAML uses `xmlns:loc="clr-namespace:DiscImageStudio.Localization"` with `{loc:Text ResourceKey}`, resolved when windows and templates are created.

Define a shared phrase once; keys must be unique across all resource files. When the current language has no text for a key the English text is used, and a key that does not exist displays the key itself. At startup the language is initialized before any window or view model is created. Only the UI culture is set and the numeric culture is left alone. Do not translate protocol identifiers, commands, paths or user data, and never use translated text in logic.

The scope is the desktop app interface and application-level messages. Standalone command-line help, low-level encoder diagnostics and third-party or operating-system errors keep their own language, and licence texts stay unchanged.

## How this fork differs from upstream

- Upstream's source text and resource keys are Simplified Chinese. This fork keeps those keys exactly as upstream has them, so a new upstream catalog can be merged key by key, and only replaces the `en` values with this fork's established English wording. When merging an upstream catalog, keep upstream's `zh-CN` and `zh-TW`, take the `en` of new keys from upstream and then align it with this fork's interface terms: Title Case for buttons, headings and toast titles, and ASCII `|`, `...` and `-` in English interface text instead of `·`, `…` and `–`.
- The lower-level modules (Core, CD, DVD, Blu-ray, Burning), the command-line help and the built-in presets in `built-in-disc-presets.json` are English at the source in this fork. Text from them that the app passes through `L.T`, namely the built-in and manual preset names and descriptions and `ProjectJsonStore.FileFilter`, is keyed by its English text in `Catalogs/Fork.json`. That file also holds the few fork-only keys, such as `Fork.UnsavedChangesBeforeClosing`, which let "Save changes to 'Project' before closing?" read naturally in English. When a built-in preset is added or renamed, add or update its entry there; `LocalizationTests` fails if one is missing.
- Diagnostics from the lower-level modules are English whatever the interface language is. Code that inspects those messages, such as the calibration warning checks in `CalibrationViewModel`, matches this fork's English text.
- Text resolved before `L.Initialize` (tests and tools) is English, and `ui-snapshot` renders in English unless `--language` is given.

## Verification

`LocalizationTests` checks that every resource is complete in all languages, format arguments, the system language fallback, saving and cancelling settings, and that a failed save does not apply the language. In this fork it also checks that every built-in and manual preset name has a `Fork.json` entry.

```powershell
dotnet run --project src/DiscImageStudio.App -c Release -- ui-snapshot --settings-dialog --language en --output artifacts/settings-en.png
dotnet run --project src/DiscImageStudio.App -c Release -- ui-snapshot --settings-dialog --language zh-CN --output artifacts/settings-zh.png
dotnet run --project src/DiscImageStudio.App -c Release -- ui-snapshot --settings-dialog --language zh-TW --output artifacts/settings-tw.png
```

Snapshots use a one-off settings file and never change the user's settings. To add a language, extend the language normalization and resolution rules, the settings drop-down options, every resource file and the tests together.
