import Foundation

extension Languages {

    static var systems: [LanguageDefinition] {
        var result: [LanguageDefinition] = []

        // ---- Rust ------------------------------------------------------------
        var rust = LanguageDefinition.cLike(
            id: "rust", name: "Rust",
            extensions: ["rs"],
            keywords: "as async await const crate dyn enum extern fn impl in let mod move mut pub ref self Self static struct super trait type union unsafe use where macro_rules",
            controlKeywords: "break continue else for if loop match return while yield",
            types: "bool char str String i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128 usize f32 f64 Vec HashMap HashSet BTreeMap Option Result Box Rc Arc RefCell Cell Mutex RwLock Cow Path PathBuf Iterator Future Pin",
            constants: "true false None Some Ok Err",
            builtins: "println print eprintln format vec panic assert assert_eq assert_ne write writeln unwrap expect clone into from iter collect map filter todo unimplemented matches dbg",
            rules: [RegexRule("#!?\\[[^\\]]*\\]", .annotation),
                    RegexRule("'[a-z_][a-zA-Z0-9_]*(?![a-zA-Z0-9_'])", .annotation),
                    RegexRule("\\b[a-z_][a-z0-9_]*!", .builtin)])
        rust.docLineComments = ["///", "//!"]
        rust.strings = [StringRule(open: "r#\"", close: "\"#", escape: nil, multiline: true, raw: true),
                        StringRule(open: "b\"", close: "\""),
                        StringRule(open: "\"", multiline: true)]
        rust.keyboardExtras = ["{", "}", "(", ")", "<", ">", "&", "::", ";", "!"]
        result.append(rust)

        // ---- Go ------------------------------------------------------------------
        var go = LanguageDefinition.cLike(
            id: "go", name: "Go",
            extensions: ["go"],
            filenames: ["go.mod", "go.sum"],
            keywords: "package import func var const type struct interface map chan go defer select range",
            controlKeywords: "if else for switch case default break continue return goto fallthrough",
            types: "bool byte rune string error int int8 int16 int32 int64 uint uint8 uint16 uint32 uint64 uintptr float32 float64 complex64 complex128 any comparable",
            constants: "true false nil iota",
            builtins: "append cap close complex copy delete imag len make new panic print println real recover min max fmt errors context sync time strings strconv")
        go.strings = [StringRule(open: "`", close: "`", escape: nil, multiline: true, raw: true),
                      StringRule(open: "\""), StringRule(open: "'")]
        go.indentUnit = "\t"
        go.keyboardExtras = ["{", "}", "(", ")", ":=", "*", "&", "<-", "`"]
        result.append(go)

        // ---- Zig --------------------------------------------------------------------
        var zig = LanguageDefinition.cLike(
            id: "zig", name: "Zig",
            extensions: ["zig", "zon"],
            keywords: "const var fn pub export extern inline noinline comptime struct enum union opaque error test usingnamespace align allowzero anyframe anytype asm callconv linksection noalias packed threadlocal volatile suspend resume nosuspend async await defer errdefer unreachable orelse and or try catch",
            controlKeywords: "if else while for switch break continue return",
            types: "bool void noreturn type anyerror anyopaque comptime_int comptime_float i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128 usize f16 f32 f64 f80 f128 c_int c_uint c_long",
            constants: "true false null undefined",
            builtins: "@import @TypeOf @sizeOf @alignOf @intCast @ptrCast @bitCast @intFromEnum @enumFromInt @field @hasDecl @compileError @compileLog @panic @memcpy @memset @embedFile",
            blockComments: [],
            rules: [RegexRule("@[A-Za-z_][A-Za-z0-9_]*", .builtin)])
        zig.docLineComments = ["///", "//!"]
        zig.strings = [StringRule(open: "\\\\", close: "\n", escape: nil), StringRule(open: "\""), StringRule(open: "'")]
        result.append(zig)

        // ---- Nim ---------------------------------------------------------------------
        var nim = LanguageDefinition.cLike(
            id: "nim", name: "Nim",
            extensions: ["nim", "nims", "nimble"],
            keywords: "addr and as asm bind concept const converter defer discard distinct div do enum export from func import in include interface is isnot iterator let macro method mixin mod not notin object of or out proc ptr ref shl shr static template type using var when xor yield",
            controlKeywords: "block break case continue elif else except finally for if raise return try while",
            types: "int int8 int16 int32 int64 uint uint8 uint16 uint32 uint64 float float32 float64 bool char string cstring seq array set openArray varargs Table HashSet Option",
            constants: "true false nil result",
            builtins: "echo len add new inc dec high low ord chr repr toSeq newSeq",
            lineComments: ["#"],
            blockComments: [BlockComment("#[", "]#", nested: true)])
        nim.strings = [StringRule(open: "\"\"\"", close: "\"\"\"", multiline: true), StringRule(open: "\""), StringRule(open: "'")]
        nim.indentAfter = [":", "="]
        result.append(nim)

        // ---- Crystal ----------------------------------------------------------------------
        result.append(LanguageDefinition.cLike(
            id: "crystal", name: "Crystal",
            extensions: ["cr"],
            keywords: "abstract alias annotation as asm begin class def do end enum extend fun include instance_sizeof is_a lib macro module next of out pointerof private protected require responds_to return select self sizeof struct super type typeof uninitialized union until verbatim with yield",
            controlKeywords: "if elsif else unless case when while break ensure rescue then in",
            types: "Int8 Int16 Int32 Int64 UInt8 UInt16 UInt32 UInt64 Float32 Float64 Bool Char String Symbol Array Hash Range Tuple NamedTuple Nil Proc",
            constants: "true false nil self",
            builtins: "puts print p pp raise loop spawn",
            lineComments: ["#"],
            blockComments: []))

        // ---- Assembly ----------------------------------------------------------------------
        var asm = LanguageDefinition.cLike(
            id: "assembly", name: "Assembly",
            extensions: ["asm", "s", "nasm", "inc"],
            keywords: "section global extern db dw dd dq resb resw resd resq equ times align byte word dword qword ptr offset org bits default struc endstruc macro endmacro proc endp",
            controlKeywords: "jmp je jne jz jnz jg jge jl jle ja jae jb jbe call ret loop int syscall",
            types: "eax ebx ecx edx esi edi esp ebp rax rbx rcx rdx rsi rdi rsp rbp r8 r9 r10 r11 r12 r13 r14 r15 ax bx cx dx al bl cl dl x0 x1 x2 x3 x29 x30 sp pc w0 w1",
            constants: "",
            builtins: "mov movzx movsx lea push pop add sub mul imul div idiv inc dec and or xor not neg shl shr sar cmp test nop leave enter ldr str stp ldp bl blr adrp",
            lineComments: [";", "#", "//"],
            blockComments: [BlockComment("/*", "*/")],
            caseInsensitive: true)
        asm.rules = [RegexRule("^[ \\t]*[A-Za-z_.][A-Za-z0-9_.$]*:", .function, options: [.anchorsMatchLines]),
                     RegexRule("^[ \\t]*\\.[a-z_]+", .preprocessor, options: [.anchorsMatchLines])]
        result.append(asm)

        // ---- LLVM IR ------------------------------------------------------------------------
        result.append(LanguageDefinition.cLike(
            id: "llvm", name: "LLVM IR",
            extensions: ["ll"],
            keywords: "define declare global constant private internal external linkonce weak common appending extern_weak dso_local dllimport dllexport align nounwind readonly readnone alwaysinline noinline target datalayout triple attributes type opaque to",
            controlKeywords: "br switch indirectbr invoke resume unreachable ret",
            types: "void i1 i8 i16 i32 i64 i128 half float double x86_fp80 fp128 label metadata ptr",
            constants: "true false null undef poison zeroinitializer none",
            builtins: "add sub mul udiv sdiv fadd fsub fmul fdiv icmp fcmp alloca load store getelementptr call phi select bitcast trunc zext sext ptrtoint inttoptr",
            lineComments: [";"],
            blockComments: [],
            rules: [RegexRule("[%@][A-Za-z0-9_.$]+", .variable)]))

        // ---- Ada / Pascal / Fortran-adjacent legacy -------------------------------------------
        result.append(LanguageDefinition.cLike(
            id: "ada", name: "Ada",
            extensions: ["adb", "ads", "ada"],
            keywords: "abort abs abstract accept access aliased all and array at begin body constant declare delay delta digits do end entry exception exit generic goto in interface is limited mod new not null of or others out overriding package pragma private procedure protected raise range record rem renames requeue return reverse separate some subtype synchronized tagged task terminate then type until use when with xor function",
            controlKeywords: "case elsif else for if loop while select",
            types: "Integer Natural Positive Float Boolean Character String Duration",
            constants: "True False null",
            lineComments: ["--"],
            blockComments: [],
            caseInsensitive: true))

        result.append(LanguageDefinition.cLike(
            id: "pascal", name: "Pascal / Delphi",
            extensions: ["pas", "pp", "dpr", "lpr", "dfm"],
            keywords: "program unit uses interface implementation initialization finalization begin end var const type procedure function record array set of packed object class property published private protected public inherited nil new dispose with in is as out constructor destructor override virtual abstract",
            controlKeywords: "if then else case for to downto do while repeat until break continue exit goto try except finally raise",
            types: "Integer Cardinal Byte Word LongInt Int64 Real Single Double Extended Currency Boolean Char String AnsiString WideString Pointer Variant TObject",
            constants: "True False nil",
            lineComments: ["//"],
            blockComments: [BlockComment("{", "}"), BlockComment("(*", "*)")],
            caseInsensitive: true))

        result.append(LanguageDefinition.cLike(
            id: "cobol", name: "COBOL",
            extensions: ["cob", "cbl", "cpy", "cobol"],
            keywords: "IDENTIFICATION DIVISION PROGRAM-ID ENVIRONMENT CONFIGURATION SECTION INPUT-OUTPUT FILE-CONTROL DATA WORKING-STORAGE LINKAGE PROCEDURE SELECT ASSIGN FD PIC PICTURE VALUE OCCURS REDEFINES USAGE COMP COMP-3 DISPLAY MOVE ADD SUBTRACT MULTIPLY DIVIDE COMPUTE ACCEPT OPEN CLOSE READ WRITE REWRITE DELETE START CALL USING RETURNING STOP RUN EXIT COPY",
            controlKeywords: "IF ELSE END-IF PERFORM UNTIL VARYING THRU GO TO EVALUATE WHEN END-EVALUATE",
            types: "",
            constants: "ZERO ZEROS SPACE SPACES HIGH-VALUES LOW-VALUES TRUE FALSE",
            lineComments: ["*>"],
            blockComments: [],
            caseInsensitive: true))

        return result
    }

    static var functional: [LanguageDefinition] {
        var result: [LanguageDefinition] = []

        var haskell = LanguageDefinition.cLike(
            id: "haskell", name: "Haskell",
            extensions: ["hs", "lhs"],
            keywords: "module import qualified as hiding where let in data newtype type class instance deriving do forall foreign infix infixl infixr family pattern",
            controlKeywords: "if then else case of",
            types: "Int Integer Float Double Char String Bool Maybe Either IO Ordering Word Rational Functor Applicative Monad Foldable Traversable",
            constants: "True False Nothing Just Left Right LT EQ GT otherwise undefined",
            builtins: "map filter foldr foldl zip zipWith head tail init last length reverse concat concatMap take drop span return pure fmap putStrLn print show read",
            lineComments: ["--"],
            blockComments: [BlockComment("{-", "-}", nested: true)],
            identifierExtras: ["_", "'"])
        haskell.operatorCharacters = Set("+-*/=<>$!&|.:#@%^?~\\")
        result.append(haskell)

        let ocaml = LanguageDefinition.cLike(
            id: "ocaml", name: "OCaml",
            extensions: ["ml", "mli", "mll", "mly"],
            keywords: "let rec and in fun function module struct sig end open include type val mutable ref as of begin new object method inherit private virtual external lazy assert",
            controlKeywords: "if then else match with when for to downto while do done try raise",
            types: "int float char string bool unit list array option ref exn",
            constants: "true false None Some ()",
            builtins: "print_endline print_string printf sprintf List Array String Hashtbl Map Set failwith ignore",
            lineComments: [],
            blockComments: [BlockComment("(*", "*)", nested: true)],
            identifierExtras: ["_", "'"])
        result.append(ocaml)

        var fsharp = ocaml
        fsharp.id = "fsharp"
        fsharp.name = "F#"
        fsharp.extensions = ["fs", "fsi", "fsx"]
        fsharp.lineComments = ["//"]
        fsharp.keywords.formUnion(["namespace", "member", "static", "abstract", "override", "interface",
                                   "inline", "use", "yield", "return", "async", "task", "do!", "let!"])
        fsharp.types.formUnion(["int", "float", "string", "bool", "seq", "Map", "Set", "Async", "Task", "Result"])
        result.append(fsharp)

        result.append(LanguageDefinition.cLike(
            id: "elm", name: "Elm",
            extensions: ["elm"],
            keywords: "module exposing import as type alias port let in where infix",
            controlKeywords: "if then else case of",
            types: "Int Float String Char Bool List Maybe Result Cmd Sub Html Program Order",
            constants: "True False Nothing Just Ok Err",
            lineComments: ["--"],
            blockComments: [BlockComment("{-", "-}", nested: true)]))

        var erlang = LanguageDefinition.cLike(
            id: "erlang", name: "Erlang",
            extensions: ["erl", "hrl", "escript"],
            keywords: "module export import compile behaviour record define include include_lib spec type opaque callback fun begin end receive after when of andalso orelse band bor bxor bnot div rem not and or xor",
            controlKeywords: "case if try catch throw",
            types: "atom binary bitstring boolean float integer list map pid port reference tuple",
            constants: "true false undefined ok error",
            builtins: "io lists maps gen_server spawn spawn_link self send exit hd tl length element setelement is_atom is_list is_tuple",
            lineComments: ["%"],
            blockComments: [],
            identifierExtras: ["_", "@"])
        erlang.rules = [RegexRule("^-[a-z_]+", .preprocessor, options: [.anchorsMatchLines])]
        result.append(erlang)

        var elixir = LanguageDefinition.cLike(
            id: "elixir", name: "Elixir",
            extensions: ["ex", "exs", "eex", "heex", "leex"],
            filenames: ["mix.exs"],
            keywords: "def defp defmodule defmacro defmacrop defstruct defprotocol defimpl defdelegate defexception defguard do end fn use import alias require quote unquote when in not and or",
            controlKeywords: "if unless else cond case with for try rescue catch after raise throw receive",
            types: "Enum Map List String Atom Integer Float Tuple Keyword Process Task Agent GenServer Supervisor Stream Regex",
            constants: "true false nil __MODULE__ __ENV__ __DIR__",
            builtins: "IO puts inspect is_nil is_atom is_binary is_list is_map length hd tl elem put_elem spawn send self",
            lineComments: ["#"],
            blockComments: [],
            rules: [RegexRule("@[a-z_][a-zA-Z0-9_]*", .annotation),
                    RegexRule(":[a-zA-Z_][a-zA-Z0-9_]*[?!]?", .constant),
                    RegexRule("~[a-zA-Z][\\[({<\"'|/][\\s\\S]*?[\\])}>\"'|/]", .string)],
            identifierExtras: ["_", "?", "!"])
        elixir.strings = [StringRule(open: "\"\"\"", close: "\"\"\"", multiline: true,
                                     interpolationOpen: "#{", interpolationClose: "}"),
                          StringRule(open: "\"", interpolationOpen: "#{", interpolationClose: "}"),
                          StringRule(open: "'")]
        result.append(elixir)

        var lisp = LanguageDefinition.cLike(
            id: "lisp", name: "Common Lisp",
            extensions: ["lisp", "lsp", "cl", "el", "asd"],
            keywords: "defun defmacro defvar defparameter defconstant defstruct defclass defmethod defgeneric let let* labels flet lambda setq setf progn quote function declare declaim in-package require provide loop do dolist dotimes",
            controlKeywords: "if when unless cond case and or not return return-from block catch throw unwind-protect",
            types: "integer float string symbol list cons vector array hash-table function stream character",
            constants: "t nil",
            builtins: "car cdr cons list append length nth mapcar reduce remove-if find position format print princ apply funcall eq eql equal equalp",
            lineComments: [";"],
            blockComments: [BlockComment("#|", "|#", nested: true)],
            identifierExtras: ["-", "*", "+", "?", "!", "_", "/", "<", ">", "="])
        lisp.highlightProperties = false
        lisp.operatorCharacters = Set("'`,@")
        lisp.punctuation = Set("()[]")
        result.append(lisp)

        var scheme = lisp
        scheme.id = "scheme"
        scheme.name = "Scheme"
        scheme.extensions = ["scm", "ss", "sls", "sld"]
        scheme.keywords = Set("define define-syntax define-record-type lambda let let* letrec letrec* set! begin quote quasiquote unquote syntax-rules named-lambda delay force call/cc call-with-current-continuation".split(separator: " ").map(String.init))
        scheme.constants = ["#t", "#f"]
        result.append(scheme)

        var clojure = lisp
        clojure.id = "clojure"
        clojure.name = "Clojure"
        clojure.extensions = ["clj", "cljs", "cljc", "edn"]
        clojure.keywords = Set("def defn defn- defmacro defmulti defmethod defprotocol defrecord deftype definterface ns let letfn fn loop recur binding do doto -> ->> as-> some-> cond-> require import use in-ns quote var set! try".split(separator: " ").map(String.init))
        clojure.controlKeywords = ["if", "if-let", "if-not", "when", "when-let", "when-not", "cond", "condp", "case", "catch", "finally", "throw"]
        clojure.constants = ["true", "false", "nil"]
        clojure.builtins = Set("map filter reduce apply conj cons first rest last count assoc dissoc get get-in update update-in merge into vec vector list hash-map set str println print pr prn atom swap! reset! deref".split(separator: " ").map(String.init))
        clojure.rules = [RegexRule(":[a-zA-Z_][a-zA-Z0-9_/.*+!?-]*", .constant)]
        result.append(clojure)

        result.append(LanguageDefinition.cLike(
            id: "prolog", name: "Prolog",
            extensions: ["pro", "prolog", "plg"],
            keywords: "module use_module dynamic discontiguous initialization op assert asserta assertz retract findall bagof setof forall is",
            controlKeywords: "if then else fail true not once catch throw",
            types: "",
            constants: "true false fail nil",
            builtins: "write writeln nl read atom number var nonvar functor arg copy_term length append member reverse msort",
            lineComments: ["%"],
            blockComments: [BlockComment("/*", "*/")]))

        result.append(LanguageDefinition.cLike(
            id: "smalltalk", name: "Smalltalk",
            extensions: ["st"],
            keywords: "class extend subclass instanceVariableNames classVariableNames package category self super thisContext",
            controlKeywords: "ifTrue ifFalse whileTrue whileFalse to do timesRepeat",
            types: "Object String Symbol Number Integer Float Collection Array OrderedCollection Dictionary Set Bag",
            constants: "true false nil",
            lineComments: [],
            blockComments: [BlockComment("\"", "\"")],
            strings: [StringRule(open: "'", escape: nil)]))

        return result
    }
}
