.pragma library

// Home Assistant's camera APIs (the entity_picture attribute, the
// "camera/stream" websocket command) return paths relative to the server,
// e.g. "/api/camera_proxy/camera.foo?token=...", and Controler.hassUrl is a
// WebSocket URL, e.g. "wss://host:8123/api/websocket". Both already carry
// their own access token in the path/query, so turning one into a full URL is
// all Image/Video need to load them directly -- no Authorization header.

// "ws://host:8123/api/websocket" / "wss://..." -> "http://host:8123" / "https://...".
function httpBaseUrl(wsUrl) {
    return wsUrl.replace(/^ws/, "http").replace(/\/api\/websocket$/, "");
}

function resolve(wsUrl, path) {
    return path ? httpBaseUrl(wsUrl) + path : "";
}
