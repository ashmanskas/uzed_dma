from bitstring import Bits  # install with 'easy_install bitstring'

class MyBits(object):
  """
  Extends (by composition) 'bitstring.Bits' class as follows:
  - Two-argument constructor (length, unsigned integer value)
  - bitfield 'bf' method analogous to verilog bit slicing
  """
  __maskdict = {}  # memo-ize lookup of known bitmasks
  def __init__(self, length, uintvalue):
    if length in MyBits.__maskdict:
      mask = MyBits.__maskdict[length]
    else:
      mask = 0
      for i in range(length):
        mask |= 1<<i
      MyBits.__maskdict[length] = mask
    uintvalue &= mask
    self._bits = Bits(length=length, uint=uintvalue)
  def b(self, hi, lo):
    j = 0
    rv = 0
    for i in range(lo, hi+1):
      if self._bits[-1-i]:
        rv |= 1<<j
      j += 1
    return rv
  def __add__(self, bs):
    "Concatenate bitstrings and return new bitstring"
    newbits = self._bits + bs._bits
    newobj = MyBits(newbits.len, newbits.uint)
    return newobj
  def __radd__(self, bs):
    "Append current bitstring to bs and return new bitstring"
    return bs.__add__(self)
  def __int__(self):
    "Convert bitstring to unsigned integer"
    return self._bits.uint
  def __hex__(self):
    "Convert bitstring to hexadecimal"
    return hex(self._bits.uint)
  def __getitem__(self, key):
    "Verilog-style bitslice operation"
    try:
      step = key.step if key.step is not None else 1
    except AttributeError:
      # single element
      return self.b(key,key)
    else:
      assert(step==1)  # other step sizes not implemented
      assert(key.start>=key.stop)
      return self.b(key.start, key.stop)
