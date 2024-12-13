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
        final type = is_compressed(buffer);
        if (type != Uncompress) {
            buffer = inflate_data(buffer, type);
        }

        return buffer.toString();
    }
}

enum CompressType {
    Uncompress;
    ZLib;
    GZip;
}

// support with pitaya message compress
function is_compressed(data: Bytes): CompressType {
    if (data == null || data.length < 2) {
        return Uncompress;
    }

    final d0 = data.get(0);
    final d1 = data.get(1);

    if (d0 == 0x78 && (
        d1 == 0x9C ||
        d1 == 0x01 ||
        d1 == 0xDA ||
        d1 == 0x5E
    )) {
        return ZLib;
    } else if (d0 == 0x1F && d1 == 0x8B) {
        return GZip;
    } else {
        return Uncompress;
    }
}

function inflate_data(data: Bytes, type: CompressType): Bytes {
    switch (type) {
        case ZLib | GZip:
            return haxe.zip.Uncompress.run(data);
        default:
            return data;    
    }
}