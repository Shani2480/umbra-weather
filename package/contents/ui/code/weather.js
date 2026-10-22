.pragma library

// Open-Meteo client + WMO weather code helpers.
// Conditions: clear, partly, cloudy, fog, rain, snow, thunder

var WMO_TEXT = {
    0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
    45: "Fog", 48: "Rime fog",
    51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle",
    56: "Freezing drizzle", 57: "Heavy freezing drizzle",
    61: "Light rain", 63: "Rain", 65: "Heavy rain",
    66: "Freezing rain", 67: "Heavy freezing rain",
    71: "Light snow", 73: "Snow", 75: "Heavy snow", 77: "Snow grains",
    80: "Light showers", 81: "Showers", 82: "Violent showers",
    85: "Snow showers", 86: "Heavy snow showers",
    95: "Thunderstorm", 96: "Thunderstorm with hail", 99: "Severe thunderstorm with hail"
}

function describe(code) {
    return WMO_TEXT[code] || "Unknown"
}

function category(code) {
    if (code === 0) return "clear"
    if (code === 1 || code === 2) return "partly"
    if (code === 3) return "cloudy"
    if (code === 45 || code === 48) return "fog"
    if (code >= 51 && code <= 67) return "rain"
    if (code >= 71 && code <= 77) return "snow"
    if (code >= 80 && code <= 82) return "rain"
    if (code === 85 || code === 86) return "snow"
    if (code >= 95) return "thunder"
    return "cloudy"
}

// Weather Underground icon name (see contents/icons) for a WMO code.
// Falls back to the coarse condition when no code is known.
var WU_BY_CODE = {
    0: "sunny", 1: "mostlysunny", 2: "partlycloudy", 3: "cloudy",
    45: "fog", 48: "fog",
    51: "chancerain", 53: "rain", 55: "rain", 56: "sleet", 57: "sleet",
    61: "rain", 63: "rain", 65: "rain", 66: "sleet", 67: "sleet",
    71: "flurries", 73: "snow", 75: "snow", 77: "flurries",
    80: "chancerain", 81: "rain", 82: "rain", 85: "flurries", 86: "snow",
    95: "tstorms", 96: "tstorms", 99: "tstorms"
}
var WU_BY_CONDITION = {
    clear: "sunny", partly: "partlycloudy", cloudy: "cloudy", fog: "fog",
    rain: "rain", snow: "snow", thunder: "tstorms"
}

function wuIcon(code, isDay, condition) {
    var name = WU_BY_CODE[code] || WU_BY_CONDITION[condition] || "unknown"
    if (!isDay) name = "nt_" + (name === "sunny" ? "clear" : name)
    return name
}

// units: { temperature: "celsius"|"fahrenheit", wind: "kmh"|"mph"|"ms"|"kn" }
function buildUrl(lat, lon, units) {
    units = units || {}
    return "https://api.open-meteo.com/v1/forecast"
        + "?latitude=" + lat + "&longitude=" + lon
        + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,is_day,weather_code,wind_speed_10m"
        + ",wind_direction_10m,pressure_msl,cloud_cover,precipitation"
        + "&hourly=temperature_2m,weather_code"
        + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max,wind_speed_10m_max,precipitation_sum"
        + "&temperature_unit=" + (units.temperature || "celsius")
        + "&wind_speed_unit=" + (units.wind || "kmh")
        + "&timezone=auto&forecast_days=8"
}

// Open-Meteo spells miles per hour "mp/h"; everything else is fine as is.
function windUnitLabel(u) {
    return u === "mp/h" ? "mph" : u
}

// Compass point for a wind direction in degrees.
function compass(deg) {
    var points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    return points[Math.round(((deg % 360) + 360) % 360 / 45) % 8]
}

// Open-Meteo returns local times without offset ("2026-10-20T14:00"),
// which Date() parses as the machine's local time.
function parseTime(s) {
    return new Date(s)
}

function isDaytime(daily, t) {
    for (var i = 0; i < daily.length; i++) {
        if (daily[i].date.toDateString() === t.toDateString())
            return t >= daily[i].sunrise && t < daily[i].sunset
    }
    return true
}

// The next `count` hourly entries that fall on a multiple of `stepHours`,
// starting with the slot that contains the current time (`machineNow`, or
// the real clock).
// All timestamps from the API are the location's wall-clock time, parsed as if
// they were local to this machine. This returns "now" on the same footing: a
// Date whose machine-local wall-clock reads what a clock at the location reads.
function localNow(data, machineNow) {
    var t = machineNow ? machineNow.getTime() : Date.now()
    if (!data || data.utcOffsetSeconds === undefined) return new Date(t)
    var machineOffsetSeconds = -new Date(t).getTimezoneOffset() * 60
    return new Date(t + (data.utcOffsetSeconds - machineOffsetSeconds) * 1000)
}

function upcomingSlots(data, count, stepHours, machineNow) {
    var now = localNow(data, machineNow).getTime()
    var out = []
    for (var i = 0; i < data.hourly.length && out.length < count; i++) {
        var h = data.hourly[i]
        if (h.time.getHours() % stepHours !== 0) continue
        if (h.time.getTime() + 3600000 <= now) continue
        out.push(h)
    }
    return out
}

// Solar phase of `day` (a parsed daily entry) at time `now`:
// "dawn"/"dusk" within 45 minutes either side of sunrise/sunset, else "day"/"night".
function solarPhase(day, now) {
    var window = 45 * 60 * 1000
    var t = now.getTime(), sr = day.sunrise.getTime(), ss = day.sunset.getTime()
    if (Math.abs(t - sr) <= window) return "dawn"
    if (Math.abs(t - ss) <= window) return "dusk"
    return (t > sr && t < ss) ? "day" : "night"
}

// Three-stop horizontal hero gradients, one per condition and solar phase.
var HERO_DAY = {
    clear:   ["#0D47A1", "#1E88E5", "#4FC3F7"],   // deep sky blue
    partly:  ["#2F5F98", "#4F86BE", "#8AB6DD"],   // blue with a haze of cloud
    cloudy:  ["#3E4F63", "#53677D", "#7A8FA4"],   // blue-grey
    fog:     ["#58606B", "#737B86", "#9AA2AC"],   // flat, washed-out grey
    rain:    ["#15324C", "#1F4A6B", "#2E6587"],   // dark blue-teal
    snow:    ["#4E6F8F", "#7A9BB8", "#B3C9DC"],   // cool pale
    thunder: ["#1A1033", "#3A2466", "#2E3A50"]    // bruised purple
}
var HERO_NIGHT = {
    clear:   ["#070B14", "#101A2E", "#1E1C40"],   // near-black blue with a violet edge
    partly:  ["#0C121C", "#182233", "#2A3448"],
    cloudy:  ["#14181E", "#1F252D", "#2D353E"],
    fog:     ["#1C1F24", "#2A2E34", "#3A3F46"],
    rain:    ["#0A1824", "#102638", "#17364B"],
    snow:    ["#182636", "#263A4F", "#3A5169"],
    thunder: ["#0E0820", "#241446", "#1E2535"]
}
var HERO_DUSK = {
    clear:   ["#0D47A1", "#7B1FA2", "#E65100"],   // the classic sunset
    partly:  ["#283E6B", "#6A3A7E", "#B9552E"],
    cloudy:  ["#2C3A4D", "#4E4059", "#7A5346"]    // muted, overcast glow
}

function mixHex(a, b, t) {
    function ch(h, i) { return parseInt(h.substr(1 + i * 2, 2), 16) }
    function hex(v) { v = Math.round(v); return (v < 16 ? "0" : "") + v.toString(16) }
    var out = "#"
    for (var i = 0; i < 3; i++) out += hex(ch(a, i) + (ch(b, i) - ch(a, i)) * t)
    return out
}

// Palette for a condition at a solar phase ("day", "night", "dawn"/"dusk").
function heroPalette(condition, phase) {
    var c = HERO_DAY[condition] ? condition : "cloudy"
    if (phase === "night") return HERO_NIGHT[c]
    if (phase === "dawn" || phase === "dusk") {
        if (HERO_DUSK[c]) return HERO_DUSK[c]
        return HERO_DAY[c].map(function (col, i) { return mixHex(col, HERO_NIGHT[c][i], 0.5) })
    }
    return HERO_DAY[c]
}

function daySlots(data, date, hours) {
    var out = []
    var key = date.toDateString()
    for (var i = 0; i < data.hourly.length; i++) {
        var h = data.hourly[i]
        if (h.time.toDateString() !== key) continue
        if (hours.indexOf(h.time.getHours()) >= 0) out.push(h)
    }
    return out
}

function parse(json) {
    var c = json.current
    var h = json.hourly
    var d = json.daily

    var hourly = []
    for (var i = 0; i < h.time.length; i++) {
        hourly.push({
            time: parseTime(h.time[i]),
            temp: h.temperature_2m[i],
            code: h.weather_code[i],
            condition: category(h.weather_code[i])
        })
    }

    var daily = []
    for (var j = 0; j < d.time.length; j++) {
        daily.push({
            date: parseTime(d.time[j]),
            code: d.weather_code[j],
            condition: category(d.weather_code[j]),
            text: describe(d.weather_code[j]),
            max: d.temperature_2m_max[j],
            min: d.temperature_2m_min[j],
            sunrise: parseTime(d.sunrise[j]),
            sunset: parseTime(d.sunset[j]),
            uv: d.uv_index_max[j],
            rain: d.precipitation_probability_max[j],
            wind: d.wind_speed_10m_max[j],
            precipSum: d.precipitation_sum[j]
        })
    }

    for (var k = 0; k < hourly.length; k++)
        hourly[k].isDay = isDaytime(daily, hourly[k].time)

    return {
        current: {
            temp: c.temperature_2m,
            feelsLike: c.apparent_temperature,
            humidity: c.relative_humidity_2m,
            wind: c.wind_speed_10m,
            windDir: c.wind_direction_10m,
            pressure: c.pressure_msl,
            cloudCover: c.cloud_cover,
            precipitation: c.precipitation,
            isDay: c.is_day === 1,
            code: c.weather_code,
            condition: category(c.weather_code),
            text: describe(c.weather_code)
        },
        hourly: hourly,
        daily: daily,
        utcOffsetSeconds: json.utc_offset_seconds || 0,
        tempUnit: (json.current_units && json.current_units.temperature_2m) || "°C",
        windUnit: windUnitLabel((json.current_units && json.current_units.wind_speed_10m) || "km/h"),
        precipUnit: (json.current_units && json.current_units.precipitation) || "mm",
        fetchedAt: new Date()
    }
}

// Open-Meteo geocoding: up to 5 places matching `query`, as
// { displayName, name, country, latitude, longitude, timezone }.
function searchLocation(query, callback) {
    if (!query || query.trim().length < 2) {
        callback([])
        return
    }
    var url = "https://geocoding-api.open-meteo.com/v1/search?name="
            + encodeURIComponent(query.trim()) + "&count=5&language=en&format=json"
    var xhr = new XMLHttpRequest()
    xhr.open("GET", url)
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return
        if (xhr.status !== 200) { callback([]); return }
        try {
            var response = JSON.parse(xhr.responseText)
            callback((response.results || []).map(function (item) {
                var parts = [item.name]
                if (item.admin1 && item.admin1 !== item.name) parts.push(item.admin1)
                if (item.country) parts.push(item.country)
                return {
                    displayName: parts.join(", "),
                    name: item.name,
                    country: item.country || "",
                    latitude: item.latitude,
                    longitude: item.longitude,
                    timezone: item.timezone || "auto"
                }
            }))
        } catch (e) {
            callback([])
        }
    }
    xhr.send()
}

function fetchWeather(lat, lon, units, onSuccess, onError) {
    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return
        if (xhr.status !== 200) {
            onError("HTTP " + xhr.status)
            return
        }
        try {
            onSuccess(parse(JSON.parse(xhr.responseText)))
        } catch (e) {
            onError("Bad response: " + e)
        }
    }
    xhr.open("GET", buildUrl(lat, lon, units))
    xhr.send()
}

// Approximate location from the public IP address (no GPS on a desktop).
// Tries ipapi.co first, then ipwho.is. callback({name, latitude, longitude}),
// errorCallback(message).
function detectLocation(callback, errorCallback) {
    var services = [
        { url: "https://ipapi.co/json/", read: function (j) {
            if (j.error || j.latitude === undefined) return null
            return { name: j.city, country: j.country_name || "", latitude: j.latitude, longitude: j.longitude }
        } },
        { url: "https://ipwho.is/", read: function (j) {
            if (!j.success) return null
            return { name: j.city, country: j.country || "", latitude: j.latitude, longitude: j.longitude }
        } }
    ]
    function attempt(i) {
        if (i >= services.length) { errorCallback(i18n("Could not determine your location")); return }
        var xhr = new XMLHttpRequest()
        xhr.open("GET", services[i].url)
        xhr.timeout = 8000
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            var place = null
            if (xhr.status === 200) {
                try { place = services[i].read(JSON.parse(xhr.responseText)) } catch (e) { place = null }
            }
            if (place && place.name) {
                place.displayName = place.country !== "" ? place.name + ", " + place.country : place.name
                callback(place)
            } else {
                attempt(i + 1)
            }
        }
        xhr.send()
    }
    attempt(0)
}
