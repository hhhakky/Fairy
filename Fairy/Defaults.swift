//
//  Defaults.swift
//  Fairy
//
//  Created by Riyat Rahim on 26.10.2026.
// стандартные навыки
import Foundation

enum Defaults {
    static let skills: [String: String] = [

        "open_app.json": #"""
        {
          "id": "open_app",
          "description": "Open an installed application",
          "triggers": ["открой {app}", "открыть {app}", "запусти {app}", "запустить {app}", "включи {app}",
                       "открой приложение {app}", "запусти приложение {app}", "открой программу {app}",
                       "запусти программу {app}", "открыть программу {app}", "открыть приложение {app}",
                       "open {app}", "launch {app}", "start {app}"],
          "params": { "app": { "type": "app" } },
          "run": [["open", "-a", "{app}"]],
          "display": "open -a {app}"
        }
        """#,

        "quit_app.json": #"""
        {
          "id": "quit_app",
          "description": "Quit a running application",
          "triggers": ["закрой {app}", "закрыть {app}", "выключи {app}", "выйди из {app}",
                       "закрой приложение {app}", "закрой программу {app}", "quit {app}", "close {app}"],
          "params": { "app": { "type": "app" } },
          "run": [["osascript", "-e", "on run argv", "-e", "tell application (item 1 of argv) to quit", "-e", "end run", "{app}"]],
          "display": "quit {app}"
        }
        """#,

        "set_volume.json": #"""
        {
          "id": "set_volume",
          "description": "Set the system volume to a number from 0 to 100",
          "triggers": ["громкость {value}", "громкость на {value}", "поставь громкость {value}",
                       "поставь громкость на {value}", "сделай громкость {value}", "volume {value}", "set volume {value}"],
          "params": { "value": { "type": "int", "min": 0, "max": 100 } },
          "run": [["osascript", "-e", "set volume output volume {value}"]],
          "display": "volume {value}%"
        }
        """#,

        "mute.json": #"""
        {
          "id": "mute",
          "description": "Mute the sound",
          "triggers": ["выключи звук", "без звука", "заглуши звук", "mute"],
          "run": [["osascript", "-e", "set volume output muted true"]],
          "display": "mute"
        }
        """#,

        "unmute.json": #"""
        {
          "id": "unmute",
          "description": "Unmute the sound",
          "triggers": ["включи звук", "верни звук", "unmute"],
          "run": [["osascript", "-e", "set volume output muted false"]],
          "display": "unmute"
        }
        """#,

        "open_url.json": #"""
        {
          "id": "open_url",
          "description": "Open a website in the default browser",
          "triggers": ["открой сайт {url}", "открыть сайт {url}", "открой {url}", "открыть {url}",
                       "зайди на {url}", "зайди на сайт {url}", "перейди на {url}",
                       "open site {url}", "open url {url}", "open {url}"],
          "params": { "url": { "type": "url" } },
          "run": [["open", "-a", "Safari", "{url}"]],
          "display": "open {url}"
        }
        """#,

        "open_folder.json": #"""
        {
          "id": "open_folder",
          "description": "Open a folder in Finder",
          "triggers": ["открой папку {folder}", "открыть папку {folder}", "покажи папку {folder}",
                       "открой {folder}", "открыть {folder}", "покажи {folder}", "open folder {folder}", "open {folder}"],
          "params": { "folder": { "type": "folder" } },
          "run": [["open", "{folder}"]],
          "display": "open {folder}"
        }
        """#,

        "sleep.json": #"""
        {
          "id": "sleep",
          "description": "Put the Mac to sleep (the user may say 'turn off the computer')",
          "triggers": ["выключи компьютер", "выключи мак", "усыпи компьютер", "усыпи мак",
                       "спящий режим", "режим сна", "засни", "sleep", "sleep mac"],
          "run": [["pmset", "sleepnow"]],
          "display": "pmset sleepnow"
        }
        """#,

        "web_search.json": #"""
        {
          "id": "web_search",
          "description": "Search Google in the browser for the given query",
          "triggers": ["найди в гугле {query}", "поищи в гугле {query}", "загугли {query}",
                       "найди в интернете {query}", "поищи в интернете {query}", "google {query}", "search {query}"],
          "params": { "query": { "type": "query" } },
          "run": [["open", "https://www.google.com/search?q={query}"]],
          "display": "google: {query}"
        }
        """#,
        "weather.json": #"""
        {
          "id": "weather",
          "description": "Show the current weather in Almaty",
          "triggers": ["погода", "какая погода", "что с погодой", "weather"],
          "run": [["curl", "-s", "-f", "-m", "8", "wttr.in/Almaty?format=%c+%t+%w&lang=ru&m"]],
          "output": "show",
          "display": { "text": "погода…", "icon": "cloud.sun" }
        }
        """#,

        "weather_city.json": #"""
        {
          "id": "weather_city",
          "description": "Show the current weather in the given city",
          "triggers": ["погода в {city}", "какая погода в {city}", "weather in {city}"],
          "params": { "city": { "type": "query" } },
          "run": [["weather.sh", "{city}"]],
          "output": "show",
          "display": { "text": "погода…", "icon": "cloud.sun" }
        }
        """#
    ]
    static let scripts: [String: String] = [
        "weather.sh": #"""
        #!/bin/bash
        # $1 — город (уже закодирован для адреса). Если не передан, берём Almaty.
        city="${1:-Almaty}"
        curl -s -f -m 8 "wttr.in/${city}?format=%c+%t+%w&lang=ru&m" || echo "нет данных о погоде"
        """#
    ]
    static let aliases = #"""
    {
      "apps": {
        "терминал": "ghostty",
        "командная строка": "ghostty",
        "командную строку": "ghostty",
        "консоль": "ghostty",
        "браузер": "safari",
        "хром": "google chrome",
        "телеграм": "telegram",
        "настройки": "system settings"
      },
      "folders": {
        "загрузки": "~/Downloads",
        "документы": "~/Documents",
        "рабочий стол": "~/Desktop",
        "картинки": "~/Pictures",
        "музыка": "~/Music",
        "видео": "~/Movies",
        "домашняя папка": "~",
        "программы": "/Applications"
      },
      "sites": {
        "ютуб": "youtube.com",
        "гугл": "google.com",
        "гитхаб": "github.com",
        "почта": "mail.google.com",
        "википедия": "wikipedia.org"
      }
    }
    """#
}
