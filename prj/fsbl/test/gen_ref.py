#!/usr/bin/env python3
"""Emit the 1 GB build's ps7 tables as reference arrays for the native test."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "scripts"))
from gen_ddr_patch import extract_arrays, OPCODE_ARGS, OPCODE_NUM

src, out = Path(sys.argv[1]), Path(sys.argv[2])
arrays = extract_arrays(src)

lines = ["/* Generated for the native patch test - reference from the 1 GB build. */",
         '#include "ref.h"', ""]
names = sorted(arrays)
for name in names:
    words = []
    for kind, args, _ in arrays[name]:
        words.append((OPCODE_NUM[kind] << 4) | OPCODE_ARGS[kind])
        words.extend(args)
    lines.append(f"static const unsigned long ref_{name}[] = {{")
    for i in range(0, len(words), 6):
        lines.append("    " + " ".join(f"0x{w:X}UL," for w in words[i:i + 6]))
    lines.append("};")
    lines.append("")

for name in names:
    lines.append(f"extern unsigned long {name}[];")
lines.append("")
lines.append("const ref_table_t ref_tables[] = {")
for name in names:
    lines.append(f'    {{ "{name}", {name}, ref_{name},')
    lines.append(f"      (unsigned)(sizeof(ref_{name}) / sizeof(ref_{name}[0])) }},")
lines.append("};")
lines.append("const unsigned ref_tables_len = "
             "(unsigned)(sizeof(ref_tables) / sizeof(ref_tables[0]));")
lines.append("")
out.write_text("\n".join(lines))
print(f"gen_ref: {len(names)} reference tables")
