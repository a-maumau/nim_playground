#[
    color mapper to change the grid color which is related to distance.
]#

import math

import glm

# array of (r,g,b) 
const baseColor = [[0,0,1], [0,1,1], [0,1,0], [1,1,0], [1,0,0]]
const numColorMin1 = baseColor.len-1

proc valueToColor*(value: float): Vec3[float32] = 
    var fractBetween = 0.0
    var val = value
    var idx1, idx2: int
    var r,g,b: float32

    if val <= 0:
        idx1 = 0
        idx2 = 0
    elif val >= 1:
        idx1 = numColorMin1
        idx2 = numColorMin1
    else:
        val = val * numColorMin1
        idx1  = floor(val).int
        idx2  = idx1+1;
        fractBetween = val - idx1.float
    
    r = (baseColor[idx2][0] - baseColor[idx1][0]).float*fractBetween + baseColor[idx1][0].float
    g = (baseColor[idx2][1] - baseColor[idx1][1]).float*fractBetween + baseColor[idx1][1].float
    b = (baseColor[idx2][2] - baseColor[idx1][2]).float*fractBetween + baseColor[idx1][2].float

    return vec3(r,g,b)
