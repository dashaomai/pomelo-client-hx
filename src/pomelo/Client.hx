package pomelo;

import pomelo.Consts.ClientDef;
import pomelo.Message.MessageData;
import pomelo.Consts.MessageType;
import pomelo.Package.PackageData;
import pomelo.Consts.PackageType;
import pomelo.DecodeIO.IDecodeIODecoder;
import pomelo.DecodeIO.IDecodeIOEncoder;
import haxe.net.WebSocket;
import emitter.signals.Emitter;
import haxe.io.Bytes;
import haxe.ds.Vector;
import haxe.Timer;
import emitter.signals.SignalType;
import haxe.Json;

typedef HandshakeData = {
    final sys: {
        final type: String;
        final version: String;
        final rsa: {};
    };
    final user: {};
}

typedef ConnectParams = {
    final maxReconnectAttempts: Int;
}

class Client {
    static final HX_WS_CLIENT_TYPE = 'hx-websocket';
    static final HX_WS_CLIENT_VERSION = '0.1.0';

    static final HAND_SHAKE_DATA: HandshakeData = {
        sys: {
            type: Client.HX_WS_CLIENT_TYPE,
            version: Client.HX_WS_CLIENT_VERSION,
            rsa: {},
        },
        user: {},
    }

    static final DEFAULT_MAX_RECONNECT_ATTEMPTS = 10;

    static var ON_RECONNECT: SignalType<Void -> Void> = "on_reconnect";
    static var ON_ERROR: SignalType1<Void -> Void, String> = "on_error";
    static var ON_IO_ERROR: SignalType1<Void -> Void, String> = "on_io_error";
    static var ON_CLOSE: SignalType1<Void -> Void, Dynamic> = "on_close";

    final decodeIO_encoder: Null<IDecodeIOEncoder>;
    final decodeIO_decoder: Null<IDecodeIODecoder>;

    final url: String;
    var socket: WebSocket;

    #if sys
    final socketTicker: Timer;
    #end

    public final emitter: Emitter;

    var heartbeatInterval: Int;
    var heartbeatTimeout: Int;
    var nextHeartbeatTimeout: Int;
    var gapThreshold: Int;
    var heartbeatTimer: Timer;

    final encode: Any;
    final decode: Any;

    var reconnect: Bool;
    var reconnectAttempts: Int;
    var reconnectionDelay: Int;
    var reconnectTimer: Timer;

    // compacted route from route string -> route code
    final routeDict: Map<String, Int>;
    // compacted route from route code -> route string
    final routeAbbrs: Map<Int, String>;
    // pending requests from request-id -> route
    final pendingRequests: Vector<Null<String>>;

    public function new(
        url: String,
        ?handshakeCallback: Dynamic -> Void,
        ?initialCallback: Void -> Void
    ) {
        // TODO
        this.decodeIO_encoder = null;
        this.decodeIO_decoder = null;

        this.url = url;

        #if sys
        this.socketTicker = new Timer(100);
        this.socketTicker.run = () -> {
            if (this.socket != null) {
                this.socket.process();
            }
        };
        #end

        this.emitter = new Emitter();

        this.decode = this.default_decode;
        this.encode = this.default_encode;

        this.routeDict = new Map();
        this.routeAbbrs = new Map();
        this.pendingRequests = new Vector(128);

        if (handshakeCallback != null) {
            this.handshake_callback = handshakeCallback;
        }
        if (initialCallback != null) {
            this.initial_callback = initialCallback;
        }
    }

    public function connect(?params: ConnectParams):Void {
        var maxReconnectAttempts: Int;

        maxReconnectAttempts = params?.maxReconnectAttempts ?? Client.DEFAULT_MAX_RECONNECT_ATTEMPTS;

        this.socket = WebSocket.create(url, [], true);
        this.socket.onopen = function (): Void {
            if (this.reconnect) {
                this.emitter.emit(Client.ON_RECONNECT);
            }

            trace('pomelo client onOpen');

            this.reset();

            final packet = Package.encode(
                PackageType.HANDSHAKE,
                Protocol.str_encode(
                    haxe.Json.stringify(Client.HAND_SHAKE_DATA),
                ),
            );

            this.send(packet);
        };
        this.socket.onmessageBytes = function (message: Bytes): Void {
            trace('pomelo client receive ${message.length} bytes.');

            this.process_package(Package.decode(message));

            if (this.heartbeatTimeout > 0) {
                this.nextHeartbeatTimeout = Std.int(Date.now().getTime()) + this.heartbeatTimeout;
            }
        };
        this.socket.onmessageString = function (message: String): Void {
            trace(message);
        };
        this.socket.onerror = function (message: String): Void {
            trace('pomelo client error:', message);

            this.emitter.emit(ON_IO_ERROR, message);
        };
        this.socket.onclose = function (?evt: Dynamic): Void {
            trace('pomelo client closed.');

            this.emitter.emit(ON_CLOSE, evt);
        };
    }

    function send(packet: Bytes): Void {
        trace('pomelo client send ${packet.length} bytes.');

        this.socket.sendBytes(packet);
    }

    function process_package(msgs: Array<PackageData>): Void {
        for (i in 0...msgs.length) {
            final msg = msgs[i];

            switch (msg.type) {
                case PackageType.HANDSHAKE: this.handshake(msg.body);
                case PackageType.HEARTBEAT:
                case PackageType.DATA:
                case PackageType.KICK:
            }
        }
    }

    function handshake(body: Bytes): Void {
        var data = Json.parse(Protocol.str_decode(body));

        switch (data.code) {
            case ClientDef.RES_OK:
                this.handshake_init(data);

                final pkg = Package.encode(PackageType.HANDSHAKE_ACK);
                this.send(pkg);
                this.initial_callback();

            case ClientDef.RES_OLD_CLIENT:
                this.emitter.emit(ON_ERROR, "client version can't fullfill");

            default:
                this.emitter.emit(ON_ERROR, 'handshake fail');
        }
    }

    function handshake_init(data: Dynamic): Void {
        if (data.sys != null && data.sys.heartbeat > 0) {
            this.heartbeatInterval = Std.int(data.sys.heartbeat) * 1000;
            this.heartbeatTimeout = this.heartbeatInterval * 2;
        } else {
            this.heartbeatInterval = 0;
            this.heartbeatTimeout = 0;
        }

        this.handshake_callback(data.user);
    }

    dynamic function handshake_callback(user: Dynamic): Void {

    }

    dynamic function initial_callback(): Void {

    }

    function init_data(data: Dynamic): Void {
        if (data == null || data.sys == null) {
            return;
        }

        final dict: Dynamic = data.sys.dict;
        if (dict != null) {
            for (k in Reflect.fields(dict)) {
                final v = Reflect.field(dict, k);
                this.routeDict.set(k, v);
                this.routeAbbrs.set(v, k);
            }
        }
    }

    function reset(): Void {
        trace('pomelo client reset.');

        this.reconnect = false;
        this.reconnectionDelay = 5000;
        this.reconnectAttempts = 0;
        this.reconnectTimer?.stop();
    }

    function default_decode(data: Bytes): Any {
        var msg = Message.decode(data);

        if (msg.id > 0) {
            msg.sRoute = this.pendingRequests[msg.id];
            this.pendingRequests[msg.id] = null;

            if (msg.sRoute == null || msg.sRoute.length == 0) {
                return null;
            }
        }

        msg.payload = de_compose(msg);
        return msg;
    }

    function default_encode(reqId: Int, sRoute: String, msg: Any) {
        var type = reqId > 0 ? MessageType.REQUEST : MessageType.NOTIFY;

        var buffer: Bytes;

        if (this.decodeIO_encoder != null && this.decodeIO_encoder.lookup(sRoute)) {
            buffer = this.decodeIO_encoder.build(sRoute).encode(msg);
        } else {
            buffer = Protocol.str_encode(haxe.Json.stringify(msg));
        }

        var compressRoute = false;
        var iRoute: Int = 0;
        if (this.routeDict.exists(sRoute)) {
            iRoute = this.routeDict.get(sRoute);
            compressRoute = true;
        }

        return Message.encode(reqId, type, compressRoute, sRoute, iRoute, buffer);
    }

    function de_compose(msg: MessageData): Any {
        var route: String;

        if (msg.compressRoute) {
            if (!this.routeAbbrs.exists(msg.iRoute)) {
                return {};
            }

            route = this.routeAbbrs.get(msg.iRoute);
        } else {
            route = msg.sRoute;
        }

        if (this.decodeIO_decoder != null && this.decodeIO_decoder.lookup(route)) {
            return this.decodeIO_decoder.build(route).decode(msg.body);
        } else {
            return haxe.Json.parse(Protocol.str_decode(msg.body));
        }
    }
}