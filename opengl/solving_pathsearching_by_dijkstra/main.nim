import docopt
import strutils

import main_window

const
    VERSION = "1.0.0"

let doc = """
dijkstra

Usage:
    dijkstra [--map_num=<num>] [--sps=<sps>]
    dijkstra (-h | --help)

  Options:
    --map_num=<num>   map number                        (optional) [default: 0]
    --sps=<sps>       simulation step per sec.          (optional) [default: 30.0]
                       max speed is capped to 60.0fps by GLFW.
    -h --help         Show this screen.
    --version         Show version.
"""

if isMainModule :
    let args = docopt(doc, version=VERSION)
    
    openMainWindow(parseInt($args["--map_num"]), parseFloat($args["--sps"]))
