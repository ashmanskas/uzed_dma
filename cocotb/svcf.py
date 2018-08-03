
#
# This hack reads a 'simvision.svcf' (from saving the state of a
# simvision run) and outputs just the 'waveform add' commands, in a
# more readable/editable format than the original.
#
# wja 2017-08-17
#

import re

fdat = open("simvision.svcf").read()
patt = r'waveform add[^\n]*\{\n\t\{\[format \{(.*)\}\]\}'
result = re.findall(patt, fdat)
for r in result:
    print "waveform add -signals {%s}"%(r)

