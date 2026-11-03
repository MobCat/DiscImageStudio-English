# Interface localization

Click the permanent gear-and-"Settings" button at the top right, then under "General → Language" choose Use System Setting, 简体中文, 繁體中文, English, 日本語 or にほんご（ひらがな）; save and restart the app to apply it. The Settings button appears on the home page and in every workspace, and Ctrl+, also opens it; the "…" menu keeps only the About entry. Cancel, Escape or closing the settings window does not save the language. Changing the language does not restart the app automatically, and it neither closes the project nor interrupts jobs.

`language` in `settings.json` is `system`, `zh-CN`, `zh-TW`, `en`, `ja` or `ja-Hira`. Language and theme both follow the system by default; a missing, empty or unsupported language also falls back to following the system, and valid language and theme choices in existing settings are kept. Following the system uses the system UI language at startup: `zh-TW`, `zh-HK`, `zh-MO`, `zh-Hant` and explicit `zh-Hant-*` use Traditional Chinese; `zh-CN`, `zh-SG`, `zh-Hans` and every other Chinese locale use Simplified Chinese; `ja` and `ja-*` use 日本語 (never the hiragana-only option); English, French and every other locale use English. A change to the system language while the app is running needs a restart to take effect. The theme follows the Windows app colour mode to choose dark or light. The language is independent of `.discproj`; project names, user preset names, layer names, file paths and numeric parsing rules are never translated.

## Adding and maintaining text

Translations live in `src/DiscImageStudio.App/Localization/Catalogs/*.json` and are embedded in the assembly at build time, with no extra runtime dependency. Every key carries `zh-CN`, `zh-TW`, `en`, `ja` and `ja-Hira` text. Traditional Chinese is a separate resource using Taiwan terms such as 「設定」「專案」「檔案」「燒錄」; user data is never converted at run time:

```json
{
  "示例 {0}": { "zh-CN": "示例 {0}", "en": "Example {0}", "zh-TW": "範例 {0}", "ja": "例 {0}", "ja-Hira": "れい {0}" }
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
- Japanese (`ja` and `ja-Hira`) exists only in this fork. When merging upstream catalogs, new keys need both values too, or `LocalizationTests` fails.

## Japanese style

There are two Japanese options. 日本語 (`ja`) is written in casual plain form (no です/ます) with kanji and hiragana. にほんご（ひらがな） (`ja-Hira`) is the simple version: the same casual tone with no kanji at all, simpler words, and spaces between phrases (分かち書き), the usual convention for text written only in kana. Only an explicit choice selects `ja-Hira`; a Japanese system follows to `ja`, and `ja-Hira` uses the Japanese UI culture.

In both, prefer a native word to a katakana loanword and never fall back to transliterating the English into katakana. `ja` keeps katakana for loanwords Japanese software genuinely uses (ディスク, ファイル, フォルダ, プロジェクト, プリセット, レイヤー, セクタ, ディザ, インターリーブ); `ja-Hira` replaces even most of those with plain words and keeps katakana only where there is no everyday alternative (ディスク, ファイル, フォルダ, ドライブ, データ, セクタ, トラック, ボタン, アプリ). Product and format names stay in English: CD, CD-R, DVD, BD-R, Blu-ray, ISO, PNG, WAV, sRGB, LBA. `LocalizationTests` fails if a `ja-Hira` value contains kanji (the 简体中文 / 繁體中文 language names excepted). Keep these terms consistent:

| English | 日本語 (`ja`) | にほんご（ひらがな） (`ja-Hira`) |
| --- | --- | --- |
| Design / Preview / Export / Burn / Calibrate (workspaces) | 図案 / 確認 / 書き出し / 書き込み / 校正 | えづくり / かくにん / かきだし / かきこみ / ちょうせい |
| Project | プロジェクト | さくひん |
| Image | 画像 | え |
| Preview (image) | プレビュー | みほん |
| Streaming burn | 直接書き込み | そのまま かきこみ |
| Recorder | ドライブ | ドライブ |
| Design Projection / Image Readback | 図案の投影 / 完成品の読み戻し | えの うつしこみ / できあがりの よみもどし |
| Readback simulation | 読み戻しの再現 | よみもどしの まね |
| Artwork | 絵柄 | え |
| Composite | 合成画像 | かさねた え |
| Layer | レイヤー | かさね |
| Calibration pattern / record | 校正図 / 校正記録 | ちょうせいようの え / ちょうせいの きろく |
| Rectify (photo) / trace | 補正 / なぞる | ゆがみなおし / なぞる |
| Inner / outer ring, inner / outer radius | 内周 / 外周, 内周半径 / 外周半径 | うちがわ / そとがわ, うちがわの はんけい / そとがわの はんけい |
| Track pitch | トラック間隔 | みぞの かんかく |
| Tone / dither strength / grayscale levels | 濃淡 / ディザの強さ / 階調 | こさ / つぶつぶの つよさ / こさの だんかい |
| Interleaving / deinterleave | インターリーブ / インターリーブ解除 | ならべかえ / ならべかえを もどす |
| Parameters / geometry | 設定値 / 寸法 | せってい / おおきさ |
| Files on Disc | 同梱ファイル | いっしょに いれる ファイル |
| Cache | 一時ファイル | いちじファイル |
| Preset / template | プリセット / ひな形 | ひながた |
| Custom (preset) / Built-in | 自作 / 内蔵 | じぶんの / さいしょから ある |
| Window / sidebar | ウィンドウ / サイドバー | まど / よこの らん |
| Cancel / Browse / Back to Home | やめる / 選ぶ / 最初の画面に戻る | やめる / えらぶ / さいしょの がめんに もどる |
| Use System Setting | Windowsに合わせる | Windowsに あわせる |

The bundled HarmonyOS Sans SC is a Simplified Chinese font, so in both Japanese options the app puts the installed Yu Gothic UI (then Meiryo UI) first and keeps the bundled font as the fallback; see `AppHost.CreateApplication`. Those fonts come with Windows and must not be copied into the repository, because their licence does not allow redistribution. Japanese fonts draw the backslash as `¥`, so paths appear as `C:¥Users¥…`, as they do everywhere on Japanese Windows.

## Verification

`LocalizationTests` checks that every resource is complete in all languages, format arguments, the system language fallback, saving and cancelling settings, and that a failed save does not apply the language. In this fork it also checks that every built-in and manual preset name has a `Fork.json` entry.

```powershell
dotnet run --project src/DiscImageStudio.App -c Release -- ui-snapshot --settings-dialog --language en --output artifacts/settings-en.png
dotnet run --project src/DiscImageStudio.App -c Release -- ui-snapshot --settings-dialog --language zh-CN --output artifacts/settings-zh.png
dotnet run --project src/DiscImageStudio.App -c Release -- ui-snapshot --settings-dialog --language zh-TW --output artifacts/settings-tw.png
dotnet run --project src/DiscImageStudio.App -c Release -- ui-snapshot --settings-dialog --language ja --output artifacts/settings-ja.png
dotnet run --project src/DiscImageStudio.App -c Release -- ui-snapshot --settings-dialog --language ja-Hira --output artifacts/settings-ja-hira.png
```

Snapshots use a one-off settings file and never change the user's settings. To add a language, extend the language normalization and resolution rules, the settings drop-down options, every resource file and the tests together.
