package client;

import client.Consts.ProtocolDef;
import client.Consts.MessageType;
import haxe.io.Bytes;
import haxe.io.Encoding;


typedef MessageData = {
    final id: Int;
    final type: Int;
    final compressRoute: Bool;
    final sRoute: String;          // route in string, compressRoute MUST!!! be false
    final iRoute: Int;             // route in int, compressRoute MUST!!! be true
    final body: Bytes;
}

class Message {


    /* static public final TYPE_REQUEST = 0;
    static public final TYPE_NOTIFY = 1;
    static public final TYPE_RESPONSE = 2;
    static public final TYPE_PUSH = 3; */

    /**
     * Message protocol encode.
     *
     * @param  id            message id
     * @param  type          message type
     * @param  compressRoute whether compress route
     * @param  route         route code or route string
     * @param  msg           message body bytes
     * @return {Bytes}       encode result
     */
    static public function encode(id: Int, type: Int, compressRoute: Bool, route: Any, msg: Bytes): Bytes {
        var idBytes = msg_has_id(type) ? calculate_msg_id_bytes(id) : 0;
        var msgLen = ProtocolDef.MSG_FLAG_BYTES + idBytes;

        if (msg_has_route(type)) {
            if (compressRoute) {
                if (!(route is Int)) {
                    throw 'error flag for number route!';
                }

                msgLen += ProtocolDef.MSG_ROUTE_CODE_BYTES;
            } else {
                msgLen += ProtocolDef.MSG_ROUTE_LEN_BYTES;
                if (route != null && route is String) {
                    var bRoute = Protocol.str_encode((route : String));
                    if (bRoute.length > 255) {
                        throw 'route max-length is overflow';
                    }

                    msgLen += bRoute.length;
                }
            }
        }

        if (msg != null) {
            msgLen += msg.length;
        }

        var buffer = Bytes.alloc(msgLen);
        var offset = 0;

        // add flag
        offset = encode_msg_flag(type, compressRoute, buffer, offset);

        // add message id
        if (msg_has_id(type)) {
            offset = encode_msg_id(id, buffer, offset);
        }

        // add route
        if (msg_has_route(type)) {
            offset = encode_msg_route(compressRoute, route, buffer, offset);
        }

        // add body
        if (msg != null) {
            offset = encode_msg_body(msg, buffer, offset);
        }

        return buffer;
    }

    /**
      * Message protocol decode.
      *
      * @param  buffer message bytes
      * @return {MessageData}            message object
      */
    static public function decode(buffer: Bytes): MessageData {
        var bytesLen = buffer.length;
        var bytes = Bytes.alloc(bytesLen);
        bytes.blit(0, buffer, 0, bytesLen);
        var offset = 0;
        var id = 0;

        // parse flag
        var flag = bytes.get(offset++);
        var compressRoute = (flag & ProtocolDef.MSG_COMPRESS_ROUTE_MASK) != 0;
        var type = (flag >> 1) & ProtocolDef.MSG_TYPE_MASK;

        // route in tow type, not use of Any
        var sRoute: String = "";
        var iRoute: Int = 0;

        // parse id
        if (msg_has_id(type)) {
//            var m = bytes.get(offset);
            var i = 0;

            do {
                var m = bytes.get(offset);
                id = id + ((m & 0x7f) * Std.int(Math.pow(2, 7 * i)));
                offset++;
                i++;
            } while (m >= 128);
        }

        // parse route
        if (msg_has_route(type)) {
            if (compressRoute) {
                iRoute = (bytes.get(offset++) << 8) | bytes.get(offset++);
            } else {
                var routeLen = bytes.get(offset++);
                if (routeLen > 0) {
                    var bRoute = Bytes.alloc(routeLen);
                    bRoute.blit(0, bytes, offset, routeLen);

                    sRoute = Protocol.str_decode(bRoute);
                } else {
                    sRoute = "";
                }

                offset += routeLen;
            }
        }

        // parse body
        var bodyLen = bytesLen - offset;
        var body = Bytes.alloc(bodyLen);

        body.blit(0, bytes, offset, bodyLen);

        return {
            id: id,
            type: type,
            compressRoute: compressRoute,
            sRoute: sRoute,
            iRoute: iRoute,
            body: Bytes,
        };
    }
}


function msg_has_id(type: Int): Bool {
    return switch (type) {
        case MessageType.REQUEST | MessageType.RESPONSE:
            return true;
        case _:
            return false;
    };
}

function msg_has_route(type: Int): Bool {
    return switch (type) {
        case MessageType.REQUEST | MessageType.NOTIFY | MessageType.PUSH:
            return true;
        case _:
            return false;
    }
}

function calculate_msg_id_bytes(id: Int): Int {
    var len = 0;

    do {
        len += 1;
        id >>= 7;
    } while (id > 0);

    return len;
}

function encode_msg_flag(type: Int, compressRoute: Bool, buffer: Bytes, offset: Int): Int {
    if (type != MessageType.REQUEST && type != MessageType.NOTIFY && 
        type != MessageType.RESPONSE && type != MessageType.PUSH) {
        throw 'unknown message type: $type';
    }

    buffer.set(offset, (type << 1) | (compressRoute ? 1 : 0));

    return offset + ProtocolDef.MSG_FLAG_BYTES;
}

function encode_msg_id(id: Int, buffer: Bytes, offset: Int): Int {
    do {
        var tmp = id % 128;
        var next = Math.floor(id / 128);

        if (next != 0) {
            tmp += 128;
        }
        buffer.set(offset++, tmp);

        id = next;
    } while (id != 0);

    return offset;
}

function encode_msg_route(compressRoute: Bool, route: Any, buffer: Bytes, offset: Int): Int {
    if (compressRoute) {
        var nRoute: Int = (route : Int);

        if (nRoute > ProtocolDef.MSG_ROUTE_CODE_MAX) {
            throw 'route number is overflow';
        }

        buffer.set(offset++, (nRoute >> 8) & 0xff);
        buffer.set(offset++, route & 0xff);
    } else {
        var bRoute: Bytes = Bytes.ofString((route : String), Encoding.UTF8);

        if (bRoute != null && bRoute.length > 0) {
            buffer.set(offset++, bRoute.length & 0xff);
            buffer.blit(offset, bRoute, 0, bRoute.length);
            offset += bRoute.length;
        } else {
            buffer.set(offset++, 0);
        }
    }

    return offset;
}

function encode_msg_body(msg: Bytes, buffer: Bytes, offset: Int): Int {
    buffer.blit(offset, msg, 0, msg.length);
    return offset + msg.length;
}