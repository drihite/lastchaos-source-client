# Last Chaos Win32 client — verified build and compatibility blockers

Status checked 2026-11-24. This document is for engineering triage, not a release approval.

## Confirmed evidence

- GitHub Actions run #28 (45437794522) completed the GERLIVE/Win32 solution build. Its log includes output paths D:\Bin\Engine.dll, EntitiesMP.dll, GameMP.dll, Shaders.dll and Nksp.exe. Binaries were **not** uploaded; only diagnostic logs were retained.
- Run #29 (45440435675) enabled /SAFESEH for Engine and failed at link time with LNK2026 and LNK1281. Incompatible objects were identified in d3dx8.lib (legacy DirectX 8 SDK) and IJL15L.LIB (repo: Lib/VC100/IJL15L.LIB).
- The successful run #28 used /SAFESEH:NO for the Engine link. A successful link does not prove runtime compatibility, exploit mitigations, code provenance, or permission to redistribute third-party components.

## Current CI behavior

- Workflow .github/workflows/win32-experimental.yml is manual-only to avoid exhausting GitHub Actions minutes.
- strict_safeseh mode is the default test and must not be silently weakened.
- legacy_compat_audit mode is **diagnostic only**. Its ASLR/DEP attempts do not replace SafeSEH.
- .github/scripts/audit-win32-client.ps1 inventories core outputs, PE headers, import dependencies, hashes, and Authenticode status. It does not upload executables.

## Safe next steps (ordered; no paid CI required for research)

1. Inventory **exactly which DirectX 8/D3DX8 APIs** the Engine references, distinguish Direct3D runtime imports from bundled D3DX utility implementations, and assess compatibility with a supported replacement. The old d3dx8.lib contains object code without SafeSEH metadata and cannot be made SafeSEH-compatible merely by setting linker flags.
2. Inventory the IJL codec entry points used by Engine; identify compatible, appropriately licensed alternatives, and verify codec/API behavior before swapping implementation.
3. Prefer a clean rebuild or replacement of incompatible native libraries compiled with a contemporary x86 toolchain and suitable mitigations. Do not just suppress LNK2026 for a public release.
4. Once dependencies are replaced, use a single controlled `strict_safeseh` CI run; if it passes, inspect the PE report for every core module, not only Engine.
5. For a **private Windows runtime test** use a legally sourced, complete installation/data set; verify imports, DirectX compatibility, startup behavior, login protocol compatibility and logs. A successful build alone is insufficient.
6. Only after the above: assemble a distribution package with provenance, hashes, licensing review and reproducible build instructions.

## Open questions

- Are replacements for D3DX8's legacy shader/math/texture helpers behaviorally compatible with this client?
- Can the Intel JPEG Library static dependency be substituted without changing image formats or rendering behavior?
- Which data archives and external DLLs are required for an executable to launch?
- Is the user's GameServer build protocol compatible with this specific client revision?

Avoid automated build-on-push until these are resolved; do not upload unverified or unlicensed binaries.


## Source-level dependency inventory (2026-11-24; read-only review)

### Intel JPEG Library (IJL 1.51)

- Repo contains `include/ijl.h` (Intel proprietary license notice) and `Lib/VC100/IJL15L.LIB`.
- `Engine/Graphics/ImageInfo.cpp` includes `ijl.h`. In `CImageInfo::SaveJPG_t`, the direct API calls are `ijlInit`, `ijlWrite(..., IJL_JFILE_WRITEWHOLEIMAGE)`, and `ijlFree`.
- That method sets `IJL_BGR`, three DIB channels, negative DIB height, and JPEG quality 100; it flips and swaps pixels before encoding. A replacement codec must match channel order, vertical orientation and buffer layout rather than mechanically replacing the function names.
- **Format compatibility detail:** after encoding, the method appends a 4-byte value calculated as `jcp.JPGSizeBytes ^ 0xFFFFFFFF` to the JPG file. Replacing IJL without preserving or intentionally migrating this nonstandard trailer may break screenshot integrity checks or consumers. Identify readers/validators before altering the format.
- **Potential correctness issue for later review:** the row-stride/padding expression `((ii_Width)*3)/4*4` rounds down instead of rounding up; the allocation and row-stride assumptions need tests for widths not divisible by four. Do not change this blindly while replacing the encoder.
- Since the IJL header explicitly carries an Intel proprietary notice, do not assume a right to redistribute the static library.

### Legacy DirectX 8

- `Engine/Graphics/Gfx_Direct3D.cpp` references `D3DXAssembleShader` while compiling vertex/pixel program bytecode, with `ID3DXBuffer` handling. `Engine/Graphics/Gfx_wrapper_Direct3D.cpp` passes the assembled tokens to `IDirect3DDevice8::CreateVertexShader` and `CreatePixelShader`.
- `Gfx_Direct3D.cpp` obtains `Direct3DCreate8` through `GetProcAddress` on the selected driver DLL. D3D8 runtime use is separate from the D3DX8 static utility library.
- Any D3DX replacement must emit shader bytecode compatible with **Direct3D 8** and its shader instruction syntax; adopting a modern shader compiler without testing those semantics can cause blank rendering or shader failures.
- Build #29 specifically identified objects within the legacy `d3dx8.lib` as unsafe for SafeSEH, so a linker switch cannot repair the existing object files.

### Recommended engineering sequence

1. Inventory all IJL and D3DX references across the complete source tree and record exact API signatures, before choosing replacements. The observations above cover inspected graphics units, not an exhaustive whole-repository scan.
2. Prototype JPEG output and historical screenshot trailer behavior in isolated tests (especially non-4-byte-aligned image widths), with a license-compatible maintained encoder.
3. Prototype a legacy shader-assembler replacement that accepts the project's existing shader text and produces D3D8-compatible tokens.
4. Link each replacement into the strict SafeSEH build separately; run only a **single** manual diagnostic workflow after a meaningful code change. Evaluate ASLR/DEP and imported dependencies per module after link success.
