import glm

import config
import square

# I think there is a heap data structure in standard lib.
# but I will make by myself
type Heap = ref object of RootObj
    heapList: seq[Square]

proc newHeap(): Heap =
    new result

    result.heapList = @[]

    return result

proc dataSize(this: Heap): int =
    return this.heapList.len

proc sortForPush(this: Heap) =
    var index: int
    var parentIndex: int
    var tmpNode: Square

    index = this.heapList.len-1
    while true:
        if index != 0:
            parentIndex = ((index-1)/2).int

            if this.heapList[index].costFromStart < this.heapList[parentIndex].costFromStart:
                tmpNode = this.heapList[index]
                this.heapList[index] = this.heapList[parentIndex]
                this.heapList[parentIndex] = tmpNode

                index = parentIndex
            else:
                break

        else:
            break

proc sortForPop(this: Heap) =
    var index: int
    var leftChildIndex, rightChildIndex: int
    var tmpNode: Square

    tmpNode = this.heapList[this.heapList.len-1]
    this.heapList.delete(this.heapList.len-1)
    this.heapList.insert(tmpNode, 0)

    index = 0
    while true:
        leftChildIndex = index*2+1
        rightChildIndex = index*2+2

        if leftChildIndex < this.heapList.len:
            tmpNode = this.heapList[leftChildIndex]

        # no child
        else:
            break

        # if right side child exist
        if rightChildIndex < this.heapList.len:
            # check right side
            if this.heapList[rightChildIndex].costFromStart < tmpNode.costFromStart:
                tmpNode = this.heapList[rightChildIndex]

                # swap right side child
                if this.heapList[index].costFromStart > tmpNode.costFromStart:
                    this.heapList[rightChildIndex] = this.heapList[index]
                    this.heapList[index] = tmpNode
                    index = rightChildIndex

                    continue
                else:
                    break

            else:
                # swap left side child
                if this.heapList[index].costFromStart > tmpNode.costFromStart:
                    this.heapList[leftChildIndex] = this.heapList[index]
                    this.heapList[index] = tmpNode
                    index = leftChildIndex

                # no swap
                else:
                    break


        # if right side child does NOT exist
        else:
            # swap left side child
            if this.heapList[index].costFromStart > tmpNode.costFromStart:
                this.heapList[leftChildIndex] = this.heapList[index]
                this.heapList[index] = tmpNode
                index = leftChildIndex

            # no swap
            else:
                break

proc push(this: Heap, newNode: Square) = 
    this.heapList.insert(newNode, this.heapList.len)
    this.sortForPush()

proc pop(this: Heap): Square =
    var minData: Square = nil

    if this.heapList.len > 0:
        minData = this.heapList[0]

        this.heapList.delete(0)

        if this.heapList.len > 0:
            this.sortForPop()

    return minData

################################################################
# solver
#
type Dijkstra* = ref object of RootObj
    nodeData: array[GRID_Y_NUM, array[GRID_X_NUM, Square]]
    visited: array[GRID_Y_NUM, array[GRID_X_NUM, int]]
    nextNodeList: Heap
    currentNode: Square

    eachStepSameCost: bool
    currentMinScore: int
    searchDirection: seq[array[2, int]]
    goalNode: Square
    goalMinCost: int
    solved*: bool

proc newDijkstra*(startX: int, startY: int, data: array[GRID_Y_NUM, array[GRID_X_NUM, Square]], stepSameCost: bool = false): Dijkstra =
    #[
        if `eachStepSameCost` is `true`, it will render one step
        when all the same cost square was searched.
    ]#

    new result

    result.nodeData = data

    for y in 0..<GRID_Y_NUM:
        for x in 0..<GRID_X_NUM:
            result.visited[y][x] = 0

    result.nextNodeList = newHeap()
    # (x,y) order
    result.searchDirection = @[[0, 1],[-1, 0],[0, -1],[1, 0]]

    data[startY][startX].cost = 0
    data[startY][startX].costFromStart = 0
    result.visited[startY][startX] = 1
    result.currentNode = data[startY][startX]

    result.eachStepSameCost = stepSameCost
    result.currentMinScore = 0

    result.goalNode = nil
    result.goalMinCost = 999999999
    result.solved = false

    return result

proc isValidSquare(this: Dijkstra, nextX: int, nextY: int): bool =
    if nextX >= GRID_X_NUM or nextX < 0 or nextY >= GRID_Y_NUM or nextY < 0:
        return false

    if this.nodeData[nextY][nextX].attribute != wall:
        return true
    else:
        return false

proc checkNext(this: Dijkstra) =
    var
        totalCost: int
        nextX: int
        nextY: int

    for sd in this.searchDirection:
        nextX = this.currentNode.posX+sd[0]
        nextY = this.currentNode.posY+sd[1]

        if this.isValidSquare(nextX, nextY):
            if this.visited[nextY][nextX] == 0 and this.nodeData[nextY][nextX].attribute != goal:
                this.nextNodeList.push(this.nodeData[nextY][nextX])
                this.visited[nextY][nextX] = 1

            totalCost = this.currentNode.costFromStart+this.nodeData[nextY][nextX].cost
            if totalCost < this.nodeData[nextY][nextX].costFromStart:
                this.nodeData[nextY][nextX].setCostFromStart(totalCost)
                this.nodeData[nextY][nextX].parentNode = this.currentNode

                if this.nodeData[nextY][nextX].attribute == goal:
                    this.goalNode = this.nodeData[nextY][nextX]
                    this.goalMinCost = totalCost

proc selectNext(this: Dijkstra) = 
    var nextNode: Square

    if this.nextNodeList.dataSize() > 0:
        nextNode = this.nextNodeList.pop()

        if nextNode.costFromStart >= this.goalMinCost:
            this.solved = true
            echo "solver: solved"
            return

        this.currentNode = nextNode

    else:
        this.solved = true

        if this.goalNode != nil:
            echo "solver: solved!"
        else:
            echo "solver: no goal found."

proc drawMinPath(this: Dijkstra) =
    if this.goalNode != nil:
        var node = this.goalNode
        var pathColor = vec3(255f,255f,255f).toRgb()

        #echo cast[ptr Square](node).posY, ",", cast[ptr Square](node).posX
        #node = cast[Square](node).parentNode
        #while node != nil:
        #    echo cast[ptr Square](node).posY, ",", cast[ptr Square](node).posX
        #    cast[ptr Square](node).color = pathColor
        #    node = cast[Square](node).parentNode

        node = node.parentNode
        while node.parentNode != nil:
            node.setColor(pathColor)
            node = node.parentNode

proc step*(this: Dijkstra) = 
    if not this.solved:
        # render when all same cost node had been searched
        if this.eachStepSameCost:
            var prevScore = this.currentNode.costFromStart

            while prevScore == this.currentNode.costFromStart and not this.solved:
                this.checkNext()
                this.selectNext()

        # render each step
        else:
            this.checkNext()
            this.selectNext()

    else:
        this.drawMinPath()

