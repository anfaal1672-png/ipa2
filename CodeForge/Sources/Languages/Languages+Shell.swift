import Foundation

extension Languages {

    static var shell: [LanguageDefinition] {
        var result: [LanguageDefinition] = []

        // ---- POSIX shell / Bash ---------------------------------------------------
        var bash = LanguageDefinition.cLike(
            id: "shell", name: "Shell / Bash",
            extensions: ["sh", "bash", "zsh", "ksh", "ash", "bashrc", "zshrc", "profile",
                         "bash_profile", "zprofile", "aliases", "envrc"],
            filenames: [".bashrc", ".zshrc", ".bash_profile", ".profile", ".zprofile",
                        ".bash_aliases", "configure", "install.sh"],
            keywords: "function local export readonly declare typeset let eval exec source alias unalias set unset shift trap return exit builtin command time coproc",
            controlKeywords: "if then elif else fi for while until do done case esac in select break continue",
            types: "",
            constants: "true false",
            builtins: "echo printf read cd pwd ls cp mv rm mkdir rmdir touch cat head tail grep egrep sed awk cut sort uniq wc find xargs chmod chown ln df du ps kill sleep test date curl wget tar gzip zip unzip ssh scp rsync git make sudo apt brew npm yarn python pip docker kubectl systemctl",
            lineComments: ["#"],
            blockComments: [],
            rules: [RegexRule("\\$\\{[^}]*\\}|\\$[A-Za-z_][A-Za-z0-9_]*|\\$[0-9@*#?$!]", .variable),
                    RegexRule("\\$\\([^)]*\\)", .interpolation),
                    RegexRule("^[ \\t]*([A-Za-z_][A-Za-z0-9_]*)\\s*\\(\\)", .function, group: 1, options: [.anchorsMatchLines]),
                    RegexRule("(^|\\s)(-{1,2}[A-Za-z][A-Za-z0-9-]*)", .annotation, group: 2)])
        bash.strings = [StringRule(open: "\"", interpolationOpen: "${", interpolationClose: "}"),
                        StringRule(open: "'", escape: nil)]
        bash.shebangs = ["sh", "bash", "zsh"]
        bash.indentAfter = ["then", "do", "{", "("]
        bash.dedentTokens = ["fi", "done", "esac", "}", ")", "else", "elif"]
        bash.keyboardExtras = ["$", "|", "-", "/", "\"", "'", "&", ">", "*", "~"]
        result.append(bash)

        var fish = bash
        fish.id = "fish"
        fish.name = "Fish Shell"
        fish.extensions = ["fish"]
        fish.keywords = Set("function set setenv end source alias abbr bind status test math string".split(separator: " ").map(String.init))
        fish.controlKeywords = ["if", "else", "switch", "case", "for", "while", "begin", "and", "or", "not", "return", "break", "continue"]
        result.append(fish)

        // ---- PowerShell ---------------------------------------------------------------
        var ps = LanguageDefinition.cLike(
            id: "powershell", name: "PowerShell",
            extensions: ["ps1", "psm1", "psd1"],
            keywords: "function filter workflow configuration param begin process end class enum using module namespace dynamicparam data inlinescript parallel sequence hidden static",
            controlKeywords: "if elseif else switch foreach for while do until break continue return try catch finally throw trap exit",
            types: "string int long double decimal bool char byte array hashtable psobject pscustomobject scriptblock datetime void",
            constants: "true false null $true $false $null $_ $args $PSItem $PSScriptRoot $Error $Host",
            builtins: "Write-Host Write-Output Write-Error Write-Verbose Get-ChildItem Get-Content Set-Content Get-Item Set-Item New-Item Remove-Item Copy-Item Move-Item Test-Path Select-Object Where-Object ForEach-Object Sort-Object Measure-Object Group-Object Import-Module Export-ModuleMember Invoke-WebRequest Invoke-RestMethod Start-Process Get-Process Stop-Process ConvertTo-Json ConvertFrom-Json Join-Path Split-Path",
            lineComments: ["#"],
            blockComments: [BlockComment("<#", "#>")],
            rules: [RegexRule("\\$[A-Za-z_][A-Za-z0-9_:]*", .variable),
                    RegexRule("(^|\\s)(-[A-Za-z][A-Za-z0-9]*)", .annotation, group: 2)],
            identifierExtras: ["_", "-"],
            caseInsensitive: true)
        ps.strings = [StringRule(open: "@\"", close: "\"@", multiline: true),
                      StringRule(open: "\"", escape: "`"), StringRule(open: "'", escape: nil)]
        result.append(ps)

        // ---- Windows batch --------------------------------------------------------------
        let batch = LanguageDefinition.cLike(
            id: "batch", name: "Batch / CMD",
            extensions: ["bat", "cmd"],
            keywords: "set setlocal endlocal call start exit shift pushd popd echo",
            controlKeywords: "if else for goto do in not exist errorlevel defined",
            types: "",
            constants: "on off nul",
            builtins: "dir copy xcopy move del rd md cd type find findstr sort more attrib timeout ping tasklist taskkill",
            lineComments: ["rem ", "REM ", "::"],
            blockComments: [],
            rules: [RegexRule("%[A-Za-z0-9_~]+%|%%[A-Za-z]", .variable),
                    RegexRule("^\\s*:[A-Za-z_][A-Za-z0-9_]*", .function, options: [.anchorsMatchLines])],
            caseInsensitive: true)
        result.append(batch)

        // ---- awk / sed -------------------------------------------------------------------
        result.append(LanguageDefinition.cLike(
            id: "awk", name: "AWK",
            extensions: ["awk", "gawk"],
            keywords: "function getline delete BEGIN END print printf next nextfile exit",
            controlKeywords: "if else while for do break continue return",
            types: "",
            constants: "NR NF FS OFS ORS RS FILENAME RSTART RLENGTH SUBSEP",
            builtins: "length substr index split sub gsub match sprintf sin cos atan2 exp log sqrt int rand srand tolower toupper system close fflush",
            lineComments: ["#"],
            blockComments: []))

        // ---- Nginx / Apache / server config ------------------------------------------------
        let nginx = LanguageDefinition.cLike(
            id: "nginx", name: "Nginx Config",
            extensions: ["nginx"],
            filenames: ["nginx.conf"],
            keywords: "server location upstream http events stream mail map geo split_clients include listen server_name root index try_files proxy_pass proxy_set_header fastcgi_pass return rewrite error_page access_log error_log ssl_certificate ssl_certificate_key add_header client_max_body_size gzip worker_processes worker_connections user pid",
            controlKeywords: "if set break",
            types: "",
            constants: "on off",
            lineComments: ["#"],
            blockComments: [],
            rules: [RegexRule("\\$[A-Za-z_][A-Za-z0-9_]*", .variable)])
        result.append(nginx)

        result.append(LanguageDefinition.cLike(
            id: "apache", name: "Apache Config",
            extensions: ["htaccess", "htpasswd"],
            filenames: [".htaccess", "httpd.conf", "apache2.conf"],
            keywords: "ServerRoot Listen LoadModule ServerName ServerAdmin DocumentRoot Directory DirectoryIndex Options AllowOverride Require Order Allow Deny ErrorLog CustomLog RewriteEngine RewriteRule RewriteCond RewriteBase VirtualHost Location Files FilesMatch LocationMatch DirectoryMatch Alias ScriptAlias ProxyPass ProxyPassReverse Header SetEnv",
            controlKeywords: "IfModule IfDefine",
            types: "",
            constants: "On Off All None",
            lineComments: ["#"],
            blockComments: [],
            caseInsensitive: true))

        result.append(LanguageDefinition.cLike(
            id: "crontab", name: "Crontab",
            extensions: ["cron", "crontab"],
            filenames: ["crontab"],
            keywords: "SHELL PATH MAILTO CRON_TZ",
            controlKeywords: "",
            types: "",
            constants: "@reboot @yearly @annually @monthly @weekly @daily @midnight @hourly",
            lineComments: ["#"],
            blockComments: []))

        result.append(LanguageDefinition.cLike(
            id: "gitignore", name: "Git Ignore / Attributes",
            extensions: ["gitignore", "gitattributes", "dockerignore", "npmignore", "eslintignore"],
            filenames: [".gitignore", ".gitattributes", ".dockerignore", ".npmignore", ".prettierignore"],
            keywords: "",
            controlKeywords: "",
            types: "",
            constants: "",
            lineComments: ["#"],
            blockComments: [],
            strings: [],
            rules: [RegexRule("^!.*$", .deleted, options: [.anchorsMatchLines]),
                    RegexRule("[*?\\[\\]]", .operator)]))

        var vim = LanguageDefinition.cLike(
            id: "vim", name: "Vim Script",
            extensions: ["vim", "vimrc"],
            filenames: [".vimrc", "init.vim", ".gvimrc"],
            keywords: "function endfunction let unlet set setlocal setglobal call execute source autocmd augroup command nnoremap inoremap vnoremap xnoremap map noremap imap nmap highlight syntax filetype colorscheme normal echo echom echoerr silent",
            controlKeywords: "if elseif else endif for endfor while endwhile try catch finally endtry return break continue",
            types: "",
            constants: "v:true v:false v:null on off",
            lineComments: ["\""],
            blockComments: [],
            rules: [RegexRule("[bwglstav]:[A-Za-z_][A-Za-z0-9_]*", .variable)])
        vim.strings = [StringRule(open: "'", escape: nil)]
        result.append(vim)

        return result
    }

    static var scientific: [LanguageDefinition] {
        var result: [LanguageDefinition] = []

        let r = LanguageDefinition.cLike(
            id: "r", name: "R",
            extensions: ["r", "rmd", "rdata", "rds", "rprofile"],
            filenames: [".Rprofile", "DESCRIPTION", "NAMESPACE"],
            keywords: "function return library require source attach detach with within local on.exit invisible UseMethod NextMethod setClass setGeneric setMethod R6Class",
            controlKeywords: "if else for while repeat break next switch stop warning tryCatch",
            types: "numeric integer character logical complex raw list vector matrix array data.frame factor tibble",
            constants: "TRUE FALSE NULL NA NA_integer_ NA_real_ NA_character_ Inf NaN T F",
            builtins: "c print cat paste paste0 length nrow ncol dim names colnames rownames head tail summary str seq rep sapply lapply vapply mapply apply do.call Reduce Filter Map ifelse is.na na.omit mean median sd var sum min max round abs sqrt exp log factor levels table merge rbind cbind subset order sort unique which read.csv write.csv ggplot aes geom_point mutate filter select group_by summarise arrange",
            lineComments: ["#"],
            blockComments: [],
            identifierExtras: ["_", "."])
        result.append(r)

        var julia = LanguageDefinition.cLike(
            id: "julia", name: "Julia",
            extensions: ["jl"],
            keywords: "function macro module baremodule using import export struct mutable abstract primitive type where global local const let quote begin end do in isa new return outer",
            controlKeywords: "if elseif else for while break continue try catch finally throw",
            types: "Int Int8 Int16 Int32 Int64 UInt Float16 Float32 Float64 Bool Char String Symbol Array Vector Matrix Tuple NamedTuple Dict Set Range Complex Rational Any Nothing Missing Union",
            constants: "true false nothing missing nan Inf pi ℯ",
            builtins: "println print push! pop! append! length size sum prod minimum maximum sort map filter reduce zip enumerate collect reshape rand randn zeros ones fill similar @time @show @assert @views",
            lineComments: ["#"],
            blockComments: [BlockComment("#=", "=#", nested: true)],
            rules: [RegexRule("@[A-Za-z_][A-Za-z0-9_.!]*", .annotation)],
            identifierExtras: ["_", "!"])
        julia.strings = [StringRule(open: "\"\"\"", close: "\"\"\"", multiline: true),
                         StringRule(open: "\"", interpolationOpen: "$(", interpolationClose: ")"),
                         StringRule(open: "'")]
        julia.indentAfter = ["function", "begin", "do", "(", "[", "{"]
        julia.dedentTokens = ["end", ")", "]", "}", "else", "elseif", "catch", "finally"]
        result.append(julia)

        var matlab = LanguageDefinition.cLike(
            id: "matlab", name: "MATLAB / Octave",
            extensions: ["mat", "matlab", "octave"],
            keywords: "function end global persistent classdef properties methods events enumeration arguments nargin nargout varargin varargout",
            controlKeywords: "if elseif else for while switch case otherwise break continue return try catch parfor",
            types: "double single int8 int16 int32 int64 uint8 uint16 uint32 uint64 logical char string cell struct table",
            constants: "true false pi Inf NaN eps i j ans",
            builtins: "disp fprintf sprintf size length numel zeros ones eye rand randn linspace reshape sum prod mean median std max min sort find any all isempty isnan strcmp strcat num2str str2num plot figure hold xlabel ylabel title legend axis subplot",
            lineComments: ["%", "#"],
            blockComments: [BlockComment("%{", "%}")])
        matlab.strings = [StringRule(open: "\""), StringRule(open: "'", escape: nil)]
        result.append(matlab)

        let fortran = LanguageDefinition.cLike(
            id: "fortran", name: "Fortran",
            extensions: ["f", "for", "f77", "f90", "f95", "f03", "f08", "ftn"],
            keywords: "program module submodule subroutine function end contains use implicit none intent in out inout parameter dimension allocatable pointer target save external internal interface type class abstract extends procedure public private result recursive pure elemental call allocate deallocate nullify common equivalence data block",
            controlKeywords: "if then else elseif endif do while enddo select case default cycle exit go to return stop continue where forall associate",
            types: "integer real double precision complex logical character kind len",
            constants: ".true. .false. .and. .or. .not. .eqv. .neqv. .eq. .ne. .lt. .le. .gt. .ge.",
            builtins: "print write read open close format allocated associated present size shape sum product maxval minval abs sqrt exp log sin cos tan trim adjustl adjustr len_trim",
            lineComments: ["!", "c ", "C "],
            blockComments: [],
            identifierExtras: ["_"],
            caseInsensitive: true)
        result.append(fortran)

        result.append(LanguageDefinition.cLike(
            id: "sas", name: "SAS",
            extensions: ["sas"],
            keywords: "data set proc run quit libname filename infile input output format informat length label keep drop rename retain array merge by where var class model title footnote options ods",
            controlKeywords: "if then else do end while until select when otherwise",
            types: "",
            constants: "_n_ _null_ _all_",
            lineComments: ["*"],
            blockComments: [BlockComment("/*", "*/")],
            caseInsensitive: true))

        result.append(LanguageDefinition.cLike(
            id: "stata", name: "Stata",
            extensions: ["do", "ado", "dta"],
            keywords: "program define end syntax args local global scalar matrix use save clear set display list generate replace egen drop keep merge append sort by bysort collapse reshape label",
            controlKeywords: "if else foreach forvalues while continue break exit return",
            types: "",
            constants: "_N _n",
            lineComments: ["*", "//"],
            blockComments: [BlockComment("/*", "*/")]))

        result.append(LanguageDefinition.cLike(
            id: "mathematica", name: "Wolfram / Mathematica",
            extensions: ["nb", "wl", "wls", "m"],
            keywords: "Module Block With Function Set SetDelayed Rule RuleDelayed Pattern Blank Condition",
            controlKeywords: "If Which Switch Do While For Table Map Apply Nest Fold Return Break Continue Throw Catch",
            types: "Integer Real Complex String Symbol List Association",
            constants: "True False None Null Pi E I Infinity Automatic All",
            builtins: "Print Plot Plot3D ListPlot Solve NSolve Integrate D Sum Product Simplify FullSimplify Expand Factor Length Part Append Prepend Join Sort Select Range",
            lineComments: [],
            blockComments: [BlockComment("(*", "*)", nested: true)]))

        return result
    }
}
