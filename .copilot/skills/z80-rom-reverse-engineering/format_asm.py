#!/usr/bin/env python3
"""Format Z80 assembly comments.

Usage: python3 format_asm.py <input.asm> <output.asm>

1. Aligns inline ; comments (on code/data lines) to COMMENT_COL.
2. Indents standalone comment lines (single-tab indent, not block
   comments or --- headers) to INLINE_COMMENT_INDENT tabs.
3. Aligns 'equ' keyword to EQU_COL on label:equ lines.
"""
import re
import sys

COMMENT_COL = 40
TAB = 4
INLINE_COMMENT_INDENT = 2  # number of tabs for standalone inline comments
EQU_COL = 20  # visual column for 'equ' keyword

def visual_width(s):
    col = 0
    for ch in s:
        if ch == '\t':
            col += TAB - (col % TAB)
        else:
            col += 1
    return col

def find_inline_comment(line):
    # In Z80 assembly, ; is always a comment delimiter (never inside operands)
    return line.find(';')

def format_equ(line):
    """Align 'equ' keyword to EQU_COL on label:equ lines."""
    m = re.match(r'^(\S+:)\s+(equ)\s+(.*)$', line, re.IGNORECASE)
    if not m:
        return line
    label = m.group(1)
    value = m.group(3)
    w = visual_width(label)
    pad = max(1, EQU_COL - w)
    return label + ' ' * pad + 'equ' + '\t' + value

def format_line(line, in_block):
    line = line.rstrip('\n').rstrip('\r')
    if not line.strip():
        return line
    stripped = line.lstrip()
    if stripped.startswith(';'):
        # Standalone comment-only line: re-indent if it's a single-tab
        # inline comment (not a block comment, not a --- header)
        if not in_block and re.match(r'^\t; ', line) and not re.match(r'^\t; ---', line):
            return '\t' * INLINE_COMMENT_INDENT + stripped
        return line
    pos = find_inline_comment(line)
    if pos < 0:
        return format_equ(line)
    code = line[:pos].rstrip()
    comment = line[pos:]
    if not code.strip():
        return line
    code = format_equ(code)
    w = visual_width(code)
    pad = max(1, COMMENT_COL - w)
    return code + ' ' * pad + comment

with open(sys.argv[1]) as f:
    lines = f.readlines()

in_block = False
result = []
for line in lines:
    stripped = line.strip()
    if re.match(r'^; ={4,}', stripped):
        in_block = not in_block
    result.append(format_line(line, in_block))

with open(sys.argv[2], 'w') as f:
    f.write('\n'.join(result) + '\n')
