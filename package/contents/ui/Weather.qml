import QtQuick

// Non-visual weather source (Open-Meteo). Geocodes `city`, fetches the forecast,
// caches the raw response in cfg.CachedWeather so the scene works offline.
Item {
    id: root

    property string city: ""
    property var cfg: null

    property int code: 0
    property real cloudCover: 20
    property real precipitation: 0
    property real windSpeed: 0
    property real windDir: 0
    property real visibility: 24000
    property real temperature: 15
    property date sunrise: _today(6)
    property date sunset: _today(18)
    property bool valid: false

    property bool _busy: false
    property bool _ready: false
    property bool _again: false     // a forced run was requested while busy
    property int _fails: 0
    property double _last: 0        // ms timestamp of last request start
    property string _badCity: ""    // last city geocoding found nothing for

    function _today(h) {
        const d = new Date();
        d.setHours(h, 0, 0, 0);
        return d;
    }

    // Public: fetch now, but never more than once per 60 s.
    function refresh(force) { _run(!!force); }

    function _run(force) {
        if (_busy) { _again = _again || force; return; }
        if (!force && Date.now() - _last < 60000) return;
        _busy = true;
        _again = false;
        _last = Date.now();
        retry.stop();
        if (city !== "" && city !== cfg.ResolvedCity && city !== _badCity)
            _geocode(city);
        else
            _forecast();
    }

    function _get(url, ok) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            try {
                if (xhr.status !== 200) throw new Error("HTTP " + xhr.status);
                ok(xhr.responseText);
            } catch (e) {
                _fail(e);
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function _geocode(name) {
        _get("https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(name)
             + "&count=1&format=json", function (text) {
            const r = JSON.parse(text).results;
            if (r && r.length) {
                cfg.Latitude = r[0].latitude;
                cfg.Longitude = r[0].longitude;
                cfg.ResolvedCity = name;
                cfg.writeConfig();
            } else if (_badCity !== name) {
                _badCity = name;
                console.warn("Weather: no geocoding result for '" + name + "', keeping old location");
            }
            _forecast();
        });
    }

    function _forecast() {
        _get("https://api.open-meteo.com/v1/forecast?latitude=" + cfg.Latitude + "&longitude=" + cfg.Longitude
             + "&current=weather_code,cloud_cover,precipitation,wind_speed_10m,wind_direction_10m,visibility,temperature_2m"
             + "&daily=sunrise,sunset&timezone=auto&forecast_days=1&timeformat=unixtime", function (text) {
            _apply(text);
            cfg.CachedWeather = text;
            cfg.writeConfig();
            _fails = 0;
            _done();
        });
    }

    // Throws on malformed data, leaving current values untouched until all fields parsed.
    function _apply(text) {
        const j = JSON.parse(text), c = j.current;
        const rise = new Date(j.daily.sunrise[0] * 1000), set = new Date(j.daily.sunset[0] * 1000);
        if (isNaN(rise) || isNaN(set) || c.weather_code === undefined) throw new Error("bad payload");
        code = c.weather_code;
        cloudCover = c.cloud_cover;
        precipitation = c.precipitation;
        windSpeed = c.wind_speed_10m;
        windDir = c.wind_direction_10m;
        visibility = c.visibility;
        temperature = c.temperature_2m;
        sunrise = rise;
        sunset = set;
        valid = true;
    }

    function _fail(e) {
        console.warn("Weather: " + e);
        _fails++;
        retry.interval = Math.min(2 * 60000 * Math.pow(2, _fails - 1), 15 * 60000);
        retry.restart();
        _done();
    }

    function _done() {
        _busy = false;
        if (_again) _run(true);
    }

    Timer { id: retry; onTriggered: root._run(false) }
    Timer { interval: 15 * 60 * 1000; repeat: true; running: true; onTriggered: root.refresh() }
    Timer { id: debounce; interval: 1500; onTriggered: root._run(true) }

    onCityChanged: if (_ready) debounce.restart()

    Component.onCompleted: {
        try {
            if (cfg.CachedWeather) _apply(cfg.CachedWeather);
        } catch (e) {
            console.warn("Weather: bad cache: " + e);
        }
        _ready = true;
        refresh();
    }
}
