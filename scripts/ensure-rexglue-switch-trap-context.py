#!/usr/bin/env python3
"""Make ReXGlue jump-table traps debugger-friendly and deterministic.

Generated bctr switch code can trap when the runtime index is outside the
statically discovered case list. In RelWithDebInfo the generated PPCContext
reference and local CTR/index values may be optimized away, so GDB cannot
reliably inspect them at the raw SIGILL site.

This idempotent helper upgrades ReXGlue codegen to call a tiny noinline/optnone
DebugSwitchTableTrap(ctx, index, bctr_address) helper immediately before the
trap. The real CTR target is copied to PPCContext::last_indirect_target first.
GDB can then read all four pieces of state from stable function arguments:
  * PPCContext pointer
  * runtime switch index
  * guest bctr address
  * runtime CTR target (ctx.last_indirect_target)
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import NoReturn


def die(message: str) -> NoReturn:
    print(f"[switch-trap] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


PCH_MARKER = "REXGLUE_GDB_SWITCH_TRAP_HELPER"
CALL_MARKER = "rex::runtime::DebugSwitchTableTrap"

PCH_BLOCK = r'''
// REXGLUE_GDB_SWITCH_TRAP_HELPER
// Stable debugger stop for generated bctr switch-table misses. Keeping this
// helper out-of-line and unoptimized preserves its arguments in RelWithDebInfo.
namespace rex::runtime {
[[noreturn]]
#if defined(__clang__)
__attribute__((noinline, optnone))
#elif defined(__GNUC__)
__attribute__((noinline, optimize("O0")))
#elif defined(_MSC_VER)
__declspec(noinline)
#endif
inline void DebugSwitchTableTrap(PPCContext& ctx, uint32_t index,
                                               uint32_t bctr_address) {
  // Keep all arguments observably live for a debugger. The generated caller
  // stores the real CTR destination in ctx.last_indirect_target before here.
  volatile PPCContext* debug_ctx = &ctx;
  volatile uint32_t debug_index = index;
  volatile uint32_t debug_bctr = bctr_address;
  (void)debug_ctx;
  (void)debug_index;
  (void)debug_bctr;
#if defined(__clang__) || defined(__GNUC__)
  __builtin_trap();
#else
  std::abort();
#endif
}
}  // namespace rex::runtime
// END REXGLUE_GDB_SWITCH_TRAP_HELPER
'''.strip("\n")


def patch_pch(sdk: Path) -> bool:
    path = sdk / "resources/templates/codegen/pch_h.inja"
    if not path.is_file():
        die(f"missing {path}")
    text = path.read_text(encoding="utf-8")
    if PCH_MARKER in text:
        return False

    anchor = (
        "#include <unordered_map>\n\n"
        "//=============================================================================\n"
        "// Image Info\n"
    )
    if anchor not in text:
        die("could not locate PCH insertion anchor")

    replacement = (
        "#include <unordered_map>\n\n"
        + PCH_BLOCK
        + "\n\n"
        "//=============================================================================\n"
        "// Image Info\n"
    )
    path.write_text(text.replace(anchor, replacement, 1), encoding="utf-8")
    return True


def patch_control_flow(sdk: Path) -> bool:
    path = sdk / "src/codegen/builders/control_flow.cpp"
    if not path.is_file():
        die(f"missing {path}")
    text = path.read_text(encoding="utf-8")
    if CALL_MARKER in text:
        return False

    # Upgrade the previous project helper first (CTR capture + raw trap).
    old_patched = (
        '    ctx.println("\\tdefault:");\n'
        '    // Keep the original bctr target observable for the project GDB helper.\n'
        '    // This is especially important when ctr_as_local lets the host compiler\n'
        '    // optimize the local CTR temporary away at the trap site.\n'
        '    ctx.println("\\t\\tctx.last_indirect_target = {}.u32;", ctx.ctr());\n'
        '    ctx.println("\\t\\t__builtin_trap(); // Switch case out of range");\n'
    )

    # Also support an untouched SDK at the pinned ReXGlue commit.
    old_original = (
        '    ctx.println("\\tdefault:");\n'
        '    ctx.println("\\t\\t__builtin_trap(); // Switch case out of range");\n'
    )

    new = (
        '    ctx.println("\\tdefault:");\n'
        '    // Preserve the real bctr target, then enter a stable debugger helper.\n'
        '    // The helper arguments survive RelWithDebInfo even if ctx/CTR locals in\n'
        '    // the generated guest function are optimized away.\n'
        '    ctx.println("\\t\\tctx.last_indirect_target = {}.u32;", ctx.ctr());\n'
        '    ctx.println(\n'
        '        "\\t\\trex::runtime::DebugSwitchTableTrap(ctx, {}.u32, 0x{:08X});",\n'
        '        ctx.r(jt->indexRegister), ctx.base);\n'
    )

    if old_patched in text:
        path.write_text(text.replace(old_patched, new, 1), encoding="utf-8")
        return True
    if old_original in text:
        path.write_text(text.replace(old_original, new, 1), encoding="utf-8")
        return True

    die("could not locate supported switch-trap codegen pattern")


def main() -> int:
    if len(sys.argv) != 2:
        die("usage: ensure-rexglue-switch-trap-context.py <rexglue-sdk-root>")

    sdk = Path(sys.argv[1]).resolve()
    changed_pch = patch_pch(sdk)
    changed_flow = patch_control_flow(sdk)

    if changed_pch:
        print("[switch-trap] added noinline/optnone DebugSwitchTableTrap helper to generated PCH")
    else:
        print("[switch-trap] DebugSwitchTableTrap PCH helper already present")
    if changed_flow:
        print("[switch-trap] routed bctr out-of-range through stable debugger helper")
    else:
        print("[switch-trap] bctr out-of-range debugger call already present")
    print("[switch-trap] OK (no root patch generated)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
