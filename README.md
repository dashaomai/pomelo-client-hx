# Pomelo Client Hx

This is a client designed for many pomelo-family protocol, like pomelo(node.js), pinus(typescript), nano(golang), pitaya(golang) etc.

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

```hx
import pomelo.Client;

// create a client but not connect immediately
var client: Client = new Client('ws://localhost:3510/');

// listen on initialize means you are connected successful and can do every request you want now
client.emitter.on(Client.ON_INITIALIZE, () -> {
    entry(client, "346bacd9-7830-4092-bfcc-75e0bab1ba4e");
});

// listen on push can handle messages from server pushing
client.emitter.on(Client.ON_PUSH, (route: String, payload: Dynamic) -> {
    trace(route, payload);
});

// do the connect
client.connect();
```
