import Foundation

extension Languages {

    static var misc: [LanguageDefinition] {
        var result: [LanguageDefinition] = []

        // ---- Hardware description --------------------------------------------------
        result.append(LanguageDefinition.cLike(
            id: "verilog", name: "Verilog / SystemVerilog",
            extensions: ["v", "vh", "sv", "svh"],
            keywords: "module endmodule input output inout wire reg logic parameter localparam assign always always_ff always_comb always_latch initial begin end function endfunction task endtask generate endgenerate genvar integer real time posedge negedge negedge signed unsigned typedef struct union enum package endpackage import class endclass virtual interface endinterface modport property endproperty assert cover sequence",
            controlKeywords: "if else case casex casez endcase for while repeat forever break continue return fork join",
            types: "bit byte shortint int longint logic reg wire tri wand wor supply0 supply1 string void",
            constants: "1'b0 1'b1 1'bx 1'bz",
            lineComments: ["//"],
            blockComments: [BlockComment("/*", "*/")],
            rules: [RegexRule("`[a-z_]+", .preprocessor),
                    RegexRule("\\d+'[bodhBODH][0-9a-fA-FxXzZ_]+", .number)]))

        result.append(LanguageDefinition.cLike(
            id: "vhdl", name: "VHDL",
            extensions: ["vhd", "vhdl"],
            keywords: "library use entity architecture of is begin end component port map signal variable constant type subtype array record generic process function procedure return package body attribute alias configuration generate downto to others all open buffer linkage inout in out",
            controlKeywords: "if elsif else then case when for while loop next exit wait assert report severity",
            types: "std_logic std_logic_vector bit bit_vector integer natural positive real boolean character string time unsigned signed",
            constants: "true false others",
            lineComments: ["--"],
            blockComments: [],
            caseInsensitive: true))

        // ---- Enterprise ----------------------------------------------------------------
        result.append(LanguageDefinition.cLike(
            id: "apex", name: "Apex (Salesforce)",
            extensions: ["cls", "trigger", "apex"],
            keywords: "public private protected global static final abstract virtual override class interface extends implements enum trigger on before after insert update delete undelete with sharing without sharing transient testMethod webService new this super instanceof",
            controlKeywords: "if else for while do switch case break continue return try catch finally throw",
            types: "Integer Long Double Decimal Boolean String Date Datetime Time Id Blob Object List Set Map SObject Account Contact Opportunity Lead Case User",
            constants: "true false null",
            builtins: "System debug Database insert update upsert delete Test assert assertEquals Trigger Schema Limits",
            caseInsensitive: true))

        result.append(LanguageDefinition.cLike(
            id: "abap", name: "ABAP",
            extensions: ["abap"],
            keywords: "REPORT PROGRAM CLASS ENDCLASS METHOD ENDMETHOD FORM ENDFORM FUNCTION ENDFUNCTION DATA TYPES CONSTANTS FIELD-SYMBOLS PARAMETERS SELECT-OPTIONS TABLES INCLUDE DEFINITION IMPLEMENTATION PUBLIC PRIVATE PROTECTED SECTION IMPORTING EXPORTING CHANGING RETURNING RAISING MOVE APPEND INSERT MODIFY DELETE SELECT FROM INTO WHERE UP TO ROWS ENDSELECT WRITE",
            controlKeywords: "IF ELSEIF ELSE ENDIF CASE WHEN ENDCASE DO ENDDO WHILE ENDWHILE LOOP ENDLOOP EXIT CHECK CONTINUE TRY CATCH ENDTRY RAISE",
            types: "TYPE LIKE STRING XSTRING I F P C N D T REF TABLE STRUCTURE",
            constants: "abap_true abap_false space sy-subrc sy-tabix sy-index",
            lineComments: ["*", "\""],
            blockComments: [],
            caseInsensitive: true))

        result.append(LanguageDefinition.cLike(
            id: "actionscript", name: "ActionScript",
            extensions: ["as"],
            keywords: "package import class interface extends implements public private protected internal static final dynamic override native function var const get set new delete typeof is as instanceof super this namespace use",
            controlKeywords: "if else for each while do switch case default break continue return try catch finally throw with",
            types: "void Boolean int uint Number String Array Object Function Vector Date RegExp XML Error Sprite MovieClip",
            constants: "true false null undefined NaN Infinity",
            identifierExtras: ["_", "$"]))

        // ---- Modern / niche --------------------------------------------------------------
        result.append(LanguageDefinition.cLike(
            id: "v", name: "V",
            extensions: ["vv"],
            keywords: "module import fn struct interface enum type const mut pub union go spawn defer unsafe shared atomic static assert as in is or none",
            controlKeywords: "if else for match break continue return select lock rlock",
            types: "bool string rune int i8 i16 i32 i64 u8 u16 u32 u64 f32 f64 voidptr byteptr charptr any",
            constants: "true false none err"))

        result.append(LanguageDefinition.cLike(
            id: "purescript", name: "PureScript",
            extensions: ["purs"],
            keywords: "module import as hiding where let in data newtype type class instance derive foreign infix infixl infixr forall ado do",
            controlKeywords: "if then else case of",
            types: "Int Number String Char Boolean Array Maybe Either Effect Aff Unit Ordering",
            constants: "true false Nothing Just Left Right unit",
            lineComments: ["--"],
            blockComments: [BlockComment("{-", "-}", nested: true)],
            identifierExtras: ["_", "'"]))

        result.append(LanguageDefinition.cLike(
            id: "reason", name: "ReasonML / ReScript",
            extensions: ["re", "rei", "res", "resi"],
            keywords: "let rec and module open include type external switch fun as of mutable ref lazy exception",
            controlKeywords: "if else switch when for to downto while try raise",
            types: "int float char string bool unit list array option",
            constants: "true false None Some",
            identifierExtras: ["_", "'"]))

        result.append(LanguageDefinition.cLike(
            id: "sml", name: "Standard ML",
            extensions: ["sml", "sig", "fun"],
            keywords: "val fun type datatype exception structure signature functor local open infix infixr nonfix and rec as op withtype abstype where sharing include",
            controlKeywords: "if then else case of handle raise let in end while do",
            types: "int real char string bool list option order unit",
            constants: "true false nil NONE SOME",
            lineComments: [],
            blockComments: [BlockComment("(*", "*)", nested: true)],
            identifierExtras: ["_", "'"]))

        result.append(LanguageDefinition.cLike(
            id: "raku", name: "Raku / Perl 6",
            extensions: ["raku", "rakumod", "p6", "pl6", "pm6"],
            keywords: "my our has is does sub method multi submethod class role grammar token rule regex module package need use require constant state augment supersede proto enum subset",
            controlKeywords: "if elsif else unless with without while until repeat for loop given when default last next redo return try CATCH",
            types: "Int Num Rat Str Bool Array Hash List Any Mu Nil Junction Range Pair Bag Set",
            constants: "True False Nil Any self",
            lineComments: ["#"],
            blockComments: [],
            rules: [RegexRule("[$@%&][.!*?^:]?[A-Za-z_][A-Za-z0-9_-]*", .variable)]))

        result.append(LanguageDefinition.cLike(
            id: "ballerina", name: "Ballerina",
            extensions: ["bal"],
            keywords: "import public private service resource function returns type record object client listener worker fork transaction retry commit rollback isolated readonly final const var check checkpanic trap typeof is new start wait",
            controlKeywords: "if else while foreach in match break continue return panic do on fail",
            types: "int float decimal boolean string byte json xml map table stream future any anydata never error nil",
            constants: "true false null"))

        result.append(LanguageDefinition.cLike(
            id: "bicep", name: "Bicep",
            extensions: ["bicep"],
            keywords: "param var resource module output targetScope existing import metadata type func",
            controlKeywords: "if for in",
            types: "string int bool array object secureString secureObject",
            constants: "true false null",
            builtins: "resourceGroup subscription deployment union concat length contains split replace toLower toUpper json reference listKeys uniqueString guid",
            lineComments: ["//"],
            blockComments: [BlockComment("/*", "*/")]))

        result.append(LanguageDefinition.cLike(
            id: "puppet", name: "Puppet",
            extensions: ["pp"],
            keywords: "class define node inherits include require contain import function type attr application site plan",
            controlKeywords: "if elsif else unless case default and or in",
            types: "String Integer Float Boolean Array Hash Undef Any Variant Optional Enum Pattern",
            constants: "true false undef present absent running stopped",
            lineComments: ["#"],
            blockComments: [BlockComment("/*", "*/")],
            rules: [RegexRule("\\$[A-Za-z_][A-Za-z0-9_:]*", .variable)]))

        result.append(LanguageDefinition.cLike(
            id: "gherkin", name: "Gherkin / Cucumber",
            extensions: ["feature"],
            keywords: "Feature Background Scenario Scenarios Examples Rule",
            controlKeywords: "Given When Then And But",
            types: "",
            constants: "",
            lineComments: ["#"],
            blockComments: [],
            strings: [StringRule(open: "\"\"\"", close: "\"\"\"", multiline: true), StringRule(open: "\"")],
            rules: [RegexRule("<[^>]+>", .variable),
                    RegexRule("@[A-Za-z0-9_-]+", .annotation)]))

        result.append(LanguageDefinition.cLike(
            id: "pug", name: "Pug / Jade",
            extensions: ["pug", "jade"],
            keywords: "doctype block extends include mixin each while if else unless case when default append prepend",
            controlKeywords: "",
            types: "",
            constants: "true false null",
            lineComments: ["//", "//-"],
            blockComments: [],
            rules: [RegexRule("^\\s*[a-z][a-z0-9]*", .tag, options: [.anchorsMatchLines]),
                    RegexRule("[.#][A-Za-z0-9_-]+", .attribute)]))

        result.append(LanguageDefinition.cLike(
            id: "regex", name: "Regular Expression",
            extensions: ["regex", "re2"],
            keywords: "",
            controlKeywords: "",
            types: "",
            constants: "",
            lineComments: [],
            blockComments: [],
            strings: [],
            rules: [RegexRule("\\\\[dDwWsSbBAZzGnrtfve0-9]", .escape),
                    RegexRule("[\\[\\]()|]", .keyword),
                    RegexRule("[*+?{}]", .operator),
                    RegexRule("\\(\\?[:=!<>PR#]?", .function)]))

        result.append(LanguageDefinition.cLike(
            id: "ignorelike", name: "Robots / Hosts / Plain Config",
            extensions: ["robots", "hosts", "resolv", "list", "sources"],
            filenames: ["robots.txt", "hosts", "CODEOWNERS", "Procfile", ".nvmrc", ".ruby-version"],
            keywords: "User-agent Disallow Allow Sitemap Crawl-delay Host",
            controlKeywords: "",
            types: "",
            constants: "",
            lineComments: ["#"],
            blockComments: []))

        return result
    }
}
