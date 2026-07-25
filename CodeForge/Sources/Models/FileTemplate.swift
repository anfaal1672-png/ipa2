import Foundation

/// A starting point offered in the "new file" sheet. Beginners pick a type
/// instead of guessing a file extension, and get a working snippet rather than
/// an empty buffer.
struct FileTemplate: Identifiable {
    let id: String
    let englishName: String
    let fileExtension: String
    let icon: String
    let suggestedName: String
    let body: String

    var name: String { L(englishName) }

    var isCustom: Bool { id == "custom" }

    static let all: [FileTemplate] = [
        FileTemplate(id: "text", englishName: "Text note", fileExtension: "txt",
                     icon: "doc.text", suggestedName: "memo", body: ""),

        FileTemplate(id: "markdown", englishName: "Markdown document", fileExtension: "md",
                     icon: "doc.richtext", suggestedName: "note", body: """
                     # 見出し

                     ここに本文を書きます。

                     - 箇条書き 1
                     - 箇条書き 2

                     ```swift
                     print("コードもそのまま貼れます")
                     ```
                     """),

        FileTemplate(id: "python", englishName: "Python script", fileExtension: "py",
                     icon: "chevron.left.forwardslash.chevron.right", suggestedName: "script", body: """
                     def main() -> None:
                         print("Hello, world!")


                     if __name__ == "__main__":
                         main()
                     """),

        FileTemplate(id: "javascript", englishName: "JavaScript file", fileExtension: "js",
                     icon: "chevron.left.forwardslash.chevron.right", suggestedName: "main", body: """
                     function greet(name) {
                       return `Hello, ${name}!`;
                     }

                     console.log(greet("world"));
                     """),

        FileTemplate(id: "html", englishName: "Web page (HTML)", fileExtension: "html",
                     icon: "globe", suggestedName: "index", body: """
                     <!DOCTYPE html>
                     <html lang="ja">
                       <head>
                         <meta charset="utf-8" />
                         <meta name="viewport" content="width=device-width, initial-scale=1" />
                         <title>ページのタイトル</title>
                         <style>
                           body { font-family: system-ui; margin: 2rem; line-height: 1.7; }
                         </style>
                       </head>
                       <body>
                         <h1>こんにちは</h1>
                         <p>ここに内容を書きます。</p>
                       </body>
                     </html>
                     """),

        FileTemplate(id: "css", englishName: "Stylesheet (CSS)", fileExtension: "css",
                     icon: "paintbrush", suggestedName: "style", body: """
                     :root {
                       --accent: #62b4ff;
                     }

                     body {
                       margin: 0;
                       font-family: system-ui, sans-serif;
                       color: #222;
                     }
                     """),

        FileTemplate(id: "swift", englishName: "Swift file", fileExtension: "swift",
                     icon: "swift", suggestedName: "Main", body: """
                     import Foundation

                     struct Greeter {
                         let name: String

                         func greet() -> String {
                             "Hello, \\(name)!"
                         }
                     }

                     print(Greeter(name: "world").greet())
                     """),

        FileTemplate(id: "json", englishName: "JSON data", fileExtension: "json",
                     icon: "list.bullet.rectangle", suggestedName: "data", body: """
                     {
                       "name": "example",
                       "version": "1.0.0",
                       "items": [1, 2, 3]
                     }
                     """),

        FileTemplate(id: "shell", englishName: "Shell script", fileExtension: "sh",
                     icon: "terminal", suggestedName: "run", body: """
                     #!/usr/bin/env bash
                     set -euo pipefail

                     echo "Hello, world!"
                     """),

        FileTemplate(id: "custom", englishName: "Other (type the extension)", fileExtension: "",
                     icon: "ellipsis.circle", suggestedName: "file", body: "")
    ]
}
