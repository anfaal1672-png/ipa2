import Foundation

extension Languages {

    static var data: [LanguageDefinition] {
        var result: [LanguageDefinition] = []

        // ---- JSON ---------------------------------------------------------------
        var json = LanguageDefinition.cLike(
            id: "json", name: "JSON",
            extensions: ["json", "jsonl", "ndjson", "webmanifest", "avsc"],
            filenames: ["package.json", "tsconfig.json", "composer.json", ".babelrc", ".eslintrc"],
            keywords: "",
            controlKeywords: "",
            types: "",
            constants: "true false null",
            lineComments: [],
            blockComments: [],
            strings: [StringRule(open: "\"")],
            rules: [RegexRule("\"(?:\\\\.|[^\"\\\\])*\"\\s*:", .property)])
        json.highlightCalls = false
        json.keyboardExtras = ["{", "}", "[", "]", "\"", ":", ",", "-"]
        result.append(json)

        var jsonc = json
        jsonc.id = "jsonc"
        jsonc.name = "JSON with Comments"
        jsonc.extensions = ["jsonc", "json5", "hjson"]
        jsonc.lineComments = ["//"]
        jsonc.blockComments = [BlockComment("/*", "*/")]
        result.append(jsonc)

        // ---- YAML -----------------------------------------------------------------
        var yaml = LanguageDefinition.cLike(
            id: "yaml", name: "YAML",
            extensions: ["yaml", "yml"],
            filenames: ["docker-compose.yml", ".gitlab-ci.yml", "action.yml", "pubspec.yaml"],
            keywords: "",
            controlKeywords: "",
            types: "",
            constants: "true false null yes no on off ~ True False Null Yes No On Off",
            lineComments: ["#"],
            blockComments: [],
            rules: [RegexRule("^[ \\t-]*([\\w.$-]+)\\s*:", .property, group: 1, options: [.anchorsMatchLines]),
                    RegexRule("^[ \\t]*-\\s", .operator, options: [.anchorsMatchLines]),
                    RegexRule("^---$|^\\.\\.\\.$", .keyword, options: [.anchorsMatchLines]),
                    RegexRule("[&*][A-Za-z0-9_-]+", .annotation),
                    RegexRule("\\$\\{\\{[^}]*\\}\\}", .interpolation)])
        yaml.indentUnit = "  "
        yaml.indentAfter = [":"]
        yaml.dedentTokens = []
        yaml.autoClosePairs = ["\"": "\"", "'": "'", "[": "]", "{": "}"]
        yaml.keyboardExtras = ["-", ":", " ", "#", "\"", "[", "]", "{", "}"]
        result.append(yaml)

        // ---- TOML ------------------------------------------------------------------
        var toml = LanguageDefinition.cLike(
            id: "toml", name: "TOML",
            extensions: ["toml"],
            filenames: ["Cargo.toml", "pyproject.toml", "Pipfile", "poetry.lock", "Cargo.lock"],
            keywords: "",
            controlKeywords: "",
            types: "",
            constants: "true false",
            lineComments: ["#"],
            blockComments: [],
            strings: [StringRule(open: "\"\"\"", close: "\"\"\"", multiline: true),
                      StringRule(open: "'''", close: "'''", multiline: true),
                      StringRule(open: "\""), StringRule(open: "'", escape: nil)],
            rules: [RegexRule("^\\s*\\[\\[?[^\\]]*\\]\\]?", .heading, options: [.anchorsMatchLines]),
                    RegexRule("^\\s*([A-Za-z0-9_.\"-]+)\\s*=", .property, group: 1, options: [.anchorsMatchLines])])
        result.append(toml)

        // ---- INI / properties / env --------------------------------------------------
        var ini = LanguageDefinition(id: "ini", name: "INI / Config",
                                     extensions: ["ini", "cfg", "conf", "properties", "editorconfig",
                                                  "gitconfig", "npmrc", "curlrc", "desktop", "service", "inf"],
                                     flavor: .ini)
        ini.filenames = [".editorconfig", ".gitconfig", ".npmrc", "gradle.properties", "local.properties"]
        result.append(ini)

        var dotenv = ini
        dotenv.id = "dotenv"
        dotenv.name = "Environment File"
        dotenv.extensions = ["env"]
        dotenv.filenames = [".env", ".env.local", ".env.production", ".env.development"]
        result.append(dotenv)

        // ---- SQL ------------------------------------------------------------------------
        var sql = LanguageDefinition.cLike(
            id: "sql", name: "SQL",
            extensions: ["sql", "ddl", "dml", "mysql", "pgsql", "psql", "hql"],
            keywords: "SELECT FROM WHERE INSERT INTO VALUES UPDATE SET DELETE CREATE ALTER DROP TRUNCATE TABLE VIEW INDEX SEQUENCE TRIGGER PROCEDURE FUNCTION DATABASE SCHEMA GRANT REVOKE JOIN INNER LEFT RIGHT FULL OUTER CROSS ON USING GROUP BY ORDER HAVING LIMIT OFFSET UNION ALL DISTINCT AS AND OR NOT IN EXISTS BETWEEN LIKE ILIKE IS NULL PRIMARY KEY FOREIGN REFERENCES UNIQUE CHECK DEFAULT CONSTRAINT CASCADE WITH RECURSIVE OVER PARTITION WINDOW RETURNING CONFLICT DO NOTHING BEGIN COMMIT ROLLBACK TRANSACTION EXPLAIN ANALYZE VACUUM DECLARE CURSOR FETCH IF ELSE WHILE LOOP RETURN CASE WHEN THEN END AUTO_INCREMENT ENGINE CHARSET COLLATE TEMPORARY MATERIALIZED",
            controlKeywords: "",
            types: "INT INTEGER SMALLINT BIGINT TINYINT DECIMAL NUMERIC FLOAT REAL DOUBLE PRECISION BOOLEAN BOOL CHAR VARCHAR TEXT NCHAR NVARCHAR CLOB BLOB BINARY VARBINARY DATE TIME TIMESTAMP TIMESTAMPTZ DATETIME INTERVAL JSON JSONB UUID SERIAL BIGSERIAL ARRAY ENUM MONEY BIT XML",
            constants: "TRUE FALSE NULL CURRENT_DATE CURRENT_TIME CURRENT_TIMESTAMP CURRENT_USER",
            builtins: "COUNT SUM AVG MIN MAX ROUND ABS CEIL FLOOR COALESCE NULLIF CAST CONVERT SUBSTRING TRIM UPPER LOWER LENGTH REPLACE CONCAT NOW DATE_ADD DATE_SUB DATEDIFF EXTRACT ROW_NUMBER RANK DENSE_RANK LAG LEAD FIRST_VALUE LAST_VALUE ARRAY_AGG STRING_AGG JSON_BUILD_OBJECT GENERATE_SERIES",
            lineComments: ["--", "#"],
            blockComments: [BlockComment("/*", "*/")],
            strings: [StringRule(open: "'", escape: nil), StringRule(open: "\"", escape: nil), StringRule(open: "`", close: "`", escape: nil)],
            caseInsensitive: true)
        sql.keyboardExtras = ["*", ",", "(", ")", "'", "=", ";", "%"]
        result.append(sql)

        var plsql = sql
        plsql.id = "plsql"
        plsql.name = "PL/SQL & T-SQL"
        plsql.extensions = ["pls", "plb", "pks", "pkb", "tsql", "prc"]
        plsql.keywords.formUnion(["PACKAGE", "BODY", "EXCEPTION", "RAISE", "PRAGMA", "CURSOR", "ROWTYPE",
                                  "TYPE", "IS", "LOOP", "EXIT", "ELSIF", "GO", "PRINT", "EXEC", "TRY", "CATCH"])
        result.append(plsql)

        // ---- Markdown & docs ----------------------------------------------------------------
        var md = LanguageDefinition(id: "markdown", name: "Markdown",
                                    extensions: ["md", "markdown", "mdown", "mkd", "mdx", "qmd"],
                                    flavor: .markdown)
        md.filenames = ["README", "CHANGELOG", "CONTRIBUTING", "LICENSE"]
        md.autoClosePairs = ["(": ")", "[": "]", "`": "`", "\"": "\"", "*": "*", "_": "_"]
        md.keyboardExtras = ["#", "*", "-", "`", "[", "]", "(", ")", ">"]
        result.append(md)

        var rst = LanguageDefinition.cLike(
            id: "rst", name: "reStructuredText",
            extensions: ["rst", "rest"],
            keywords: "", controlKeywords: "", types: "", constants: "",
            lineComments: [], blockComments: [],
            strings: [StringRule(open: "``", close: "``")],
            rules: [RegexRule("^\\.\\. [a-z-]+::.*$", .keyword, options: [.anchorsMatchLines]),
                    RegexRule("^[=~`#\"^_*+-]{3,}$", .heading, options: [.anchorsMatchLines]),
                    RegexRule(":[a-z]+:`[^`]*`", .link)])
        result.append(rst)

        var latex = LanguageDefinition.cLike(
            id: "latex", name: "LaTeX / TeX",
            extensions: ["tex", "sty", "cls", "ltx", "bib", "bbx", "cbx"],
            keywords: "", controlKeywords: "", types: "", constants: "",
            lineComments: ["%"], blockComments: [],
            strings: [],
            rules: [RegexRule("\\\\[a-zA-Z@]+\\*?", .keyword),
                    RegexRule("\\\\(begin|end)\\{[^}]*\\}", .function),
                    RegexRule("\\$[^$]*\\$", .string),
                    RegexRule("\\{[^{}]*\\}", .plain)])
        latex.punctuation = Set("{}[]")
        result.append(latex)

        // ---- Diff / patch -----------------------------------------------------------------------
        var diff = LanguageDefinition(id: "diff", name: "Diff / Patch",
                                      extensions: ["diff", "patch", "rej"],
                                      flavor: .diff)
        diff.filenames = ["COMMIT_EDITMSG"]
        result.append(diff)

        // ---- CSV / TSV -----------------------------------------------------------------------
        var csv = LanguageDefinition.cLike(
            id: "csv", name: "CSV / TSV",
            extensions: ["csv", "tsv", "psv"],
            keywords: "", controlKeywords: "", types: "", constants: "",
            lineComments: [], blockComments: [],
            strings: [StringRule(open: "\"", escape: nil)],
            rules: [RegexRule("[,;\\t|]", .operator),
                    RegexRule("\\b\\d+(\\.\\d+)?\\b", .number)])
        result.append(csv)

        // ---- Infrastructure as code ---------------------------------------------------------------
        var hcl = LanguageDefinition.cLike(
            id: "terraform", name: "Terraform / HCL",
            extensions: ["tf", "tfvars", "hcl", "nomad", "workflow"],
            keywords: "resource data variable output provider module locals terraform backend provisioner connection dynamic lifecycle depends_on count for_each each var local self required_providers source version",
            controlKeywords: "for in if else",
            types: "string number bool list map set object tuple any",
            constants: "true false null",
            builtins: "file jsonencode jsondecode yamlencode yamldecode templatefile lookup merge concat length join split format formatlist coalesce try can toset tolist tomap",
            lineComments: ["#", "//"],
            blockComments: [BlockComment("/*", "*/")],
            strings: [StringRule(open: "<<-EOF", close: "EOF", escape: nil, multiline: true),
                      StringRule(open: "\"", interpolationOpen: "${", interpolationClose: "}")])
        result.append(hcl)

        var dockerfile = LanguageDefinition.cLike(
            id: "dockerfile", name: "Dockerfile",
            extensions: ["dockerfile", "containerfile"],
            filenames: ["Dockerfile", "Containerfile", "Dockerfile.dev", "Dockerfile.prod"],
            keywords: "FROM AS RUN CMD LABEL MAINTAINER EXPOSE ENV ADD COPY ENTRYPOINT VOLUME USER WORKDIR ARG ONBUILD STOPSIGNAL HEALTHCHECK SHELL",
            controlKeywords: "",
            types: "",
            constants: "",
            lineComments: ["#"],
            blockComments: [],
            caseInsensitive: true)
        result.append(dockerfile)

        var makefile = LanguageDefinition.cLike(
            id: "makefile", name: "Makefile",
            extensions: ["mk", "mak", "make"],
            filenames: ["Makefile", "makefile", "GNUmakefile", "Makefile.am", "Makefile.in"],
            keywords: "include ifeq ifneq ifdef ifndef else endif define endef export unexport override vpath .PHONY .DEFAULT .PRECIOUS .SUFFIXES",
            controlKeywords: "",
            types: "",
            constants: "",
            builtins: "wildcard patsubst subst filter filter-out sort word words firstword lastword dir notdir suffix basename addsuffix addprefix join foreach call eval shell error warning info",
            lineComments: ["#"],
            blockComments: [],
            rules: [RegexRule("^[A-Za-z0-9_./$(){}%-]+\\s*:(?!=)", .function, options: [.anchorsMatchLines]),
                    RegexRule("\\$[({][^)}]*[)}]", .variable)])
        makefile.indentUnit = "\t"
        result.append(makefile)

        var cmake = LanguageDefinition.cLike(
            id: "cmake", name: "CMake",
            extensions: ["cmake"],
            filenames: ["CMakeLists.txt"],
            keywords: "cmake_minimum_required project set unset list string file include add_executable add_library add_subdirectory target_link_libraries target_include_directories target_compile_options target_compile_definitions find_package find_library install option message get_target_property set_target_properties add_custom_command add_custom_target enable_testing add_test",
            controlKeywords: "if elseif else endif foreach endforeach while endwhile function endfunction macro endmacro return break continue",
            types: "",
            constants: "TRUE FALSE ON OFF YES NO REQUIRED QUIET STATIC SHARED MODULE INTERFACE PUBLIC PRIVATE",
            lineComments: ["#"],
            blockComments: [],
            rules: [RegexRule("\\$\\{[^}]*\\}", .variable)],
            caseInsensitive: true)
        result.append(cmake)

        var starlark = LanguageDefinition.cLike(
            id: "starlark", name: "Starlark / Bazel",
            extensions: ["bzl", "star", "bazel"],
            filenames: ["BUILD", "BUILD.bazel", "WORKSPACE", "WORKSPACE.bazel"],
            keywords: "def load lambda pass return and or not in",
            controlKeywords: "if elif else for break continue",
            types: "",
            constants: "True False None",
            builtins: "cc_library cc_binary java_library py_library py_binary filegroup genrule glob select package licenses exports_files http_archive git_repository",
            lineComments: ["#"],
            blockComments: [])
        starlark.indentAfter = [":"]
        result.append(starlark)

        result.append(LanguageDefinition.cLike(
            id: "protobuf", name: "Protocol Buffers",
            extensions: ["proto"],
            keywords: "syntax package import option message enum service rpc returns extend extensions reserved oneof map repeated optional required stream public weak group",
            controlKeywords: "",
            types: "double float int32 int64 uint32 uint64 sint32 sint64 fixed32 fixed64 sfixed32 sfixed64 bool string bytes",
            constants: "true false"))

        result.append(LanguageDefinition.cLike(
            id: "thrift", name: "Apache Thrift",
            extensions: ["thrift"],
            keywords: "namespace include cpp_include struct union exception service extends enum const typedef required optional oneway throws senum",
            controlKeywords: "",
            types: "bool byte i8 i16 i32 i64 double string binary list set map void",
            constants: "true false"))

        result.append(LanguageDefinition.cLike(
            id: "jsonnet", name: "Jsonnet",
            extensions: ["jsonnet", "libsonnet"],
            keywords: "local function import importstr self super assert tailstrict",
            controlKeywords: "if then else for in error",
            types: "",
            constants: "true false null",
            builtins: "std"))

        result.append(LanguageDefinition.cLike(
            id: "solidity", name: "Solidity",
            extensions: ["sol"],
            keywords: "pragma solidity import contract library interface abstract is using struct enum mapping function modifier event error constructor fallback receive public private internal external pure view payable virtual override immutable constant memory storage calldata returns emit new delete assembly unchecked type indexed anonymous",
            controlKeywords: "if else for while do break continue return try catch revert require assert throw",
            types: "address bool string bytes byte uint uint8 uint16 uint32 uint64 uint128 uint256 int int8 int256 bytes1 bytes32 fixed ufixed",
            constants: "true false wei gwei ether seconds minutes hours days weeks msg block tx now this super",
            builtins: "keccak256 sha256 ripemd160 ecrecover addmod mulmod selfdestruct blockhash gasleft transfer send call delegatecall staticcall abi",
            rules: [RegexRule("@[a-z]+", .annotation)]))

        return result
    }
}
