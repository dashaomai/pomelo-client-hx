import pomelo.Client;

class Main {

    static function main() {
        final client = new Client('ws://localhost:3150/');

        client.connect();
    }   
}