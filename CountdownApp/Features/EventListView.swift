import SwiftUI

@MainActor struct EventListView: View {
    let kind: EventKind
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var tag: String?
    @State private var removed: CountEvent?
    private var tags: [String] { Array(Set(model.ordered(kind).map(\.tag).filter { !$0.isEmpty })).sorted() }
    private var filtered: [CountEvent] {
        model.ordered(kind).filter {
            (tag == nil || $0.tag == tag) && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.tag.localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 9) {
                            tagButton(nil)
                            ForEach(tags, id: \.self) { tagButton($0) }
                        }.padding(.horizontal, 24).padding(.vertical, 10)
                    }
                }
                List {
                    if filtered.isEmpty {
                        VStack(spacing: 20) {
                            BrandFace().frame(width: 120)
                            Text("No matching days.").font(TypeStyle.heavy(24))
                            Text("Try another name or tag.").font(TypeStyle.regular(16))
                        }.frame(maxWidth: .infinity).padding(.vertical, 40).listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                    ForEach(filtered) { event in
                        Button { model.select(event); dismiss() } label: { EventRow(event: event, engine: model.engine, now: model.now) }
                            .buttonStyle(.plain).listRowInsets(EdgeInsets(top: 6, leading: 24, bottom: 6, trailing: 24))
                            .listRowSeparator(.hidden).listRowBackground(Color.clear)
                            .swipeActions { Button("Remove", role: .destructive) { removed = event } }
                    }
                }.listStyle(.plain).scrollContentBackground(.hidden)
            }.background(Palette.paper)
                .navigationTitle("All \(kind.title.lowercased())").navigationBarTitleDisplayMode(.inline)
                .searchable(text: $search, prompt: "Search names or tags")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Move this event to Recently deleted?", isPresented: Binding(get: { removed != nil }, set: { if !$0 { removed = nil } }), titleVisibility: .visible) {
                    Button("Remove event", role: .destructive) { if let removed { _ = model.remove(removed) }; removed = nil }
                    Button("Cancel", role: .cancel) { removed = nil }
                }
                .alert("Couldn't complete that", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                    Button("OK") { model.errorMessage = nil }
                } message: { Text(model.errorMessage ?? "") }
        }.font(TypeStyle.regular(17)).foregroundStyle(Palette.ink).tint(Palette.orange)
    }
    private func tagButton(_ value: String?) -> some View {
        Button { tag = value } label: {
            Text(value ?? "All").font(TypeStyle.bold(13)).padding(.horizontal, 17).padding(.vertical, 10)
                .background(tag == value ? Palette.gold.opacity(0.6) : Palette.field, in: Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(tag == value ? .isSelected : [])
    }
}
