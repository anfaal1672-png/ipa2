import Foundation

extension Languages {

    static let annotationRule = RegexRule("@[A-Za-z_][A-Za-z0-9_.]*", .annotation)

    static var jvm: [LanguageDefinition] {
        var result: [LanguageDefinition] = []

        // ---- Java ----------------------------------------------------------
        var java = LanguageDefinition.cLike(
            id: "java", name: "Java",
            extensions: ["java", "jav"],
            keywords: "abstract assert class const default enum extends final finally implements import instanceof interface native new package private protected public record sealed permits static strictfp super synchronized this throws transient var volatile yield non-sealed",
            controlKeywords: "if else for while do switch case break continue return try catch throw",
            types: "boolean byte char double float int long short void String Object Integer Long Double Float Boolean Character Byte Short List ArrayList Map HashMap LinkedHashMap Set HashSet TreeMap Optional Stream Collection Iterable Runnable Thread Exception RuntimeException Class Number BigDecimal BigInteger LocalDate LocalDateTime",
            constants: "true false null",
            builtins: "System out err println print printf length size get put add remove contains equals hashCode toString valueOf format",
            rules: [annotationRule])
        java.docLineComments = []
        java.blockComments = [BlockComment("/**", "*/", doc: true), BlockComment("/*", "*/")]
        java.strings = [StringRule(open: "\"\"\"", close: "\"\"\"", multiline: true),
                        StringRule(open: "\""), StringRule(open: "'")]
        java.keyboardExtras = ["{", "}", "(", ")", ";", "<", ">", "@", "."]
        result.append(java)

        // ---- Kotlin ---------------------------------------------------------
        var kotlin = LanguageDefinition.cLike(
            id: "kotlin", name: "Kotlin",
            extensions: ["kt", "kts"],
            keywords: "package import class interface object fun val var typealias constructor init companion this super where by get set out in reified inline noinline crossinline suspend operator infix external annotation data sealed enum abstract final open override private protected public internal lateinit vararg tailrec const expect actual is as it field delegate",
            controlKeywords: "if else for while do when break continue return try catch finally throw",
            types: "Any Unit Nothing Boolean Byte Short Int Long Float Double Char String Array List MutableList Map MutableMap Set MutableSet Pair Triple Sequence Flow Deferred Job CoroutineScope Result",
            constants: "true false null",
            builtins: "println print listOf mutableListOf mapOf mutableMapOf setOf arrayOf let run apply also with takeIf takeUnless lazy require check error launch async await",
            rules: [annotationRule])
        kotlin.blockComments = [BlockComment("/**", "*/", doc: true), BlockComment("/*", "*/")]
        kotlin.strings = [StringRule(open: "\"\"\"", close: "\"\"\"", multiline: true,
                                     interpolationOpen: "${", interpolationClose: "}"),
                          StringRule(open: "\"", interpolationOpen: "${", interpolationClose: "}"),
                          StringRule(open: "'")]
        result.append(kotlin)

        // ---- Scala -----------------------------------------------------------
        var scala = LanguageDefinition.cLike(
            id: "scala", name: "Scala",
            extensions: ["scala", "sc", "sbt"],
            keywords: "abstract case class def extends final forSome implicit import lazy match new object override package private protected sealed super this trait type val var with yield given using enum extension inline opaque transparent derives end then",
            controlKeywords: "if else for while do try catch finally throw return",
            types: "Any AnyRef AnyVal Boolean Byte Char Double Float Int Long Short String Unit Nothing Null Option Some None List Seq Vector Map Set Array Future Either Left Right Try Success Failure",
            constants: "true false null",
            builtins: "println printf require assert map flatMap filter foreach fold reduce collect",
            rules: [annotationRule])
        scala.strings = [StringRule(open: "\"\"\"", close: "\"\"\"", multiline: true),
                         StringRule(open: "s\"", close: "\"", interpolationOpen: "${", interpolationClose: "}"),
                         StringRule(open: "\""), StringRule(open: "'")]
        result.append(scala)

        // ---- Groovy / Gradle --------------------------------------------------
        var groovy = LanguageDefinition.cLike(
            id: "groovy", name: "Groovy",
            extensions: ["groovy", "gvy", "gradle"],
            filenames: ["build.gradle", "settings.gradle"],
            keywords: "abstract as assert class def enum extends final implements import in instanceof interface native new package private protected public static strictfp super synchronized this threadsafe throws trait transient volatile it",
            controlKeywords: "if else for while do switch case default break continue return try catch finally throw",
            types: "boolean byte char double float int long short void String Object List Map Set Closure GString BigDecimal",
            constants: "true false null",
            builtins: "println print printf task apply plugins dependencies repositories implementation testImplementation android compileOnly",
            rules: [annotationRule])
        groovy.strings = [StringRule(open: "\"\"\"", close: "\"\"\"", multiline: true),
                          StringRule(open: "'''", close: "'''", multiline: true),
                          StringRule(open: "\"", interpolationOpen: "${", interpolationClose: "}"),
                          StringRule(open: "'"), StringRule(open: "/", close: "/")]
        result.append(groovy)

        // ---- Dart --------------------------------------------------------------
        var dart = LanguageDefinition.cLike(
            id: "dart", name: "Dart",
            extensions: ["dart"],
            keywords: "abstract as assert async await class const covariant deferred dynamic export extends extension external factory final get implements import in interface is late library mixin new on operator part required rethrow sealed set show hide static super sync this typedef var with yield base when",
            controlKeywords: "if else for while do switch case default break continue return try catch finally throw",
            types: "int double num bool String List Map Set Iterable Future Stream Object Null void Function Widget StatelessWidget StatefulWidget BuildContext State Key Duration DateTime",
            constants: "true false null",
            builtins: "print runApp setState build initState dispose then map where toList add remove",
            rules: [annotationRule])
        dart.docLineComments = ["///"]
        dart.strings = [StringRule(open: "\"\"\"", close: "\"\"\"", multiline: true),
                        StringRule(open: "'''", close: "'''", multiline: true),
                        StringRule(open: "\"", interpolationOpen: "${", interpolationClose: "}"),
                        StringRule(open: "'", interpolationOpen: "${", interpolationClose: "}")]
        result.append(dart)

        // ---- Swift ---------------------------------------------------------------
        var swift = LanguageDefinition.cLike(
            id: "swift", name: "Swift",
            extensions: ["swift"],
            keywords: "associatedtype class deinit enum extension fileprivate func import init inout internal let open operator private precedencegroup protocol public rethrows static struct subscript typealias var actor async await nonisolated isolated some any each borrowing consuming convenience dynamic didSet final get indirect infix lazy left mutating none nonmutating optional override postfix prefix Protocol required right set Self Type unowned weak willSet macro package sending",
            controlKeywords: "break case catch continue default defer do else fallthrough for guard if in repeat return switch throw throws try where while",
            types: "Int Int8 Int16 Int32 Int64 UInt UInt8 UInt16 UInt32 UInt64 Float Double Bool String Character Array Dictionary Set Optional Result Any AnyObject Void Never Data Date URL UUID Error Task Sequence Collection Codable Encodable Decodable Hashable Equatable Comparable Identifiable View Text Image Color Font State Binding Published ObservableObject",
            constants: "true false nil self super",
            builtins: "print debugPrint assert precondition fatalError map filter reduce compactMap flatMap sorted forEach append remove count isEmpty first last min max zip stride withUnsafePointer",
            rules: [RegexRule("@[A-Za-z_][A-Za-z0-9_]*", .annotation),
                    RegexRule("#[a-zA-Z]+", .preprocessor)])
        swift.docLineComments = ["///"]
        swift.blockComments = [BlockComment("/**", "*/", doc: true), BlockComment("/*", "*/", nested: true)]
        swift.strings = [StringRule(open: "\"\"\"", close: "\"\"\"", multiline: true,
                                    interpolationOpen: "\\(", interpolationClose: ")"),
                         StringRule(open: "#\"", close: "\"#", escape: nil, raw: true),
                         StringRule(open: "\"", interpolationOpen: "\\(", interpolationClose: ")")]
        swift.keyboardExtras = ["{", "}", "(", ")", "[", "]", ".", ":", "?", "!"]
        result.append(swift)

        return result
    }
}
