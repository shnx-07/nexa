use serde::{Deserialize, Serialize};

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};


// ============================================================
// API
// ============================================================

const FORECAST_URL: &str =
    "https://api.open-meteo.com/v1/forecast";

const GEOCODING_URL: &str =
    "https://geocoding-api.open-meteo.com/v1/search";

const IP_LOCATION_URL: &str =
    "https://ipapi.co/json/";

const CACHE_MAX_AGE: u64 =
    15 * 60;

const HTTP_TIMEOUT_SECONDS: u64 =
    12;


// ============================================================
// WEATHER CONFIG
// ============================================================




#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WeatherConfig {
    pub location_mode: String,

    pub city: String,
    pub admin1: String,
    pub country: String,

    pub latitude: Option<f64>,
    pub longitude: Option<f64>,

    pub elevation: Option<f64>,
    pub timezone: String,
}

impl Default for WeatherConfig {
    fn default() -> Self {
        Self {
            location_mode:
                "auto".to_string(),

            city:
                String::new(),

            admin1:
                String::new(),

            country:
                String::new(),

            latitude:
                None,

            longitude:
                None,

            elevation:
                None,

            timezone:
                String::new(),
        }
    }
}


// ============================================================
// LOCATION OUTPUT
// ============================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WeatherLocation {
    pub name: String,
    pub admin1: String,
    pub country: String,

    pub latitude: f64,
    pub longitude: f64,

    pub elevation: f64,

    pub timezone: String,
    pub timezone_abbreviation: String,
}


#[derive(Debug, Clone, Serialize)]
pub struct LocationInfo {
    pub mode: String,

    pub configured_city: String,
    pub configured_admin1: String,
    pub configured_country: String,

    pub latitude: Option<f64>,
    pub longitude: Option<f64>,

    pub resolved: WeatherLocation,
}


#[derive(Debug, Clone, Serialize)]
pub struct LocationSearchResult {
    pub name: String,

    pub admin1: String,
    pub country: String,

    pub latitude: f64,
    pub longitude: f64,

    pub elevation: f64,

    pub timezone: String,
}


// ============================================================
// WEATHER OUTPUT
// ============================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WeatherOutput {
    pub success: bool,
    pub cached: bool,

    pub location: WeatherLocation,

    pub current: CurrentWeather,
    pub details: WeatherDetails,

    pub daily: Vec<DailyForecast>,
    pub hourly: Vec<HourlyForecast>,

    pub updated_at: u64,
}


#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CurrentWeather {
    pub temperature: f64,
    pub apparent_temperature: f64,

    pub condition: String,
    pub weather_code: i32,
    pub icon: String,

    pub min_temperature: f64,
    pub max_temperature: f64,

    pub wind_speed: f64,

    pub wind_direction_degrees: f64,
    pub wind_direction: String,

    pub is_day: bool,
}


#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WeatherDetails {
    pub temperature_min: f64,
    pub temperature_max: f64,

    pub wind_speed: f64,
    pub wind_direction: String,

    pub sunrise: String,
    pub sunset: String,

    pub elevation: f64,

    pub uv_index: f64,

    pub timezone: String,
    pub timezone_abbreviation: String,
}


#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DailyForecast {
    pub date: String,

    pub weather_code: i32,
    pub condition: String,
    pub icon: String,

    pub min_temperature: f64,
    pub max_temperature: f64,

    pub sunrise: String,
    pub sunset: String,

    pub uv_index: f64,

    pub precipitation_probability: f64,
}


#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HourlyForecast {
    pub time: String,

    pub temperature: f64,
    pub apparent_temperature: f64,

    pub weather_code: i32,
    pub condition: String,
    pub icon: String,

    pub precipitation_probability: f64,

    pub wind_speed: f64,
    pub wind_direction: String,

    pub is_day: bool,
}


// ============================================================
// GEOCODING API
// ============================================================

#[derive(Debug, Deserialize)]
struct GeocodingResponse {
    results: Option<Vec<GeocodingResult>>,
}


#[derive(Debug, Deserialize)]
struct GeocodingResult {
    name: String,

    latitude: f64,
    longitude: f64,

    elevation: Option<f64>,

    timezone: Option<String>,

    country: Option<String>,
    admin1: Option<String>,
}


// ============================================================
// AUTO LOCATION API
// ============================================================

#[derive(Debug, Deserialize)]
struct AutoLocationResponse {
    city: Option<String>,
    country_name: Option<String>,

    latitude: Option<f64>,
    longitude: Option<f64>,

    timezone: Option<String>,
}


// ============================================================
// FORECAST API
// ============================================================

#[derive(Debug, Deserialize)]
struct ForecastResponse {
    elevation: f64,

    timezone: String,
    timezone_abbreviation: String,

    current: ForecastCurrent,
    hourly: ForecastHourly,
    daily: ForecastDaily,
}


#[derive(Debug, Deserialize)]
struct ForecastCurrent {
    temperature_2m: f64,
    apparent_temperature: f64,

    weather_code: i32,

    wind_speed_10m: f64,
    wind_direction_10m: f64,

    is_day: i32,
}


#[derive(Debug, Deserialize)]
struct ForecastHourly {
    time: Vec<String>,

    temperature_2m: Vec<f64>,
    apparent_temperature: Vec<f64>,

    precipitation_probability:
        Vec<Option<f64>>,

    weather_code:
        Vec<i32>,

    wind_speed_10m:
        Vec<f64>,

    wind_direction_10m:
        Vec<f64>,

    is_day:
        Vec<i32>,
}


#[derive(Debug, Deserialize)]
struct ForecastDaily {
    time: Vec<String>,

    weather_code: Vec<i32>,

    temperature_2m_max: Vec<f64>,
    temperature_2m_min: Vec<f64>,

    sunrise: Vec<String>,
    sunset: Vec<String>,

    uv_index_max:
        Vec<Option<f64>>,

    precipitation_probability_max:
        Vec<Option<f64>>,
}


// ============================================================
// COMMAND ENTRY
// ============================================================

pub fn handle(
    args: &[String]
) -> Result<(), String> {

    let action =
        args.first()
            .map(String::as_str)
            .unwrap_or("info");


    match action {

        // --------------------------------------------------------
        // WEATHER INFO
        // --------------------------------------------------------

        "info" => {
            let weather =
                load_weather(false)?;

            print_json(
                &weather
            )?;
        }


        // --------------------------------------------------------
        // WEATHER REFRESH
        // --------------------------------------------------------

        "refresh" => {
            let weather =
                load_weather(true)?;

            print_json(
                &weather
            )?;
        }


        // --------------------------------------------------------
        // LOCATION
        // --------------------------------------------------------

        "location" => {
            handle_location(
                &args[1..]
            )?;
        }


        _ => {
            return Err(
                weather_usage()
            );
        }
    }


    Ok(())
}


// ============================================================
// LOCATION COMMANDS
// ============================================================

fn handle_location(
    args: &[String]
) -> Result<(), String> {

    let action =
        args.first()
            .map(String::as_str)
            .unwrap_or("info");


    match action {

        // --------------------------------------------------------
        // LOCATION INFO
        // --------------------------------------------------------

        "info" => {
            let config =
                read_weather_config();


            let location =
                resolve_configured_location(
                    &config
                )?;


            let output =
                LocationInfo {
                    mode:
                        config.location_mode,

                    configured_city:
                        config.city,

                    latitude:
                        config.latitude,

                    longitude:
                        config.longitude,

                    configured_admin1:
                        config.admin1,

                    configured_country:
                        config.country,

                    resolved:
                        location,
                };


            print_json(
                &output
            )?;
        }


        // --------------------------------------------------------
        // AUTO LOCATION
        // --------------------------------------------------------

        "auto" => {

            let config =
                WeatherConfig::default();


            save_weather_config(
                &config
            )?;


            clear_weather_cache()?;


            let location =
                resolve_auto_location()?;


            print_json(
                &LocationInfo {
                    mode:
                        "auto".to_string(),

                    configured_city:
                        String::new(),

                    latitude:
                        None,

                    longitude:
                        None,

                    configured_admin1:
                        String::new(),

                    configured_country:
                        String::new(),

                    resolved:
                        location,
                }
            )?;
        }


        // --------------------------------------------------------
        // SEARCH LOCATION
        // --------------------------------------------------------

        "search" => {

            if args.len() < 2 {
                return Err(
                    "usage: nexad weather location search <city>"
                        .to_string()
                );
            }


            let query =
                args[1..]
                    .join(" ");


            let results =
                search_locations(
                    &query
                )?;


            print_json(
                &results
            )?;
        }


        // --------------------------------------------------------
        // SET MANUAL LOCATION
        // --------------------------------------------------------

        "set" => {

            if args.len() < 2 {
                return Err(
                    "usage: nexad weather location set <city>"
                        .to_string()
                );
            }


            let query =
                args[1..]
                    .join(" ");


            let result =
                resolve_manual_location(
                    &query
                )?;


           
            let config =
                WeatherConfig {
                    location_mode:
                        "manual".to_string(),

                    city:
                        result.name.clone(),

                    admin1:
                        result.admin1.clone(),

                    country:
                        result.country.clone(),

                    latitude:
                        Some(
                            result.latitude
                        ),

                    longitude:
                        Some(
                            result.longitude
                        ),

                    elevation:
                        Some(
                            result.elevation
                        ),

                    timezone:
                        result.timezone.clone(),
                };


            save_weather_config(
                &config
            )?;


            clear_weather_cache()?;


            print_json(
                &LocationInfo {
                    mode:
                        "manual".to_string(),

                    configured_city:
                        result.name.clone(),

                    latitude:
                        Some(
                            result.latitude
                        ),

                    longitude:
                        Some(
                            result.longitude
                        ),

                    configured_admin1:
                        result.admin1.clone(),

                    configured_country:
                        result.country.clone(),

                    resolved:
                        result,
                }
            )?;
        }


        _ => {
            return Err(
                location_usage()
            );
        }
    }


    Ok(())
}


// ============================================================
// WEATHER LOADING
// ============================================================

fn load_weather(
    force_refresh: bool
) -> Result<WeatherOutput, String> {

    let config =
        read_weather_config();


    if !force_refresh {

        if let Some(weather) =
            load_cached_weather(
                &config
            )
        {
            return Ok(
                weather
            );
        }
    }


    let location =
        resolve_configured_location(
            &config
        )?;


    let mut weather =
        fetch_weather(
            &location
        )?;


    weather.cached =
        false;


    save_weather_cache(
        &weather
    )?;


    Ok(
        weather
    )
}


// ============================================================
// CONFIGURED LOCATION
// ============================================================

fn resolve_configured_location(
    config: &WeatherConfig
) -> Result<WeatherLocation, String> {

    match config.location_mode.as_str() {

        // --------------------------------------------------------
        // MANUAL
        // --------------------------------------------------------

        "manual" => {

                        if let (
                Some(latitude),
                Some(longitude)
            ) =
                (
                    config.latitude,
                    config.longitude
                )
            {
                return Ok(
                    WeatherLocation {
                        name:
                            if config.city.is_empty() {
                                "Manual Location".to_string()
                            } else {
                                config.city.clone()
                            },

                        admin1:
                            config.admin1.clone(),

                        country:
                            config.country.clone(),

                        latitude,
                        longitude,

                        elevation:
                            config.elevation
                                .unwrap_or(0.0),

                        timezone:
                            config.timezone.clone(),

                        timezone_abbreviation:
                            String::new(),
                    }
                );
            }


            if !config.city.trim().is_empty() {
                return resolve_manual_location(
                    &config.city
                );
            }


            Err(
                "manual weather location has no city or coordinates"
                    .to_string()
            )
        }


        // --------------------------------------------------------
        // AUTO
        // --------------------------------------------------------

        _ => {
            resolve_auto_location()
        }
    }
}


// ============================================================
// AUTOMATIC LOCATION
// ============================================================

fn resolve_auto_location()
    -> Result<WeatherLocation, String>
{
    let client =
        http_client()?;


    let response =
        client
            .get(IP_LOCATION_URL)
            .send()
            .map_err(
                |error|
                    format!(
                        "automatic location request failed: {error}"
                    )
            )?;


    if !response
        .status()
        .is_success()
    {
        return Err(
            format!(
                "automatic location request returned HTTP {}",
                response.status()
            )
        );
    }


    let data:
        AutoLocationResponse =
        response
            .json()
            .map_err(
                |error|
                    format!(
                        "failed to parse automatic location response: {error}"
                    )
            )?;


    let latitude =
        data.latitude
            .ok_or_else(
                ||
                    "automatic location response did not contain latitude"
                        .to_string()
            )?;


    let longitude =
        data.longitude
            .ok_or_else(
                ||
                    "automatic location response did not contain longitude"
                        .to_string()
            )?;


    Ok(
        WeatherLocation {
            name:
                data.city
                    .unwrap_or_else(
                        ||
                            "Current Location"
                                .to_string()
                    ),
            
            admin1:
                String::new(),



            country:
                data.country_name
                    .unwrap_or_default(),

            latitude,
            longitude,

            elevation:
                0.0,

            timezone:
                data.timezone
                    .unwrap_or_default(),

            timezone_abbreviation:
                String::new(),
        }
    )
}


// ============================================================
// MANUAL LOCATION
// ============================================================

fn resolve_manual_location(
    query: &str
) -> Result<WeatherLocation, String> {

    let results =
        search_locations(
            query
        )?;


    let result =
        results
            .into_iter()
            .next()
            .ok_or_else(
                ||
                    format!(
                        "location not found: {query}"
                    )
            )?;


    Ok(
        WeatherLocation {
            name:
                result.name,

            admin1:
                result.admin1,

            country:
                result.country,

            latitude:
                result.latitude,

            longitude:
                result.longitude,

            elevation:
                result.elevation,

            timezone:
                result.timezone,

            timezone_abbreviation:
                String::new(),
        }
    )
}


// ============================================================
// LOCATION SEARCH
// ============================================================

fn search_locations(
    query: &str
) -> Result<Vec<LocationSearchResult>, String> {

    let query =
        query.trim();


    if query.is_empty() {
        return Err(
            "location search query is empty"
                .to_string()
        );
    }


    let client =
        http_client()?;


    let response =
        client
            .get(GEOCODING_URL)
            .query(
                &[
                    (
                        "name",
                        query
                    ),
                    (
                        "count",
                        "10"
                    ),
                    (
                        "language",
                        "en"
                    ),
                    (
                        "format",
                        "json"
                    ),
                ]
            )
            .send()
            .map_err(
                |error|
                    format!(
                        "location search request failed: {error}"
                    )
            )?;


    if !response
        .status()
        .is_success()
    {
        return Err(
            format!(
                "location search returned HTTP {}",
                response.status()
            )
        );
    }


    let data:
        GeocodingResponse =
        response
            .json()
            .map_err(
                |error|
                    format!(
                        "failed to parse location search response: {error}"
                    )
            )?;


    let results =
        data.results
            .unwrap_or_default()
            .into_iter()
            .map(
                |result|
                    LocationSearchResult {
                        name:
                            result.name,

                        admin1:
                            result.admin1
                                .unwrap_or_default(),

                        country:
                            result.country
                                .unwrap_or_default(),

                        latitude:
                            result.latitude,

                        longitude:
                            result.longitude,

                        elevation:
                            result.elevation
                                .unwrap_or(0.0),

                        timezone:
                            result.timezone
                                .unwrap_or_default(),
                    }
            )
            .collect();


    Ok(
        results
    )
}


// ============================================================
// WEATHER API
// ============================================================

fn fetch_weather(
    location: &WeatherLocation
) -> Result<WeatherOutput, String> {

    let client =
        http_client()?;


    let latitude =
        location.latitude
            .to_string();

    let longitude =
        location.longitude
            .to_string();


    let current =
        concat!(
            "temperature_2m,",
            "apparent_temperature,",
            "weather_code,",
            "wind_speed_10m,",
            "wind_direction_10m,",
            "is_day"
        );


    let hourly =
        concat!(
            "temperature_2m,",
            "apparent_temperature,",
            "precipitation_probability,",
            "weather_code,",
            "wind_speed_10m,",
            "wind_direction_10m,",
            "is_day"
        );


    let daily =
        concat!(
            "weather_code,",
            "temperature_2m_max,",
            "temperature_2m_min,",
            "sunrise,",
            "sunset,",
            "uv_index_max,",
            "precipitation_probability_max"
        );


    let response =
        client
            .get(FORECAST_URL)
            .query(
                &[
                    (
                        "latitude",
                        latitude.as_str()
                    ),
                    (
                        "longitude",
                        longitude.as_str()
                    ),

                    (
                        "current",
                        current
                    ),

                    (
                        "hourly",
                        hourly
                    ),

                    (
                        "daily",
                        daily
                    ),

                    (
                        "timezone",
                        "auto"
                    ),

                    (
                        "forecast_days",
                        "7"
                    ),

                    (
                        "temperature_unit",
                        "celsius"
                    ),

                    (
                        "wind_speed_unit",
                        "kmh"
                    ),
                ]
            )
            .send()
            .map_err(
                |error|
                    format!(
                        "weather request failed: {error}"
                    )
            )?;


    if !response
        .status()
        .is_success()
    {
        let status =
            response.status();


        let body =
            response
                .text()
                .unwrap_or_default();


        return Err(
            format!(
                "weather request returned HTTP {status}: {body}"
            )
        );
    }


    let api:
        ForecastResponse =
        response
            .json()
            .map_err(
                |error|
                    format!(
                        "failed to parse weather response: {error}"
                    )
            )?;


    build_weather_output(
        location,
        api
    )
}


// ============================================================
// BUILD WEATHER OUTPUT
// ============================================================

fn build_weather_output(
    location: &WeatherLocation,
    api: ForecastResponse,
) -> Result<WeatherOutput, String> {

    let today_min =
        api.daily
            .temperature_2m_min
            .first()
            .copied()
            .unwrap_or(
                api.current
                    .temperature_2m
            );


    let today_max =
        api.daily
            .temperature_2m_max
            .first()
            .copied()
            .unwrap_or(
                api.current
                    .temperature_2m
            );


    let sunrise =
        api.daily
            .sunrise
            .first()
            .map(
                |value|
                    extract_time(
                        value
                    )
            )
            .unwrap_or_default();


    let sunset =
        api.daily
            .sunset
            .first()
            .map(
                |value|
                    extract_time(
                        value
                    )
            )
            .unwrap_or_default();


    let uv_index =
        api.daily
            .uv_index_max
            .first()
            .and_then(
                |value|
                    *value
            )
            .unwrap_or(0.0);


    let wind_direction =
        degrees_to_direction(
            api.current
                .wind_direction_10m
        );


    let (
        condition,
        icon
    ) =
        weather_description(
            api.current
                .weather_code,

            api.current
                .is_day
                == 1,
        );


    let current =
        CurrentWeather {
            temperature:
                api.current
                    .temperature_2m,

            apparent_temperature:
                api.current
                    .apparent_temperature,

            condition:
                condition.to_string(),

            weather_code:
                api.current
                    .weather_code,

            icon:
                icon.to_string(),

            min_temperature:
                today_min,

            max_temperature:
                today_max,

            wind_speed:
                api.current
                    .wind_speed_10m,

            wind_direction_degrees:
                api.current
                    .wind_direction_10m,

            wind_direction:
                wind_direction.to_string(),

            is_day:
                api.current
                    .is_day
                    == 1,
        };


    let details =
        WeatherDetails {
            temperature_min:
                today_min,

            temperature_max:
                today_max,

            wind_speed:
                api.current
                    .wind_speed_10m,

            wind_direction:
                wind_direction.to_string(),

            sunrise,
            sunset,

            elevation:
                api.elevation,

            uv_index,

            timezone:
                api.timezone.clone(),

            timezone_abbreviation:
                api.timezone_abbreviation
                    .clone(),
        };


    let daily =
        build_daily_forecast(
            &api.daily
        );


    let hourly =
        build_hourly_forecast(
            &api.hourly
        );


    let output_location =
        WeatherLocation {
            name:
                location.name.clone(),

            admin1:
                location.admin1.clone(),

            country:
                location.country.clone(),

            latitude:
                location.latitude,

            longitude:
                location.longitude,

            // Forecast API value is preferable here.
            elevation:
                api.elevation,

            timezone:
                api.timezone.clone(),

            timezone_abbreviation:
                api.timezone_abbreviation
                    .clone(),
        };


    Ok(
        WeatherOutput {
            success:
                true,

            cached:
                false,

            location:
                output_location,

            current,
            details,

            daily,
            hourly,

            updated_at:
                unix_time(),
        }
    )
}


// ============================================================
// DAILY FORECAST
// ============================================================

fn build_daily_forecast(
    daily: &ForecastDaily
) -> Vec<DailyForecast> {

    let mut output =
        Vec::new();


    for index in 0..daily.time.len() {

        let code =
            get_i32(
                &daily.weather_code,
                index
            );


        let (
            condition,
            icon
        ) =
            weather_description(
                code,
                true
            );


        output.push(
            DailyForecast {
                date:
                    get_string(
                        &daily.time,
                        index
                    ),

                weather_code:
                    code,

                condition:
                    condition.to_string(),

                icon:
                    icon.to_string(),

                min_temperature:
                    get_f64(
                        &daily.temperature_2m_min,
                        index
                    ),

                max_temperature:
                    get_f64(
                        &daily.temperature_2m_max,
                        index
                    ),

                sunrise:
                    extract_time(
                        &get_string(
                            &daily.sunrise,
                            index
                        )
                    ),

                sunset:
                    extract_time(
                        &get_string(
                            &daily.sunset,
                            index
                        )
                    ),

                uv_index:
                    get_optional_f64(
                        &daily.uv_index_max,
                        index
                    ),

                precipitation_probability:
                    get_optional_f64(
                        &daily.precipitation_probability_max,
                        index
                    ),
            }
        );
    }


    output
}


// ============================================================
// HOURLY FORECAST
// ============================================================

fn build_hourly_forecast(
    hourly: &ForecastHourly
) -> Vec<HourlyForecast> {

    let mut output =
        Vec::new();


    for index in 0..hourly.time.len() {

        let code =
            get_i32(
                &hourly.weather_code,
                index
            );


        let is_day =
            hourly
                .is_day
                .get(index)
                .copied()
                .unwrap_or(1)
                == 1;


        let (
            condition,
            icon
        ) =
            weather_description(
                code,
                is_day
            );


        output.push(
            HourlyForecast {
                time:
                    get_string(
                        &hourly.time,
                        index
                    ),

                temperature:
                    get_f64(
                        &hourly.temperature_2m,
                        index
                    ),

                apparent_temperature:
                    get_f64(
                        &hourly.apparent_temperature,
                        index
                    ),

                weather_code:
                    code,

                condition:
                    condition.to_string(),

                icon:
                    icon.to_string(),

                precipitation_probability:
                    get_optional_f64(
                        &hourly.precipitation_probability,
                        index
                    ),

                wind_speed:
                    get_f64(
                        &hourly.wind_speed_10m,
                        index
                    ),

                wind_direction:
                    degrees_to_direction(
                        get_f64(
                            &hourly.wind_direction_10m,
                            index
                        )
                    )
                    .to_string(),

                is_day,
            }
        );
    }


    output
}


// ============================================================
// WEATHER CODES
// ============================================================

fn weather_description(
    code: i32,
    is_day: bool,
) -> (&'static str, &'static str) {

    match code {

        0 => {
            if is_day {
                (
                    "Clear sky",
                    "clear-day"
                )
            } else {
                (
                    "Clear sky",
                    "clear-night"
                )
            }
        }


        1 => {
            if is_day {
                (
                    "Mainly clear",
                    "mostly-clear-day"
                )
            } else {
                (
                    "Mainly clear",
                    "mostly-clear-night"
                )
            }
        }


        2 => {
            if is_day {
                (
                    "Partly cloudy",
                    "partly-cloudy-day"
                )
            } else {
                (
                    "Partly cloudy",
                    "partly-cloudy-night"
                )
            }
        }


        3 =>
            (
                "Overcast",
                "cloudy"
            ),


        45 | 48 =>
            (
                "Fog",
                "fog"
            ),


        51 | 53 | 55 =>
            (
                "Drizzle",
                "drizzle"
            ),


        56 | 57 =>
            (
                "Freezing drizzle",
                "freezing-rain"
            ),


        61 | 63 | 65 =>
            (
                "Rain",
                "rain"
            ),


        66 | 67 =>
            (
                "Freezing rain",
                "freezing-rain"
            ),


        71 | 73 | 75 =>
            (
                "Snow",
                "snow"
            ),


        77 =>
            (
                "Snow grains",
                "snow"
            ),


        80 | 81 | 82 =>
            (
                "Rain showers",
                "rain-showers"
            ),


        85 | 86 =>
            (
                "Snow showers",
                "snow-showers"
            ),


        95 =>
            (
                "Thunderstorm",
                "thunderstorm"
            ),


        96 | 99 =>
            (
                "Thunderstorm with hail",
                "thunderstorm-hail"
            ),


        _ =>
            (
                "Unknown",
                "unknown"
            ),
    }
}


// ============================================================
// WIND DIRECTION
// ============================================================

fn degrees_to_direction(
    degrees: f64
) -> &'static str {

    let degrees =
        degrees.rem_euclid(
            360.0
        );


    match degrees {

        d if d < 22.5 =>
            "N",

        d if d < 67.5 =>
            "NE",

        d if d < 112.5 =>
            "E",

        d if d < 157.5 =>
            "SE",

        d if d < 202.5 =>
            "S",

        d if d < 247.5 =>
            "SW",

        d if d < 292.5 =>
            "W",

        d if d < 337.5 =>
            "NW",

        _ =>
            "N",
    }
}


// ============================================================
// CONFIG
// ============================================================

fn read_weather_config()
    -> WeatherConfig
{
    let path =
        config_path();


    let Ok(contents) =
        fs::read_to_string(
            path
        )
    else {
        return WeatherConfig::default();
    };


    let mut config =
        WeatherConfig::default();


    for line in contents.lines() {

        let line =
            line.trim();


        if line.is_empty()
            || line.starts_with('#')
        {
            continue;
        }


        let Some(
            (
                key,
                value
            )
        ) =
            line.split_once('=')
        else {
            continue;
        };


        let key =
            key.trim();

        let value =
            value.trim();


        match key {

            "location_mode" => {

                if value == "auto"
                    || value == "manual"
                {
                    config.location_mode =
                        value.to_string();
                }
            }


            "city" => {
                config.city =
                    value.to_string();
            }


            "latitude" => {

                if !value.is_empty() {
                    config.latitude =
                        value
                            .parse::<f64>()
                            .ok();
                }
            }


            "longitude" => {

                if !value.is_empty() {
                    config.longitude =
                        value
                            .parse::<f64>()
                            .ok();
                }
            }

            "admin1" => {
                config.admin1 =
                    value.to_string();
            }


            "country" => {
                config.country =
                    value.to_string();
            }


            "elevation" => {
                if !value.is_empty() {
                    config.elevation =
                        value
                            .parse::<f64>()
                            .ok();
                }
            }


            "timezone" => {
                config.timezone =
                    value.to_string();
            }


            _ => {}
        }
    }


    config
}


fn save_weather_config(
    config: &WeatherConfig
) -> Result<(), String> {

    let path =
        config_path();


    if let Some(parent) =
        path.parent()
    {
        fs::create_dir_all(
            parent
        )
        .map_err(
            |error|
                format!(
                    "failed to create config directory: {error}"
                )
        )?;
    }


    let latitude =
        config.latitude
            .map(
                |value|
                    value.to_string()
            )
            .unwrap_or_default();


    let longitude =
        config.longitude
            .map(
                |value|
                    value.to_string()
            )
            .unwrap_or_default();

    let elevation =
        config.elevation
            .map(
                |value|
                    value.to_string()
            )
            .unwrap_or_default();


    let contents =
        format!(
            concat!(
                "# NEXA Weather\n",
                "\n",
                "location_mode={}\n",
                "city={}\n",
                "admin1={}\n",
                "country={}\n",
                "latitude={}\n",
                "longitude={}\n",
                "elevation={}\n",
                "timezone={}\n"
            ),

            config.location_mode,
            config.city,
            config.admin1,
            config.country,
            latitude,
            longitude,
            elevation,
            config.timezone,
        );

    


    fs::write(
        path,
        contents
    )
    .map_err(
        |error|
            format!(
                "failed to save weather config: {error}"
            )
    )
}


// ============================================================
// CACHE
// ============================================================

fn load_cached_weather(
    config: &WeatherConfig
) -> Option<WeatherOutput> {

    let path =
        cache_path();


    let contents =
        fs::read_to_string(
            path
        )
        .ok()?;


    let mut weather:
        WeatherOutput =
        serde_json::from_str(
            &contents
        )
        .ok()?;


    let now =
        unix_time();


    if now.saturating_sub(
        weather.updated_at
    ) > CACHE_MAX_AGE
    {
        return None;
    }


    // Manual config may have been edited outside nexad.
    // Refuse stale cache when coordinates no longer match.
    if config.location_mode == "manual" {

        if let (
            Some(latitude),
            Some(longitude)
        ) =
            (
                config.latitude,
                config.longitude
            )
        {
            if !coordinates_equal(
                weather.location.latitude,
                latitude
            )
            || !coordinates_equal(
                weather.location.longitude,
                longitude
            )
            {
                return None;
            }
        }
    }


    weather.cached =
        true;


    Some(
        weather
    )
}


fn save_weather_cache(
    weather: &WeatherOutput
) -> Result<(), String> {

    let path =
        cache_path();


    if let Some(parent) =
        path.parent()
    {
        fs::create_dir_all(
            parent
        )
        .map_err(
            |error|
                format!(
                    "failed to create weather cache directory: {error}"
                )
        )?;
    }


    let json =
        serde_json::to_string_pretty(
            weather
        )
        .map_err(
            |error|
                format!(
                    "failed to serialize weather cache: {error}"
                )
        )?;


    fs::write(
        path,
        json
    )
    .map_err(
        |error|
            format!(
                "failed to write weather cache: {error}"
            )
    )
}


fn clear_weather_cache()
    -> Result<(), String>
{
    remove_file_if_exists(
        &cache_path()
    )
}


fn remove_file_if_exists(
    path: &Path
) -> Result<(), String> {

    match fs::remove_file(
        path
    ) {

        Ok(_) =>
            Ok(()),


        Err(error)
            if error.kind()
                == std::io::ErrorKind::NotFound =>
        {
            Ok(())
        }


        Err(error) => {
            Err(
                format!(
                    "failed to remove {}: {error}",
                    path.display()
                )
            )
        }
    }
}


// ============================================================
// HTTP
// ============================================================

fn http_client()
    -> Result<reqwest::blocking::Client, String>
{
    reqwest::blocking::Client::builder()
        .user_agent(
            "nexa-weather/0.1"
        )
        .timeout(
            Duration::from_secs(
                HTTP_TIMEOUT_SECONDS
            )
        )
        .build()
        .map_err(
            |error|
                format!(
                    "failed to create HTTP client: {error}"
                )
        )
}


// ============================================================
// PATHS
// ============================================================

fn config_path()
    -> PathBuf
{
    home_dir()
        .join(".config")
        .join("nexa")
        .join("config")
        .join("weather.conf")
}


fn cache_path()
    -> PathBuf
{
    home_dir()
        .join(".cache")
        .join("nexa")
        .join("weather")
        .join("weather.json")
}


fn home_dir()
    -> PathBuf
{
    env::var_os(
        "HOME"
    )
    .map(
        PathBuf::from
    )
    .unwrap_or_else(
        ||
            PathBuf::from(".")
    )
}


// ============================================================
// HELPERS
// ============================================================

fn unix_time()
    -> u64
{
    SystemTime::now()
        .duration_since(
            UNIX_EPOCH
        )
        .map(
            |duration|
                duration.as_secs()
        )
        .unwrap_or(0)
}


fn coordinates_equal(
    first: f64,
    second: f64,
) -> bool {

    (
        first
        -
        second
    )
    .abs()
        < 0.0001
}


fn extract_time(
    value: &str
) -> String {

    value
        .split('T')
        .nth(1)
        .unwrap_or(
            value
        )
        .to_string()
}


fn get_string(
    values: &[String],
    index: usize,
) -> String {

    values
        .get(index)
        .cloned()
        .unwrap_or_default()
}


fn get_f64(
    values: &[f64],
    index: usize,
) -> f64 {

    values
        .get(index)
        .copied()
        .unwrap_or(0.0)
}


fn get_i32(
    values: &[i32],
    index: usize,
) -> i32 {

    values
        .get(index)
        .copied()
        .unwrap_or(0)
}


fn get_optional_f64(
    values: &[Option<f64>],
    index: usize,
) -> f64 {

    values
        .get(index)
        .copied()
        .flatten()
        .unwrap_or(0.0)
}


// ============================================================
// JSON
// ============================================================

fn print_json<T>(
    value: &T
) -> Result<(), String>
where
    T: Serialize,
{
    let json =
        serde_json::to_string(
            value
        )
        .map_err(
            |error|
                format!(
                    "failed to serialize weather output: {error}"
                )
        )?;


    println!(
        "{json}"
    );


    Ok(())
}


// ============================================================
// USAGE
// ============================================================

fn weather_usage()
    -> String
{
    concat!(
        "usage:\n",
        "  nexad weather info\n",
        "  nexad weather refresh\n",
        "  nexad weather location info\n",
        "  nexad weather location auto\n",
        "  nexad weather location search <city>\n",
        "  nexad weather location set <city>"
    )
    .to_string()
}


fn location_usage()
    -> String
{
    concat!(
        "usage:\n",
        "  nexad weather location info\n",
        "  nexad weather location auto\n",
        "  nexad weather location search <city>\n",
        "  nexad weather location set <city>"
    )
    .to_string()
}
