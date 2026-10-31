import Foundation
import Testing

/// Keeps motion and Liquid Glass within the rules in CLAUDE.md, for code that only compiles on
/// macOS.
///
/// Scans `Sources/BatteryPulseApp`, `Sources/BatteryPulseWidget` and `Sources/BatteryArt` with
/// comments and string literals blanked out. It fails on:
/// - continuous animation: `repeatForever`, `TimelineView(.animation…)`, a phase or keyframe
///   animator without `trigger:`, a symbol effect repeating indefinitely, and an indefinite
///   `symbolEffect` modifier (`isActive:`, or no `value:`);
/// - an `.animation` modifier keyed on the whole snapshot or reading, which changes with every
///   2 s reading;
/// - an animation that doesn't go through `\.motion`: `withAnimation` or `.animation(…)` with an
///   animation of its own (or the default one), which would ignore Reduce Motion and hidden
///   windows. Only `App/Motion.swift`, where the presets are built, is exempt;
/// - an animation built outside `App/Motion.swift` (`Animation.…`, `.smooth(…)`, `.linear(…)` and
///   the other constructors), even one gated by hand: every timing is a preset there;
/// - any animation in the menu bar label, which is always on screen and renders an image per
///   frame;
/// - `glassEffect(` outside the few files that float controls over content;
/// - a material in `Main/` (`Material`, `.regularMaterial`, `.bar`) outside the History chart's
///   readout: content stays free of glass and materials;
/// - a system colour name in the windows' content (`Main/`, the level and Demo Mode tints)
///   outside the tone map's bridge, where it would bypass Clear's monochrome, and there a colour
///   read as a property (`tier.color`), which comes from the standard tones, not the window's;
/// - a white tint (`.tint(.white)`): macOS draws white labels and knobs on tinted fills, so it
///   would leave white on white; Clear's tint is graphite;
/// - a see-through window background or an appearance override (`containerBackground(…, for:
///   .window)`, visual effect and glass effect views, `materialActiveAppearance`,
///   `preferredColorScheme`, assigning `.appearance`) outside `App/WindowLook.swift`, and any
///   animation in that file: the window style's background never animates;
/// - in the widget, time the system updates that would show seconds, a sign or a per-second
///   countdown: `TimelineView(.periodic…)` and `TimelineView(.everyMinute)`, `Text(…, style:)`
///   with `.timer`, `.relative` or `.offset`, `Text(timerInterval:…)` and
///   `ProgressView(timerInterval:…)`, and the timer, stopwatch and reference format styles
///   (https://developer.apple.com/documentation/widgetkit/displaying-dynamic-dates). The one
///   self-updating text is the time label's offset (``widgetTimeTextFile``), which allows no
///   `.second` and passes `sign: .never`: the default sign puts a minus before an end in the
///   future (REJ-62).
@Suite struct MotionGuardTests {
    /// Paths relative to `Sources/`.
    static let glassAllowList: Set<String> = [
        // The floating Demo Mode bar.
        "BatteryPulseApp/Main/DemoView.swift",
        // The glass sheet of Translucent and Clear: one behind the whole window.
        "BatteryPulseApp/App/WindowLook.swift",
    ]

    /// Files in `Main/` that may use a material.
    static let materialAllowList: Set<String> = [
        // The History chart's hover readout floats over the plot and must read on every window
        // style; on the glass sheets a card's surface didn't (the 0.6.1 M5 session).
        "BatteryPulseApp/Main/History/HistoryChartParts.swift"
    ]

    static let menuBarLabelFiles: Set<String> = [
        "BatteryPulseApp/MenuBar/MenuBarLabel.swift",
        "BatteryPulseApp/MenuBar/BatteryIconView.swift",
        // The painter, shared with the widget: the icon it draws is the menu bar label's.
        "BatteryArt/BatteryIconPainter.swift",
    ]

    /// Where the `\.motion` presets are built from concrete animations.
    static let motionPresetFiles: Set<String> = ["BatteryPulseApp/App/Motion.swift"]

    /// The one file that changes a window's background or appearance: the window style.
    static let windowLookFile = "BatteryPulseApp/App/WindowLook.swift"

    /// The one file in the app's content that maps tone roles to system colours.
    static let toneMapBridge = "BatteryPulseApp/App/ToneStyle.swift"

    /// The widget's sources, whose time the system updates between reloads.
    static let widgetFolder = "BatteryPulseWidget/"

    /// The widget's one self-updating text: the time label's time left, which the system counts
    /// down by the minute without a reload.
    static let widgetTimeTextFile = "BatteryPulseWidget/WidgetDetailViews.swift"

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

    /// A colour read as a property (`tier.color`, `levelTier(for: s).color`): a level tier's own
    /// colour comes from the standard tones and stays green or orange in Clear. Calls such as
    /// `tones.color(.level(tier))` or a context's `.color(ink)` shading don't count.
    private static var standardToneColor: Regex<Substring> {
        words(#/\.color\b(?!\s*\()/#)
    }

    /// A material by name (`Material.thin`, `.ultraThinMaterial`, `.bar` as a style); a
    /// `.materialize` transition doesn't count.
    private static var material: Regex<Substring> {
        words(
            #/\bMaterial\b|\b(?:ultraThin|thin|regular|thick|ultraThick)Material\b|\bbackgroundMaterial\b|\(\s*\.bar\s*[,)]/#
        )
    }

    /// APIs that make a window see-through or change its appearance; `containerBackground(…,
    /// for: .window)` is checked by its arguments, so the widget's own background stays allowed.
    private static var windowBackgroundAPI: Regex<Substring> {
        words(
            #/\bNSVisualEffectView\b|\bNSGlassEffectView\b|\bmaterialActiveAppearance\s*\(|\bpreferredColorScheme\s*\(|\.appearance\s*=(?!=)/#
        )
    }

    /// An animation built from its parts: `Animation.smooth`, or a constructor such as
    /// `.smooth(duration:)`. `\bAnimation` needs its word boundary, so `DemoAnimation.allCases`
    /// doesn't count; `.linear` without a call is a progress view style.
    private static var animationConstructor: Regex<Substring> {
        words(
            #/\bAnimation\s*\.|\.(?:smooth|snappy|bouncy|spring|interactiveSpring|interpolatingSpring|easeIn|easeOut|easeInOut|linear|timingCurve)\s*\(/#
        )
    }

    /// Text that every ``animationConstructor`` match holds, so a file without any skips it: a
    /// `Regex` is slow on Linux.
    static let animationLiterals = [
        "Animation", ".smooth", ".snappy", ".bouncy", ".spring", ".interactiveSpring", ".interpolatingSpring",
        ".easeIn", ".easeOut", ".linear", ".timingCurve",
    ]

    /// The identifier that ends right before `index`, such as `motion` in `motion.linear(`.
    private static func identifier(before index: String.Index, in code: String) -> String {
        String(code[..<index].reversed().prefix { $0.isLetter || $0.isNumber || $0 == "_" }.reversed())
    }

    /// Time in the widget that shows seconds, a signed offset or a per-second countdown: a
    /// periodic or every-minute timeline, a date's timer, relative or offset style, a timer
    /// interval's text or progress view, and the counting and reference format styles.
    private static var widgetCountdown: Regex<Substring> {
        words(
            #/\bTimelineView\s*\(\s*(?:\.periodic|\.everyMinute|PeriodicTimelineSchedule|EveryMinuteTimelineSchedule)\b|\bstyle\s*:\s*\.(?:timer|relative|offset)\b|\btimerInterval\s*:|\.(?:timer|stopwatch|reference)\s*\(\s*(?:countingDownIn|countingUpIn|startingAt|to)\s*:/#
        )
    }

    /// A date offset format, `.offset(to:…)`; the `.offset(x:y:)` modifier and an `\.offset` key
    /// path don't count.
    private static var dateOffset: Regex<Substring> {
        words(#/\.offset\s*\(\s*to\s*:/#)
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
        violations(inCode: SourceScanner.codeOnly(source), path: path)
    }

    /// Every rule broken in `code`, a source already blanked by ``SourceScanner/codeOnly(_:)``.
    static func violations(inCode code: String, path: String) -> [String] {
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
        for call in SourceScanner.calls(named: animator, in: code)
        where !call.arguments.contains(words(#/\btrigger\s*:/#)) {
            flag(call.start, "\(call.name) without trigger: loops continuously")
        }
        for call in SourceScanner.calls(named: #/\.symbolEffect/#, in: code) where call.isModifier {
            if call.arguments.contains(words(#/\bisActive\s*:/#)) {
                flag(call.start, "symbolEffect(_:isActive:) runs until removed; use symbolEffect(_:value:)")
            } else if !call.arguments.contains(words(#/\bvalue\s*:/#)) {
                flag(call.start, "symbolEffect without value: runs indefinitely; use symbolEffect(_:value:)")
            }
        }
        let buildsPresets = motionPresetFiles.contains(path)
        if !buildsPresets {
            for call in SourceScanner.calls(named: words(#/\bwithAnimation/#), in: code)
            where !goesThroughMotion(call.firstArgument) {
                flag(call.start, "withAnimation with an animation of its own; use a \\.motion preset")
            }
            for match in code.matches(of: words(#/\bwithAnimation\s*\{/#)) {
                flag(match.range.lowerBound, "withAnimation with the default animation; use a \\.motion preset")
            }
            // `motion.linear(_:)` is the preset, not the constructor.
            let builds = animationLiterals.contains { code.contains($0) }
            for match in builds ? code.matches(of: animationConstructor) : []
            where identifier(before: match.range.lowerBound, in: code) != "motion" {
                flag(match.range.lowerBound, "an animation built outside Motion.swift; add a preset there")
            }
        }
        for call in SourceScanner.calls(named: #/\.animation/#, in: code) where call.isModifier {
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
        // Every match holds `Material` or `.bar`; a `Regex` over the other files is slow on Linux.
        if path.hasPrefix("BatteryPulseApp/Main/"), !Self.materialAllowList.contains(path),
            code.contains("Material") || code.contains(".bar")
        {
            for match in code.matches(of: material) {
                flag(match.range.lowerBound, "a material in the windows' content; groups use a Card surface")
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
            for call in SourceScanner.calls(named: words(#/\bcontainerBackground/#), in: code)
            where call.arguments.contains(words(#/\bfor\s*:\s*\.window\b/#)) {
                flag(call.start, "a window background outside App/WindowLook.swift")
            }
        }
        for match in code.matches(of: words(#/\.tint\s*\(\s*(?:Color\s*)?\.white\b/#)) {
            flag(match.range.lowerBound, "a white tint hides white labels on tinted controls")
        }
        if path.hasPrefix(widgetFolder) {
            for match in code.matches(of: widgetCountdown) {
                flag(match.range.lowerBound, "widget time that shows seconds, a sign or a countdown (REJ-62)")
            }
            if path != widgetTimeTextFile {
                for match in code.matches(of: words(#/\.currentDate\b/#)) {
                    flag(match.range.lowerBound, "self-updating text only in the widget's time label")
                }
            }
            for match in code.matches(of: dateOffset) {
                guard
                    let call = SourceScanner.calls(
                        named: words(#/\.offset/#), in: String(code[match.range.lowerBound...])
                    ).first
                else { continue }
                let fields = call.argument(labeled: "allowedFields")
                if fields == nil || fields?.contains(words(#/\.second\b/#)) == true {
                    flag(match.range.lowerBound, "a date offset that may show seconds; allow hours and minutes only")
                }
                if call.argument(labeled: "sign")?.replacing(#/\s+/#, with: "") != ".never" {
                    flag(match.range.lowerBound, "a date offset without sign: .never shows a minus before a later end")
                }
            }
        }
        if colorsGoThroughTheToneMap(path) {
            for match in code.matches(of: systemColor) {
                flag(match.range.lowerBound, "a system colour bypasses the tone map; ask `tones` for a role")
            }
            for match in code.matches(of: standardToneColor) {
                flag(match.range.lowerBound, "a standard colour ignores the window's tones; ask `tones` for a role")
            }
        }

        return found.sorted { $0.0 < $1.0 }.map { index, message in
            let line = code[..<index].reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
            return "\(path):\(line): \(message)"
        }
    }

    // MARK: Tests

    /// One case per file, so a failure names the file and the files are scanned in parallel.
    @Test(arguments: (try? SourceScanner.files.get()) ?? [])
    func appAndWidgetFollowTheMotionRules(_ file: SourceScanner.File) {
        let violations = Self.violations(inCode: file.code, path: file.path)
        #expect(violations.isEmpty, "\(violations.joined(separator: "\n"))")
    }

    /// The file list behind the cases above: readable, and not empty or cut short.
    @Test func scansTheAppAndTheWidget() throws {
        #expect(try SourceScanner.files.get().count > 20)
    }

    @Test func allowListedFilesExist() {
        let lists = Self.glassAllowList.union(Self.menuBarLabelFiles).union(Self.motionPresetFiles)
        for path in lists.union([Self.toneMapBridge, Self.windowLookFile, Self.widgetTimeTextFile]) {
            #expect(
                FileManager.default.fileExists(atPath: SourceScanner.sources.appendingPathComponent(path).path),
                "\(path)")
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
        // Animations built outside the presets, even when gated by hand (CH-01).
        "var drawIn: Animation? { motion.allowsFlourish ? .smooth(duration: 0.8).delay(0.2) : nil }",
        "let fade = Animation.easeInOut(duration: 0.2)",
        "let bounce: Animation = .spring(response: 0.3, dampingFraction: 0.8)",
    ])
    func catches(source: String) {
        #expect(flags(source), "\(source)")
        // Skipping a file without the literals could hide a constructor that has none of them.
        let code = SourceScanner.codeOnly(source)
        if code.contains(Self.animationConstructor) {
            #expect(Self.animationLiterals.contains { code.contains($0) }, "\(source)")
        }
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
        // A type whose name ends in Animation, the preset `motion.linear(_:)`, and a progress
        // view style (CH-01).
        "ForEach(DemoAnimation.allCases) { Text($0.title) }",
        "withAnimation(motion.linear(Self.frame / .seconds(1))) { advance() }",
        "ProgressView(value: 0.5).progressViewStyle(.linear)",
    ])
    func allows(source: String) {
        #expect(!flags(source), "\(Self.violations(in: source, path: Self.somewhere))")
    }

    @Test func glassIsAllowedOnlyInTheListedFiles() {
        let glass = "bar.glassEffect(.regular.interactive(), in: .capsule)"
        #expect(!flags(glass, path: "BatteryPulseApp/Main/DemoView.swift"))
        // Content is never glass: the cards' "Glass Cards" option is gone.
        #expect(flags(glass, path: "BatteryPulseApp/Main/Components/Card.swift"))
        // The tile pickers mark their choice with an accent outline only.
        #expect(flags(glass, path: "BatteryPulseApp/Settings/PreviewTilePicker.swift"))
        // The window's glass sheet: allowed, but never interactive (`windowBackgroundNeverAnimates`).
        let sheet = "Rectangle().fill(.clear).glassEffect(Glass.clear.tint(tint), in: .rect)"
        #expect(!flags(sheet, path: "BatteryPulseApp/App/WindowLook.swift"))
        #expect(flags(sheet, path: "BatteryPulseApp/Main/OverviewView.swift"))
        #expect(flags(glass, path: "BatteryPulseApp/Main/CompactView.swift"))
        #expect(flags(glass, path: "BatteryPulseWidget/BatteryPulseWidget.swift"))
    }

    /// Content has no material of its own; the chart readout is the one exception.
    @Test(arguments: [
        "readout.background(.regularMaterial, in: .rect(cornerRadius: 8))",
        "readout.background(Material.thin)",
        "readout.background(.ultraThinMaterial)",
        "toolbar.background(.bar)",
        "let fill: Material = .thick",
        "content.environment(\\.backgroundMaterial, .regular)",
    ])
    func noMaterialInTheWindowsContent(source: String) {
        #expect(flags(source, path: "BatteryPulseApp/Main/History/HistoryView.swift"), "\(source)")
        #expect(flags(source, path: "BatteryPulseApp/Main/OverviewView.swift"), "\(source)")
        #expect(!flags(source, path: "BatteryPulseApp/Main/History/HistoryChartParts.swift"), "\(source)")
        #expect(!flags(source, path: "BatteryPulseApp/Settings/SettingsView.swift"), "\(source)")
        #expect(!flags(source, path: "BatteryPulseApp/MenuBar/PopoverView.swift"), "\(source)")
    }

    @Test func materialGuardAllows() {
        let path = "BatteryPulseApp/Main/DemoView.swift"
        #expect(!flags("bar.glassEffectTransition(motion.level == .full ? .materialize : .identity)", path: path))
        #expect(!flags("// A plain fill, not a second Material", path: path))
        #expect(!flags("readout.background(tones.style(.surface), in: .rect(cornerRadius: 8))", path: path))
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
        // A tier's own colour is the standard one: green or orange in Clear too.
        "ProgressView(value: 1).tint(tier.color)",
        "return BatteryPresentation.levelTier(percent: p, isCharging: c).color",
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
        "ProgressView(value: 1).tint(tones.color(part.isOffline ? .text(.secondary) : .level(tier)))",
        "context.fill(path, with: .color(ink))",
        "let tint = tones.color (.cycles)",
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
        #expect(!flags("bolt.foregroundStyle(.white)", path: "BatteryPulseApp/Main/Components/BatteryGlyph.swift"))
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
            try SourceScanner.file(path).code
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

    /// The tile pickers mark the choice with the accent outline alone (V1b): the selection reaches
    /// only the outline's colour and the selected trait VoiceOver reads, never the preview, the
    /// tile's fill or its padding, so a preview looks the same selected or not.
    @Test func tileSelectionChangesOnlyTheOutline() throws {
        let code = try SourceScanner.file("BatteryPulseApp/Settings/PreviewTilePicker.swift").code
        let allowed = [
            Self.words(#/\blet\s+isSelected\s*=\s*value\s*==\s*selection\b/#),
            Self.words(#/\bstrokeBorder\s*\(\s*isSelected\s*\?\s*Color\.accentColor\s*:\s*\.clear\s*,/#),
            Self.words(#/\baccessibilityAddTraits\s*\(\s*isSelected\s*\?\s*\.isSelected\s*:\s*\[\s*\]\s*\)/#),
        ]
        let uses = code.split(separator: "\n").filter { $0.contains(Self.words(#/\bisSelected\b/#)) }
        #expect(uses.count == allowed.count)
        for use in uses {
            #expect(allowed.contains { use.contains($0) }, "\(use)")
        }
        for pattern in allowed {
            #expect(code.matches(of: pattern).count == 1)
        }
        // The choice is compared in that one place only.
        #expect(code.matches(of: Self.words(#/==\s*selection\b|\bselection\s*[!=]=/#)).count == 1)
    }

    private static let widgetView = "BatteryPulseWidget/BatteryWidgetView.swift"

    /// The widget's time never shows seconds, a sign or a per-second countdown (REJ-62), in the
    /// time label's file too; the app may use them.
    @Test(arguments: [
        "TimelineView(.periodic(from: .now, by: 60)) { _ in Text(\"x\") }",
        "TimelineView(.everyMinute) { context in Text(context.date, style: .time) }",
        "TimelineView(PeriodicTimelineSchedule(from: start, by: 1)) { _ in Text(\"x\") }",
        "Text(entry.end, style: .timer)",
        "Text(entry.end, style: .relative)",
        "Text(entry.end, style: .offset)",
        "Text(timerInterval: Date.now...end, countsDown: true)",
        "ProgressView(timerInterval: start...end) { Text(\"x\") }",
        "Text(.currentDate, format: .timer(countingDownIn: Date.now..<end))",
        "Text(.currentDate, format: .stopwatch(startingAt: start))",
        "Text(.currentDate, format: .reference(to: end, allowedFields: [.hour, .minute]))",
    ])
    func catchesWidgetCountdowns(source: String) {
        #expect(flags(source, path: Self.widgetView), "\(source)")
        #expect(flags(source, path: Self.widgetTimeTextFile), "\(source)")
        #expect(!flags(source, path: "BatteryPulseApp/Main/OverviewView.swift"), "\(source)")
    }

    /// The time label's offset is the widget's one self-updating text: hours and minutes, no sign.
    @Test func theWidgetsOnlySelfUpdatingTextIsTheTimeLabelsOffset() throws {
        let offset = "Text(.currentDate, format: .offset(to: time.end, allowedFields: [.hour, .minute], sign: .never))"
        #expect(!flags(offset, path: Self.widgetTimeTextFile))
        #expect(flags(offset, path: Self.widgetView))
        // The default sign puts a minus before an end in the future (W0-6), and the default
        // fields include seconds.
        for source in [
            "Text(.currentDate, format: .offset(to: end, allowedFields: [.hour, .minute]))",
            "Text(.currentDate, format: .offset(to: end, allowedFields: [.hour, .minute], sign: .always))",
            "Text(.currentDate, format: .offset(to: end, allowedFields: [.hour, .minute, .second], sign: .never))",
            "Text(.currentDate, format: .offset(to: end, sign: .never))",
        ] {
            #expect(flags(source, path: Self.widgetTimeTextFile), "\(source)")
        }
        // Key paths, enumerations and the layout modifier are not dates.
        for source in [
            "ForEach(Array(rows.enumerated()), id: \\.offset) { _, row in Text(\"x\") }",
            "Text(\"x\").offset(x: 1, y: 2)",
            "Text(clock, style: .time)",
        ] {
            #expect(!flags(source, path: Self.widgetView), "\(source)")
        }
        // The shipped label is the one self-updating text, and it passes.
        let code = try SourceScanner.file(Self.widgetTimeTextFile).code
        #expect(code.matches(of: Self.words(#/\.currentDate\b/#)).count == 1)
        #expect(code.matches(of: Self.dateOffset).count == 1)
    }

    @Test func menuBarLabelNeverAnimates() {
        let path = "BatteryPulseApp/MenuBar/MenuBarLabel.swift"
        #expect(flags("withAnimation(motion.change) { on.toggle() }", path: path))
        #expect(flags("Text(\"x\").animation(motion.change, value: key)", path: path))
        #expect(!flags("withAnimation(motion.change) { on.toggle() }", path: "BatteryPulseApp/Main/DemoView.swift"))
        // The painter draws the label's icon from its own target.
        #expect(flags("withAnimation(motion.change) { on.toggle() }", path: "BatteryArt/BatteryIconPainter.swift"))
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
        let drawIn = "var iconDrawIn: Animation? { allowsFlourish ? .smooth(duration: 0.8).delay(0.2) : nil }"
        #expect(!flags(drawIn, path: "BatteryPulseApp/App/Motion.swift"))
        #expect(flags(drawIn, path: "BatteryPulseApp/Welcome/AppIconView.swift"))
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
