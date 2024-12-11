package client;

/**
 * 封包类型
 */
enum abstract PackageType(Int) {
    final HANDSHAKE = 1;
    final HANDSHAKE_ACK = 2;
    final HEARTBEAT = 3;
    final DATA = 4;
    final KICK = 5;
}

/**
 * 消息类型
 */
enum abstract MessageType(Int) {
    final REQUEST = 0;
    final NOTIFY = 1;
    final RESPONSE = 2;
    final PUSH = 3;
}

/**
 * 协议相关定义
 */
class ProtocolDef {
    static public final PKG_HEAD_BYTES = 4;
    static public final MSG_FLAG_BYTES = 1;
    static public final MSG_ROUTE_CODE_BYTES = 2;
    static public final MSG_ID_MAX_BYTES = 5;
    static public final MSG_ROUTE_LEN_BYTES = 1;

    static public final MSG_ROUTE_CODE_MAX = 0xffff;

    static public final MSG_COMPRESS_ROUTE_MASK = 0x1;
    static public final MSG_TYPE_MASK = 0x7;
}