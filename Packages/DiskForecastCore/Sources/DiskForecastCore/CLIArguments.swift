import Foundation

/// What the `diskforecast` command was asked to do.
public enum CLICommand: Equatable, Sendable {
    /// `wait`: for scan, keep going until the scan finishes.
    case send(CLIRequest, json: Bool, wait: Bool = false)
    case help
    case version
}

public struct CLIUsageError: Error, Equatable, Sendable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }
}

public enum CLIArguments {
    public static func parse(_ arguments: [String]) throws(CLIUsageError) -> CLICommand {
        guard let name = arguments.first else { return .help }
        var options = Options(command: name, arguments: Array(arguments.dropFirst()))
        switch name {
        case "help", "-h", "--help": return .help
        case "version", "-v", "--version": return .version
        case "status", "cleanup":
            try options.parse()
            try options.noPositionals()
            return .send(CLIRequest(action: name == "status" ? .status : .cleanup), json: options.json)
        case "changes":
            try options.parse(allowing: ["--days"])
            try options.noPositionals()
            return .send(CLIRequest(action: .changes, days: options.days ?? 7), json: options.json)
        case "scan":
            try options.parse(allowing: ["--wait"])
            try options.noPositionals()
            return .send(CLIRequest(action: .scan), json: options.json, wait: options.wait)
        case "trash":
            try options.parse(allowing: ["--yes"])
            guard !options.positionals.isEmpty else {
                throw CLIUsageError("Name what to move, like: diskforecast trash xcode-derived-data")
            }
            let request = CLIRequest(action: .trash, targets: options.positionals, confirmed: options.yes)
            return .send(request, json: options.json)
        case "open":
            try options.parse()
            return .send(CLIRequest(action: .open, window: try window(options.positionals)), json: options.json)
        default:
            throw CLIUsageError("Unknown command: \(name)")
        }
    }

    private static func window(_ names: [String]) throws(CLIUsageError) -> CLIRequest.Window {
        guard names.count == 1, let window = CLIRequest.Window(rawValue: names[0]) else {
            let all = CLIRequest.Window.allCases.map(\.rawValue).joined(separator: ", ")
            throw CLIUsageError("Name a window to open: \(all).")
        }
        return window
    }

    private struct Options {
        let command: String
        var arguments: [String]
        var positionals: [String] = []
        var json = false
        var wait = false
        var yes = false
        var days: Int?

        init(command: String, arguments: [String]) {
            self.command = command
            self.arguments = arguments
        }

        mutating func parse(allowing allowed: Set<String> = []) throws(CLIUsageError) {
            while !arguments.isEmpty {
                let argument = arguments.removeFirst()
                guard argument.hasPrefix("-") else {
                    positionals.append(argument)
                    continue
                }
                guard argument == "--json" || allowed.contains(argument) else {
                    throw CLIUsageError("Unknown option for \(command): \(argument)")
                }
                switch argument {
                case "--json": json = true
                case "--wait": wait = true
                case "--yes": yes = true
                case "--days":
                    guard let value = arguments.first, let number = Int(value), (1...120).contains(number) else {
                        throw CLIUsageError("--days needs a number of days from 1 to 120, like --days 30.")
                    }
                    arguments.removeFirst()
                    days = number
                default: break
                }
            }
        }

        func noPositionals() throws(CLIUsageError) {
            if let extra = positionals.first {
                throw CLIUsageError("\(command) takes no \(extra).")
            }
        }
    }
}

/// Turns the names given to `diskforecast trash` into entries from the cleanup list. Only what's
/// on the list can be moved, so the command can't be used to throw away anything else.
public enum CLITrashTargets {
    public static func entries(
        for targets: [String], in items: [CleanupItem], home: String
    ) throws(CLIUsageError) -> [CleanupEntry] {
        var entries: [CleanupEntry] = []
        for target in targets {
            let path = target == "~" || target.hasPrefix("~/") ? home + target.dropFirst() : target
            let trimmed = path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
            let matched: [(CleanupItem, [CleanupEntry])]
            if let item = items.first(where: { $0.id == target }) {
                matched = [(item, item.entries)]
            } else {
                matched = items.compactMap { item in
                    let found = item.entries.filter { $0.path == trimmed }
                    return found.isEmpty ? nil : (item, found)
                }
            }
            guard !matched.isEmpty else {
                throw CLIUsageError(
                    "\(target) isn't on the cleanup list. Run diskforecast cleanup to see what can go."
                )
            }
            for (item, found) in matched {
                if case .useTool(let tool) = item.action {
                    throw CLIUsageError("\(item.title) is reclaimed with \(tool)'s own command, not the Trash.")
                }
                entries.append(contentsOf: found.filter { !entries.contains($0) })
            }
        }
        return entries
    }
}
