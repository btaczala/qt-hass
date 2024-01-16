.pragma library
var token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIxNTQ1MmJhZWQ0ZmM0NzAxOGYzMzM1OGYzNzRmYTk0ZCIsImlhdCI6MTcwNTA4MTQzNCwiZXhwIjoyMDIwNDQxNDM0fQ.dnoJSkbYFc-zo2Q1iTQlDzpi96m6WHDO2HxMgGZ4Xf0"

var hass_address = "http://192.168.1.40:8123"

var update_handlers = [];

function __request(verb, endpoint, obj, cb) {
    // print('HassAPI: request ' + verb + ' ' + hass_address + (endpoint ? '/' + endpoint : ''))
    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
        // print('xhr: on ready state change: ' + xhr.readyState)
        if(xhr.readyState === XMLHttpRequest.DONE) {
            if(cb) {
                var res = JSON.parse(xhr.responseText.toString())
                cb(res)
            }
        }
    }
    xhr.open(verb, hass_address + (endpoint ? '/' + endpoint : ''))
    xhr.setRequestHeader('Authorization', 'Bearer ' + token)
    xhr.setRequestHeader('Content-Type', 'application/json')
    var data = obj ? JSON.stringify(obj) : ''
    xhr.send(data)
}

function register_handler_for_state_updates(cb, where) {
    update_handlers.push(cb);
    // console.log("Registered handler for", where)
}

function update_callback(response) {
    for(var callback of update_handlers) {
        callback(response);
    }
}

function request_update_state(entity_id) {
    __request('GET', '/api/states/' + entity_id, null, update_callback);
}

function light_set_state(entity_id, state, callback) {
}

