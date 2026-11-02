# License notice

Disc Image Studio is released under the **GNU General Public License v3.0 or later (GPL-3.0-or-later)**; the full licence text is in [LICENSE](LICENSE). This project may be used, modified and distributed under version 3 of the GPL or any later version, and comes with no warranty.

Copyright (c) 2026 Disc Image Studio contributors.

The CD interleaving implementation includes code ported from [CDImage](https://github.com/arduinocelentano/cdimage) and modified; its original author's copyright is Copyright (C) 2008-2022 arduinocelentano, and upstream is licensed under the GPL version 3 or later. The project's overall distribution therefore uses the compatible GPL-3.0-or-later. The affected files retain their provenance and modification notes.

When distributing a modified version or a binary program you must satisfy the GPL's requirements for copyright notices, the licence, modification notes and the corresponding source code. Publishing an EXE/MSIX requires the complete source code and build instructions that correspond to that build; offering only the latest development source, unrelated to the binary, is not enough.

Third-party components and separate resources keep their own licences:

- CommunityToolkit.Mvvm, MahApps.Metro.IconPacks and their dependencies: see the [third-party notices](THIRD-PARTY-NOTICES.txt). The Lucide icons additionally carry ISC terms and MIT terms inherited from Feather.
- The self-contained EXE/MSIX carry .NET 10 and the Windows Desktop Runtime, which keep their MIT licence and upstream third-party terms; the full texts are kept in the same [third-party notices](THIRD-PARTY-NOTICES.txt).
- The HarmonyOS Sans SC font: as a separate font resource it is governed by the [HarmonyOS Sans Font License Agreement](src/DiscImageStudio.App/Assets/Fonts/HarmonyOS-Sans-LICENSE.txt), and this project does not change its licensing.
- The referenced ECMA / ISO standard documents and any images the user imports do not change ownership because of this project's licence.

The app's About page shows the project licence, third-party notices and font agreement offline; these texts are embedded in the assembly and ship with both the single-file EXE and the MSIX. Applicable third-party notices must be retained when redistributing.
