#!/usr/bin/env python3
"""Estimate assembled byte length of a Z80 mnemonic line (SjASMPlus-ish)."""

from __future__ import annotations

import re

_REGS8 = {"a", "b", "c", "d", "e", "h", "l", "ixh", "ixl", "iyh", "iyl"}
_REGS16 = {"af", "bc", "de", "hl", "ix", "iy", "sp"}


def _norm(mnemonic: str) -> str:
    s = mnemonic.strip().split(";")[0].strip()
    return re.sub(r"\s+", " ", s)


def estimate_size(mnemonic: str) -> int | None:
    """Return byte size or None if unknown."""
    s = _norm(mnemonic)
    if not s:
        return None
    low = s.lower()

    if low.startswith("db ") or low.startswith("db\t"):
        parts = re.findall(r"#?[0-9A-Fa-f]+|'.'|\"[^\"]*\"", s[2:])
        return max(1, len(parts)) if parts else None
    if low.startswith("dw ") or low.startswith("dw\t"):
        parts = [p for p in re.split(r"[, \t]+", s[2:].strip()) if p]
        return 2 * len(parts) if parts else None
    if low.startswith(("ds ", "ds\t", "org ", "org\t", "assert ", "include ")):
        return None

    op, _, arg = low.partition(" ")
    arg = arg.strip()
    args = [a.strip() for a in arg.split(",")] if arg else []

    def a0() -> str:
        return args[0] if args else ""

    def a1() -> str:
        return args[1] if len(args) > 1 else ""

    def is_reg8(x: str) -> bool:
        return x in _REGS8

    def is_reg16(x: str) -> bool:
        return x in _REGS16

    def is_ixy(x: str) -> bool:
        return x in ("ix", "iy")

    def is_mem(x: str) -> bool:
        return x.startswith("(") and x.endswith(")")

    def mem_inner(x: str) -> str:
        return x[1:-1].strip() if is_mem(x) else ""

    def is_ixy_mem(x: str) -> bool:
        inn = mem_inner(x)
        return inn.startswith("ix") or inn.startswith("iy")

    def is_imm(x: str) -> bool:
        if not x or is_reg8(x) or is_reg16(x) or is_mem(x):
            return False
        return True  # #nn, decimal, symbol

    # --- ED / block ---
    if op in {
        "ldir", "lddr", "cpir", "cpdr", "inir", "indr", "otir", "otdr",
        "ldi", "ldd", "cpi", "cpd", "neg", "reti", "retn",
    } or op == "im":
        return 2

    # --- index / CB ---
    if op in {"push", "pop"} and is_ixy(a0()):
        return 2
    if op == "ex" and is_ixy(a1()):
        return 2
    if op == "jp" and is_mem(a0()) and is_ixy(mem_inner(a0())):
        return 2
    if op in {"inc", "dec"} and is_ixy(a0()):
        return 2
    if op == "add" and is_ixy(a0()):
        return 2

    if any(is_ixy_mem(x) for x in args) or (op == "ld" and (is_ixy(a0()) or is_ixy(a1()))):
        # dd/fd prefix forms
        if op == "ld" and is_ixy(a0()) and is_imm(a1()):
            return 4  # ld ix,nn
        if op == "ld" and is_mem(a0()) and is_ixy(a1()):
            return 4  # ld (nn),ix
        if op == "ld" and is_ixy(a0()) and is_mem(a1()):
            return 4  # ld ix,(nn)
        if op == "ld" and is_ixy_mem(a0()) and is_imm(a1()):
            return 4
        if op in {"bit", "res", "set", "rlc", "rrc", "rl", "rr", "sla", "sra", "srl", "sll"}:
            return 4
        return 3

    if op in {"bit", "res", "set", "rlc", "rrc", "rl", "rr", "sla", "sra", "srl", "sll"}:
        return 2

    # --- jumps / calls ---
    if op in {"jp", "call"}:
        if is_mem(a0()) and mem_inner(a0()) == "hl":
            return 1
        return 3
    if op in {"jr", "djnz"}:
        return 2

    # --- LD family ---
    if op == "ld":
        d, s_ = a0(), a1()
        if d == "a" and s_ in {"i", "r"}:
            return 2
        if d in {"i", "r"} and s_ == "a":
            return 2
        if is_reg16(d) and is_imm(s_):
            return 3
        if d == "hl" and is_mem(s_):
            return 3
        if is_mem(d) and s_ == "hl":
            return 3
        # (hl)/(bc)/(de) forms are 1-byte — check before (nn)
        if is_mem(d) and mem_inner(d) in {"hl", "bc", "de"} and (
            is_reg8(s_) or is_imm(s_)
        ):
            return 2 if is_imm(s_) else 1
        if is_reg8(d) and is_mem(s_) and mem_inner(s_) in {"hl", "bc", "de"}:
            return 1
        if d == "a" and is_mem(s_) and not is_ixy_mem(s_):
            return 3  # ld a,(nn)
        if is_mem(d) and s_ == "a" and not is_ixy_mem(d):
            return 3  # ld (nn),a
        if is_reg8(d) and is_imm(s_):
            return 2
        if is_reg8(d) and is_reg8(s_):
            return 1
        # ed: ld (nn),rr / ld rr,(nn) for bc/de/sp
        if is_mem(d) and is_reg16(s_):
            return 4
        if is_reg16(d) and is_mem(s_):
            return 4
        return None

    # --- ALU ---
    if op in {"add", "adc", "sbc"}:
        if a0() == "hl":
            return 1
        if a0() == "a" and is_imm(a1()):
            return 2
        return 1
    if op in {"sub", "and", "or", "xor", "cp"}:
        if is_imm(a0()):
            return 2
        return 1

    if op in {"out", "in"}:
        return 2

    if op in {
        "nop", "halt", "di", "ei", "ret", "exx", "ex", "scf", "ccf", "cpl",
        "daa", "rlca", "rrca", "rla", "rra", "inc", "dec", "push", "pop", "rst",
    }:
        return 1
    if op.startswith("ret"):
        return 1

    return None
