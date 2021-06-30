#[
    for checking how to increment pointer.
    in C,
        int *p = &variable;
        p++;
]#

echo "----------------------------------------"
echo "array = [0xA0,0xA1,0xA2,0xA3], and p pointing at array[0]"
echo ""

var uint8_array: array[4, uint8] = [0xA0u8,0xA1u8,0xA2u8,0xA3u8]
stdout.write(repr(uint8_array[0].addr))
stdout.write(repr(uint8_array[1].addr))
stdout.write(repr(uint8_array[2].addr))
stdout.write(repr(uint8_array[3].addr))
echo ""

var p:pointer = uint8_array.addr
stdout.write("p -> ")
stdout.write(repr(p))
echo "*p == " & $cast[ref uint8](p)[]
echo ""

echo "p++\n"

# this will do the same thing of <pointer>++ on C
# but we need to specify the bytes to increment
# it is possible to use generics for it
p = cast[pointer](cast[uint64](p)+1u) # it works on 1, 1u32 or etc.
stdout.write("p -> ")
stdout.write(repr(p))
echo "*p == " & $cast[ref uint8](p)[]
