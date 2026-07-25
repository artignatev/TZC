import SwiftUI

struct ZonePickerView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @FocusState private var searchIsFocused: Bool

    var body: some View {
        let palette = model.theme.palette

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    TextField("Enter city name", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(palette.primary)
                        .focused($searchIsFocused)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(palette.control)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                }
                .padding(.leading, 20)
                .padding(.trailing, 12)
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(palette.separator)
                    .frame(width: 0.5)

                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPresented = false
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(palette.secondary)
                .frame(width: 72, height: 50)
            }
            .frame(height: 50)
            .background(palette.background)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(palette.separator)
                    .frame(height: 0.5)
            }

            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                palette.background
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { option in
                            CitySearchResultRow(option: option) {
                                model.add(option)
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isPresented = false
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.visible)
                .background(palette.background)
            }
        }
        .background(palette.background)
        .onAppear {
            DispatchQueue.main.async {
                searchIsFocused = true
            }
        }
    }

    private var results: [CityOption] {
        Array(CityCatalog.search(searchText).prefix(150))
    }
}

private struct CitySearchResultRow: View {
    @EnvironmentObject private var model: AppModel
    let option: CityOption
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        let palette = model.theme.palette
        let foreground = isHovered ? Color.white : palette.primary
        let secondary = isHovered ? Color.white.opacity(0.55) : palette.secondary

        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(option.name)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(foreground)
                    .lineLimit(1)

                Text(option.region)
                    .font(.system(size: 14, weight: .ultraLight))
                    .foregroundStyle(secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .frame(height: 64)
            .background(isHovered ? Color(red: 0.305, green: 0.615, blue: 1) : palette.background)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(palette.separator)
                    .frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
