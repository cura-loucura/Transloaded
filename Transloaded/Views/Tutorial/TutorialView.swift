import SwiftUI

struct TutorialView: View {
    @Binding var isPresented: Bool
    var onDismiss: () -> Void

    @State private var currentPage = 0
    private let pages = TutorialPage.pages

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Spacer()

            contentView

            Spacer()

            navigationView
        }
        .frame(width: 500, height: 450)
    }

    private var headerView: some View {
        HStack {
            Spacer()
            Button {
                closeTutorial()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding()
    }

    private var contentView: some View {
        VStack(spacing: 20) {
            Image(systemName: pages[currentPage].imageName)
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
                .frame(height: 80)

            Text(pages[currentPage].title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(pages[currentPage].description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var navigationView: some View {
        VStack(spacing: 16) {
            pageIndicator

            HStack {
                if currentPage > 0 {
                    Button("Previous") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        closeTutorial()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 24)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentPage ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }

    private func closeTutorial() {
        isPresented = false
        onDismiss()
    }
}
