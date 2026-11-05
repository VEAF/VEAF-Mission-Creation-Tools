"""Petit outil de désassemblage x64 pour DLL DCS (capstone + pefile).

usage:
  dis.py <dll> str <texte>            -> VA de la chaîne + instructions qui la référencent
  dis.py <dll> fn <va_hex> [n]        -> désassemble n instructions à partir de va
  dis.py <dll> exp <motif>            -> exports dont le nom contient motif
  dis.py <dll> xref <va_hex>          -> instructions qui référencent va (rip-relative / call)
"""
import struct
import sys

import capstone
import pefile

path, cmd = sys.argv[1], sys.argv[2]
pe = pefile.PE(path, fast_load=False)
base = pe.OPTIONAL_HEADER.ImageBase
img = pe.get_memory_mapped_image()

imports = {}
for e in getattr(pe, "DIRECTORY_ENTRY_IMPORT", []):
    for i in e.imports:
        imports[i.address] = f"{e.dll.decode()}!{i.name.decode() if i.name else i.ordinal}"
exports = {}
if hasattr(pe, "DIRECTORY_ENTRY_EXPORT"):
    for s in pe.DIRECTORY_ENTRY_EXPORT.symbols:
        exports[base + s.address] = s.name.decode() if s.name else str(s.ordinal)

md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
md.detail = True

text = [s for s in pe.sections if s.Name.startswith(b".text")][0]
tstart = base + text.VirtualAddress
tdata = img[text.VirtualAddress:text.VirtualAddress + text.Misc_VirtualSize]


def rd(va, n):
    o = va - base
    return img[o:o + n]


def cstr(va):
    b = rd(va, 200)
    return b.split(b"\0")[0]


def target(ins):
    """Adresse référencée par une instruction rip-relative ou un call/jmp direct."""
    for op in ins.operands:
        if op.type == capstone.x86.X86_OP_MEM and op.mem.base == capstone.x86.X86_REG_RIP:
            return ins.address + ins.size + op.mem.disp
        if op.type == capstone.x86.X86_OP_IMM and ins.mnemonic in ("call", "jmp") :
            return op.imm
    return None


def annotate(ins):
    t = target(ins)
    note = ""
    if t is not None:
        if t in imports:
            note = imports[t]
        elif t in exports:
            note = "EXPORT " + exports[t]
        else:
            s = cstr(t)
            if len(s) >= 4 and all(32 <= c < 127 for c in s):
                note = repr(s.decode())
            elif "ss" in ins.op_str or "sd" in ins.mnemonic or "xmm" in ins.op_str:
                raw = rd(t, 8)
                note = f"f64={struct.unpack("<d", raw)[0]!r}"
    return note


def dis(va, n):
    o = va - tstart
    cnt = 0
    for ins in md.disasm(tdata[o:o + n * 15], va):
        print(f"{ins.address:x}: {ins.mnemonic:8s} {ins.op_str:45s} {annotate(ins)}")
        cnt += 1
        if cnt >= n:
            break


def xrefs(va):
    """Balayage linéaire grossier : trouve les instructions rip-relatives visant va."""
    res = []
    data = tdata
    i = 0
    # recherche de motifs disp32 possibles : pour chaque position, disp = va - (pos_fin)
    for off in range(len(data) - 4):
        disp = struct.unpack_from("<i", data, off)[0]
        # l'instruction finit typiquement à off+4 (ou +5 avec immédiat 1 octet)
        for extra in (0, 1, 4):
            if tstart + off + 4 + extra + disp == va:
                for back in range(2, 8):
                    st = off - back
                    for ins in md.disasm(data[st:st + 16], tstart + st):
                        if ins.address + ins.size == tstart + off + 4 + extra and target(ins) == va:
                            res.append(ins)
                        break
    seen = set()
    for ins in res:
        if ins.address in seen:
            continue
        seen.add(ins.address)
        print(f"{ins.address:x}: {ins.mnemonic} {ins.op_str}")


if cmd == "str":
    needle = sys.argv[3].encode()
    for s in pe.sections:
        d = s.get_data()
        i = d.find(needle + b"\0")
        while i >= 0:
            va = base + s.VirtualAddress + i
            if i == 0 or d[i - 1] == 0:
                print(f"string at {va:x} in {s.Name.strip(chr(0).encode())}")
                xrefs(va)
            i = d.find(needle + b"\0", i + 1)
elif cmd == "fn":
    dis(int(sys.argv[3], 16), int(sys.argv[4]) if len(sys.argv) > 4 else 80)
elif cmd == "exp":
    for va, n in sorted(exports.items()):
        if sys.argv[3].lower() in n.lower():
            print(f"{va:x} {n}")
elif cmd == "xref":
    xrefs(int(sys.argv[3], 16))
elif cmd == "imp":
    for a, n in sorted(imports.items()):
        if sys.argv[3].lower() in n.lower():
            print(f"{a:x} {n}")
