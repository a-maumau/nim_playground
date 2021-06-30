import docopt

import ping

const
    VERSION = "1.0.0"

let doc = """
ping

Usage:
    ping <addr>
    ping (-h | --help)

Options:
    <addr>      IP address 
    -h --help   Show this screen.
    --version   Show version.
"""

if isMainModule:
    let args = docopt(doc, version=VERSION)
    
    sendPingPacket($args["<addr>"])
