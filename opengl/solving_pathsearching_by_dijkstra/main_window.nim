import strformat

import nimgl/glfw
import nimgl/opengl
import glm

import config
import square
import solver

var solverCanStepForward = true

proc keyProc(window: GLFWWindow, key: int32, scancode: int32, action: int32, mods: int32): void {.cdecl.} =
    if (key == GLFWKey.Escape or key == GLFWKey.Q) and action == GLFWPress:
        window.setWindowShouldClose(true)

    elif key == GLFWKey.Space and action == GLFWPress:
        #glPolygonMode(GL_FRONT_AND_BACK, if action != GLFWRelease: GL_LINE else: GL_FILL)
        if action != GLFWRelease:
            if solverCanStepForward:
                solverCanStepForward = false
            else:
                solverCanStepForward = true

    elif key == GLFWKey.B:
        glPolygonMode(GL_FRONT_AND_BACK, if action != GLFWRelease: GL_LINE else: GL_FILL)

proc statusShader(shader: uint32) =
    var status: int32
    glGetShaderiv(shader, GL_COMPILE_STATUS, status.addr);
    if status != GL_TRUE.ord:
        var
            log_length: int32
            message = newSeq[char](1024)
        
        glGetShaderInfoLog(shader, 1024, log_length.addr, message[0].addr);
        echo message

proc registerRenderingObject(renderingObject: Square) =     
    # generate buffer
    glGenVertexArrays(1, renderingObject.mesh.vao.addr)
    glGenBuffers(1, renderingObject.mesh.vbo.addr)
    glGenBuffers(1, renderingObject.mesh.ebo.addr)

    # bind VAO
    glBindVertexArray(renderingObject.mesh.vao)

    # mesh VBO
    glBindBuffer(GL_ARRAY_BUFFER, renderingObject.mesh.vbo)
    glBufferData(GL_ARRAY_BUFFER, cint(cfloat.sizeof * renderingObject.vertices.len), renderingObject.vertices[0].addr, GL_STATIC_DRAW)

    # mesh EBO, for index
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, renderingObject.mesh.ebo)
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, cint(cuint.sizeof * renderingObject.indices.len), renderingObject.indices[0].addr, GL_STATIC_DRAW)

    # bind VAO
    glEnableVertexAttribArray(0)
    glVertexAttribPointer(0'u32, 2, EGL_FLOAT, false, cfloat.sizeof * 2, nil)

    # unbind, unbind VAO first, otherwise binded data will be unbind (loss)
    glBindVertexArray(0)
    glBindBuffer(GL_ARRAY_BUFFER, 0)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0)

proc renderScene(drawingList: seq[Square], program: GLuint, uColor: GLint, uMVP: GLint, mvp: var Mat4) =
    # shader
    glUseProgram(program)
    # feed ortho matrix to shader
    glUniformMatrix4fv(uMVP, 1, false, mvp.caddr)

    for renderObject in drawingList:
        # feed color to shader
        glUniform3fv(uColor, 1, renderObject.color.caddr)
        # bind the vao for drawing
        glBindVertexArray(renderObject.mesh.vao)
        # draw
        glDrawElements(GL_TRIANGLES, renderObject.indices.len.cint, GL_UNSIGNED_INT, nil)

        glBindVertexArray(0)

proc genSquareVertex(centerX: float32, centerY: float32, edge_len: float32): seq[float32] = 
    #[
        return [left_bottom_x, left_bottom_y,
                left_top_x, left_top_y,
                right_top_x, right_top_y,
                right_bottom_x, right_bottom_y]
    ]#
    var diffFromCenter = (edge_len/2.0).float32
    return @[centerX-diffFromCenter, centerY-diffFromCenter,
             centerX-diffFromCenter, centerY+diffFromCenter,
             centerX+diffFromCenter, centerY+diffFromCenter,
             centerX+diffFromCenter, centerY-diffFromCenter,
            ]

proc openMainWindow*(mapNumber: int, simStepPerSec: float32=30.0) =
    var mapNum = 0
    if mapNumber >= problemList.len or mapNumber < 0:
        echo fmt"map numeber {mapNumber} not found, set to 0"
    else:
        mapNum = mapNumber

    echo "press ESC or Q to quit."

    # GLFW
    doAssert glfwInit()

    glfwWindowHint(GLFWContextVersionMajor, 3)
    glfwWindowHint(GLFWContextVersionMinor, 3)
    glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE)
    glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
    glfwWindowHint(GLFWResizable, GLFW_FALSE)

    let w: GLFWWindow = glfwCreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "NimGL", nil, nil)
    doAssert w != nil

    discard w.setKeyCallback(keyProc)
    w.makeContextCurrent

    # Opengl
    doAssert glInit()
    #echo $glVersionMajor & "." & $glVersionMinor

    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

    var
        vertex  : uint32
        fragment: uint32
        program : uint32

    vertex = glCreateShader(GL_VERTEX_SHADER)
    var vsrc: cstring = """
#version 330 core
layout (location = 0) in vec2 aPos;

uniform mat4 uMVP;

void main() {
  gl_Position = vec4(aPos, 0.0, 1.0) * uMVP;
}
"""
    glShaderSource(vertex, 1'i32, vsrc.addr, nil)
    glCompileShader(vertex)
    statusShader(vertex)

    fragment = glCreateShader(GL_FRAGMENT_SHADER)
    var fsrc: cstring = """
#version 330 core
out vec4 FragColor;

uniform vec3 uColor;

void main() {
  FragColor = vec4(uColor, 1.0f);
}
"""
    glShaderSource(fragment, 1, fsrc.addr, nil)
    glCompileShader(fragment)
    statusShader(fragment)

    program = glCreateProgram()
    glAttachShader(program, vertex)
    glAttachShader(program, fragment)
    glLinkProgram(program)

    var
        log_length: int32
        message = newSeq[char](1024)
        pLinked: int32

    glGetProgramiv(program, GL_LINK_STATUS, pLinked.addr);
    if pLinked != GL_TRUE.ord:
        glGetProgramInfoLog(program, 1024, log_length.addr, message[0].addr);
        echo message

    let
        uColor = glGetUniformLocation(program, "uColor")
        uMVP   = glGetUniformLocation(program, "uMVP")
    var
        bg    = vec3(33f, 33f, 33f).toRgb()
        mvp   = ortho(-WINDOW_ASPECT, WINDOW_ASPECT, -1.0f, 1.0f, -1f, 1f)
        #mvp   = ortho(-1f, 1f, -1.0f, 1.0f, -1f, 1f)


    var
        renderList: seq[Square]

    #[
    _________________________
    |    ^
    |    | gridMarginY
    |    v________________________...
    |<-->|     ^        |
    |    |     | dFC    |
    |    |     v        |
    |    |<--->* center |
    |    |              |
    |    |              |
    |    |______________|_________...
    |    |
    |    |
    |    |
    |    |
    |    ...
    ]#
  
    # calc. edge lengh from larger number of grid which ranged in [-1, 1] to make square
    var
        #adjustment = if WINDOW_WIDTH <= WINDOW_HEIGHT: WINDOW_ASPECT else: WINDOW_ASPECT
        #square_edge_len = (2.0/(max(GRID_X_NUM, GRID_Y_NUM).int).float)#*adjustment
        square_edge_len = if WINDOW_ASPECT > 1.0: (2.0/(GRID_Y_NUM).int.float) else: (2.0/(GRID_X_NUM).int.float)*WINDOW_ASPECT
        gridMarginX = (2.0-square_edge_len*GRID_X_NUM)/2.0
        gridMarginY = (2.0-square_edge_len*GRID_Y_NUM)/2.0
    
        # left to right
        initialSquarePosX = -1.0+gridMarginX+(square_edge_len/2.0)
        # top to bottom
        initialSquarePosY = 1.0-gridMarginY-(square_edge_len/2.0)

        gridMatrix: array[GRID_Y_NUM, array[GRID_X_NUM, Square]]

        square: Square
        color: Vec3[float32]
        colorTable: array[4, Vec3[float32]] = [vec3(180f,180f,180f).toRgb(), vec3(20f,20f,20f).toRgb(), vec3(80f, 200f,250f).toRgb(), vec3(80f, 120f,250f).toRgb()]
        startX = 0
        startY = 0

    # this will make the grid
    # for efficiency, we should make the point of all grid and then use the VBO and indices to create a single mesh...
    for y in 0..<GRID_Y_NUM:
        for x in 0..<GRID_X_NUM:
            color = colorTable[problemList[mapNum][y][x]]
            square = newSquare(x, y, genSquareVertex(initialSquarePosX+(square_edge_len*x.float), initialSquarePosY-(square_edge_len*y.float), square_edge_len), color, Attribute(problemList[mapNum][y][x]))
            registerRenderingObject(square)
            renderList.insert(square, renderList.len)
            gridMatrix[y][x] = square

            if Attribute(problemList[mapNum][y][x]) == start:
                startX = x
                startY = y

    # shader
    glUseProgram(program)
    # feed ortho matrix to shader
    glUniformMatrix4fv(uMVP, 1, false, mvp.caddr)

    var
        currentTime, lastTime, elapsedTime: float
        #frameCount = 0 # needed when calc. fps
        alreadyCalc = false

    currentTime = 0.0
    lastTime = -100.0
    elapsedTime = 0.0
    glfwSetTime(0.0);

    var solver = newDijkstra(startX, startY, gridMatrix, true)

    while not w.windowShouldClose:
        # do nothing, and rendering (swapBuffer) will stop too
        # so pressing `B` will not change the screen
        if solver.solved:
            discard
        else:
            currentTime = glfwGetTime()
            elapsedTime = currentTime - lastTime
            
            if not alreadyCalc:
                solver.step()
                alreadyCalc = true

            if elapsedTime >= 1.0/simStepPerSec:
                if solverCanStepForward:
                    if not alreadyCalc:
                        solver.step()
                    else:
                        alreadyCalc = false

                glClearColor(bg.r, bg.g, bg.b, 1f)
                glClear(GL_COLOR_BUFFER_BIT)

                renderScene(renderList, program, uColor, uMVP, mvp)

                lastTime = glfwGetTime()

                w.swapBuffers

            #[
            # for calc fps
            if elapsedTime < 1.0:
                solver.step()
                glClearColor(bg.r, bg.g, bg.b, 1f)
                glClear(GL_COLOR_BUFFER_BIT)

                renderScene(renderList, program, uColor, uMVP, mvp)

                #lastTime = glfwGetTime()

                w.swapBuffers
                frameCount += 1
                glfwPollEvents()
            else:
                echo frameCount
                frameCount = 0
                lastTime = glfwGetTime()
            ]#

        glfwPollEvents()

    w.destroyWindow

    glfwTerminate()

    # we should release some memory, but it will finish anyway.
    # ex.
    #glDeleteVertexArrays(1, mesh.vao.addr)
    #glDeleteBuffers(1, mesh.vbo.addr)
    #glDeleteBuffers(1, mesh.ebo.addr)
