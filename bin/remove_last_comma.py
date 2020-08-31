#!/usr/bin/python3

"""
Small utility to remove the last comma in a file
used to clean up swagger replacements }, ==> }
after doing several replacements.

Outputs to standard out.
"""

import sys

all_lines = ""
with open( sys.argv[1], "r" ) as in_file:
    all_lines = in_file.read()

reversed_all_lines = all_lines[::-1]
n = 0
for ch in reversed_all_lines:
    if ch in ",\n\r\f ":
        n += 1
    else:
        break
if n > 0 :
    all_lines = reversed_all_lines[:n-1:-1]
    with open( sys.argv[1], "w" ) as in_file:
        in_file.write(all_lines)





