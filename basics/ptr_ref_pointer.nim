#[
    checking how it works,
]#

# without var, it will receive constant value
proc testProcLiteral(a: int) =
    echo "type: ", a.type
    # this will be not allowed
    #a = a + 1

    # no address available
    #echo repr(a.addr)

    echo a

# with var, it will be ptr variable
proc testProc(a: var int) =
    echo "type: ", a.type

    stdout.write("a.addr = ")    
    stdout.write(repr(a.addr))

    # casting to a value
    stdout.write("cast[int](a) = ")
    echo cast[int](a)

    echo a
    # it will have side effect
    a = a+1

    echo a

proc testProcPtr(a: ptr int) =
    echo "type: ", a.type

    stdout.write("a: ")
    stdout.write(repr(a))

    stdout.write("a[] = ")
    # access to value
    echo a[]

    stdout.write("cast[int](a) = ")
    # casting to a value
    echo repr(cast[int](a))

    # this is not allowed
    #cast[int](a) = cast[int](a)+1

    echo a[]
    a[] = a[]+1

    # access to value
    echo a[]

proc testProcRef(b: ref int) =
    echo "type: ", b.type

    stdout.write("b: ")
    stdout.write(repr(b))

    stdout.write("cast[int](b) = ")
    # casting to a value
    echo repr(cast[int](b))

    stdout.write("cast[ptr int](b) = ")
    # casting to a ptr
    stdout.write(repr(cast[ref int](b)))

    # this is not allowed
    #cast[int](a) = cast[int](a)+1
    
    echo b[]

    echo cast[ref int](b)[]
    cast[ref int](b)[] = cast[ptr int](b)[]+1
    echo cast[ref int](b)[]

# using pointer, it do not need a type, it is void*
proc testProcPointer(a: pointer) =
    echo "type: ", a.type

    stdout.write("a: ")
    stdout.write(repr(a))

    stdout.write("cast[int](a) = ")
    # casting to a value
    echo repr(cast[int](a))

    stdout.write("cast[ptr int](a) = ")
    # casting to a ptr
    stdout.write(repr(cast[ptr int](a)))

    # this is not allowed
    #cast[int](a) = cast[int](a)+1
    #echo a[]

    echo cast[ptr int](a)[]
    cast[ptr int](a)[] = cast[ptr int](a)[]+1
    echo cast[ptr int](a)[]

# call proc via poiner
proc testProcedureArgument(p: proc) =
    echo "type: ", p.type
    
    stdout.write("p: ")
    stdout.write(repr(p))

    p(123)

# call proc via poiner
proc testProcedureArgumentPtr(p: ptr proc(a: int)) =
    echo "type: ", p.type

    # not allowed
    #stdout.write("p: ")
    #stdout.write(repr(p))

    cast[proc(a: int){.nimcall.}](p)(123)

# call proc via poiner
proc testProcedureArgumentPointer(p: pointer) =
    echo "type: ", p.type

    stdout.write("p: ")
    stdout.write(repr(p))
    cast[proc(a: int){.nimcall.}](p)(123)

var a: int = 0

echo "proc testProcLiteral (calling by literal): "
testProcLiteral(0)

echo "a address        : ", repr(a.addr)

echo "proc testProcLiteral: "
testProcLiteral(a)
echo ""

echo "proc testProc: "
testProc(a)
echo ""

a = 0
echo "proc testProcPtr: "
testProcPtr(a.addr)
echo ""

# this will create a nil pointed variable for ref int
var b: ref int

# this cannot done
#b = a.addr
b = new int
echo "proc testProcRef: "
testProcRef(b)
echo ""

a = 0
echo "proc testProcPointer: "
testProcPointer(a.addr)
echo ""

echo "################################################################"

echo "proc testProcedure: "
testProcedureArgument(testProcLiteral)
echo ""

echo "proc testProcedurePtr: "
# this not allowed
#testProcedureArgument(testProcLiteral.addr)
var p_ptr: ptr proc(a: int)
p_ptr = cast[ptr proc(a: int)](testProcLiteral)
testProcedureArgumentPtr(p_ptr)
echo ""

echo "proc testProcedurePointer: "
var p_pointer: pointer
p_pointer = testProcLiteral
testProcedureArgumentPointer(p_pointer)
