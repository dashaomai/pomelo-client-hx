# Pomelo Client Hx

This is a client designed for many pomelo-like frameworks, like pomelo(node.js), pinus(typescript), nano(golang), pitaya(golang) etc.

# Who's pomelo?

Pomelo is a fast, scalable game server framework for node.js.
with the successful design of the communication layer, many of new game server select the pomelo-protocol as their default communication mechanics.

## Featuers

- **connect**: connect to and disconnect from your game server.
- **heartbeat**: do heartbeat with server negotiated parameters.
- **request**: a request/response behavior.
- **notify**: just send a request to server, don't care about the response.
- **push**: a message from server.
- **dynamic protobuff**: NOT support yet.

## Usage

First you need a game-server in pomelo or alternative framework like: pinus, nano, pitaya, etc.

Next, in hexa project, install the pomelo-client-hx library via haxelib:

```shell
haxelib install pomelo-client-hx
```

Then create and use the client like this:

```haxe
import pomelo.Client;

// create a client but not connect immediately
var client: Client = new Client('ws://localhost:3510/');

// listen on initialize means you are connected successful and can do every request you want now
client.emitter.on(Client.ON_INITIALIZE, () -> {
    client.request(
        'connector.entryHandler.entry',
        {
            accoundId: 'account-id-uuid',
        },
        entryResponse -> {
            trace('entry successfule:', entryResponse);
        }
    );
});

// listen on push can handle messages from server pushing
client.emitter.on(Client.ON_PUSH, (route: String, payload: Dynamic) -> {
    trace(route, payload);
});

// do the connect
client.connect();
```
