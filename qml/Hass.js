.pragma library
var token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI1MmZjMThmYWU3YTc0NzhiOGY5ZDFjNDM0OGI0YmI1NCIsImlhdCI6MTcyNzgxMDMyMCwiZXhwIjoyMDQzMTcwMzIwfQ.Trt5hwKRUI3XqLJeKs4-Dm1QEpNlip7qfLJmBOB0MoY"

var hass_address = "http://192.168.1.40:8123"

var update_handlers = [];

function __request(verb, endpoint, obj, cb) {
    print('HassAPI: request ' + verb + ' ' + hass_address + (endpoint ? '/' + endpoint : ''))
    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
        print('xhr: on ready state change: ' + xhr.readyState, xhr.status)
        if(xhr.readyState === XMLHttpRequest.DONE) {
            if(xhr.status === 200) {
                if(cb) {
                    var res = JSON.parse(xhr.responseText.toString())
                    cb(res)
                } else {
                    console.log("Error",xhr.statusText);
                }
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
    console.log("Registered handler for", where)
}

function update_callback(response) {
    for(var callback of update_handlers) {
        callback(response);
    }
}

function request_update_state(entity_id) {
    __request('GET', '/api/states/' + entity_id, null, update_callback);
}

function light_toggle(entity_id) {
    var payload = {
        entity_id: entity_id
    }
    // console.log("Payload is ", JSON.stringify(payload))
    __request('POST', 'api/services/light/toggle', payload, update_callback);
}


function light_update_color(entity_id, color) {
    var payload = {
        entity_id: entity_id,
        rgb_color: color
    }
     console.log("Payload is ", JSON.stringify(payload))
    __request('POST', 'api/services/light/turn_on', payload, update_callback);
}

function light_update_brightness(entity_id, brightness) {
    var payload = {
        entity_id: entity_id,
        brightness: brightness
    }
    __request('POST', 'api/services/light/turn_on', payload, update_callback);
}

function light_update_color_temp(entity_id, color_temp_kelvin) {
    var payload = {
        entity_id: entity_id,
        kelvin: color_temp_kelvin
    }
    __request('POST', 'api/services/light/turn_on', payload, update_callback);
}

function climate_set_temperature(entity_id, temp) {
}
