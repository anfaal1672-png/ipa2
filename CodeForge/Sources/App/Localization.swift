import Foundation
import SwiftUI

/// App language. "System" follows the device setting; the other two let a
/// beginner force the UI into a language they read, without digging through
/// the iOS settings app.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case japanese
    case english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return L("Follow system")
        case .japanese: return "日本語"
        case .english: return "English"
        }
    }

    var isJapanese: Bool {
        switch self {
        case .japanese: return true
        case .english: return false
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.hasPrefix("ja")
        }
    }
}

/// Shorthand used throughout the UI. The English string is the key, so an
/// untranslated string still reads correctly instead of showing a raw key.
func L(_ key: String) -> String {
    Localization.shared.string(key)
}

/// Tiny in-app localisation table.
///
/// A `.lproj` bundle would be the usual answer, but the project file is
/// generated from disk and variant groups would complicate that for two
/// languages; a table keeps everything in Swift and lets the user switch
/// language live, without relaunching.
final class Localization {

    static let shared = Localization()

    var language: AppLanguage = .system

    func string(_ key: String) -> String {
        guard language.isJapanese else { return key }
        return Localization.japanese[key] ?? key
    }

    // MARK: - Table

    /// Built through `uniquingKeysWith` rather than a dictionary literal: a
    /// literal *traps at runtime* on a duplicate key, so one careless copy of a
    /// line becomes a crash on launch for every Japanese user.
    static let japanese: [String: String] =
        Dictionary(entries, uniquingKeysWith: { _, latest in latest })

    /// Keys present more than once. Harmless at runtime now that the table is
    /// built with `uniquingKeysWith`, but always a mistake — the self test
    /// fails on it so a stray copy is caught in CI rather than in the UI.
    static var duplicateKeys: [String] {
        var seen = Set<String>()
        return entries.compactMap { seen.insert($0.0).inserted ? nil : $0.0 }
    }

    private static let entries: [(String, String)] = [
        // --- toolbar / global -------------------------------------------
        ("Project", "ファイル"),
        ("Project browser", "ファイル一覧"),
        ("New file", "新規ファイル"),
        ("New folder", "新規フォルダ"),
        ("New file here", "ここに新規ファイル"),
        ("New folder here", "ここに新規フォルダ"),
        ("Find in file", "このファイル内を検索"),
        ("Save", "保存"),
        ("Saved", "保存済み"),
        ("Unsaved changes", "未保存の変更"),
        ("Settings", "設定"),
        ("Menu", "メニュー"),
        ("Preview", "プレビュー"),
        ("Reload", "再読み込み"),
        ("Console", "コンソール"),
        ("Clear console", "コンソールを消去"),
        ("Copy", "コピー"),
        ("Copy all", "すべてコピー"),
        ("Copied", "コピーしました"),
        ("Repeated", "同じ出力の回数"),
        ("Too many different messages — the rest are not shown.",
         "異なるメッセージが多すぎるため、これ以降は表示しません。"),
        ("Full screen", "フルスクリーン"),
        ("Exit full screen", "フルスクリーンを終了"),
        ("Tap the screen to show the buttons again",
         "ボタンが消えたら画面をタップすると戻ります"),
        ("No console output", "出力はまだありません"),
        ("Reload when the file changes", "変更したら自動で再読み込み"),
        ("This file type cannot be previewed", "この種類のファイルはプレビューできません"),
        ("This file type cannot be run on the device", "この言語は端末上で実行できません"),
        ("iOS does not let an app generate machine code at runtime, so a compiler for this language cannot ship inside the app. Interpreters can, and these are bundled:",
             "iOS はアプリが実行時に機械語を生成することを許していないため、この言語のコンパイラは同梱できません。インタプリタは同梱でき、以下が入っています:"),
        ("Rendered and executed by the system web engine.", "システムのWebエンジンで描画・実行します。"),
        ("The runtime could not start", "ランタイムを起動できませんでした"),
        ("Bundled runtimes", "同梱している実行環境"),
        ("Sort by", "並び替え"),
        ("Last modified", "更新日"),
        ("1 item", "1 個"),
        ("items", "個"),
        ("Run this file", "このファイルを実行"),
        ("Runnable", "実行できます"),
        ("A few things to know", "はじめに知っておくと便利なこと"),
        ("Run what you write", "書いたコードを動かせます"),
        ("Python, Lua, SQL, JavaScript and HTML run on the phone — tap Run in the toolbar. Everything else previews as text.",
             "Python・Lua・SQL・JavaScript・HTML はこの端末で実行できます。上部の「実行」をタップしてください。それ以外の言語は表示のみです。"),
        ("Running code", "コードを動かす"),
        ("Python, Lua, SQL and JavaScript run on the device; HTML, CSS, Markdown, JSON and SVG render. The run key also sits in the keyboard row.",
             "Python・Lua・SQL・JavaScript は端末上で実行、HTML・CSS・Markdown・JSON・SVG は描画されます。実行キーはキーボードの上の列にもあります。"),
        ("See the output", "出力を見る"),
        ("print() and console.log() land in the console panel, which opens by itself when something fails.",
             "print() や console.log() の出力はコンソールに表示されます。エラーが出たときは自動で開きます。"),
        ("These run inside the app, offline. HTML, CSS, JavaScript, Markdown, JSON and SVG are handled by the system web engine.",
             "これらはアプリ内でオフライン実行されます。HTML・CSS・JavaScript・Markdown・JSON・SVG はシステムのWebエンジンが担当します。"),
        ("Run", "実行"),
        ("HTML, Markdown, CSS, JavaScript, JSON and SVG can be previewed. Other languages need a compiler or runtime that iOS does not allow apps to ship.",
             "HTML・Markdown・CSS・JavaScript・JSON・SVG はプレビューできます。他の言語は、iOSがAppに同梱を許可していないコンパイラや実行環境が必要です。"),
        ("Valid JSON", "JSON として正しい形式です"),
        ("Invalid JSON", "JSON の形式が正しくありません"),
        ("Script ran. Output goes to the console.", "スクリプトを実行しました。出力はコンソールに表示されます。"),
        ("Large file — colouring only the visible part", "大きいファイルのため、表示中の部分だけ色付けしています"),
        ("Help", "使い方"),
        ("Share file", "ファイルを共有"),
        ("Done", "完了"),
        ("Cancel", "キャンセル"),
        ("Create", "作成"),
        ("Open", "開く"),
        ("Close", "閉じる"),
        ("OK", "OK"),
        ("Back", "戻る"),
        ("Next", "次へ"),
        ("Start", "はじめる"),
        ("Skip", "スキップ"),
        ("Delete", "削除"),
        ("Rename", "名前を変更"),
        ("Duplicate", "複製"),
        ("Refresh", "更新"),
        ("Close others", "他のタブを閉じる"),
        ("Close all", "すべてのタブを閉じる"),
        ("Copy name", "ファイル名をコピー"),
        ("Dark", "ダーク"),
        ("Light", "ライト"),
        ("Import from Files", "「ファイル」App から読み込む"),
        ("Something went wrong", "エラーが発生しました"),

        // --- editor menu -------------------------------------------------
        ("Toggle comment", "コメントの切り替え"),
        ("Duplicate line", "行を複製"),
        ("Delete line", "行を削除"),
        ("Search in project", "すべてのファイルを検索"),
        ("Go to line…", "指定の行へ移動…"),
        ("Go to line", "指定の行へ移動"),
        ("Line number", "行番号"),
        ("Go", "移動"),
        ("Undo", "取り消す"),
        ("Redo", "やり直す"),
        ("Syntax", "言語(シンタックス)"),
        ("Auto", "自動"),
        ("Language", "言語"),

        // --- status bar ----------------------------------------------------
        ("Ln", "行"),
        ("Col", "列"),
        ("lines", "行"),
        ("selected", "文字を選択中"),
        ("characters", "文字"),

        // --- welcome / onboarding -------------------------------------------
        ("A code editor for every language you carry around.",
             "どんな言語でも書ける、ポケットの中のコードエディタ。"),
        ("Open a file", "ファイルを開く"),
        ("Open the sample project", "サンプルを開いてみる"),
        ("languages", "言語"),
        ("themes", "テーマ"),
        ("Welcome to CodeForge", "CodeForge へようこそ"),
        ("Three things to know", "はじめに知っておくと便利な3つのこと"),
        ("Your files live here", "ファイルはここにあります"),
        ("The folder icon at the top left opens your files. Everything is saved inside this app and is also visible in the iPhone Files app.",
             "左上のフォルダアイコンでファイル一覧を開きます。ファイルはこのApp内に保存され、iPhoneの「ファイル」Appからも見られます。"),
        ("The extra key row", "コード用キーボード"),
        ("Above the keyboard you get the symbols code needs — brackets, quotes, arrows — and they change to match the language you are editing.",
             "キーボードの上に、コードでよく使う記号（括弧・引用符・矢印など）が並びます。編集中の言語に合わせて中身が変わります。"),
        ("Nothing to save manually", "保存は自動です"),
        ("Your work is saved automatically as you type. The dot next to the file name means there are changes still being written.",
             "入力した内容は自動で保存されます。ファイル名の横の点は、書き込み中の変更があることを示します。"),
        ("Got it", "はじめる"),
        ("Show this again from Help", "この案内は「使い方」からいつでも開けます"),

        // --- new file flow ---------------------------------------------------
        ("What do you want to make?", "何を作りますか？"),
        ("Pick a file type; the extension is added for you.",
             "種類を選ぶだけで、拡張子は自動で付きます。"),
        ("File name", "ファイル名"),
        ("Choose a type", "種類を選ぶ"),
        ("Start from an example", "サンプルの内容から始める"),
        ("Empty file", "空のファイル"),
        ("Text note", "テキストメモ"),
        ("Other (type the extension)", "その他（拡張子を自分で入力）"),
        ("Name", "名前"),
        ("will be saved as", "保存されるファイル名"),
        ("Create file", "ファイルを作成"),

        // --- file browser -------------------------------------------------------
        ("Documents", "書類"),
        ("Filter files", "ファイルを絞り込む"),
        ("This folder is visible in the Files app under “On My iPhone › CodeForge”.",
             "このフォルダは「ファイル」App の「このiPhone内 › CodeForge」から見られます。"),
        ("No files yet", "まだファイルがありません"),
        ("Tap + to make your first file.", "右上の + から最初のファイルを作りましょう。"),
        ("Delete this item?", "削除しますか？"),
        ("This cannot be undone.", "この操作は取り消せません。"),
        ("already exists.", "はすでに存在します。"),
        ("That name is taken", "同じ名前のファイルがあります"),
        ("“%@” already exists. Create “%@” instead?",
         "「%@」はすでにあります。「%@」として作成しますか？"),
        ("This file is not text (binary content).", "このファイルはテキストではありません（バイナリ）。"),

        // --- find & replace --------------------------------------------------------
        ("Find", "検索"),
        ("Replace with", "置換後の文字"),
        ("Replace", "置換"),
        ("All", "すべて"),
        ("Case sensitive", "大文字と小文字を区別"),
        ("Whole word", "単語単位"),
        ("Regular expression", "正規表現"),
        ("matches", "件"),
        ("No matches", "見つかりませんでした"),
        ("Search all files", "すべてのファイルを検索"),
        ("line", "行目"),

        // --- settings ------------------------------------------------------------------
        ("Appearance", "見た目"),
        ("Theme", "テーマ"),
        ("Light theme", "ライトテーマ"),
        ("Follow system light/dark", "システムのライト/ダークに合わせる"),
        ("Follow system", "システムに合わせる"),
        ("App language", "表示言語"),
        ("Typography", "文字"),
        ("Font", "フォント"),
        ("Size", "サイズ"),
        ("Editing", "編集"),
        ("Tab width", "インデント幅"),
        ("Insert spaces instead of tabs", "タブの代わりにスペースを入れる"),
        ("Auto indent", "自動インデント"),
        ("Auto close brackets & quotes", "括弧・引用符の自動補完"),
        ("Auto save", "自動保存"),
        ("Display", "表示"),
        ("Syntax highlighting", "シンタックスハイライト"),
        ("Line numbers", "行番号"),
        ("Wrap long lines", "長い行を折り返す"),
        ("Highlight current line", "カーソル行を強調"),
        ("Indentation guides", "インデントの目安線"),
        ("Code keyboard row", "コード用キーボード"),
        ("Pinch to change text size", "ピンチで文字サイズを変える"),
        ("Languages", "対応言語"),
        ("Supported languages", "対応している言語"),
        ("Search languages", "言語を検索"),
        ("About", "このApp について"),
        ("Version", "バージョン"),
        ("Build", "ビルド"),
        ("CodeForge — an offline code editor. Files live in the app's Documents folder and are reachable from the Files app.",
             "CodeForge はオフラインで動くコードエディタです。ファイルはApp内の書類フォルダに保存され、「ファイル」App からも扱えます。"),
        ("Show the welcome guide again", "はじめての案内をもう一度見る"),
        ("Reset to defaults", "初期設定に戻す"),

        // --- help ---------------------------------------------------------------------------
        ("How to use CodeForge", "CodeForge の使い方"),
        ("Basics", "基本"),
        ("Open the file list", "ファイル一覧を開く"),
        ("Tap the folder icon at the top left.", "左上のフォルダアイコンをタップします。"),
        ("Make a new file", "新しいファイルを作る"),
        ("Tap the page icon at the top, pick a type, and type a name — the extension is added for you.",
             "上部のページアイコンをタップし、種類を選んで名前を入力します。拡張子は自動で付きます。"),
        ("Switch between open files", "開いているファイルを切り替える"),
        ("Use the tabs under the toolbar. Long-press a tab to close others.",
             "ツールバーの下のタブを使います。タブを長押しすると他を閉じられます。"),
        ("Symbols above the keyboard", "キーボード上の記号"),
        ("Tap them to insert brackets, quotes and arrows without switching keyboard pages.",
             "キーボードを切り替えずに、括弧・引用符・矢印などをそのまま入力できます。"),
        ("Indent and unindent", "字下げを増やす・減らす"),
        ("The two arrow keys at the left of that row indent or unindent the current line or selection.",
             "その列の左端にある2つの矢印キーで、現在の行または選択範囲の字下げを増減できます。"),
        ("Undo a mistake", "操作を取り消す"),
        ("Use the undo arrow in that row, or shake the phone.",
             "その列の「取り消す」矢印を使うか、端末を振ってください。"),
        ("Change the text size", "文字サイズを変える"),
        ("Pinch with two fingers inside the editor, or set an exact size in Settings.",
             "エディタ内で2本指のピンチ操作をするか、設定で数値を指定します。"),
        ("Finding things", "検索する"),
        ("Search inside the open file", "開いているファイル内を検索"),
        ("Tap the magnifier. Turn on .* for regular expressions.",
             "虫めがねをタップします。「.*」をオンにすると正規表現が使えます。"),
        ("Search every file", "すべてのファイルから検索"),
        ("Menu ▸ Search all files.", "メニュー ▸ すべてのファイルを検索。"),
        ("Files and sharing", "ファイルと共有"),
        ("Bring files in", "ファイルを取り込む"),
        ("File list ▸ + ▸ Import from Files. AirDrop and iCloud Drive both work.",
             "ファイル一覧 ▸ + ▸ 「ファイル」App から読み込む。AirDrop や iCloud Drive も使えます。"),
        ("Send a file out", "ファイルを送る"),
        ("Menu ▸ Share file.", "メニュー ▸ ファイルを共有。"),
        ("Tips", "ヒント"),
        ("Swipe a file left in the list to rename, duplicate or delete it.",
             "一覧でファイルを左にスワイプすると、名前の変更・複製・削除ができます。"),
        ("The language is detected from the file extension; you can override it from the status bar.",
             "言語は拡張子から自動判別されます。下部のステータスバーから手動で変更もできます。"),
    ]
}
