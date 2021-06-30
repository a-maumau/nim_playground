import glm

import color_mapper

type Attribute* = enum
    passable
    wall
    start
    goal

type Square* = ref object of RootObj
    posX*: int
    posY*: int
    vertices*: seq[float32]
    indices*: seq[uint32]
    color*: Vec3[float32]

    mesh*: tuple[vao, vbo, ebo: uint32]

    attribute*: Attribute
    cost*: int
    costFromStart*: int
    parentNode*: Square

# indices for square vertices
var ind = @[
    0'u32, 1'u32, 3'u32,
    1'u32, 2'u32, 3'u32
  ]

# using as constructor and `new`ing Square
proc newSquare*(x:int, y:int, vtx: seq[float32], col: Vec3[float32], attr: Attribute = passable, cost: int = 1): Square =
    #var result: Square = new Square
    new result

    result.posX = x
    result.posY = y
    result.vertices = vtx
    result.indices = ind
    result.color = col

    result.attribute = attr
    result.cost = cost
    result.costFromStart = 999999999
    result.parentNode = nil


    #[ old code, did not work, I need to fix it, but I will just put on here for that day .
    #echo "new square: " & repr(result.mesh.vao.addr)
    #echo "new square: " & repr(result.vertices.addr)

    # generate buffer
    glGenVertexArrays(1, result.mesh.vao.addr)
    glGenBuffers(1, result.mesh.vbo.addr)
    glGenBuffers(1, result.mesh.ebo.addr)

    # bind VAO
    glBindVertexArray(result.mesh.vao)

    # mesh VBO
    glBindBuffer(GL_ARRAY_BUFFER, result.mesh.vbo)
    glBufferData(GL_ARRAY_BUFFER, cint(cfloat.sizeof * result.vertices.len), result.vertices[0].addr, GL_STATIC_DRAW)

    # mesh EBO, for index
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, result.mesh.ebo)
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, cint(cuint.sizeof * result.indices.len), result.indices[0].addr, GL_STATIC_DRAW)

    # bind VAO
    glEnableVertexAttribArray(0)
    glVertexAttribPointer(0'u32, 2, EGL_FLOAT, false, cfloat.sizeof * 2, nil)

    # unbind, unbind VAO first, otherwise binded data will be unbind (loss)
    glBindVertexArray(0)
    glBindBuffer(GL_ARRAY_BUFFER, 0)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0)
    ]#

    return result

proc getMesh*(this: Square): ptr tuple[vao, vbo, ebo: uint32] =
    return this.mesh.addr

proc getVertices*(this: Square): ptr seq[float32] =
    return this.vertices.addr

proc getVerticesNum*(this: Square): int =
    return this.vertices.len

proc getIndices*(this: Square): ptr seq[uint32] =
    return this.indices.addr

proc getIndicesNum*(this: Square): int =
    return this.indices.len

proc setColor*(this: Square, col: Vec3[float32]) =
    this.color = col

proc getColor*(this: Square): ptr Vec3[float32] =
    return this.color.addr

proc setAttribute*(this: Square, attr: Attribute) =
    this.attribute = attr

proc getAttribute*(this: Square): Attribute =
    return this.attribute

proc setCost*(this: Square, cost: int) =
    this.cost = cost

proc getCost*(this: Square): int =
    return this.cost

proc setCostFromStart*(this: Square, cost: int) =
    this.costFromStart = cost

    if this.attribute != start and this.attribute != goal:
        this.color = valueToColor(cost.float/100.0)

proc toRGB*(vec: Vec3[float32]): Vec3[float32] =
    return vec3(vec.x / 255, vec.y / 255, vec.z / 255)
