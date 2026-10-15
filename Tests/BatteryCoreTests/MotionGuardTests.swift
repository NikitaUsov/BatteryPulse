import Foundation
import Testing

/// Keeps motion and Liquid Glass within the rules in CLAUDE.md, for code that only compiles on
/// macOS.
///
/// Scans `Sources/BatteryPulseApp` and `Sources/BatteryPulseWidget` with comments and string
/// literals blanked out. It fails on:
/// - continuous animation: `repeatForever`, `TimelineView(.animation…)`, a phase or keyframe
///   animator without `trigger:`, a symbol effect repeating indefinitely, and an indefinite
///   `symbolEffect` modifier (`isActive:`, or no `value:`);
/// - an `.animation` modifier keyed on the whole snapshot or reading, which changes with every
///   2 s reading;
/// - an animation that doesn't go through `\.motion`: `withAnimation` or `.animation(…)` with an
///   animation of its own (or the default one), which would ignore Reduce Motion and hidden
///   windows. Only `App/Motion.swift`, where the presets are built, is exempt;
/// - any animation in the menu bar label, which is always on screen and renders an image per
///   frame;
/// - `glassEffect(` outside the few files that float controls over content;
/// - a system colour name in the windows' content (`Main/`, the level and Demo Mode tints)
///   outside the tone map's bridge, where it would bypass Clear's monochrome;
/// - a white tint (`.tint(.white)`): macOS draws white labels and knobs on tinted fills, so it
///   would leave white on white; Clear's tint is graphite;
/// - a see-through window background or an appearance override (`containerBackground(…, for:
///   .window)`, visual effect and glass effect views, `materialActiveAppearance`,
///   `preferredColorScheme`, assigning `.appearance`) outside `App/WindowLook.swift`, and any
///   animation in that file: the window style's background never animates.
@Suite struct MotionGuardTests {
    private static let sources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources")

    /// Paths relative to `Sources/`.
    static let glassAllowList: Set<String> = [
        // The floating Demo Mode bar.
        "BatteryPulseApp/Main/DemoView.swift",
        // The glass selection of the preview tile pickers (icon style, window style).
        "BatteryPulseApp/Settings/SettingsView.swift",
        // The glass sheet of Translucent and Clear: one behind the whole window.
        "BatteryPulseApp/App/WindowLook.swift",
    ]

    static let menuBarLabelFiles: Set<String> = [
        "BatteryPulseApp/MenuBar/MenuBarLabel.swift",
        "BatteryPulseApp/MenuBar/BatteryIconView.swift",
    ]

    /// Where the `\.motion` presets are built from concrete animations.
    static let motionPresetFiles: Set<String> = ["BatteryPulseApp/App/Motion.swift"]

    /// The one file that changes a window's background or appearance: the window style.
    static let windowLookFile = "BatteryPulseApp/App/WindowLook.swift"

    /// The one file in the app's content that maps tone roles to system colours.
    static let toneMapBridge = "BatteryPulseApp/App/ToneStyle.swift"

    /// Files whose colours must go through the tone map: the main and compact windows' content,
    /// the level tints and Demo Mode's step tints. Settings, the menu bar and the widget keep the
    /// system's colours in every window style.
    static func colorsGoThroughTheToneMap(_ path: String) -> Bool {
        path.hasPrefix("BatteryPulseApp/Main/") || path == "BatteryPulseApp/App/Localized.swift"
            || path == "BatteryPulseApp/App/DemoController.swift"
    }

    /// Values that change on almost every reading; animations key on `BatteryMotionKey` instead.
    static let liveValues: Set<String> = [
        "snapshot", "monitor.snapshot", "monitor.reading", "reading",
        // An iPhone's or iPad's entry and battery change with every read.
        "battery", "entry.battery", "entry", "monitor.entries", "devices.entries",
    ]

    // MARK: Rules

    /// `\b` as in most regex engines: Swift's default (Unicode) word boundaries see no boundary
    /// in `view.glassEffect`.
    private static func words(_ regex: Regex<Substring>) -> Regex<Substring> {
        regex.wordBoundaryKind(.simple)
    }

    /// `.repeat(.continuous)`, `.repeat(.periodic)` or `.periodic(delay:)` without a count,
    /// `.repeat(nil)` and `.repeating`.
    private static var indefiniteRepeat: Regex<Substring> {
        words(
            #/\.repeat\s*\(\s*(?:\.continuous\b|\.periodic\s*(?:\)|\(\s*(?:\)|delay\s*:|nil\b))|nil\s*\))|\.repeating\b/#
        )
    }

    /// A system colour by name (`.orange`, `Color.green`, `.accentColor`), or the tint as a style
    /// (`.foregroundStyle(.tint)`, which is Clear's graphite, not white). Whole words only, so
    /// `capture.redacted` and `.grayscale(1)` don't count.
    private static var systemColor: Regex<Substring> {
        words(
            #/\.(?:green|orange|red|teal|blue|gray|yellow|mint|cyan|indigo|purple|pink|brown|accentColor)\b|\(\s*\.tint\s*[,)]/#
        )
    }

    /// APIs that make a window see-through or change its appearance; `containerBackground(…,
    /// for: .window)` is checked by its arguments, so the widget's own background stays allowed.
    private static var windowBackgroundAPI: Regex<Substring> {
        words(
            #/\bNSVisualEffectView\b|\bNSGlassEffectView\b|\bmaterialActiveAppearance\s*\(|\bpreferredColorScheme\s*\(|\.appearance\s*=(?!=)/#
        )
    }

    /// Phase and keyframe animators, as views or modifiers; without `trigger:` they loop.
    private static var animator: Regex<Substring> {
        words(#/\b(?:PhaseAnimator|phaseAnimator|KeyframeAnimator|keyframeAnimator)/#)
    }

    /// Whether an animation argument goes through `\.motion`: a preset (`motion.change`, maybe
    /// delayed or picked by a condition) or no animation at all.
    static func goesThroughMotion(_ argument: String) -> Bool {
        argument == "nil" || argument.contains(words(#/\bmotion\s*\./#))
    }

    /// Every rule broken in `source`, as "path:line: message".
    static func violations(in source: String, path: String) -> [String] {
        let code = codeOnly(source)
        var found: [(String.Index, String)] = []
        func flag(_ index: String.Index, _ message: String) { found.append((index, message)) }

        for match in code.matches(of: #/repeatForever/#) {
            flag(match.range.lowerBound, "repeatForever animates without end")
        }
        for match in code.matches(of: words(#/TimelineView\s*\(\s*\.animation\b/#)) {
            flag(match.range.lowerBound, "TimelineView(.animation) redraws every frame")
        }
        for match in code.matches(of: indefiniteRepeat) {
            flag(match.range.lowerBound, "a symbol effect that repeats indefinitely")
        }
        for call in calls(named: animator, in: code) where !call.arguments.contains(words(#/\btrigger\s*:/#)) {
            flag(call.start, "\(call.name) without trigger: loops continuously")
        }
        for call in calls(named: #/\.symbolEffect/#, in: code) where call.isModifier {
            if call.arguments.contains(words(#/\bisActive\s*:/#)) {
                flag(call.start, "symbolEffect(_:isActive:) runs until removed; use symbolEffect(_:value:)")
            } else if !call.arguments.contains(words(#/\bvalue\s*:/#)) {
                flag(call.start, "symbolEffect without value: runs indefinitely; use symbolEffect(_:value:)")
            }
        }
        let buildsPresets = motionPresetFiles.contains(path)
        if !buildsPresets {
            for call in calls(named: words(#/\bwithAnimation/#), in: code)
            where !goesThroughMotion(call.firstArgument) {
                flag(call.start, "withAnimation with an animation of its own; use a \\.motion preset")
            }
            for match in code.matches(of: words(#/\bwithAnimation\s*\{/#)) {
                flag(match.range.lowerBound, "withAnimation with the default animation; use a \\.motion preset")
            }
        }
        for call in calls(named: #/\.animation/#, in: code) where call.isModifier {
            if !buildsPresets, !goesThroughMotion(call.firstArgument) {
                flag(call.start, ".animation with an animation of its own; use a \\.motion preset")
            }
            guard let value = call.argument(labeled: "value") else { continue }
            let normalized = value.replacing(#/\s+/#, with: "").replacing(#/^self\./#, with: "")
                .replacing(#/[?!]+$/#, with: "")
            if liveValues.contains(normalized) {
                flag(call.start, ".animation keyed on \(value), which changes with every reading")
            }
        }
        if menuBarLabelFiles.contains(path) {
            for match in code.matches(of: words(#/\bwithAnimation\b|\.animation\s*\(/#)) {
                flag(match.range.lowerBound, "no animation in the menu bar label")
            }
        }
        if !glassAllowList.contains(path) {
            for match in code.matches(of: words(#/\bglassEffect\s*\(/#)) {
                flag(match.range.lowerBound, "glassEffect outside the floating controls (see CLAUDE.md)")
            }
        }
        if path == windowLookFile {
            for match in code.matches(
                of: words(#/\bglassEffectID\b|\bglassEffectTransition\b|\.interactive\s*\(|\bwithAnimation\b/#))
            {
                flag(match.range.lowerBound, "the window background never animates or reacts")
            }
        } else {
            for match in code.matches(of: windowBackgroundAPI) {
                flag(match.range.lowerBound, "a window background or appearance outside App/WindowLook.swift")
            }
            for call in calls(named: words(#/\bcontainerBackground/#), in: code)
            where call.arguments.contains(words(#/\bfor\s*:\s*\.window\b/#)) {
                flag(call.start, "a window background outside App/WindowLook.swift")
            }
        }
        for match in code.matches(of: words(#/\.tint\s*\(\s*(?:Color\s*)?\.white\b/#)) {
            flag(match.range.lowerBound, "a white tint hides white labels on tinted controls")
        }
        if colorsGoThroughTheToneMap(path) {
            for match in code.matches(of: systemColor) {
                flag(match.range.lowerBound, "a system colour bypasses the tone map; ask `tones` for a role")
            }
        }

        return found.sorted { $0.0 < $1.0 }.map { index, message in
            let line = code[..<index].reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
            return "\(path):\(line): \(message)"
        }
    }

    // MARK: Scanning

    struct Call {
        var name: String
        var start: String.Index
        /// Text between the parentheses.
        var arguments: Substring
        /// Applied to a view (`view.symbolEffect(…)`), not an implicit member such as
        /// `.contentTransition(.symbolEffect(.replace))` or `case .animation(let a):`.
        var isModifier: Bool

        /// The top-level arguments, trimmed.
        var topLevelArguments: [String] {
            var depth = 0
            var piece = ""
            var pieces: [String] = []
            for character in arguments {
                switch character {
                case "(", "[", "{": depth += 1
                case ")", "]", "}": depth -= 1
                case "," where depth == 0:
                    pieces.append(piece)
                    piece = ""
                    continue
                default: break
                }
                piece.append(character)
            }
            pieces.append(piece)
            return pieces.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        /// The first argument's expression, whatever its label.
        var firstArgument: String {
            topLevelArguments.first ?? ""
        }

        /// The expression of a top-level argument with this label.
        func argument(labeled label: String) -> String? {
            for piece in topLevelArguments {
                guard piece.hasPrefix(label) else { continue }
                let rest = piece.dropFirst(label.count).drop { $0 == " " }
                if rest.first == ":" { return rest.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            return nil
        }
    }

    /// Calls of `name` followed by `(`, with their balanced argument text.
    static func calls(named name: Regex<Substring>, in code: String) -> [Call] {
        var result: [Call] = []
        for match in code.matches(of: name) {
            var index = match.range.upperBound
            while index < code.endIndex, code[index] == " " { index = code.index(after: index) }
            guard index < code.endIndex, code[index] == "(" else { continue }
            let open = code.index(after: index)
            var depth = 1
            var cursor = open
            while cursor < code.endIndex, depth > 0 {
                if code[cursor] == "(" { depth += 1 }
                if code[cursor] == ")" { depth -= 1 }
                cursor = code.index(after: cursor)
            }
            guard depth == 0 else { continue }
            let close = code.index(before: cursor)
            result.append(
                Call(
                    name: String(code[match.range]).trimmingCharacters(in: .punctuationCharacters),
                    start: match.range.lowerBound,
                    arguments: code[open..<close],
                    isModifier: isModifier(dotAt: match.range.lowerBound, in: code)))
        }
        return result
    }

    /// Whether the member access at `dot` continues an expression (a modifier) rather than
    /// starting an implicit member expression.
    static func isModifier(dotAt dot: String.Index, in code: String) -> Bool {
        guard code[dot] == "." else { return false }
        var index = dot
        var sawSpace = false
        while index > code.startIndex {
            index = code.index(before: index)
            let character = code[index]
            if character.isWhitespace {
                sawSpace = true
                continue
            }
            switch character {
            case ")", "]", "}", "\"": return true
            // `view?.symbolEffect(…)` against `flag ? .symbolEffect(…) : …`.
            case "?", "!": return !sawSpace
            default:
                guard character.isLetter || character.isNumber || character == "_" else { return false }
                var start = index
                while start > code.startIndex {
                    let previous = code.index(before: start)
                    let c = code[previous]
                    guard c.isLetter || c.isNumber || c == "_" else { break }
                    start = previous
                }
                let word = code[start...index]
                let keywords: Set<Substring> = ["return", "case", "in", "else", "try", "await", "then", "some", "any"]
                // `Transition.symbolEffect(…)` is a static member of a type, not a modifier.
                return !keywords.contains(word) && !(word.first?.isUppercase ?? false)
            }
        }
        return false
    }

    /// `source` with comments and the contents of string literals replaced by spaces; line breaks
    /// and the quotes themselves stay, so positions and line numbers match the original.
    static func codeOnly(_ source: String) -> String {
        let characters = Array(source)
        var output = characters
        var index = 0
        func blank(_ range: Range<Int>) {
            for i in range where characters[i] != "\n" { output[i] = " " }
        }
        func starts(with prefix: String, at i: Int) -> Bool {
            let p = Array(prefix)
            return i + p.count <= characters.count && Array(characters[i..<(i + p.count)]) == p
        }
        while index < characters.count {
            if starts(with: "//", at: index) {
                var end = index
                while end < characters.count, characters[end] != "\n" { end += 1 }
                blank(index..<end)
                index = end
            } else if starts(with: "/*", at: index) {
                var depth = 0
                var end = index
                repeat {
                    if starts(with: "/*", at: end) {
                        depth += 1
                        end += 2
                    } else if starts(with: "*/", at: end) {
                        depth -= 1
                        end += 2
                    } else {
                        end += 1
                    }
                } while depth > 0 && end < characters.count
                blank(index..<min(end, characters.count))
                index = end
            } else if characters[index] == "\"" || (characters[index] == "#" && starts(with: "#\"", at: index)) {
                var hashes = 0
                var open = index
                while characters[open] == "#" {
                    hashes += 1
                    open += 1
                }
                let isMultiline = starts(with: "\"\"\"", at: open)
                let quote = isMultiline ? "\"\"\"" : "\""
                let closing = quote + String(repeating: "#", count: hashes)
                var end = open + quote.count
                while end < characters.count, !starts(with: closing, at: end) {
                    if hashes == 0, characters[end] == "\\" { end += 1 }
                    if !isMultiline, characters[end] == "\n" { break }
                    end += 1
                }
                let contentEnd = min(end, characters.count)
                blank((open + quote.count)..<contentEnd)
                index = min(contentEnd + closing.count, characters.count)
            } else {
                index += 1
            }
        }
        return String(output)
    }

    // MARK: Tests

    @Test func appAndWidgetFollowTheMotionRules() throws {
        var violations: [String] = []
        var scanned = 0
        for target in ["BatteryPulseApp", "BatteryPulseWidget"] {
            let directory = Self.sources.appendingPathComponent(target)
            let enumerator = try #require(
                FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil))
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                let components = url.standardizedFileURL.pathComponents
                let sourcesIndex = try #require(components.lastIndex(of: "Sources"))
                let path = components[(sourcesIndex + 1)...].joined(separator: "/")
                violations += Self.violations(in: try String(contentsOf: url, encoding: .utf8), path: path)
                scanned += 1
            }
        }
        #expect(scanned > 20)
        #expect(violations.isEmpty, "\(violations.joined(separator: "\n"))")
    }

    @Test func allowListedFilesExist() {
        let lists = Self.glassAllowList.union(Self.menuBarLabelFiles).union(Self.motionPresetFiles)
        for path in lists.union([Self.toneMapBridge, Self.windowLookFile]) {
            #expect(FileManager.default.fileExists(atPath: Self.sources.appendingPathComponent(path).path), "\(path)")
        }
    }

    private static let somewhere = "BatteryPulseApp/Main/OverviewView.swift"

    private func flags(_ source: String, path: String = somewhere) -> Bool {
        !Self.violations(in: source, path: path).isEmpty
    }

    @Test(arguments: [
        "Circle().animation(.linear.repeatForever(), value: on)",
        "TimelineView(.animation) { _ in Canvas { _, _ in } }",
        "TimelineView( .animation(minimumInterval: 1, paused: false)) { _ in }",
        "PhaseAnimator([0, 1]) { phase in Text(\"x\") }",
        "view.phaseAnimator([0, 1]) { content, phase in content }",
        "KeyframeAnimator(initialValue: 0, repeating: true) { v in Text(\"x\") } keyframes: { _ in }",
        "view.keyframeAnimator(initialValue: 0) { c, v in c } keyframes: { _ in }",
        "Image(systemName: \"bolt\").symbolEffect(.pulse, options: .repeat(.continuous), value: n)",
        "Image(systemName: \"bolt\").symbolEffect(.pulse, options: .repeating, value: n)",
        "Image(systemName: \"bolt\").symbolEffect(.pulse, options: .repeat(.periodic), value: n)",
        "Image(systemName: \"bolt\").symbolEffect(.pulse, options: .repeat(.periodic(delay: 1)), value: n)",
        "Image(systemName: \"bolt\").symbolEffect(.breathe, isActive: charging)",
        "Image(systemName: \"bolt\")\n    .symbolEffect(.pulse)",
        "Text(\"x\").animation(.smooth, value: snapshot)",
        "Text(\"x\").animation(motion.change, value: monitor.snapshot)",
        "Text(\"x\").animation(motion.change, value: self.monitor.reading)",
        "Text(\"x\").animation(motion.change, value: reading)",
        "Card { }.glassEffect(.regular, in: .capsule)",
        // Animations that bypass `\.motion`, and so Reduce Motion.
        "withAnimation(.smooth) { on.toggle() }",
        "withAnimation(.linear(duration: 0.2)) { provider.battery = next }",
        "withAnimation { on.toggle() }",
        "withAnimation(Self.change) { step = next }",
        "Text(\"x\").animation(.smooth(duration: 0.35), value: key.isPluggedIn)",
        "Text(\"x\").animation(.smooth) { $0.opacity(on ? 1 : 0) }",
        "Text(\"x\").transition(.opacity.animation(.easeInOut))",
        "HStack { }\n    .animation(.default, value: showsAdapter)",
    ])
    func catches(source: String) {
        #expect(flags(source), "\(source)")
    }

    @Test(arguments: [
        "Text(\"x\").animation(motion.change, value: key.isPluggedIn)",
        "Text(\"x\").animation(motion.numbers, value: snapshot.chargePercent)",
        "Text(\"x\").animation(motion.crossfade) { $0.opacity(on ? 1 : 0) }",
        "Text(\"x\").animation(motion.change, body: { $0 })",
        "Text(\"x\").animation(nil, value: key.isPluggedIn)",
        "Text(\"x\").animation(entrance.plays ? motion.change?.delay(0.04) : nil, value: hasEntered)",
        "Text(\"x\").transition(.opacity.animation(motion.quickFade))",
        "withAnimation(motion.linear(0.2)) { provider.battery = next }",
        "withAnimation(motion.change, apply)",
        "withAnimation(motion.crossfade) { copied = true }",
        "DemoStepRow(step: .animation(animation))",
        "case .animation(let animation): animation.title",
        "(.animation(.chargeFromEmpty), .overview)",
        "PhaseAnimator([0, 1], trigger: count) { phase in Text(\"x\") }",
        "view.keyframeAnimator(initialValue: 0, trigger: n) { c, v in c } keyframes: { _ in }",
        "Image(systemName: \"bolt\").symbolEffect(.bounce, options: .nonRepeating, value: fullCount)",
        "Image(systemName: \"bolt\").symbolEffect(.bounce, options: .repeat(2), value: n)",
        "Image(systemName: \"bolt\").symbolEffect(.pulse, options: .repeat(.periodic(2, delay: 1)), value: n)",
        "Image(systemName: \"x\").contentTransition(.symbolEffect(.replace))",
        "image.transition(.symbolEffect(.drawOn))",
        "var symbolSwap: ContentTransition { level == .full ? .symbolEffect(.replace) : .opacity }",
        "var swap: ContentTransition {\n    switch level {\n    case .full: .symbolEffect(.replace)\n    default: .identity\n    }\n}",
        "AnyTransition(SymbolEffectTransition.symbolEffect(.drawOn))",
        "Text(\"repeatForever and glassEffect(.regular) are only words here\")",
        "// TimelineView(.animation) and .symbolEffect(.pulse) in a comment",
        "/* withAnimation { glassEffect() } */ let x = 1",
        "Text(\"\"\"\n  .animation(.smooth, value: snapshot)\n  \"\"\")",
        "Text(#\"a \"quoted\" .animation(.smooth)\"#)",
        "GlassEffectContainer { bar.glassEffectID(\"bar\", in: ns) }",
    ])
    func allows(source: String) {
        #expect(!flags(source), "\(Self.violations(in: source, path: Self.somewhere))")
    }

    @Test func glassIsAllowedOnlyInTheListedFiles() {
        let glass = "bar.glassEffect(.regular.interactive(), in: .capsule)"
        #expect(!flags(glass, path: "BatteryPulseApp/Main/DemoView.swift"))
        // Content is never glass: the cards' "Glass Cards" option is gone.
        #expect(flags(glass, path: "BatteryPulseApp/Main/Components.swift"))
        #expect(!flags(glass, path: "BatteryPulseApp/Settings/SettingsView.swift"))
        // The window's glass sheet: allowed, but never interactive (`windowBackgroundNeverAnimates`).
        let sheet = "Rectangle().fill(.clear).glassEffect(Glass.clear.tint(tint), in: .rect)"
        #expect(!flags(sheet, path: "BatteryPulseApp/App/WindowLook.swift"))
        #expect(flags(sheet, path: "BatteryPulseApp/Main/OverviewView.swift"))
        #expect(flags(glass, path: "BatteryPulseApp/Main/CompactView.swift"))
        #expect(flags(glass, path: "BatteryPulseWidget/BatteryPulseWidget.swift"))
    }

    @Test(arguments: [
        "Text(\"x\").foregroundStyle(.orange)",
        "ProgressView(value: 1).tint(Color.green)",
        "case .normal: .green",
        "Image(systemName: \"checkmark\").foregroundStyle(.tint)",
        "Image(systemName: \"x\").foregroundStyle(.accentColor)",
        "RingGaugeStyle(tint: .blue)",
        "LineMark(x: x, y: y).foregroundStyle(.red.opacity(0.5))",
        "Label(\"Demo\", systemImage: \"x\").foregroundStyle(.tint, .secondary)",
    ])
    func systemColorsOnlyInTheToneMap(source: String) {
        #expect(flags(source, path: "BatteryPulseApp/Main/OverviewView.swift"), "\(source)")
        #expect(flags(source, path: "BatteryPulseApp/App/DemoController.swift"), "\(source)")
        #expect(!flags(source, path: Self.toneMapBridge), "\(source)")
        #expect(!flags(source, path: "BatteryPulseApp/MenuBar/PopoverView.swift"), "\(source)")
        #expect(!flags(source, path: "BatteryPulseApp/Settings/SettingsView.swift"), "\(source)")
    }

    @Test(arguments: [
        "text = IDeviceReport.text(for: capture.redacted)",
        "Image(systemName: \"x\").grayscale(1)",
        "@Environment(\\.redactionReasons) private var reasons",
        "bolt.foregroundStyle(.white)",
        "ProgressView(value: 1).tint(tones.color(.capacity(bar.kind)))",
        "Text(\"green, .orange and .tint in a string\")",
        "// .orange in a comment",
        "let tint = tones.color(.cycles)",
        "Text(\"x\").foregroundStyle(tones.style(.accent))",
    ])
    func toneMapGuardAllows(source: String) {
        #expect(!flags(source, path: "BatteryPulseApp/Main/DeviceView.swift"), "\(source)")
    }

    @Test(arguments: [
        "content.containerBackground(.regularMaterial, for: .window)",
        "content.containerBackground(for: .window) { GlassSheet(tint: nil) }",
        "let view = NSVisualEffectView()",
        "let glass = NSGlassEffectView()",
        "content.containerBackground(Material.regular.materialActiveAppearance(.active), for: .widget)",
        "Text(\"x\").preferredColorScheme(.dark)",
        "window.appearance = NSAppearance(named: .darkAqua)",
        "window?.appearance = nil",
    ])
    func windowLookAPIsOnlyInWindowLook(source: String) {
        #expect(flags(source, path: "BatteryPulseApp/Main/OverviewView.swift"), "\(source)")
        #expect(flags(source, path: "BatteryPulseApp/Settings/SettingsView.swift"), "\(source)")
        #expect(!flags(source, path: Self.windowLookFile), "\(source)")
    }

    @Test func whiteIsNeverATint() {
        for path in ["BatteryPulseApp/App/WindowLook.swift", "BatteryPulseApp/Settings/SettingsView.swift"] {
            #expect(flags("content.tint(.white)", path: path))
            #expect(flags("content.tint(Color.white)", path: path))
            #expect(flags("content.tint( .white.opacity(0.9))", path: path))
        }
        #expect(!flags("content.tint(policy.tones.controlTintColor)", path: "BatteryPulseApp/App/WindowLook.swift"))
        #expect(!flags("bolt.foregroundStyle(.white)", path: "BatteryPulseApp/Main/Components.swift"))
    }

    @Test func windowLookGuardAllows() {
        // The widget's own container background, and reading an appearance.
        #expect(
            !flags(
                "view.containerBackground(.fill.tertiary, for: .widget)",
                path: "BatteryPulseWidget/BatteryPulseWidget.swift"))
        #expect(
            !flags(
                "let isDark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua",
                path: "BatteryPulseApp/MenuBar/BatteryIconView.swift"))
        #expect(!flags("if window.appearance == nil { return }"))
        #expect(!flags("Text(\"preferredColorScheme(.dark) in a string\")"))
    }

    @Test(arguments: [
        "withAnimation(motion.change) { look = next }",
        "sheet.glassEffectID(\"sheet\", in: namespace)",
        "sheet.glassEffectTransition(.materialize)",
        "sheet.glassEffect(Glass.clear.interactive(), in: .rect)",
    ])
    func windowBackgroundNeverAnimates(source: String) {
        #expect(flags(source, path: Self.windowLookFile), "\(source)")
    }

    /// A window style change rebuilds what `.windowLook()` wraps, which would run the appear and
    /// disappear actions of the window's registrations (live refresh, the Dock icon policy) in an
    /// undefined order. They sit outside it: after it in its modifier chain, never in a view it
    /// wraps.
    @Test func windowRegistrationsStayOutsideTheWindowLook() throws {
        func code(_ path: String) throws -> String {
            Self.codeOnly(try String(contentsOf: Self.sources.appendingPathComponent(path), encoding: .utf8))
        }
        let registration = #/\.(?:liveRefresh|trackedWindow)\s*\(/#
        let look = #/\.windowLook\s*\(\s*\)/#
        // The main window applies the style in MainView, above its registrations; the compact
        // window in the scene, with its registrations after it.
        for path in ["BatteryPulseApp/Main/MainView.swift", "BatteryPulseApp/App/BatteryPulseApp.swift"] {
            let source = try code(path)
            let looks = source.matches(of: look)
            #expect(looks.count == 1, "\(path)")
            let start = try #require(looks.first).range.upperBound
            for match in source.matches(of: registration) {
                #expect(match.range.lowerBound > start, "\(path)")
            }
        }
        // The compact window's root view is inside the style, so it registers nothing itself.
        let compact = try code("BatteryPulseApp/Main/CompactView.swift")
        #expect(compact.firstMatch(of: registration) == nil)
        #expect(compact.firstMatch(of: look) == nil)
    }

    @Test func menuBarLabelNeverAnimates() {
        let path = "BatteryPulseApp/MenuBar/MenuBarLabel.swift"
        #expect(flags("withAnimation(motion.change) { on.toggle() }", path: path))
        #expect(flags("Text(\"x\").animation(motion.change, value: key)", path: path))
        #expect(!flags("withAnimation(motion.change) { on.toggle() }", path: "BatteryPulseApp/Main/DemoView.swift"))
        // Explaining the rule in a comment is fine.
        #expect(!flags("// No withAnimation here: every frame renders an image.", path: path))
    }

    /// The presets themselves are built from concrete animations, in one file only.
    @Test func onlyThePresetsBuildAnimations() {
        let preset = "var fadeTransition: AnyTransition { AnyTransition.opacity.animation(crossfade) }"
        #expect(!flags(preset, path: "BatteryPulseApp/App/Motion.swift"))
        #expect(flags(preset, path: "BatteryPulseApp/Main/DemoView.swift"))
        let modifier = "content.animation(.smooth(duration: 0.25), value: rounded)"
        #expect(!flags(modifier, path: "BatteryPulseApp/App/Motion.swift"))
        #expect(flags(modifier, path: "BatteryPulseApp/App/DemoController.swift"))
        // The presets file still follows the other rules.
        #expect(flags("content.animation(motion.change, value: snapshot)", path: "BatteryPulseApp/App/Motion.swift"))
    }

    @Test func reportsLineNumbers() {
        let source =
            "let a = 1\n// .animation(.smooth, value: snapshot)\nText(\"x\")\n    .animation(motion.change, value: snapshot)\n"
        let violations = Self.violations(in: source, path: "X.swift")
        #expect(violations.count == 1)
        #expect(violations.first?.hasPrefix("X.swift:4: ") == true)
    }
}
