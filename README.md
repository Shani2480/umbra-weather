# Umbra Weather

A weather widget for KDE Plasma 6 with an animated condition icon in the panel,
a hover forecast, and a detailed desktop card with a weekly view.

- Current conditions and a 7-day forecast from [Open-Meteo](https://open-meteo.com/), no API key needed
- Panel item with an animated icon that plays on hover, on a condition change, and every few minutes
- Hover popup with the next hours and today's details
- Desktop card with sunrise and sunset, an hourly strip, and ambient weather animations
  (wind-driven rain, flowing wind ribbons, drifting clouds, snow, lightning)
- A small silhouette duo, a person and their dog, that react to the weather on the hourly strip
- Three icon styles: volumetric glass, hand-drawn animated, and the Weather Underground sets
- Metric or imperial units, configurable refresh interval

## Install

From the KDE Store: right-click the panel or desktop, choose *Add Widgets*, then
*Get New Widgets* and search for "Umbra Weather".

From source:

```sh
kpackagetool6 --type Plasma/Applet --install package
```

To update an existing install use `--upgrade` instead of `--install`.

## Settings

Right-click the widget and choose *Configure*. Type a place name to look it
up; the first match sets the coordinates. The icon style, units, refresh
interval, the ambient animations and the weather character can all be
switched there.

## Credits

- Weather data by [Open-Meteo](https://open-meteo.com/), CC BY 4.0
- Weather Underground icon sets by Ashley Jager, from
  [manifestinteractive/weather-underground-icons](https://github.com/manifestinteractive/weather-underground-icons)
  (see `package/contents/icons/LICENSE`)

## License

GPL-2.0-or-later. See `LICENSE`.
