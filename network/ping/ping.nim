#[
    ***IMPORTANT***
    To use rawsocket, this program must run in admin/root privileges.
    Otherwise creating nativesockets will return `INVALID_SOCKET`.

    This code is to send a ICMP echo request in IPv4, and only do sending packet.
    This code will not handle some error on ICMP packet.

    From ftp://ftp.rfc-editor.org/in-notes/rfc792.txt 
         https://datatracker.ietf.org/doc/html/rfc792

    RFC 792

        Echo or Echo Reply Message

        0                   1                   2                   3
        0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        |     Type      |     Code      |          Checksum             |
        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        |           Identifier          |        Sequence Number        |
        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        |     Data ...
        +-+-+-+-+-

        IP Fields:
            Addresses
              The address of the source in an echo message will be the
              destination of the echo reply message.  To form an echo reply
              message, the source and destination addresses are simply reversed,
              the type code changed to 0, and the checksum recomputed.

        IP Fields:
            Type
              8 for echo message;
              0 for echo reply message.

            Code
              0

            Checksum
              The checksum is the 16-bit ones's complement of the one's
              complement sum of the ICMP message starting with the ICMP Type.
              For computing the checksum , the checksum field should be zero.
              If the total length is odd, the received data is padded with one
              octet of zeros for computing the checksum.  This checksum may be
              replaced in the future.

            Identifier
              If code = 0, an identifier to aid in matching echos and replies,
              may be zero.

            Sequence Number
              If code = 0, a sequence number to aid in matching echos and
              replies, may be zero.

            Description
              The data received in the echo message must be returned in the echo
              reply message.

              The identifier and sequence number may be used by the echo sender
              to aid in matching the replies with the echo requests.  For
              example, the identifier might be used like a port in TCP or UDP to
              identify a session, and the sequence number might be incremented
              on each echo request sent.  The echoer returns these same values
              in the echo reply.

              Code 0 may be received from a gateway or a host.


    The actual packet we will receive in this code is ICMP packet which wrapped
    in the payload of IP packet.

    So the data we receive from `recvfrom` proc. will be formatted like following.

        0                   1                   2                   3
        0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ --
        |  Ver. |  IHL  |    DSCP   |ECN|         Total Length          |  |
        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+  |
        |         Identification        |Flags|     Fragment Offset     |  |
        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+  |
        | Time To Live  |   Protocol    |        Header Checksum        |  | IP header
        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+  | (20 bytes)
        |                       Source IP Address                       |  |
        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+  |
        |                    Destination IP Address                     |  |
        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ --                   --
        |     Type      |     Code      |          Checksum             |  |                    |
        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+  | IP packet payload  | ICMP header
        |           Identifier          |        Sequence Number        |  |  (ICMP packet)     |
        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+  |                   --
        |     Data ...                                                     ~                    ~ ICMP payload
        +-+-+-+-+-                                                        --                   --

    All header data must be embedded in big endian excluding the data field.
    In this case, ICMP packet is under the data field of IP packet.
    In the data field, the endian is decided by the apprilication or some format.
    For ICMP, it seem to be big endian, but some implementation does not follow this things.
        FYI
          https://ask.wireshark.org/question/15501/what-is-the-endianness-of-captured-packet-headers/

    We are not considering the case IP packet use the optional field.

    Basic flow of this code is
        1. make the ICMP packet data to send (which contains the time data)
        2. send packet by nativesocket to allow us to use `SockType.SOCK_RAW`, and `Protocol.IPPROTO_ICMP`
        3. receive replied packet
        4. calculate the round trip time

    As mentioned in the top of this comment, we did not handle some error which may occur in this process
    like request timeout. So this program will hang if unreachable host was inputted, and
    `Destination Unreachable` packet was not sent from somewhere.

    NOTE: this implementaton is basically assuming you are using INTEL machine (little endian).
]#

import os
import net
import times
import posix
import nativesockets

import strutils
import strformat

type
    ReplyPacketStatus {.pure.} = enum
        OK
        DifferentID
        DestinationUnreachable
        TypeMismatch

let replyPacketStatusMessage: array[ReplyPacketStatus, string] = ["OK",
                                                                  "Different ID",
                                                                  "Destination Unreachable",
                                                                  "Type Mismatch"]

# for nim style, `IcmpPacket` is recommended? 
type
    ICMPPacket = ref object of RootObj
        icmpType: uint8
        icmpCode: uint8
        icmpCsum: uint16
        icmpId  : uint16
        icmpSeq : uint16
        icmpData: array[8, uint8] # we will fill the data of epochTime() -> float64

    PacketInfo = ref object of RootObj
        ipVersion           : uint8
        ipIHL               : uint8
        ipDSCP              : uint8
        ipECN               : uint8
        ipTotalLength       : uint16
        ipIdentification    : uint16
        ipFLags             : uint8
        ipFlagmentOffset    : uint16
        ipTTL               : uint8
        ipProtocol          : uint8
        ipHeaderChecksum    : uint16
        ipSourceAddress     : uint32
        ipDestinationAddress: uint32

        icmpType            : uint8
        icmpCode            : uint8
        icmpCsum            : uint16
        icmpId              : uint16
        icmpSeq             : uint16
        icmpData            : seq[uint8]
        icmpDataLength      : uint16

#[
    Checksum
        The checksum is the 16-bit ones’s complement of the one’s complement sum of
        the ICMP message starting with the ICMP Type. For computing the checksum,
        the checksum field should be zero. If the total length is odd, the received
        data is padded with one octet of zeros for computing the checksum.
        This checksum may be replaced in the future.

    You can find some implementation on
      https://github.com/amitsaha/ping/blob/master/ping.c
      http://www.faqs.org/rfcs/rfc1071.html
    or somewhere.

    Above code is licensed in GPL, but the definition of this process is on RFC.
    So for my understanding, the code origin in other language and translation in nim
    is not violating the license in this case.

    If there is a misunderstood of licensing or something to be correctify, please contact me.
    Anyway, this code is for my study and for helping someone in the Internet.
]#
proc checksum(buf: pointer, size: int): uint16 =
    var
        sum: uint32 = 0
        s: int = size
        p: pointer = buf

    while s > 1:
        sum += cast[ptr uint16](p)[]

        # this emulates the syntax of buf++ of pointer
        # I am not sure to use uint64, but it should wrap the memory address space, I hope
        p = cast[pointer](cast[uint64](p) + 2)
        s -= 2

    # mop up an odd byte, if necessary
    if s == 1:
        sum += cast[ptr uint8](p)[]

    # add hi 16 to low 16
    sum = (sum shr 16) + (sum and 0x0000ffff)
    # add carry
    sum += (sum shr 16)

    return not (sum.uint16);

# just a wraper to address correctly
proc getICMPPacketAddr(p: ICMPPacket): pointer = 
    return p.icmpType.addr

proc createICMPEchoPacket(seq_num: uint16, packetSize: int): ICMPPacket =
    #[
        `icmpId` should be a process id for not to corrupt with other ping command.
        `icmpSeq` is actually not necessary for just timing RTT, I think.
    ]#

    new result

    # see the head comment for this values
    result.icmpType = 0x08
    result.icmpCode = 0x00
    result.icmpCsum = 0x0000
    result.icmpId = nativesockets.htons(getpid().uint16)
    result.icmpSeq = nativesockets.htons(seq_num)

    # we will embed a epoch time in payload
    var timeData = cast[array[8, uint8]](epochTime())
    for i in 0..<8:
        result.icmpData[i] = timeData[i]

    # checksum will be calculated with the checksum initialized to 0
    # if we use nativesockets.htons(), it won't reply
    result.icmpCsum = checksum(result.getICMPPacketAddr(), packetSize)

    return result

# for replied packet
proc validatePacketChecksum[N](icmpCsum: uint16, packet: array[N, uint8], recvSize: int): bool =
    #[
        this procedure is for validating the packet checksum

        bytes are formatted in
            0                   1                   2                   3
            0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ --
            |  Ver. |  IHL  |    DSCP   |ECN|         Total Length          |  |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+  |
            |         Identification        |Flags|     Fragment Offset     |  |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+  |
            | Time To Live  |   Protocol    |        Header Checksum        |  | IP header
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+  | (20 bytes)
            |                       Source IP Address                       |  |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+  |
            |                    Destination IP Address                     |  |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ --
            |     Type      |     Code      |          Checksum             |    ICMP packet start from 21th byte
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |           Identifier          |        Sequence Number        |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |     Data ...                                                   
            +-+-+-+-+-                                                       

        reads the ICMP packet data which will start from packet[20]
    ]#

    var tmpPacketData: array[N, uint8] = packet

    # checksum will be calculated with checksum set to 0
    tmpPacketData[22] = 0
    tmpPacketData[23] = 0

    return icmpCsum == checksum(tmpPacketData[20].addr, recvSize-20)

proc validateReply[N](requestPacket: ICMPPacket, replyPacket: array[N, uint8]): ReplyPacketStatus =
    #[
        this procedure is for validating the packet is sent by this program

        bytes are formatted in
            0                   1                   2                   3
            0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |  Ver. |  IHL  |    DSCP   |ECN|         Total Length          |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |         Identification        |Flags|     Fragment Offset     |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            | Time To Live  |   Protocol    |        Header Checksum        |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |                       Source IP Address                       |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |                    Destination IP Address                     |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |     Type      |     Code      |          Checksum             |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |           Identifier          |        Sequence Number        |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |     Data ...                                                   
            +-+-+-+-+-                                                       

        only reads the ICMP Identifier
    ]#

    var
        packetID: uint16

    # 3 is for Destination Unreachable
    if replyPacket[20] == 3:
        return ReplyPacketStatus.DestinationUnreachable
    # 0 is for echo reply
    elif replyPacket[20] != 0:
        return ReplyPacketStatus.TypeMismatch

    else:
        # convert big endian to little endian
        packetID = cast[uint16](replyPacket[25]) shl 8
        packetID += replyPacket[24]

        if requestPacket.icmpID != packetID:
            return ReplyPacketStatus.DifferentID
        else:
            return ReplyPacketStatus.OK

# for replied packet
proc parsePacket[N](packet: array[N, uint8], recvSize: int): PacketInfo =
    #[
        bytes are formatted in
            0                   1                   2                   3
            0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |  Ver. |  IHL  |    DSCP   |ECN|         Total Length          |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |         Identification        |Flags|     Fragment Offset     |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            | Time To Live  |   Protocol    |        Header Checksum        |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |                       Source IP Address                       |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |                    Destination IP Address                     |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |     Type      |     Code      |          Checksum             |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |           Identifier          |        Sequence Number        |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            |     Data ...                                                   
            +-+-+-+-+-                                                       

        so we will just read byte by byte. (if you are using big endian machine, you may can just cast it)

        Note we are not considering a option data for IP packet

        Also, we do not need the `recvSize` var., but some problem on receiving packet
        corrupting the `Total Length` bytes made us to use the total received bytes
        from the `recv` proc.

        The following computaion is doing a casting to little endian,
        I should use ntoh() stuff to maintain a capability of un-architectual order (little/big endian).
    ]#

    new result

    result.ipVersion = (packet[0] and 0b11110000) shr 4
    result.ipIHL = packet[0] and 0b00001111

    result.ipDSCP = (packet[1] and 0b11111100) shr 2
    result.ipECN = packet[1] and 0b00000011

    result.ipTotalLength = cast[uint16](packet[2]) shl 8
    result.ipTotalLength += packet[3]

    result.ipIdentification = cast[uint16](packet[4]) shl 8
    result.ipIdentification += packet[5]

    result.ipFLags = (packet[6] and 0b11100000) shr 5

    result.ipFlagmentOffset = cast[uint16](packet[6] and 0b00011111) shl 8
    result.ipFlagmentOffset = packet[7]

    result.ipTTL = packet[8]

    result.ipProtocol = packet[9]

    result.ipHeaderChecksum = cast[uint16](packet[10]) shl 8
    result.ipHeaderChecksum += packet[11]

    result.ipSourceAddress = cast[uint32](packet[12]) shl 24
    result.ipSourceAddress += cast[uint32](packet[13]) shl 16
    result.ipSourceAddress += cast[uint32](packet[14]) shl 8
    result.ipSourceAddress += cast[uint32](packet[15])

    result.ipDestinationAddress = cast[uint32](packet[16]) shl 24
    result.ipDestinationAddress += cast[uint32](packet[17]) shl 16
    result.ipDestinationAddress += cast[uint32](packet[18]) shl 8
    result.ipDestinationAddress += cast[uint32](packet[19])

    result.icmpType = packet[20]

    result.icmpCode = packet[21]

    # read check sum by little endian
    # I am not sure, but we did not swap the bytes when sending
    result.icmpCsum = packet[22]
    result.icmpCsum += cast[uint16](packet[23]) shl 8

    result.icmpId = cast[uint16](packet[24]) shl 8
    result.icmpId += packet[25]

    result.icmpSeq = cast[uint16](packet[26]) shl 8
    result.icmpSeq += packet[27]

    var currentByte = 28
    result.icmpDataLength = (recvSize - currentByte).uint16
    while currentByte < recvSize:
        result.icmpData.insert(packet[currentByte], result.icmpData.len)
        currentByte += 1

    return result

proc parseTimeData(packetData: var seq[uint8], recvTime: float64): float64 =
    #[
        return ms of diff. of time.
    ]#
    
    # we will fix to 8 because of recvTime is float (float64)
    let dataLen = 8
    var dataArray: array[8, uint8]

    # cast[float64](packetData) does not work on seq, I dont know why...
    for i in 0..<dataLen:
        dataArray[i] = packetData[i]

    return (recvTime-cast[float64](dataArray))*1000

proc printRequestICMP(requestPacket: ICMPPacket, packetSize: int) = 
    echo "ICMP echo request packet:"
    echo fmt"    Type              : {requestPacket.icmpType:<15} (0x{toHex(requestPacket.icmpType, 2)})"
    echo fmt"    Code              : {requestPacket.icmpCode:<15} (0x{toHex(requestPacket.icmpCode, 2)})"
    echo fmt"    Checksum          : {requestPacket.icmpCsum:<15} (0x{toHex(requestPacket.icmpCsum, 4)})"
    echo fmt"    ID                : {nativesockets.ntohs(requestPacket.icmpId):<15} (0x{toHex(nativesockets.ntohs(requestPacket.icmpId), 4)})"
    echo fmt"    Seq               : {nativesockets.ntohs(requestPacket.icmpSeq):<15} (0x{toHex(nativesockets.ntohs(requestPacket.icmpSeq), 4)})"

    echo ""
    var
        row = 0
        col = 0
        bytes = 0
        dp: pointer = getICMPPacketAddr(requestPacket)

    echo fmt"request packet ({packetSize} bytes):"
    echo "         0  1  2  3  4  5  6  7    8  9  A  B  C  D  E  F"
    echo "---------------------------------------------------------"
    #     0x0000: 00 01 02 03 04 05 06 07   08 09 0A 0B 0C 0D 0E 0F
    stdout.write(fmt"0x{toHex(row, 4)}: ")
    while true:
        stdout.write(fmt"{toHex(ord(cast[ptr uint8](dp)[]), 2)} ")
        col += 1
        bytes += 1
        dp = cast[pointer](cast[uint64](dp) + 1)

        if bytes >= packetSize:
            break
        
        if col > 15:
            echo ""
            col = 0
            row += 1
            stdout.write(fmt"0x{toHex(row*16, 4)}: ")

        if col == 8:
            stdout.write("  ")

    echo "\n"

    return

proc printPacket[N](packet: array[N, uint8], recvSize: int) = 
    var row = 0
    var col = 0
    var bytes = 0

    echo fmt"received IP packet ({recvSize} bytes):"
    echo "         0  1  2  3  4  5  6  7    8  9  A  B  C  D  E  F"
    echo "---------------------------------------------------------"
    #     0x0000: 00 01 02 03 04 05 06 07   08 09 0A 0B 0C 0D 0E 0F
    stdout.write(fmt"0x{toHex(row, 4)}: ")
    for i in packet:
        stdout.write(fmt"{toHex(ord(i), 2)} ")
        col += 1
        bytes += 1

        if bytes >= recvSize:
            break
        
        if col > 15:
            echo ""
            col = 0
            row += 1
            stdout.write(fmt"0x{toHex(row*16, 4)}: ")

        if col == 8:
            stdout.write("  ")

    echo "\n"

    return

proc printPacketInfo(pp: PacketInfo) = 
    var
        row = 0
        col = 0
        bytes: uint16 = 0

        srcAddr: string = $((pp.ipSourceAddress and 0xff000000u32) shr 24) & "." &
                          $((pp.ipSourceAddress and 0x00ff0000u32) shr 16) & "." &
                          $((pp.ipSourceAddress and 0x0000ff00u32) shr 8)  & "." &
                          $( pp.ipSourceAddress and 0x000000ffu32) 

        dstAddr: string = $((pp.ipDestinationAddress and 0xff000000u32) shr 24) & "." &
                          $((pp.ipDestinationAddress and 0x00ff0000u32) shr 16) & "." &
                          $((pp.ipDestinationAddress and 0x0000ff00u32) shr 8)  & "." &
                          $( pp.ipDestinationAddress and 0x000000ffu32) 

    echo "IP header:"
    echo fmt"    version           : {pp.ipVersion:<15} (0x{toHex(pp.ipVersion, 1)})"
    echo fmt"    IHL               : {pp.ipIHL:<15} (0x{toHex(pp.ipIHL, 1)})"
    echo fmt"    DSCP              : {pp.ipDSCP:<15} (0b{toBin(BiggestInt(pp.ipDSCP), 6)})"
    echo fmt"    ECN               : {pp.ipECN:<15} (0b{toBin(BiggestInt(pp.ipECN), 2)})"
    echo fmt"    TotalLength       : {pp.ipTotalLength:<15} (0x{toHex(pp.ipTotalLength, 4)})"
    echo fmt"    Identification    : {pp.ipIdentification:<15} (0x{toHex(pp.ipIdentification, 4)})"
    echo fmt"    FLags             : {pp.ipFLags:<15} (0b{toBin(BiggestInt(pp.ipFLags), 3)})"
    echo fmt"    FlagmentOffset    : {pp.ipFlagmentOffset:<15} (0x{toHex(pp.ipFlagmentOffset, 4)})"
    echo fmt"    TTL               : {pp.ipTTL:<15} (0x{toHex(pp.ipTTL, 2)})"
    echo fmt"    Protocol          : {pp.ipProtocol:<15} (0x{toHex(pp.ipProtocol, 2)})"
    echo fmt"    HeaderChecksum    : {pp.ipHeaderChecksum:<15} (0x{toHex(pp.ipHeaderChecksum, 4)})"
    echo fmt"    SourceAddress     : {srcAddr:<15} (0x{toHex(pp.ipSourceAddress, 8)})"
    echo fmt"    DestinationAddress: {dstAddr:<15} (0x{toHex(pp.ipDestinationAddress, 8)})"

    echo ""

    echo "ICMP header:"
    echo fmt"    Type              : {pp.icmpType:<15} (0x{toHex(pp.icmpType, 2)})"
    echo fmt"    Code              : {pp.icmpCode:<15} (0x{toHex(pp.icmpCode, 2)})"
    echo fmt"    Checksum          : {pp.icmpCsum:<15} (0x{toHex(pp.icmpCsum, 4)})"
    echo fmt"    Identifier        : {pp.icmpId:<15} (0x{toHex(pp.icmpId, 4)})"
    echo fmt"    Sequence Number   : {pp.icmpSeq:<15} (0x{toHex(pp.icmpSeq, 4)})"

    echo ""
    echo "ICMP payload:"
    echo "         0  1  2  3  4  5  6  7    8  9  A  B  C  D  E  F"
    echo "---------------------------------------------------------"
    #     0x0000: 00 01 02 03 04 05 06 07   08 09 0A 0B 0C 0D 0E 0F
    stdout.write(fmt"0x{toHex(row, 4)}: ")
    for i in pp.icmpData:
        stdout.write(fmt"{toHex(ord(i), 2)} ")
        col += 1
        bytes += 1

        if bytes >= pp.icmpDataLength:
            break
        
        if col > 15:
            echo ""
            col = 0
            row += 1
            stdout.write(fmt"0x{toHex(row*16, 4)}: ")

        if col == 8:
            stdout.write("  ")

    echo "\n"

    return

proc sendPingPacket*(ipAddr: string) = 
    var socket = createNativeSocket(Domain.AF_INET, SockType.SOCK_RAW, Protocol.IPPROTO_ICMP)
    if socket == INVALID_SOCKET:
        raiseOSError(osLastError())

    var
        destAddr = Sockaddr_in()

        pkt: ICMPPacket
        sizeOfICMPPacket = 16 # see the ICMPPacket for the size
        # these does not work
        # according to `https://forum.nim-lang.org/t/5010`, this should work...
        #sizeOfICMPPacket = sizeof(ICMPPacket)     # this will return 8 which is a size of pointer
        #sizeOfICMPPacket = sizeof(ICMPPacket[])   # causing type error
        #sizeOfICMPPacket = sizeof(ICMPPacket()[]) # this will return 24 for some cpu memory alignment, I think
        
        buf: array[256, uint8] # it should be just fine for any enough large array than the received data
        
        pktReturnTime: float
        receivedBytes: int
        replyStatus: ReplyPacketStatus

    destAddr.sin_family = toInt(Domain.AF_INET).uint8
    destAddr.sin_addr.s_addr = inet_addr(ipAddr)

    pkt = createICMPEchoPacket(1, sizeOfICMPPacket)
    # casting to SockAddr seems to be very common, not only on nim, but also on C lang.
    if socket.sendto(getICMPPacketAddr(pkt), sizeOfICMPPacket, 0, cast[ptr SockAddr](addr(destAddr)), sizeof(destAddr).Socklen) < 0:
        raiseOSError(osLastError())

    # this will receive IP packet
    # 20byte (IP) + ICMPPacket size you made, echo reply will fill the same data in payload.
    receivedBytes = socket.recv(buf.addr, sizeof(buf), 0)
    pktReturnTime = epochTime()

    replyStatus = validateReply(pkt, buf)
    #if replyStatus == ReplyPacketStatus.OK:
    #elif replyStatus == ReplyPacketStatus.DestinationUnreachable:
    #else:
    #    echo replyPacketStatusMessage[replyStatus]

    if receivedBytes < 0:
        raiseOSError(osLastError())

    # at least packet should have 28 bytes (IP: 20 bytes + ICMP: 8 bytes)
    elif receivedBytes > 27:
        #[
            I don't know why, but in my environment (source node was macOS),
            the data of buf's 3rd and 4th bytes does not match to the captured data.
            
            For example, the recived reply packet was 
                45 00 20 00 55 30 00 00   40 01 A3 3B C0 A8 00 F8
                C0 A8 00 15 00 00 E2 5C   DC 5A 01 00 01 02 03 04
                05 06 07 08 09 0A 0B 0C   0D 0E 0F 10 00 00 00 00
                00 00 00 00

            , but the reply packet captured at the dest. was
                         ----- this two were different from received data
                        /  /
                       v  v
                45 00 00 34 55 30 00 00   40 01 A3 3B C0 A8 00 F8
                C0 A8 00 15 00 00 E2 5C   DC 5A 01 00 01 02 03 04
                05 06 07 08 09 0A 0B 0C   0D 0E 0F 10 00 00 00 00
                00 00 00 00

            , and the bytes are representing a total length of packet so it's very weird...
            In this case, the captured data is correct which 0x0034 == 52 is obviously correct.
            This is not a problem of endian or similar things. The bits is definitely wrong
            , while received bytes from `recv` proc. is returning correctly = 52.


            ***I confirmed this is a PROBLEM on macOS*** (and may other OS).
            at least in centOS, it was a expected result.
        ]#
        var pktInfo = parsePacket(buf, receivedBytes)

        echo "\n#### echo request packet #######################################\n"
        printRequestICMP(pkt, sizeOfICMPPacket)

        echo "\n#### echo reply packet #########################################\n"
        printPacket(buf, receivedBytes)
        printPacketInfo(pktInfo)

        var rtt = parseTimeData(pktInfo.icmpData, pktReturnTime)
        echo "\n#### ping result ####"
        echo fmt"  Reply status: {replyPacketStatusMessage[replyStatus]}"
        echo    "  Checksum    : " & (if validatePacketChecksum(pktInfo.icmpCsum, buf, receivedBytes): "OK" else: "Wrong")
        echo fmt"  RTT         : {rtt:.3f} ms"
        #if rtt < 1.0:
        #    echo fmt"    RTT: < 1 ms"
        #else:
        #    echo fmt"    RTT: {rtt:.3f} ms"

    else:
        echo "error, packet is not enough"

when isMainModule:
    sendPingPacket("127.0.0.1")
