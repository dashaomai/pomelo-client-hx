import pomelo.Client;

class Main {

    static function main() {
        final client = new Client('ws://localhost:3150/');

        final errHandler = (err: String) -> {
            trace(err);
        }

        client.emitter.on(Client.ON_ERROR, errHandler);
        client.emitter.on(Client.ON_IO_ERROR, errHandler);

        client.emitter.on(Client.ON_CLOSE, (data: Dynamic) -> {
            trace(data);
        });
        client.emitter.on(Client.ON_KICK, (info: Null<Dynamic>) -> {
            trace(info);
        });

        client.emitter.on(Client.ON_INITIALIZE, () -> {
            entry(client);
        });

        client.emitter.on(Client.ON_PUSH, (route: String, payload: Dynamic) -> {
            trace(route, payload);
        });

        client.connect();
    }

    // this is an example for entry
    static function entry(client: Client): Void {
            // call your server route, entry the connector
            client.request(
                'connector.entryHandler.entry',
                {
                    accountId: "account-id-uuid",
                },
                resp -> {
                    trace('entry response:', resp);
                },
            );
    }
}