package pomelo;
import haxe.io.Bytes;

interface IDecodeIOEncoder {
    public function lookup(route: String): Bool;

    public function build(route: String): EncodeBuilder;
}

abstract class EncodeBuilder {
    final message: Any;

    public function new(msg: Any): Void {
        this.message = msg;
    }

    public abstract function encodeNB(): Bytes;
}

interface IDecodeIODecoder {
    public function lookup(route: String): Bool;

    public function build(route: String): DecodeBuilder;
}

abstract class DecodeBuilder {
    final message: Any;

    public function new(msg: Any): Void {
        this.message = msg;
    }

    public abstract function decode(body: Bytes): Dynamic;
}