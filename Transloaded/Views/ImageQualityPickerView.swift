import SwiftUI

struct ImageQualityPickerView: View {
    let onSelect: (ImageQualityOption) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Image Quality")
                .font(.headline)

            Text("Choose the quality for the imported photo:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ForEach(ImageQualityOption.allCases, id: \.self) { option in
                Button {
                    onSelect(option)
                    dismiss()
                } label: {
                    Text(option.rawValue)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button("Cancel", role: .cancel) { dismiss() }
        }
        .padding(20)
        .frame(width: 280)
    }
}
