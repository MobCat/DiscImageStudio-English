# Release guide

## Branch and version policy

Day-to-day development uses `main` plus short-lived feature branches merged through Pull Requests. Fix releases also come from `main`; there is currently no long-lived release branch.

The version is maintained in one place, `Directory.Build.props` at the repository root. The maintainer picks the next version from the nature of the change:

| Change | Version bump | Example |
| --- | --- | --- |
| Backwards-compatible bug fix | patch | `1.0.26` → `1.0.27` |
| Backwards-compatible new feature | minor | `1.0.26` → `1.1.0` |
| Breaking interface, command or file-format change | major | `1.0.26` → `2.0.0` |

For a final release put `A.B.C` in `VersionPrefix` and leave `VersionSuffix` empty; for a pre-release put `alpha.N`, `beta.N` or `rc.N` in `VersionSuffix`, where `N` is a positive integer without leading zeros. For example `VersionPrefix=1.0.27` with `VersionSuffix=rc.1` gives `1.0.27-rc.1` — do not write the suffix into `VersionPrefix`. When promoting a release candidate to a final release, clear `VersionSuffix`.

GitHub Actions reads the full version from the configuration and creates the matching `vA.B.C` or `vA.B.C-rc.N` tag automatically. The published EXE's informational version keeps the pre-release suffix; the file version and assembly version use the four-part `A.B.C.0`. The repository's numeric field is limited to `0..65534` for .NET assembly version compatibility; when submitting to the Microsoft Store the first part must also be greater than `0`, and the MSIX version is `A.B.C.0`.

## GitHub Actions release EXE

### Preparing a release

1. Confirm that the GPL-3.0-or-later licence, the privacy policy and the support contact details meet this distribution's requirements. Keep the tag pointing at the build commit, provide the complete corresponding source code and build instructions for that version in the same Release so the source can be obtained together with the EXE/MSIX, and check that GitHub's automatically generated source archive contains the files needed to build. When upgrading dependencies or the self-contained .NET runtime, update the [third-party notices](../THIRD-PARTY-NOTICES.txt) at the same time. The project licence, third-party notices and font agreement are all embedded in the app and can be viewed offline on the About page; the licensing boundaries are described in [LICENSE-NOTICE.md](../LICENSE-NOTICE.md).
2. On a feature branch, change `VersionPrefix` in `Directory.Build.props` (and set `VersionSuffix` too for a pre-release), and move this round's entries from `Unreleased` in `CHANGELOG.md` into the matching version section. Keep `## Unreleased` for ongoing development.
3. The version section heading must use the form `## [1.0.27] - YYYY-MM-DD` or `## [1.0.27-rc.1] - YYYY-MM-DD`, replacing the date placeholder with the actual release date, and the section content must not be empty. A pre-release and a final release each need a version section that matches its tag exactly.
4. Put the version configuration and the release notes into the same release-preparation PR, confirm the `build` workflow passes, and merge into `main`. That push's change set must include both files and the full version in the configuration must actually change before automatic publishing starts.
5. GitHub Actions runs the checks, creates the version tag automatically and produces a Release draft; the maintainer reviews it and publishes manually.

For a future fix release, for example, set this in `Directory.Build.props`:

```xml
<VersionPrefix>1.0.27</VersionPrefix>
<VersionSuffix></VersionSuffix>
```

and add a non-empty `## [1.0.27] - YYYY-MM-DD` version section to `CHANGELOG.md` with the real date; merging into `main` then creates the `v1.0.27` tag automatically. For a release candidate, set `VersionSuffix` to `rc.1` and write the changelog version as `1.0.27-rc.1`.

### Automatic checks and the draft

`.github/workflows/release.yml` watches changes to `Directory.Build.props` or `CHANGELOG.md` on `main`, but enters the release flow only when that push **modifies both the version configuration and the release notes and the full version changes**. An ordinary code push only runs the normal build checks; adding to `Unreleased` alone or a configuration tweak that does not change the version produces no Release.

The workflow reads the full version from the configuration, validates its format and the matching non-empty, dated changelog section, confirms the release commit belongs to `origin/main`, and reuses the build and regression checks from `build.yml`. Only when everything passes does it build the release EXE, the matching version tag and the draft, so no tag has to be created or pushed by hand.

GitHub Actions builds a Windows x64 single-file EXE containing the .NET runtime, so no separate .NET install is needed. After packaging, the final EXE is placed alone in an isolated directory and run to perform the self-test, the two-sector RAW/WAV generation check and a GUI screenshot check, confirming that downloading the single file is enough; SHA-256 is computed afterwards. The GitHub Release attaches only that EXE, for example:

```text
DiscImageStudio-v1.0.27-win-x64.exe
```

The SHA-256 checksum is written into the Release notes so it can be checked after downloading. The workflow uses the built-in `GITHUB_TOKEN` to create a **GitHub Release draft**, so no personal access token (PAT) has to be configured. A pre-release tag sets the prerelease flag automatically; a final tag creates a final release draft. It never publishes the draft automatically, and never submits to the Microsoft Store or publishes a self-signed test certificate.

The maintainer reviews the version, release notes, EXE and checksum in the draft on GitHub's [Releases page](https://github.com/JiaFeiMiao-K-Cat/DiscImageStudio/releases), downloads it to verify that it starts, and then publishes manually. The SHA-256 of the downloaded file can be computed with the command below and compared with the value in the Release notes:

```powershell
Get-FileHash .\DiscImageStudio-v1.0.27-win-x64.exe -Algorithm SHA256
```

### Retrying a failure and corrections

A failed Actions run can be re-run, or the `release` workflow can be started manually from `main` in GitHub Actions. A manual trigger has no tag input: it reads the current configuration and release notes from `main` and runs all release checks, so retrying needs no further version-file change.

When retrying the same version, an existing tag must point to the same commit as this build and an existing Release must still be a draft. A published Release, tag or artefact must never be overwritten or moved; if a problem is found, fix it on `main` and release a new version, and for pre-release iterations increment the number, e.g. `rc.1` → `rc.2`. If `main` has moved and the same-version tag points at an old commit, re-run the originally failed run or prepare a new version for the new commits. Even a release-notes-only correction must keep the facts and a record of the correction, and must never replace a published binary.

Repository administrators are advised to configure `main` branch protection on GitHub requiring a Pull Request and the `build` required check, and to set up a ruleset for `v*` tags that lets the release workflow create tags but forbids updating or deleting them. Workflow files are not the same as remote protection settings; an administrator has to configure those protections separately.

## Local EXE rehearsal

From the repository root, run the same packaging script GitHub Actions uses:

```powershell
powershell -ExecutionPolicy Bypass -File packaging/Build-Release.ps1
```

The script takes the version from `Directory.Build.props` automatically. With `1.0.26` configured, for example, the output directory is `artifacts/release/v1.0.26/`. The script builds and separately verifies the self-contained `win-x64` EXE and produces `DiscImageStudio-v1.0.26-win-x64.exe` and `SHA256SUMS.txt`; the checksum file serves local checks and the workflow's Release notes and is not attached to the Release. A local rehearsal requires no existing version tag or changelog release section, and creates no GitHub Release; a real release must satisfy all the checks above.

## Microsoft Store MSIX

MSIX is a separate, manual distribution channel. Reserve the product name in Partner Center first, then copy from the Product identity page:

- Package/Identity/Name
- Package/Identity/Publisher
- Package/Properties/PublisherDisplayName

Run locally:

```powershell
powershell -ExecutionPolicy Bypass -File packaging/Build-MSIX.ps1 `
  -IdentityName "Partner Center Identity Name" `
  -Publisher "CN=Partner Center Publisher" `
  -PublisherDisplayName "Publisher display name" `
  -DisplayName "Reserved product name"
```

Without `-Version`, the final version is read from `Directory.Build.props` and converted to `A.B.C.0`. To force a specific Store version, use `-Version "1.0.26.0"`; that override is also applied to the EXE inside the package so the manifest and the program version cannot diverge. The Microsoft Store channel does not accept pre-release suffixes such as `-rc.1`; prepare Store packages from a final version configuration.

You can also start the `package-msix` workflow manually in GitHub Actions and fill in the same values, where an empty `version` likewise reads the repository configuration. That workflow reuses the CI from `build.yml` first and then produces the MSIX as an Actions artefact; it never submits to the Store automatically or attaches the package to a GitHub Release. The resulting Store MSIX may stay unsigned; to test-sideload it, sign it with a certificate whose Publisher matches.

## Locally signed test package

Create a code-signing certificate whose subject matches the test Publisher exactly, and put the public certificate at:

```text
artifacts/certificates/DiscImageStudio-Test.cer
```

Run `Build-MSIX.ps1 -CertificateThumbprint <thumbprint>` with the identity parameters above to produce a signed package. Then double-click `packaging/Install-TestPackage.cmd`, or run:

```powershell
powershell -ExecutionPolicy Bypass -File packaging/Install-TestPackage.ps1
```

The install script asks for administrator rights once, imports the test certificate's public key into "Local Machine/Trusted People", and installs the signed MSIX. Do not commit private keys or PFX files to GitHub, and do not attach a local self-signed test certificate to a real Release.

## Quick unsigned test on Windows 11 (optional)

An unsigned test package must use a separate OID publisher namespace and must not be mixed with the official Store identity. To build a local test package:

```powershell
powershell -ExecutionPolicy Bypass -File packaging/Build-MSIX.ps1 `
  -IdentityName "12345.DiscImageStudioArchitectureTest" `
  -Publisher "CN=Disc Image Studio Test" `
  -PublisherDisplayName "Disc Image Studio Test" `
  -DisplayName "Disc Image Studio Test" `
  -Version "1.0.26.0" `
  -UnsignedDevelopmentPackage
```

Then install it from an administrator PowerShell:

```powershell
Add-AppxPackage -Path ".\artifacts\msix\DiscImageStudio_1.0.26.0_x64_unsigned-dev.msix" -AllowUnsigned
```

`-UnsignedDevelopmentPackage` is only for quick testing on Windows 11 systems that support it; some Windows versions may still reject an executable package even with `-AllowUnsigned`, in which case use the signed test approach above. Do not use this option when preparing a distribution or submitting to the Microsoft Store — a real package still needs the genuine identity from Partner Center.

Before the real submission:

- Repackage with the real identity; a package with the test Identity must not be submitted.
- Test install, uninstall and offline operation on a clean Windows device.
- Run the Windows App Certification Kit on the final package.
- Provide at least one real desktop screenshot at 1366×768 or larger.
- Publish `PRIVACY.md` on a public HTTPS page and fill in genuine support contact details.
- Note in the certification remarks that the app produces large files, needs no sign-in and does not go online, and that it includes an experimental CD/DVD direct-burn feature using Windows IMAPI2; list the applicable devices, blank-media requirements and the current verification scope honestly.
