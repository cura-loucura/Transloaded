import Foundation

struct TutorialPage: Identifiable {
    let id: Int
    let title: String
    let description: String
    let imageName: String
}

extension TutorialPage {
    static let pages: [TutorialPage] = [
        TutorialPage(
            id: 1,
            title: "Welcome to Transloaded",
            description: "With the Transloaded App, you can view text files, markdown, pdf or image files from any supported language and use your MacOS to translate the documents for you.",
            imageName: "doc.text"
        ),
        TutorialPage(
            id: 2,
            title: "Drag and Drop Files",
            description: "You can drag and drop files or folders that you want to translate, use the toolbar buttons or open them on the File menu.",
            imageName: "folder"
        ),
        TutorialPage(
            id: 3,
            title: "Select Languages",
            description: "On the preferences, you can select all languages that you want to use for translation. An internet connection may be required to download language packs for the first time.",
            imageName: "globe"
        ),
        TutorialPage(
            id: 4,
            title: "Translate Your Files",
            description: "On the file tree, double-click the file to open its preview. The system will try to automatically match the original language. Click on the (+) button to select what language it should be translated to.",
            imageName: "text.bubble"
        ),
        TutorialPage(
            id: 5,
            title: "Import & Scan Documents",
            description: "On the toolbar, you can open files and documents or import them to a folder. You can also use a compatible iPhone with Continuity Camera to take pictures and import files.",
            imageName: "iphone"
        ),
        TutorialPage(
            id: 6,
            title: "Quick Translation with Scrapbook",
            description: "If you just need a quick translation tool, you can simply double-click the Scrapbook and a new empty text editor will open. You can write or paste any text and translate to any language.",
            imageName: "square.and.pencil"
        )
    ]
}
