# CodeForge

An offline, full-featured code editor for iPhone — written in Swift/SwiftUI with
a hand-written syntax engine, no third-party dependencies and no network access.

## Features

**Editing**
- Custom `NSTextStorage` highlighter: instant colouring of the edited lines plus a
  debounced background pass over the whole document, so multi-line constructs
  (block comments, heredocs, template literals) stay correct while typing.
- Auto-indent that follows the language's block openers, bracket/quote
  completion with selection wrapping, smart backspace over indentation and
  matched pairs, indent/outdent of a selection, comment toggling, duplicate and
  delete line.
- Line numbers, current-line highlight, indentation guides, soft wrap toggle,
  configurable tab width and spaces-vs-tabs.
- A code keyboard row above the system keyboard whose symbols change per
  language (Python offers `:`, shell offers `$` and `|`, Swift offers `?` `!` …).

**Languages** — 150+ definitions covering C/C++/Objective-C, Swift, Rust, Go,
Zig, Java, Kotlin, Scala, C#, JavaScript/TypeScript/JSX/TSX, Python, Ruby, PHP,
Perl, Lua, Dart, Haskell, OCaml, F#, Elixir, Erlang, Clojure, Lisp, SQL, HTML,
CSS/SCSS/Less, Markdown, YAML, TOML, JSON, XML, Dockerfile, Makefile, CMake,
Terraform, shell/PowerShell/batch, assembly, LLVM IR, Verilog/VHDL, Solidity,
R/Julia/MATLAB/Fortran and many more. HTML embeds JavaScript and CSS; Markdown
fences highlight with the fenced language.

**Files** — a project browser over the app's Documents folder (visible in the
Files app), create/rename/duplicate/delete, import from Files, share out,
tabs with dirty markers, session restore, and project-wide search with regex.

**Find & replace** — case sensitivity, whole word, regular expressions, match
counter, replace one/all.

**Themes** — 15 built-in themes (Midnight, Nova, Monokai Pro, Dracula, Nord,
Solarized, Gruvbox, One Dark, Tokyo Night, Catppuccin, GitHub, Xcode Light,
Paper, High Contrast …) with an optional light/dark pair that follows the system.

## Building

The Xcode project is generated from the files on disk:

```sh
python3 Tools/generate_project.py
open CodeForge.xcodeproj
```

To build an **unsigned** `.ipa` locally (macOS + Xcode required):

```sh
xcodebuild -project CodeForge.xcodeproj -scheme CodeForge \
  -configuration Release -sdk iphoneos -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build

mkdir -p Payload && cp -R build/Build/Products/Release-iphoneos/CodeForge.app Payload/
zip -qry CodeForge-unsigned.ipa Payload
```

CI does exactly this on every push and attaches `CodeForge-unsigned.ipa` to a
GitHub release — see `.github/workflows/build-ipa.yml`.

## Installing an unsigned IPA

An unsigned IPA cannot be installed by iOS as-is; it must be signed with some
certificate first. Common routes: **Sideloadly** or **AltStore** (they sign with
your Apple ID, free account = 7-day validity), **Xcode → Devices → Install**, or
**TrollStore** on supported iOS versions.

## Layout

```
CodeForge/Sources/App        app entry point, settings model
CodeForge/Sources/Editor     text storage, text view, scanner, themes, toolbar
CodeForge/Sources/Languages  language catalogue (definitions + registry)
CodeForge/Sources/Models     documents, file tree, samples
CodeForge/Sources/Services   workspace store (tabs, file ops, project search)
CodeForge/Sources/UI         SwiftUI screens
Tools/                       project + icon generators
```

Deployment target iOS 16.0, iPhone and iPad, no external packages.
