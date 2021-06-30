#[
    checking stuff we can do on C too.
]#

import strformat

echo "\n"
echo "----------------------------------------"
echo "cast uint8 (0xFF) to uint16"
echo ""
var
    a: uint8 = 0xFF
    b: uint16 = a
echo fmt"{b:#X}"

echo "\n"
echo "----------------------------------------"
echo "cast uint16 (0xAAF0) to uint8"
echo ""
b = 0xAAF0
a = b.uint8
echo fmt"{a:#X}"

echo "\n"
echo "----------------------------------------"
echo "cast array[4, uint8] ([0xA0,0xA1,0xA2,0xA3]) to uint32"
echo ""
var
    c_array: array[4, uint8] = [0xA0u8,0xA1u8,0xA2u8,0xA3u8]
    d: uint32 = cast[uint32](c_array)

stdout.write(repr(c_array[0].addr))
stdout.write(repr(c_array[1].addr))
stdout.write(repr(c_array[2].addr))
stdout.write(repr(c_array[3].addr))
echo fmt"{d:#X}"

echo "\n"
echo "----------------------------------------"
echo "cast array[2] (array[4, uint8] ([0xA0,0xA1,0xA2,0xA3])) to uint16"
echo ""
var
    d_16: uint16 = cast[uint16](c_array[2])

stdout.write(repr(c_array[0].addr))
stdout.write(repr(c_array[1].addr))
stdout.write(repr(c_array[2].addr))
stdout.write(repr(c_array[3].addr))
echo fmt"{d_16:#X}"

echo "\n"
echo "----------------------------------------"
echo "cast array[2].addr (array[4, uint8] ([0xA0,0xA1,0xA2,0xA3])) to uint16 via pointer"
echo ""
var
    p: pointer = c_array[2].addr
    d_16_from_poiner: uint16 = cast[ptr uint16](p)[]

stdout.write(repr(c_array[0].addr))
stdout.write(repr(c_array[1].addr))
stdout.write(repr(c_array[2].addr))
stdout.write(repr(c_array[3].addr))
echo fmt"{d_16_from_poiner:#X}"

echo "\n"
echo "----------------------------------------"
echo "float32 (1.23456789) to array[4, uint8] via pointer"
echo ""
var
    fv: float32 = float32(1.23456789)
    fv_array: array[4, uint8] = cast[array[4, uint8]](fv)

echo fmt"fv = float32(1.23456789): {fv}"
echo fmt"fv casting to array     : {fv_array}"
echo fmt"fv_array to float32     : {cast[float32](fv_array)}"

echo "\n"
echo "----------------------------------------"
echo "test some addr on object"
echo ""
type TestStruct = ref object of RootObj
    a: uint8
    b: uint8
    c: uint16
    d: uint16

var ts = new TestStruct
ts.a = 0xA0u8
ts.b = 0xA1u8
ts.c = 0x00A2u16
ts.d = 0x00A3u16

stdout.write(fmt"addr of ts: {repr(ts.addr)}")
stdout.write(fmt"addr of ts.a: {repr(ts.a.addr)}")
echo "this shows the address of ts (ts.addr) does not actually represent the address of first member"
echo "so you need to be careful."
# I do not remember it was same bihavior on C too

echo "\n"
echo "----------------------------------------"
echo "showing a diff. of behavior to use ts.addr and ts.a.addr"
echo ""
# this is not allowed
#var ts_array = cast[array[6, uint8]](ts)

echo "-------ts.addr------"
var ts_string = cast[ptr array[6, uint8]](ts.addr)
echo repr(ts_string)
for i in ts_string[]:
    echo fmt"{i:#X}"

echo ""
echo "------ts.a.addr-----"
var ts_a_string = cast[ptr array[6, uint8]](ts.a.addr)
echo repr(ts_a_string)
for i in ts_a_string[]:
    echo fmt"{i:#X}"
    