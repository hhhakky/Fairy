//
//  AppCatalog.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
// список установленных приложений и поиск по названию
import Foundation

struct AppEntry {
    let file: String          // для open -a: "Reminders"
    let keys: Set<String>     // как его можно назвать: "reminders", "напоминания"
}

struct AppCatalog {
    private(set) var entries: [AppEntry] = []

    /// Свои сокращения (ключ и значение в нижнем регистре)
    let aliases: [String: String] = [
        // --- AppCleaner ---
        "аппклинер": "appcleaner",
        "апклинер": "appcleaner",
        "чистилка": "appcleaner",

        // --- ArtCraft Launcher ---
        "арткрафт": "artcraft launcher",
        "лаунчер арткрафт": "artcraft launcher",

        // --- AyuGram ---
        "аюграм": "ayugram",
        "ауграм": "ayugram",

        // --- Caffeine ---
        "кофеин": "caffeine",
        "кафеин": "caffeine",
        "экран": "caffeine",

        // --- Claude ---
        "клод": "claude",
        "клауд": "claude",
        "ии": "claude",

        // --- FilmCraft ---
        "фильмкрафт": "filmcraft",

        // --- Firefox ---
        "файрфокс": "firefox",
        "фаерфокс": "firefox",
        "лиса": "firefox",
        "мозила": "firefox",

        // --- Ghostty ---
        "гостти": "ghostty",
        "гости": "ghostty",
        "терминал": "ghostty",

        // --- Keka ---
        "кека": "keka",
        "архиватор": "keka",

        // --- krita ---
        "крита": "krita",
        "рисовалка": "krita",

        // --- Legcord (клиент Discord) ---
        "легкорд": "legcord",
        "лега": "legcord",
        "дискорд": "legcord",
        "дс": "legcord",

        // --- Mac Mouse Fix ---
        "мышка": "mac mouse fix",
        "фикс мыши": "mac mouse fix",

        // --- Microsoft Office ---
        "эксель": "microsoft excel",
        "таблица": "microsoft excel",
        "поверпоинт": "microsoft powerpoint",
        "преза": "microsoft powerpoint",
        "тимс": "microsoft teams",
        "созвон": "microsoft teams",
        "ворд": "microsoft word",
        "док": "microsoft word",
        "текст": "microsoft word",

        // --- NCALayer ---
        "нкалеер": "ncalayer",
        "эгов": "ncalayer",
        "egov": "ncalayer",
        "эцп": "ncalayer",

        // --- OBS ---
        "обс": "obs",
        "стрим": "obs",

        // --- Obsidian ---
        "обсидиан": "obsidian",
        "заметки": "obsidian",
        "база знаний": "obsidian",

        // --- OpenDisk & OpenTabletDriver ---
        "опендиск": "opendisk",
        "планшет": "opentabletdriver",

        // --- osu! ---
        "осу": "osu!",
        "кружочки": "osu!",

        // --- PhotoCraft ---
        "фотокрафт": "photocraft",

        // --- Prism Launcher ---
        "призма": "prism launcher",
        "майн": "prism launcher",
        "майнкрафт": "prism launcher",

        // --- qbittorrent ---
        "кубит": "qbittorrent",
        "торрент": "qbittorrent",
        "качалка": "qbittorrent",

        // --- Safari ---
        "сафари": "safari",
        "браузер": "safari",
        "инет": "safari",

        // --- Sideloadly ---
        "сайдлоадли": "sideloadly",

        // --- Steam ---
        "стим": "steam",
        "игры": "steam",

        // --- Tailscale ---
        "тейлскейл": "tailscale",
        "впн": "tailscale",
        "vpn": "tailscale",

        // --- Telegram ---
        "тг": "ayugram",
        "телега": "ayugram",
        "телеграм": "ayugram",

        // --- Tor Browser ---
        "тор": "tor browser",
        "луковица": "tor browser",
        "даркнет": "tor browser",

        // --- uBlock Origin Lite ---
        "юблок": "ublock origin lite",
        "адблок": "ublock origin lite",

        // --- Upscayl ---
        "апскейл": "upscayl",

        // --- Utilities ---
        "утилиты": "utilities",

        // --- Xcode ---
        "икскод": "xcode",
        "разработка": "xcode",

        // --- Yaagl ZZZ OS ---
        "ягл": "yaagl zzz os",
        "ззз": "yaagl zzz os",
        "zzz": "yaagl zzz os",

        // --- Zed ---
        "зед": "zed",
        "зэд": "zed",
        "код": "zed",

        // ==========================================
        // ОПЕЧАТКИ (АНГЛИЙСКАЯ РАСКЛАДКА ДЛЯ РУССКИХ СЛОВ)
        // ==========================================

        "fggrkbyth": "appcleaner",   // аппклинер
        "xbcnbrrf": "appcleaner",    // чистилка
        
        "fhnrhfan": "artcraft launcher", // арткрафт
        "f.uhfv": "ayugram",         // аюграм
        
        "rjatby": "caffeine",        // кофеин
        "'rhfy": "caffeine",         // экран
        
        "rkjl": "claude",            // клод
        "b": "claude",               // ии (две буквы b) -> bb
        "bb": "claude",              // ии
        
        "abkmvrhfan": "filmcraft",   // фильмкрафт
        
        "afqhajrc": "firefox",       // файрфокс
        "kbcf": "firefox",           // лиса
        "vjpbkf": "firefox",         // мозила
        
        "ujcnnb": "ghostty",         // гостти
        "nthvbyfk": "ghostty",       // терминал
        
        "rtrf": "keka",              // кека
        "fh[bdfnjh": "keka",         // архиватор
        
        "rhbnf": "krita",            // крита
        
        "kturjhl": "legcord",        // легкорд
        "lbcrjhl": "legcord",        // дискорд
        "lc": "legcord",             // дс
        
        "vsirf": "mac mouse fix",    // мышка
        
        "'rctkm": "microsoft excel", // эксель
        "nf,kbwf": "microsoft excel",// таблица
        "gjdthgjbyn": "microsoft powerpoint", // поверпоинт
        "ghtpf": "microsoft powerpoint", // преза
        "nbvc": "microsoft teams",   // тимс
        "djhl": "microsoft word",    // ворд
        "ljr": "microsoft word",     // док
        
        "yrfkttth": "ncalayer",      // нкалеер
        "'ujd": "ncalayer",          // эгов
        "'wg": "ncalayer",           // эцп
        
        "j,c": "obs",                // обс
        "cnhbv": "obs",              // стрим
        
        "j,cblbfy": "obsidian",      // обсидиан
        "pfvtnrb": "obsidian",       // заметки
        
        "jce": "osu!",               // осу
        "rhepjxrb": "osu!",          // кружочки
        
        "ghbpvf": "prism launcher",  // призма
        "vfqy": "prism launcher",    // майн
        
        "re,bn": "qbittorrent",      // кубит
        "njhhtyn": "qbittorrent",    // торрент
        "rfxfkrf": "qbittorrent",    // качалка
        
        "cfafhb": "safari",          // сафари
        ",hfepth": "safari",         // браузер
        "bytn": "safari",            // инет
        
        "cnbv": "steam",             // стим
        "buhs": "steam",             // игры
        
        "ntqkcrtqk": "tailscale",    // тейлскейл
        "dgy": "tailscale",          // впн
        
        "nu": "telegram",            // тг
        "ntktuf": "telegram",        // телега
        "ntktuhfv": "telegram",      // телеграм
        
        "njh": "tor browser",        // тор
        
        ".,kjr": "ublock origin lite", // юблок
        "fl,kjr": "ublock origin lite", // адблок
        
        "fgtcrqtk": "upscayl",       // апскейл (wait, апскейл = f g c r t q k -> agcrktqk, точнее f g c r t q k = а п с к е й л -> agcrtqk)
        "fucrtqk": "upscayl",        // апскейл
        
        "enbkbnb": "utilities",      // утилиты
        
        "brcrjl": "xcode",           // икскод
        
        "zuk": "yaagl zzz os",       // ягл
        "ppp": "yaagl zzz os",       // ззз
        
        "ptl": "zed",                // зед
        "p'l": "zed",                // зэд
        "rjl": "zed"                 // код
    ]

    init() {
        let home = NSHomeDirectory()
        let dirs = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/System/Library/CoreServices",
            "\(home)/Applications"
        ]
        var found: [String: AppEntry] = [:]
        for dir in dirs {
            let items = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
            for item in items where item.hasSuffix(".app") {
                let file = String(item.dropLast(4))
                guard found[file] == nil else { continue }

                var display = FileManager.default.displayName(atPath: "\(dir)/\(item)")
                if display.hasSuffix(".app") { display = String(display.dropLast(4)) }

                found[file] = AppEntry(file: file, keys: [normalize(file), normalize(display)])
            }
        }
        entries = found.values.sorted { $0.file < $1.file }
    }

    /// Возвращает настоящее имя приложения (для open -a) или nil
    func resolve(_ query: String) -> String? {
        let q = normalize(query)
        guard !q.isEmpty else { return nil }
        let target = aliases[q] ?? q

        if let e = entries.first(where: { $0.keys.contains(target) }) { return e.file }
        guard target.count >= 3 else { return nil }
        if let e = entries.first(where: { $0.keys.contains { $0.hasPrefix(target) } }) { return e.file }
        if let e = entries.first(where: { $0.keys.contains { $0.contains(target) } }) { return e.file }
        return nil
    }
}
