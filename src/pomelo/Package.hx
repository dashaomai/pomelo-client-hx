package pomelo;

import pomelo.Consts.ProtocolDef;
import haxe.io.Bytes;

typedef PackageData = {
    final type: Int;
    final body: Null<Bytes>;
}

/**
 * Package process
 */
class Package {
    /* static public final TYPE_HANDSHAKE = 1;
    static public final TYPE_HANDSHAKE_ACK = 2;
    static public final TYPE_HEARTBEAT = 3;
    static public final TYPE_DATA = 4;
    static public final TYPE_KICK = 5; */

    /**
     * Package protocol encode.
     *
     * Pomelo package format:
     * +------+-------------+------------------+
     * | type | body length |       body       |
     * +------+-------------+------------------+
     *
     * Head: 4bytes
     *   0: package type,
     *      1 - handshake,
     *      2 - handshake ack,
     *      3 - heartbeat,
     *      4 - data
     *      5 - kick
     *   1 - 3: big-endian body length
     * Body: body length bytes
     *
     * @param  {Int}    type   package type
     * @param  {Bytes} body   body content in bytes
     * @return {Bytes}        new byte array that contains encode result
     */
    static public function encode(type: Int, ?body: Bytes): Bytes {
        var length = body != null ? body.length : 0;
        var buffer = Bytes.alloc(ProtocolDef.PKG_HEAD_BYTES + length);
        
        buffer.set(0, type & 0xff);
        buffer.set(1, (length >> 16) & 0xff);
        buffer.set(2, (length >> 8) & 0xff);
        buffer.set(3, length & 0xff);

        if (body != null) {
            buffer.blit(4, body, 0, length);
        }

        return buffer;
    }

    /**
     * Package protocol decode.
     * See encode for package format.
     *
     * @param  {Bytes} buffer byte array containing package content
     * @return {Object}           {type: package type, body: body byte array}
     */
    static public function decode(buffer: Bytes): Array<PackageData> {
        var len = buffer.length;
        var bytes = Bytes.alloc(len);
        bytes.blit(0, buffer, 0, len);

        var offset = 0;
        var results: Array<PackageData> = [];

        while (offset < bytes.length) {
            var type = bytes.get(offset++);
            var length = ((bytes.get(offset++)) << 16 | (bytes.get(offset++)) << 8 | bytes.get(offset++)) >>> 0;
            var body: Null<Bytes> = if (length > 0) {
                var b = Bytes.alloc(length);
                b.blit(0, bytes, offset, length);

                offset += length;

                b;
            }  else {
                null;
            }

            results.push({type: type, body: body});
        }

        return results;
    }
}