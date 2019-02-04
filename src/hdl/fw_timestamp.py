#! /usr/bin/env python

from __future__ import print_function
import datetime
import os
import sys

now = datetime.datetime.now()
yyyy = "%04d"%(now.year)
mmdd = "%02d%02d"%(now.month, now.day)
hhmm = "%02d%02d"%(now.hour, now.minute)

s = """
wire [15:0] fw_yyyy = 'h%s;
wire [15:0] fw_mmdd = 'h%s;
wire [15:0] fw_hhmm = 'h%s;
"""
s = s%(yyyy, mmdd, hhmm)
print(s)

fnam = "fw_timestamp.v"
dirnam = os.path.dirname(sys.argv[0])
fnam = os.path.join(dirnam, fnam)
print(fnam)
open(fnam, "r")  # make sure old version exists here
open(fnam, "w").write(s)
print("wrote %s"%(fnam))
