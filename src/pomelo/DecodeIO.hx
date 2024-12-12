package pomelo;
import haxe.io.Bytes;

interface IDecodeIOEncoder {
    public function lookup(route: String): Bool;

    public function build(route: String): EncodeBuilder;
}

abstract class EncodeBuilder {
    public abstract function encode(body: Dynamic): Bytes;
}

interface IDecodeIODecoder {
    public function lookup(route: String): Bool;

    public function build(route: String): DecodeBuilder;
}

abstract class DecodeBuilder {
    public abstract function decode(body: Bytes): Dynamic;
}