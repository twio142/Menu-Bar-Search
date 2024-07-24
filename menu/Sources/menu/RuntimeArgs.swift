//
//  RuntimeArgs.swift
//
//
//  Created by Benzi  on 20/12/2022.
//

import Foundation

class RuntimeArgs {
    let usage = """
    Usage: menu [options]

    Options:
        [-query|-q <string>]          - filter menu listing based on string
        [-pid <id>]                   - target app with the given pid, instead of the menubar owning app
        [-only <root_menu>]           - only show items from the given root menu
        [-max-depth <depth:10>]       - max traversal depth of menu
        [-max-children <count:20>]    - max set of child items to process under each parent menu
        [-match-pinyin]               - match pinyin for menu item title
        [-match-click <title> ...]    - match for exact menu item title and click if found,
                                        multiple arguments supported,
                                        levels can be separated by `\\t` in each argument
        [-click <menu_index_path>]    - click the menu path for the given pid app
        [-learning <0|1:1>]           - toggle learning mode
        [-async]                      - enable GCD based collection of sub menu items
        [-cache <timeout>]            - enable caching with given timeout interval
        [-recache]                    - forced recache
        [-reorder-apple-menu <0|1:1>] - reorder Apple menu to the end
        [-show-apple-menu]            - show Apple menu items
        [-show-disabled]              - show disabled menu items
        [-show-folders]               - output Alfred settings and cache folders
        [-dump]                       - print debug dump (output not compatible with Alfred)
        [-help|-h]                    - print this help message
    """

    var query = ""
    var matchClick: [String] = []
    var addingToMatchClick = false
    var pid: Int32 = -1
    var reorderAppleMenuToLast = true
    var learning = true
    var clickIndices: [Int]?
    var loadAsync = false
    var cachingEnabled = false
    var cacheTimeout = 0.0

    var options = MenuGetterOptions()

    var i = 1 // skip name of program
    var current: String? {
        return i < CommandLine.arguments.count ? CommandLine.arguments[i] : nil
    }

    func advance() {
        i += 1
    }

    let createInt: (String)->Int? = { Int($0) }
    let createInt32: (String)->Int32? = { Int32($0) }
    let createBool: (String)->Bool? = { Bool($0) }
    let createDouble: (String)->Double? = { Double($0) }
    let createBoolFromInt: (String)->Bool? = { value in
        if let v = Int(value), v == 1 {
            return true
        }
        return false
    }

    func parse<T>(_ create: (String)->T?, _ error: String)->T {
        if let arg = current, let value = create(arg) {
            advance()
            return value
        }
        Alfred.quit(error)
    }

    func parseOptional<T>(_ create: (String)->T?, _ fallback: T)->T {
        if let arg = current {
            advance()
            return create(arg) ?? fallback
        }
        return fallback
    }

    func parse() {
        options.maxDepth = 10
        options.maxChildren = 40
        options.appFilter = AppFilter()

        while let arg = current {
            switch arg {
            case "-query", "-q":
                addingToMatchClick = false
                advance()
                if let arg = current {
                    advance()
                    query = arg.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
                    query = parseToShortcut(from: query)
                }

            case "-pid":
                addingToMatchClick = false
                advance()
                pid = parse(createInt32, "Expected integer after -pid")

            case "-only":
                addingToMatchClick = false
                advance()
                guard let specificMenuRoot = current else {
                    Alfred.quit("Expected root menu name after -only")
                    break
                }
                advance()
                options.specificMenuRoot = specificMenuRoot

            case "-max-depth":
                addingToMatchClick = false
                advance()
                options.maxDepth = parse(createInt, "Expected number after -max-depth")

            case "-max-children":
                addingToMatchClick = false
                advance()
                options.maxChildren = parse(createInt, "Expected number after -max-children")

            case "-match-pinyin":
                addingToMatchClick = false
                advance()
                options.matchPinyin = true

            case "-match-click":
                addingToMatchClick = true
                advance()

            case "-click":
                addingToMatchClick = false
                advance()
                guard let pathJson = current else {
                    Alfred.quit("Not able to parse argument after -click \(CommandLine.arguments)")
                    break
                }
                advance()
                clickIndices = IndexParser.parse(pathJson)

            case "-learning":
                advance()
                addingToMatchClick = false
                learning = parse(createBoolFromInt, "Expected 0/1 after -learning")

            case "-async":
                addingToMatchClick = false
                advance()
                loadAsync = true

            case "-cache":
                addingToMatchClick = false
                advance()
                cachingEnabled = true
                cacheTimeout = parse(createDouble, "Expected timeout after -cache")

            case "-recache":
                addingToMatchClick = false
                advance()
                options.recache = true

            case "-reorder-apple-menu":
                advance()
                addingToMatchClick = false
                reorderAppleMenuToLast = parse(createBoolFromInt, "Expected 0/1 after -reorder-apple-menu")

            case "-show-apple-menu":
                addingToMatchClick = false
                advance()
                options.appFilter.showAppleMenu = true

            case "-show-disabled":
                addingToMatchClick = false
                advance()
                options.appFilter.showDisabledMenuItems = true

            case "-show-folders":
                let a = Alfred()
                let icon = AlfredResultItemIcon.with { $0.path = "icon.settings.png" }
                a.add(AlfredResultItem.with {
                    $0.title = "Settings Folder"
                    $0.arg = Alfred.data()
                    $0.icon = icon
                })
                if !FileManager.default.fileExists(atPath: Alfred.data(path: "settings.txt")) {
                    a.add(AlfredResultItem.with {
                        $0.title = "View a sample Settings file"
                        $0.subtitle = "You can use this as a reference to customise per app configuration"
                        $0.arg = "sample settings.txt"
                        $0.icon = icon
                    })
                }
                a.add(AlfredResultItem.with {
                    $0.title = "Cache Folder"
                    $0.arg = Alfred.cache()
                    $0.icon = icon
                })
                //        for cache in Cache.getCachedMenuControls() {
                //            let expiry = Date(timeIntervalSince1970: cache.control.timeout)
                //            let now = Date()
                //            let expirationPrefix = expiry > now ? "expires" : "expired"
                //            if #available(macOS 10.15, *) {
                //                let formatter = RelativeDateTimeFormatter()
                //                a.add(AlfredResultItem.with {
                //                    $0.title = cache.appBundleId
                //                    $0.subtitle = "\(expirationPrefix): \(formatter.localizedString(for: expiry, relativeTo: Date()))"
                //                })
                //            }
                //            else {
                //                a.add(AlfredResultItem.with {
                //                    $0.title = cache.appBundleId
                //                    $0.subtitle = "\(expirationPrefix): \(expiry)"
                //                })
                //            }
                //        }
                print(a.resultsJson)
                exit(0)

            case "-dump":
                addingToMatchClick = false
                advance()
                options.dumpInfo = true

            case "-help", "-h":
                print(usage)
                exit(0)

            default:
                if !arg.isEmpty && addingToMatchClick {
                    matchClick += [arg]
                }
                // unknown command line option
                advance()
            }
        }
    }
}

func parseToShortcut(from _term: String)->String {
    if !_term.hasPrefix("#") || _term.count < 2 {
        return _term
    }
    var term = String(_term.dropFirst()).split(separator: " ").map(String.init)
    var res = [String]()

    let keys: [(String, String)] = [
        ("ctrl", "⌃"),
        ("alt", "⌥"),
        ("shift", "⇧"),
        ("cmd", "⌘"),
        ("ret", "↩"),
        ("kp_ent", "⌤"),
        ("kp_clr", "⌧"),
        ("tab", "⇥"),
        ("space", "␣"),
        ("del", "⌫"),
        ("esc", "⎋"),
        ("caps", "⇪"),
        ("fn", "fn"),
        ("f1", "F1"),
        ("f2", "F2"),
        ("f3", "F3"),
        ("f4", "F4"),
        ("f5", "F5"),
        ("f6", "F6"),
        ("f7", "F7"),
        ("f8", "F8"),
        ("f9", "F9"),
        ("f10", "F10"),
        ("f11", "F11"),
        ("f12", "F12"),
        ("f13", "F13"),
        ("f14", "F14"),
        ("f15", "F15"),
        ("f16", "F16"),
        ("f17", "F17"),
        ("f18", "F18"),
        ("f19", "F19"),
        ("f20", "F20"),
        ("home", "↖"),
        ("pgup", "⇞"),
        ("fwd_del", "⌦"),
        ("end", "↘"),
        ("pgdn", "⇟"),
        ("left", "◀︎"),
        ("right", "▶︎"),
        ("down", "▼"),
        ("up", "▲")
    ]

    for (keycode, key) in keys {
        if let index = term.firstIndex(of: keycode) {
            res.append(key); term.remove(at: index)
        }
    }

    if !term.isEmpty {
        res.append(term.joined(separator: halfWidthSpace))
    }

    return res.joined(separator: halfWidthSpace)
}
