import Foundation

/// Files written into Documents on first launch so the editor is never empty.
enum SampleFiles {

    static let all: [(String, String)] = [
        ("README.md", readme),
        ("tour.swift", swiftSample),
        ("tour.py", pythonSample),
        ("tour.ts", typescriptSample),
        ("index.html", htmlSample),
        ("config.yaml", yamlSample)
    ]

    static let readme = """
    # CodeForge

    A full-featured code editor for iPhone.

    ## What is here

    - **150+ languages** with a real lexer: strings, escapes, interpolation,
      nested block comments, doc comments, regex literals, preprocessor lines.
    - **Fifteen themes**, dark and light, switchable from Settings.
    - **Find & Replace** with regex, case sensitivity and whole-word options.
    - **Project search** across every file in the workspace.
    - **Tabs**, a file browser, import/export through the Files app.
    - A **code keyboard row** with the symbols a mobile keyboard buries.

    ## Getting around

    | Gesture | Action |
    | --- | --- |
    | Tap the folder icon | Open the project browser |
    | Swipe a file left | Rename, duplicate, delete |
    | Tap the magnifier | Find & replace in the open file |
    | Long-press a tab | Close others |

    > Everything is stored in the app's Documents folder, which is visible from
    > the Files app — so you can drop a whole project in over AirDrop or iCloud.

    ```swift
    print("Happy hacking")
    ```
    """

    static let swiftSample = """
    import Foundation

    /// A tiny expression evaluator — a decent syntax-highlighting stress test.
    enum Token: Equatable {
        case number(Double)
        case symbol(Character)
    }

    struct Lexer {
        let input: String

        func tokens() throws -> [Token] {
            var result: [Token] = []
            var buffer = ""
            for character in input where !character.isWhitespace {
                if character.isNumber || character == "." {
                    buffer.append(character)
                    continue
                }
                if !buffer.isEmpty, let value = Double(buffer) {
                    result.append(.number(value))
                    buffer = ""
                }
                result.append(.symbol(character))
            }
            if let value = Double(buffer) { result.append(.number(value)) }
            return result
        }
    }

    let lexer = Lexer(input: "12 + 3.5 * (7 - 2)")
    print("tokens: \\(try lexer.tokens().count)")
    """

    static let pythonSample = """
    \"\"\"Async fan-out with a bounded worker pool.\"\"\"

    import asyncio
    from dataclasses import dataclass, field


    @dataclass(slots=True)
    class Result:
        url: str
        status: int = 0
        body: bytes = b""
        headers: dict[str, str] = field(default_factory=dict)


    async def fetch(session, url: str, *, retries: int = 3) -> Result:
        for attempt in range(retries):
            try:
                async with session.get(url) as response:
                    return Result(url, response.status, await response.read())
            except asyncio.TimeoutError:
                await asyncio.sleep(2 ** attempt)
        raise RuntimeError(f"giving up on {url!r} after {retries} attempts")


    if __name__ == "__main__":
        print(f"{len(URLS := ['https://example.com'])} target(s)")
    """

    static let typescriptSample = """
    type Result<T, E = Error> =
      | { ok: true; value: T }
      | { ok: false; error: E };

    export async function retry<T>(
      task: () => Promise<T>,
      attempts = 3,
      backoffMs = 250,
    ): Promise<Result<T>> {
      for (let i = 0; i < attempts; i++) {
        try {
          return { ok: true, value: await task() };
        } catch (error) {
          if (i === attempts - 1) return { ok: false, error: error as Error };
          await new Promise((r) => setTimeout(r, backoffMs * 2 ** i));
        }
      }
      throw new Error("unreachable");
    }

    const isEmail = /^[^@\\s]+@[^@\\s]+\\.[a-z]{2,}$/i;
    console.log(`valid: ${isEmail.test("dev@example.com")}`);
    """

    static let htmlSample = """
    <!DOCTYPE html>
    <html lang="ja">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>CodeForge</title>
        <style>
          :root { --bg: #0b0f17; --fg: #d6deeb; --accent: #62b4ff; }
          body { background: var(--bg); color: var(--fg); font: 16px/1.6 system-ui; }
          .card { border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 12px; }
        </style>
      </head>
      <body>
        <main class="card" data-role="root">
          <h1>Hello, world</h1>
          <button id="go" type="button">Run</button>
        </main>
        <script>
          document.querySelector("#go").addEventListener("click", () => {
            console.log("clicked at", new Date().toISOString());
          });
        </script>
      </body>
    </html>
    """

    static let yamlSample = """
    # Deployment description
    name: codeforge
    version: 1.0.0

    build:
      image: swift:6.0
      steps:
        - name: Compile
          run: swift build -c release
        - name: Test
          run: swift test --parallel

    environments:
      staging: &defaults
        replicas: 2
        resources: { cpu: 500m, memory: 512Mi }
      production:
        <<: *defaults
        replicas: 6
        flags: [--verbose, --metrics]
    """
}
