package pomelo;

import haxe.io.Bytes;
import haxe.io.Encoding;

class Protocol {
    static public final PKG_HEAD_BYTES = 4;
    static public final MSG_FLAG_BYTES = 1;
    static public final MSG_ROUTE_CODE_BYTES = 2;
    static public final MSG_ID_MAX_BYTES = 5;
    static public final MSG_ROUTE_LEN_BYTES = 1;

    static public final MSG_ROUTE_CODE_MAX = 0xffff;

    static public final MSG_COMPRESS_ROUTE_MASK = 0x1;
    static public final MSG_TYPE_MASK = 0x7;

    static public function str_encode(str: String): Bytes {
        return Bytes.ofString(str, Encoding.UTF8);
    }

    static public function str_decode(buffer: Bytes): String {
        return buffer.toString();
    }
}