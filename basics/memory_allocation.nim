#[
    This code is for considering to do C lang malloc() stuff in nim.
        e.g. int *a = malloc(sizeof(int));

    Some use case of doing these kind of stuff is to manage the all objects by ptr/pointer.

    
    Well, basically, the `ref object` which is created by `new` operator is always on heap,
    so we don't need to do some pointer stuff...
        reference: https://zevv.nl/nim-memory/

    Anyway, the define
        type
            ObjA = ref object of RootObj
                a: int
                b: int
                objB: ObjB

    seems to be a ref objct, but by `var a = new ObjA`, a is actually a `ObjA` not `ref ObjA` (in v1.4.2).
    Well, from `echo repr(a)` will output `ref 0x<mem_addr> --> ...`.
]#

type
    ObjA_with_ptr = ref object of RootObj
        a: int
        b: int
        objB: ptr ObjB

    ObjA = ref object of RootObj
        a: int
        b: int
        objB: ObjB

    ObjB = ref object of RootObj
        c: int
        d: int

# proto
proc newObjB_with_ptr(p: ptr ObjA_with_ptr)
proc newObjB(): ObjB

# basic constructor function
proc newObjA_with_ptr(): ObjA_with_ptr =
    new result

    result.a = 0
    result.b = 1
    newObjB_with_ptr(result.addr)

    echo "# objA_with_ptr in proc:"
    echo repr(result.addr)
    echo "# objA_with_ptr's objb in proc:"
    echo repr(result.objB)
    return result

proc newObjA(): ObjA =
    new result

    result.a = 0
    result.b = 1
    
    result.objB = newObjB()

    echo "# objA in proc:"
    echo repr(result.addr)
    echo "# objA's objb in proc:"
    echo repr(result.objB)
    return result

proc newObjB_with_ptr(p: ptr ObjA_with_ptr) =
    var ob = new ObjB

    echo "# objB_with_ptr in proc:"
    echo repr(ob.addr)

    ob.c = 2
    ob.d = 3

    p[].objB = ob.addr

proc newObjB(): ObjB =
    var ob = new ObjB

    ob.c = 2
    ob.d = 3

    echo "# objB in proc:"
    echo repr(ob.addr)

    return ob

# this code will cause error via reading nil of objA_with_ptr.objB
#var objA_with_ptr = newObjA_with_ptr()
#echo "# objA_with_ptr after proc:"
#echo fmt"{cast[uint64](cast[pointer](objA_with_ptr)):#x}"
#echo repr(objA_with_ptr.addr)

var objA = newObjA()
echo "# objA after proc:"
echo repr(objA.addr)
