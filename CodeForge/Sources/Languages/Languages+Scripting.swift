import Foundation

extension Languages {

    static var scripting: [LanguageDefinition] {
        var result: [LanguageDefinition] = []

        // ---- Python -------------------------------------------------------------
        var python = LanguageDefinition.cLike(
            id: "python", name: "Python",
            extensions: ["py", "pyw", "pyi", "pyx", "pxd", "rpy", "gyp"],
            filenames: ["SConstruct", "wscript"],
            keywords: "and as assert async await class def del from global import in is lambda nonlocal not or pass with yield match case type",
            controlKeywords: "if elif else for while break continue return try except finally raise",
            types: "int float complex bool str bytes bytearray list tuple dict set frozenset object type Any Optional Union List Dict Tuple Set Callable Iterator Iterable Sequence Mapping",
            constants: "True False None NotImplemented Ellipsis __name__ __file__ __doc__ self cls",
            builtins: "print len range enumerate zip map filter sorted reversed sum min max abs round open input isinstance issubclass hasattr getattr setattr delattr dir vars id repr format eval exec compile super staticmethod classmethod property iter next all any divmod hex oct bin chr ord pow",
            lineComments: ["#"],
            blockComments: [],
            rules: [RegexRule("@[A-Za-z_][A-Za-z0-9_.]*", .annotation)])
        python.strings = [StringRule(open: "\"\"\"", close: "\"\"\"", multiline: true),
                          StringRule(open: "'''", close: "'''", multiline: true),
                          StringRule(open: "f\"", close: "\"", interpolationOpen: "{", interpolationClose: "}"),
                          StringRule(open: "f'", close: "'", interpolationOpen: "{", interpolationClose: "}"),
                          StringRule(open: "r\"", close: "\"", escape: nil, raw: true),
                          StringRule(open: "b\"", close: "\""),
                          StringRule(open: "\""), StringRule(open: "'")]
        python.shebangs = ["python"]
        python.indentAfter = [":"]
        python.dedentTokens = []
        python.indentUnit = "    "
        python.keyboardExtras = [":", "(", ")", "[", "]", "{", "}", "\"", "'", "#", "_"]
        result.append(python)

        // ---- Ruby ---------------------------------------------------------------
        var ruby = LanguageDefinition.cLike(
            id: "ruby", name: "Ruby",
            extensions: ["rb", "rbw", "rake", "gemspec", "ru", "podspec"],
            filenames: ["Rakefile", "Gemfile", "Podfile", "Brewfile", "Fastfile", "Vagrantfile", "Guardfile"],
            keywords: "alias and begin BEGIN class def defined? do end END module not or self super undef yield lambda proc require require_relative include extend attr_accessor attr_reader attr_writer private public protected module_function raise new",
            controlKeywords: "if elsif else unless case when while until for break next redo retry return then ensure rescue in",
            types: "String Symbol Integer Float Array Hash Range Regexp Proc Struct Class Module Exception StandardError Time Date File IO",
            constants: "true false nil __FILE__ __LINE__ __dir__ ENV ARGV",
            builtins: "puts print p pp gets loop each map select reject reduce inject find detect sort sort_by group_by count length size push pop shift unshift join split gsub sub match freeze dup clone send respond_to? instance_variable_get",
            lineComments: ["#"],
            blockComments: [BlockComment("=begin", "=end")],
            rules: [RegexRule("@@?[A-Za-z_][A-Za-z0-9_]*", .variable),
                    RegexRule("\\$[A-Za-z_][A-Za-z0-9_]*", .variable),
                    RegexRule(":[A-Za-z_][A-Za-z0-9_]*[?!]?", .constant),
                    RegexRule("%[wWiIqQrx]?[\\[({<][^\\])}>]*[\\])}>]", .string)],
            identifierExtras: ["_", "?", "!"])
        ruby.strings = [StringRule(open: "\"", interpolationOpen: "#{", interpolationClose: "}"),
                        StringRule(open: "'")]
        ruby.shebangs = ["ruby"]
        ruby.indentAfter = ["do", "then"]
        ruby.dedentTokens = ["end", "}", ")", "]"]
        result.append(ruby)

        // ---- Perl ------------------------------------------------------------------
        var perl = LanguageDefinition.cLike(
            id: "perl", name: "Perl",
            extensions: ["pl", "pm", "pod", "t", "psgi"],
            keywords: "my our local sub package use no require BEGIN END bless ref wantarray defined undef eval do exit die warn print printf sprintf return qw qq q tr y s m",
            controlKeywords: "if elsif else unless while until for foreach last next redo given when default",
            types: "SCALAR ARRAY HASH CODE GLOB",
            constants: "STDIN STDOUT STDERR __PACKAGE__ __FILE__ __LINE__ __END__ __DATA__",
            builtins: "push pop shift unshift splice keys values each exists delete scalar join split grep map sort reverse chomp chop lc uc length substr index open close binmode",
            lineComments: ["#"],
            blockComments: [],
            rules: [RegexRule("[$@%][{$]?[A-Za-z_][A-Za-z0-9_:]*", .variable),
                    RegexRule("^=\\w+[\\s\\S]*?^=cut", .docComment, options: [.anchorsMatchLines])])
        perl.shebangs = ["perl"]
        result.append(perl)

        // ---- Lua ---------------------------------------------------------------------
        var lua = LanguageDefinition.cLike(
            id: "lua", name: "Lua",
            extensions: ["lua", "rockspec"],
            keywords: "and function local not or in end then do self",
            controlKeywords: "if elseif else for while repeat until break goto return",
            types: "string table number boolean function thread userdata",
            constants: "true false nil _G _VERSION",
            builtins: "print require pairs ipairs type tostring tonumber setmetatable getmetatable rawget rawset pcall xpcall error assert select unpack next os io math table string coroutine",
            lineComments: ["--"],
            blockComments: [BlockComment("--[[", "]]"), BlockComment("--[=[", "]=]")])
        lua.strings = [StringRule(open: "[[", close: "]]", escape: nil, multiline: true),
                       StringRule(open: "\""), StringRule(open: "'")]
        lua.indentAfter = ["then", "do", "{", "(", "function"]
        lua.dedentTokens = ["end", "until", "}", ")", "elseif", "else"]
        result.append(lua)

        // ---- Tcl ------------------------------------------------------------------------
        result.append(LanguageDefinition.cLike(
            id: "tcl", name: "Tcl",
            extensions: ["tcl", "tk", "itcl"],
            keywords: "proc set variable global upvar namespace package source expr incr append lappend array dict string list eval uplevel rename after",
            controlKeywords: "if elseif else for foreach while switch break continue return catch error try finally",
            types: "",
            constants: "true false",
            builtins: "puts open close read gets exec file glob format scan regexp regsub info",
            lineComments: ["#"],
            blockComments: []))

        // ---- AppleScript ---------------------------------------------------------------
        var applescript = LanguageDefinition.cLike(
            id: "applescript", name: "AppleScript",
            extensions: ["applescript", "scpt"],
            keywords: "tell end set to of in on run script property global local return copy make new delete duplicate exists count get activate display considering ignoring with without using terms from application",
            controlKeywords: "if then else repeat while until try error exit",
            types: "text string integer real number boolean list record date alias file",
            constants: "true false missing value it me my its result",
            lineComments: ["--", "#"],
            blockComments: [BlockComment("(*", "*)")],
            caseInsensitive: false)
        result.append(applescript)

        // ---- VBScript / VBA / Visual Basic ------------------------------------------------
        var vb = LanguageDefinition.cLike(
            id: "vb", name: "Visual Basic / VBA",
            extensions: ["vb", "vbs", "bas", "cls", "frm"],
            keywords: "Dim Set Let Const Public Private Friend Static Sub Function End Class Module Type Enum Property Get Let Set New As ByVal ByRef Optional ParamArray Option Explicit Implements Inherits Imports Namespace With Me MyBase MyClass ReDim Preserve Call Declare Lib Alias Attribute",
            controlKeywords: "If Then Else ElseIf Select Case For Each Next To Step Do Loop While Until Wend Exit Continue GoTo Return On Error Resume Try Catch Finally Throw",
            types: "Boolean Byte Integer Long Single Double Currency Date String Object Variant Decimal Char SByte Short UInteger ULong",
            constants: "True False Nothing Null Empty vbCrLf vbTab vbNewLine",
            builtins: "MsgBox InputBox Len Mid Left Right Trim UCase LCase Replace Split Join InStr CInt CLng CDbl CStr CBool IsNumeric IsEmpty IsNull Array UBound LBound",
            lineComments: ["'", "REM "],
            blockComments: [],
            strings: [StringRule(open: "\"", escape: nil)],
            caseInsensitive: true)
        vb.operatorCharacters = Set("+-*/\\^=<>&")
        result.append(vb)

        // ---- Haxe --------------------------------------------------------------------------
        result.append(LanguageDefinition.cLike(
            id: "haxe", name: "Haxe",
            extensions: ["hx", "hxml"],
            keywords: "package import using class interface enum abstract typedef extends implements function var final static public private inline override dynamic macro new cast untyped extern this super operator overload",
            controlKeywords: "if else for while do switch case default break continue return try catch throw",
            types: "Int Float Bool String Array Map Dynamic Void Null Any Class Enum",
            constants: "true false null this super"))

        // ---- GDScript ---------------------------------------------------------------------
        var gd = LanguageDefinition.cLike(
            id: "gdscript", name: "GDScript (Godot)",
            extensions: ["gd", "tres", "tscn"],
            keywords: "func var const enum class class_name extends signal export onready static tool setget yield await breakpoint assert preload load remote master puppet sync is as in not and or self super",
            controlKeywords: "if elif else for while match break continue return pass",
            types: "int float bool String Vector2 Vector3 Rect2 Transform2D Transform3D Color Array Dictionary Node Node2D Node3D Object Resource PackedScene Callable Signal",
            constants: "true false null PI TAU INF NAN",
            builtins: "print print_debug push_error push_warning get_node instance_from_id range len str int float queue_free emit_signal connect",
            lineComments: ["#"],
            blockComments: [])
        gd.indentAfter = [":"]
        gd.dedentTokens = []
        result.append(gd)

        // ---- AutoHotkey ---------------------------------------------------------------------
        result.append(LanguageDefinition.cLike(
            id: "autohotkey", name: "AutoHotkey",
            extensions: ["ahk", "ahkl"],
            keywords: "Send SendInput Click MsgBox InputBox Run RunWait WinActivate WinWait Sleep Loop Gui Menu Hotkey SetTimer global local static class extends new",
            controlKeywords: "if else while for return break continue try catch finally throw",
            types: "",
            constants: "true false A_Index A_ScriptDir A_Now",
            lineComments: [";"],
            blockComments: [BlockComment("/*", "*/")],
            caseInsensitive: true))

        return result
    }
}
