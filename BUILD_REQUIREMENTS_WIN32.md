# Last Chaos June 2015 — Windows x86 build requirements

This source tree is a legacy Visual C++ 2010 project. The GitHub Actions build is **experimental** and does not yet prove that the resulting client runs against any particular server.

## Verified in GitHub Actions
- Windows 2022 + Visual Studio MSBuild (Win32) and v143 compatibility setting
- winflexbison3 for the Ecc parser tool; Ecc compilation has passed
- Boost thread, format, multi-index, bind, function, smart-ptr, Asio (x86-windows via vcpkg)
- **Direct3D 8 and D3DX8** are both required. A modern Windows SDK does not supply the full legacy headers/libraries.
- Build targets in `Build_2010.sln` include `Engine/Engine_2010.vcxproj` and `Nksp/Nksp_2010.vcxproj`.

## Required historical DirectX material
- Direct3D 8: `d3d8.h`, `d3d8types.h`, `d3d8caps.h`, `d3d8.lib`
- D3DX8: `d3dx8.h`, `d3dx8core.h`, `d3dx8tex.h`, `d3dx8math.h`, `d3dx8math.inl`, `d3dx8mesh.h`, `d3dx8shape.h`, `d3dx8effect.h`, `d3dx8.lib`; includes `dxfile.h`
- According to the apitrace DirectX SDK reference, **October 2004** is the last SDK that contains D3DX8. The June 2010 SDK is **not** a replacement for D3DX8.
- The experimental workflow retrieves a pinned 8.0 SDK archive into the CI runner **for build only**. No SDK files are committed into this repository or uploaded as artifacts. The archive is independently mirrored, is not an open-source implementation, and remains subject to its Microsoft EULA. Provenance, licensing, compatibility and runtime behavior still require validation.

## Other library dependencies present in the tree
- Lua 5.1, TinyXML, zlib, libpng, plus prebuilt Win32 libraries in `Lib/VC100`.
- Existing `Lib/VC100` and other old binaries may have MSVC 2010 CRT/linker dependencies not compatible with modern MSVC. This is unverified until the full build reaches linking.

## X-Trap
- The compile-time `XTRAP_SECURE_CKBANG_2010_07_20` feature was disabled in the region headers for this branch.
- That does not in itself validate a running X-Trap-free client. `Nksp/xTrapWrapper.cpp` is still listed in the project, but its implementation is guarded by `#ifdef XTRAP_SECURE_CKBANG_2010_07_20`.
- Inspect actual `Engine.dll` / `Nksp.exe` imports and behavior if produced. Preserve source licensing and verify binary compatibility with the intended server before distribution.

## Build workflow
`.github/workflows/win32-experimental.yml` on the **master** branch checks out `xtrap-free-win32` for compilation. Logs and any binaries appear in the `win32-build-diagnostics` artifact. Failed Action runs do not imply valid binaries.

References:
- https://github.com/apitrace/apitrace/wiki/DirectX-SDK
- https://learn.microsoft.com/en-us/windows/win32/directx-sdk--august-2009-


## New verified result: CI run #16 (2026-11-24)

Run: https://github.com/drihite/lastchaos-source-client/actions/runs/45363099952

The experimental runner **successfully prepared Direct3D 8 and D3DX8 SDK build-only headers/libraries, built Ecc, and compiled Engine C++ sources far enough to invoke the Engine linker**. It did not produce a verified usable Engine.dll.

Actual linker failures (from run #16; these are distinct causes, not missing D3DX headers):

- `LNK2026` (70 instances): old D3DX8 static-library objects do not satisfy the modern linker's SAFESEH requirement.
- `LNK2005` (41 instances): duplicated PNG symbols exported both by `d3dx8.lib` (which embeds PNG source) and the client's `libpng.lib`.
- `LNK2001` (4 instances): CRT symbol mismatches from prebuilt old Lua/TinyXML/libpng libraries, including `___iob_func`, `_sscanf_s`, `__vsnprintf_s`, `__imp____iob_func`.
- `LNK1120`: four symbols unresolved, so link failed.

**Do not suppress duplicate symbols with `/FORCE:MULTIPLE` or indiscriminately disable security features and describe the binary as production-ready.** Instead reproduce with a compatible MSVC v100 build environment and/or rebuild third-party libraries coherently using one toolchain and eliminate PNG duplicate ownership at the link stage. Disabling SAFESEH for legacy static libraries may be needed temporarily for a diagnostic build, but is a security tradeoff requiring explicit validation before distribution.

Source-specific target and link dependency checks remain necessary: `Engine.dll` first, then `Nksp.exe`, then import/export and protocol testing.
