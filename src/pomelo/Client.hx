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
    static final MAX_REQUEST_ID = 128;
    static final DEFAULT_MAX_RECONNECT_ATTEMPTS = 10;

    static final HAND_SHAKE_DATA: HandshakeData = {
        sys: {
            type: ClientDef.HX_WS_CLIENT_TYPE,
            version: ClientDef.HX_WS_CLIENT_VERSION,
            rsa: {},
        },
        user: {},
    }

    static var ON_RECONNECT: SignalType<Void -> Void> = "on_reconnect";
    static var ON_ERROR: SignalType1<Void -> Void, String> = "on_error";
    static var ON_IO_ERROR: SignalType1<Void -> Void, String> = "on_io_error";
    static var ON_CLOSE: SignalType1<Void -> Void, Dynamic> = "on_close";

    static var ON_PUSH: SignalType2<Void -> Void, String, Dynamic> = "on_push";
    static var ON_KICK: SignalType1<Void -> Void, Null<Dynamic>> = "on_kick";

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
    var heartbeatTimeoutTimer: Timer;

    final encode: (Int, String, Any) -> Bytes;
    final decode: Bytes -> MessageData;

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
    // pending request cb from request-id -> callbcack
    final pendingCallbacks: Vector<Null<Dynamic -> Void>>;

    public function new(
        url: String,
        ?handshakeCallback: Dynamic -> Void,
        ?initialCallback: Void -> Void
    ) {
        // TODO
        decodeIO_encoder = null;
        decodeIO_decoder = null;

        this.url = url;

        #if sys
        socketTicker = new Timer(100);
        socketTicker.run = () -> {
            if (socket != null) {
                socket.process();
            }
        };
        #end

        emitter = new Emitter();

        decode = default_decode;
        encode = default_encode;

        routeDict = new Map();
        routeAbbrs = new Map();

        // request id in range(1~127)
        pendingRequests = new Vector(MAX_REQUEST_ID);
        pendingCallbacks = new Vector(MAX_REQUEST_ID);

        if (handshakeCallback != null) {
            handshake_callback = handshakeCallback;
        }
        if (initialCallback != null) {
            initial_callback = initialCallback;
        }
    }

    public function connect(?params: ConnectParams):Void {
        var maxReconnectAttempts: Int;

        maxReconnectAttempts = params?.maxReconnectAttempts ?? Client.DEFAULT_MAX_RECONNECT_ATTEMPTS;

        socket = WebSocket.create(url, [], true);
        socket.onopen = function (): Void {
            if (reconnect) {
                emitter.emit(Client.ON_RECONNECT);
            }

            trace('pomelo client onOpen');

            reset();

            final packet = Package.encode(
                PackageType.HANDSHAKE,
                Protocol.str_encode(
                    haxe.Json.stringify(Client.HAND_SHAKE_DATA),
                ),
            );

            send(packet);
        };
        socket.onmessageBytes = function (message: Bytes): Void {
            trace('pomelo client receive ${message.length} bytes.');

            process_package(Package.decode(message));

            if (heartbeatTimeout > 0) {
                nextHeartbeatTimeout = Std.int(Date.now().getTime()) + heartbeatTimeout;
            }
        };
        socket.onmessageString = function (message: String): Void {
            trace(message);
        };
        socket.onerror = function (message: String): Void {
            trace('pomelo client error:', message);

            emitter.emit(ON_IO_ERROR, message);
        };
        socket.onclose = function (?evt: Dynamic): Void {
            trace('pomelo client closed.');

            emitter.emit(ON_CLOSE, evt);
        };
    }

    function disconnect() {
        if (socket != null) {
            socket.close();
            trace('pomelo client disconnect');
            socket = null;
        }

        if (heartbeatTimer != null) {
            heartbeatTimer.stop();
            heartbeatTimer = null;
        }
        if (heartbeatTimeoutTimer != null) {
            heartbeatTimeoutTimer.stop();
            heartbeatTimeoutTimer = null;
        }

    }

    function send(packet: Bytes): Void {
        trace('pomelo client send ${packet.length} bytes.');

        try {
            socket.sendBytes(packet);
        } catch (e) {
            trace('pomelo client meet error: $e');
        }
    }

    function heartbeat(): Void {
        trace('pomelo client heartbeat received.');

        if (heartbeatInterval == 0) {
            // no heartbeat
            return;
        } else if (heartbeatTimer != null) {
            // already in a heartbeat loop
            return;
        }
        
        trace('pomelo client heartbeat actived.');

        var pkg = Package.encode(PackageType.HEARTBEAT);

        if (heartbeatTimeoutTimer != null) {
            heartbeatTimeoutTimer.stop();
            heartbeatTimeoutTimer = null;
        }

        heartbeatTimer = new Timer(heartbeatInterval);
        heartbeatTimer.run = () -> {
            trace('pomelo client send heartbeat.');
            send(pkg);

            // reset timeout
            if (heartbeatTimeoutTimer != null) {
                heartbeatTimeoutTimer.stop();
                heartbeatTimeoutTimer = null;
            }

            heartbeatTimeoutTimer = Timer.delay(() -> {
                trace('pomelo client heartbeat timeout.');
                emitter.emit(ON_ERROR, 'heartbeat timeout');
                disconnect();
            }, heartbeatTimeout);
        };
    }

    function process_package(msgs: Array<PackageData>): Void {
        for (i in 0...msgs.length) {
            final msg = msgs[i];

            switch (msg.type) {
                case PackageType.HANDSHAKE: handshake(msg.body);
                case PackageType.HEARTBEAT: heartbeat();
                case PackageType.DATA: handle_data(msg);
                case PackageType.KICK: handle_kick(msg.body);
            }
        }
    }

    function process_message(msg: MessageData) {
        if (msg.id == 0) {
            // server push message
            emitter.emit(ON_PUSH, msg.sRoute, msg.payload);
            return;
        }

        // if an id exists, find the callback with this request
        final cb = pendingCallbacks[msg.id];
        if (cb != null) {
            pendingCallbacks[msg.id] = null;
            cb(msg.payload);
        }
    }

    function handshake(body: Bytes): Void {
        var data = Json.parse(Protocol.str_decode(body));

        switch (data.code) {
            case ClientDef.RES_OK:
                handshake_init(data);

                final pkg = Package.encode(PackageType.HANDSHAKE_ACK);
                send(pkg);
                initial_callback();

            case ClientDef.RES_OLD_CLIENT:
                emitter.emit(ON_ERROR, "client version can't fullfill");

            default:
                emitter.emit(ON_ERROR, 'handshake fail');
        }
    }

    function handshake_init(data: Dynamic): Void {
        if (data.sys != null && data.sys.heartbeat > 0) {
            heartbeatInterval = Std.int(data.sys.heartbeat) * 1000;
            heartbeatTimeout = heartbeatInterval * 2;
        } else {
            heartbeatInterval = 0;
            heartbeatTimeout = 0;
        }

        handshake_callback(data.user);
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
                routeDict.set(k, v);
                routeAbbrs.set(v, k);
            }
        }
    }

    function handle_data(data: PackageData): Void {
        if (decode != null) {
            var msg = decode(data.body);

            process_message(msg);
        }
    }

    function handle_kick(data: Bytes): Void {
        var kickInfo: Dynamic = null;

        if (data != null) {
            kickInfo = Json.parse(Protocol.str_decode(data));
        }

        emitter.emit(ON_KICK, kickInfo);
    }

    function reset(): Void {
        trace('pomelo client reset.');

        reconnect = false;
        reconnectionDelay = 5000;
        reconnectAttempts = 0;
        reconnectTimer?.stop();
    }

    function default_decode(data: Bytes): MessageData {
        var msg = Message.decode(data);

        if (msg.id > 0) {
            msg.sRoute = pendingRequests[msg.id];
            pendingRequests[msg.id] = null;

            if (msg.sRoute == null || msg.sRoute.length == 0) {
                return null;
            }
        }

        msg.payload = de_compose(msg);
        msg.body = null;
        return msg;
    }

    function default_encode(reqId: Int, sRoute: String, msg: Any) {
        var type = reqId > 0 ? MessageType.REQUEST : MessageType.NOTIFY;

        var buffer: Bytes;

        if (decodeIO_encoder != null && decodeIO_encoder.lookup(sRoute)) {
            buffer = decodeIO_encoder.build(sRoute).encode(msg);
        } else {
            buffer = Protocol.str_encode(haxe.Json.stringify(msg));
        }

        var compressRoute = false;
        var iRoute: Int = 0;
        if (routeDict.exists(sRoute)) {
            iRoute = routeDict.get(sRoute);
            compressRoute = true;
        }

        return Message.encode(reqId, type, compressRoute, sRoute, iRoute, buffer);
    }

    function de_compose(msg: MessageData): Any {
        var route: String;

        if (msg.compressRoute) {
            if (!routeAbbrs.exists(msg.iRoute)) {
                return {};
            }

            route = routeAbbrs.get(msg.iRoute);
        } else {
            route = msg.sRoute;
        }

        if (decodeIO_decoder != null && decodeIO_decoder.lookup(route)) {
            return decodeIO_decoder.build(route).decode(msg.body);
        } else {
            return haxe.Json.parse(Protocol.str_decode(msg.body));
        }
    }
}