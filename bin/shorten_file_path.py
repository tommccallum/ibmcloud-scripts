#!/usr/bin/python3

# Script to short a file path specified as the first argument
# in relation to a potentially longer path in the second argument.

import sys
import os


def splitall(path):
    allparts = []
    while 1:
        parts = os.path.split(path)
        if parts[0] == path:  # sentinel for absolute paths
            allparts.insert(0, parts[0])
            break
        elif parts[1] == path:  # sentinel for relative paths
            allparts.insert(0, parts[1])
            break
        else:
            path = parts[0]
            allparts.insert(0, parts[1])
    return allparts

# bring in the two strings from the command line
str_a = sys.argv[1]
str_b = sys.argv[2]

# divide each into its constituent directory parts
# last item is always the filename
parts_a = splitall(str_a)
parts_b = splitall(str_b)

# we want the minimum as we want common part
n = min(len(parts_a), len(parts_b))

# look through for minimum
short = None
for ii in range(0, n):
    if parts_a[ii] != parts_b[ii]:
        short = ii
        break
if short is None:
    short = n
remainder = parts_a[short:]
# if we have removed all directories then user might get 
# lost so we then add on at most 2 directories
if len(remainder) == 1:
  if len(parts_a) > 1:
    short = max(0,min( len(parts_a), len(parts_a)-2 ))
short_name=os.path.join(*parts_a[short:])
print(short_name)
