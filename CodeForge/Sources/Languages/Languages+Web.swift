import Foundation

extension Languages {

    static var web: [LanguageDefinition] {
        var result: [LanguageDefinition] = []

        // ---- JavaScript ------------------------------------------------------
        var js = LanguageDefinition.cLike(
            id: "javascript", name: "JavaScript",
            extensions: ["js", "mjs", "cjs", "es6"],
            keywords: "var let const function class extends new delete typeof instanceof void in of this super get set static async await yield export import from as default debugger with",
            controlKeywords: "if else for while do switch case default break continue return try catch finally throw",
            types: "Object Array String Number Boolean Symbol BigInt Function Promise Map Set WeakMap WeakSet Date RegExp Error TypeError JSON Math Proxy Reflect ArrayBuffer Uint8Array Int32Array Float64Array",
            constants: "true false null undefined NaN Infinity globalThis",
            builtins: "console log warn error info document window fetch setTimeout setInterval clearTimeout clearInterval require module exports process alert parseInt parseFloat isNaN encodeURIComponent decodeURIComponent structuredClone queueMicrotask",
            rules: [RegexRule("`(?:\\\\.|[^`\\\\])*`", .string, options: [.dotMatchesLineSeparators])],
            identifierExtras: ["_", "$"])
        js.docLineComments = []
        js.blockComments = [BlockComment("/**", "*/", doc: true), BlockComment("/*", "*/")]
        js.strings = [StringRule(open: "`", close: "`", multiline: true,
                                 interpolationOpen: "${", interpolationClose: "}"),
                      StringRule(open: "\""), StringRule(open: "'")]
        js.rules = []
        js.shebangs = ["node"]
        js.keyboardExtras = ["{", "}", "(", ")", "[", "]", "=>", ";", "`", "$"]
        result.append(js)

        // ---- TypeScript --------------------------------------------------------
        var ts = js
        ts.id = "typescript"
        ts.name = "TypeScript"
        ts.extensions = ["ts", "mts", "cts"]
        ts.keywords.formUnion(["interface", "type", "enum", "namespace", "declare", "abstract",
                               "implements", "public", "private", "protected", "readonly",
                               "satisfies", "keyof", "infer", "is", "asserts", "override", "accessor"])
        ts.types.formUnion(["string", "number", "boolean", "any", "unknown", "never", "void", "object",
                            "bigint", "symbol", "Record", "Partial", "Required", "Readonly", "Pick",
                            "Omit", "Exclude", "Extract", "ReturnType", "Awaited", "Array"])
        result.append(ts)

        var jsx = js
        jsx.id = "jsx"
        jsx.name = "JavaScript React (JSX)"
        jsx.extensions = ["jsx"]
        jsx.rules = [RegexRule("</?[A-Z][A-Za-z0-9_.]*", .tag)]
        result.append(jsx)

        var tsx = ts
        tsx.id = "tsx"
        tsx.name = "TypeScript React (TSX)"
        tsx.extensions = ["tsx"]
        tsx.rules = [RegexRule("</?[A-Z][A-Za-z0-9_.]*", .tag)]
        result.append(tsx)

        var coffee = LanguageDefinition.cLike(
            id: "coffeescript", name: "CoffeeScript",
            extensions: ["coffee"],
            keywords: "class extends new delete typeof instanceof in of this super yield await do then unless until loop by own export import from as",
            controlKeywords: "if else for while switch when break continue return try catch finally throw",
            types: "Object Array String Number Boolean Function Promise Math JSON",
            constants: "true false yes no on off null undefined",
            builtins: "console log window document require module exports",
            lineComments: ["#"],
            blockComments: [BlockComment("###", "###")],
            identifierExtras: ["_", "$"])
        result.append(coffee)

        // ---- HTML / XML family --------------------------------------------------
        var html = LanguageDefinition(id: "html", name: "HTML",
                                      extensions: ["html", "htm", "xhtml", "shtml"],
                                      flavor: .markup)
        html.autoClosePairs = ["<": ">", "\"": "\"", "'": "'", "(": ")", "{": "}"]
        html.keyboardExtras = ["<", ">", "/", "\"", "=", "-", "{", "}"]
        result.append(html)

        var xml = html
        xml.id = "xml"
        xml.name = "XML"
        xml.extensions = ["xml", "xsd", "xsl", "xslt", "svg", "plist", "storyboard", "xib",
                          "rss", "atom", "wsdl", "pom", "csproj", "vbproj", "resx", "nib", "iml"]
        xml.filenames = ["pom.xml", "androidmanifest.xml", "info.plist"]
        result.append(xml)

        var vue = html
        vue.id = "vue"
        vue.name = "Vue"
        vue.extensions = ["vue"]
        result.append(vue)

        var svelte = html
        svelte.id = "svelte"
        svelte.name = "Svelte"
        svelte.extensions = ["svelte"]
        result.append(svelte)

        var erb = html
        erb.id = "erb"
        erb.name = "ERB / EJS Template"
        erb.extensions = ["erb", "ejs", "rhtml"]
        result.append(erb)

        var jinja = html
        jinja.id = "jinja"
        jinja.name = "Jinja / Twig / Handlebars"
        jinja.extensions = ["j2", "jinja", "jinja2", "twig", "hbs", "handlebars", "mustache", "liquid"]
        result.append(jinja)

        var blade = html
        blade.id = "blade"
        blade.name = "Blade Template"
        blade.extensions = ["blade"]
        result.append(blade)

        // ---- CSS family -----------------------------------------------------------
        var css = LanguageDefinition(id: "css", name: "CSS", extensions: ["css"], flavor: .css)
        css.keyboardExtras = ["{", "}", ":", ";", "-", "#", ".", "%"]
        result.append(css)

        var scss = css
        scss.id = "scss"
        scss.name = "SCSS / Sass"
        scss.extensions = ["scss", "sass"]
        result.append(scss)

        var less = css
        less.id = "less"
        less.name = "Less"
        less.extensions = ["less"]
        result.append(less)

        var stylus = css
        stylus.id = "stylus"
        stylus.name = "Stylus"
        stylus.extensions = ["styl"]
        result.append(stylus)

        // ---- PHP -------------------------------------------------------------------
        var php = LanguageDefinition.cLike(
            id: "php", name: "PHP",
            extensions: ["php", "php3", "php4", "php5", "php7", "php8", "phtml", "phps"],
            keywords: "abstract and array as callable class clone const declare echo empty enddeclare endfor endforeach endif endswitch endwhile enum extends final fn function global implements include include_once instanceof insteadof interface isset list match namespace new or print private protected public readonly require require_once static trait unset use var xor yield from",
            controlKeywords: "if else elseif for foreach while do switch case default break continue return try catch finally throw goto",
            types: "int float string bool array object mixed void null never iterable self parent static callable",
            constants: "true false null TRUE FALSE NULL __LINE__ __FILE__ __DIR__ __FUNCTION__ __CLASS__ __METHOD__ __NAMESPACE__ PHP_EOL PHP_INT_MAX",
            builtins: "echo print var_dump print_r count strlen str_replace substr explode implode array_map array_filter array_merge array_keys array_values in_array json_encode json_decode preg_match preg_replace sprintf printf isset unset die exit require include header",
            lineComments: ["//", "#"],
            rules: [RegexRule("\\$[A-Za-z_][A-Za-z0-9_]*", .variable),
                    RegexRule("<\\?php|<\\?=|\\?>", .preprocessor)],
            identifierExtras: ["_", "$", "\\"],
            caseInsensitive: true)
        php.strings = [StringRule(open: "\"", interpolationOpen: "{$", interpolationClose: "}"),
                       StringRule(open: "'")]
        php.keyboardExtras = ["$", "{", "}", "(", ")", ";", "->", "=>", "[", "]"]
        result.append(php)

        // ---- GraphQL ------------------------------------------------------------------
        var graphql = LanguageDefinition.cLike(
            id: "graphql", name: "GraphQL",
            extensions: ["graphql", "gql"],
            keywords: "query mutation subscription fragment on type input interface union enum scalar schema directive extend implements repeatable",
            controlKeywords: "",
            types: "Int Float String Boolean ID",
            constants: "true false null",
            lineComments: ["#"],
            blockComments: [])
        graphql.strings = [StringRule(open: "\"\"\"", close: "\"\"\"", multiline: true), StringRule(open: "\"")]
        graphql.rules = [RegexRule("@[A-Za-z_][A-Za-z0-9_]*", .annotation),
                         RegexRule("\\$[A-Za-z_][A-Za-z0-9_]*", .variable)]
        result.append(graphql)

        // ---- WebAssembly text ---------------------------------------------------------
        var wat = LanguageDefinition.cLike(
            id: "wasm", name: "WebAssembly Text",
            extensions: ["wat", "wast"],
            keywords: "module func param result local global table memory data elem export import type start block loop if else end br br_if br_table call call_indirect return drop select mut offset align",
            controlKeywords: "",
            types: "i32 i64 f32 f64 v128 funcref externref",
            constants: "true false",
            lineComments: [";;"],
            blockComments: [BlockComment("(;", ";)")],
            identifierExtras: ["_", "$", ".", "-"])
        result.append(wat)

        return result
    }
}
