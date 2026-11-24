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
