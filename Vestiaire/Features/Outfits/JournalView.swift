import PhotosUI
import SwiftUI

/// Journal privé des tenues portées : la source des statistiques et du Wrapped.
/// Rien n'y est publié ni partagé.
struct JournalView: View {
    @Environment(WardrobeStore.self) private var store

    private enum Mode: String, CaseIterable, Identifiable {
        case list, calendar

        var id: String { rawValue }

        var label: String {
            switch self {
            case .list: "Liste"
            case .calendar: "Calendrier"
            }
        }
    }

    @State private var mode: Mode = .list
    @State private var month = Date.now
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var editedEntry: Session?
    @State private var newEntry: DateRequest?
    @State private var visibleCount = 20

    var body: some View {
        let journal = store.journal
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tenues portées")
                    .font(Theme.title(32))
                Text("Ton journal privé : ce que tu as vraiment porté. Il nourrit tes statistiques et ton Wrapped. Rien n'est publié ni partagé.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }

            Button("Ajouter une tenue portée") {
                newEntry = DateRequest(date: .now)
            }
            .buttonStyle(PrimaryButtonStyle())

            if journal.isEmpty {
                EmptyState(
                    title: "Aucune tenue portée pour l'instant",
                    message: "Ajoute ce que tu portes aujourd'hui, avec une photo si tu veux. Tu peux aussi ouvrir une tenue proposée et toucher « Marquer comme portée ». Les tenues proposées ne comptent jamais toutes seules."
                )
            } else {
                HStack(spacing: 22) {
                    ForEach(Mode.allCases) { option in
                        Chip(title: option.label, isSelected: mode == option) {
                            withAnimation(.snappy) { mode = option }
                        }
                    }
                }

                switch mode {
                case .list: list(journal)
                case .calendar: calendarMode
                }
            }

            Text("Prototype : le journal reste en mémoire tant que l'app est ouverte. Les entrées marquées « Exemple » sont des données d'exemple.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 16)
        .sheet(item: $editedEntry) { entry in
            JournalEntryEditor(entry: entry)
        }
        .sheet(item: $newEntry) { request in
            JournalEntryEditor(date: request.date)
        }
    }

    // MARK: - Liste

    private func list(_ journal: [Session]) -> some View {
        let shown = Array(journal.prefix(visibleCount))
        let months = Dictionary(grouping: shown) { Calendar.current.dateInterval(of: .month, for: $0.date)?.start ?? $0.date }
        return LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(months.keys.sorted(by: >), id: \.self) { start in
                SectionLabel(start.monthYearFR)
                    .padding(.top, 18)
                    .padding(.bottom, 4)
                ForEach(months[start] ?? []) { entry in
                    Button {
                        editedEntry = entry
                    } label: {
                        JournalRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
            }
            if journal.count > visibleCount {
                Button("Afficher les tenues plus anciennes") {
                    visibleCount += 30
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 20)
            }
        }
    }

    // MARK: - Calendrier

    private var calendarMode: some View {
        let entries = store.journal.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }
        let isFuture = selectedDay > Calendar.current.startOfDay(for: .now)
        return VStack(alignment: .leading, spacing: 16) {
            MonthCalendar(month: $month, selection: $selectedDay) { day in
                DayMarker(hasOutfit: store.sessions.contains { Calendar.current.isDate($0.date, inSameDayAs: day) })
            }
            CalendarLegend(showsMissing: false, showsEvents: false, outfitLabel: "Tenue portée")

            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(selectedDay.dayFR)
                    .padding(.bottom, 4)
                if entries.isEmpty {
                    Text(isFuture ? "Ce jour n'est pas encore passé : pour le préparer, utilise l'Agenda." : "Rien d'enregistré ce jour-là.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                        .padding(.vertical, 12)
                }
                ForEach(entries) { entry in
                    Button {
                        editedEntry = entry
                    } label: {
                        JournalRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
                if !isFuture {
                    Button("Ajouter une tenue ce jour-là") {
                        newEntry = DateRequest(date: selectedDay.addingTimeInterval(12 * 3600))
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.top, 12)
                }
            }
        }
    }
}

/// Une date à ouvrir dans une feuille (nouvelle entrée, nouveau planning).
struct DateRequest: Identifiable {
    let id = UUID()
    var date: Date
}

/// Une ligne du journal : la photo (ou la tenue à plat), la date, le contexte et l'origine.
struct JournalRow: View {
    @Environment(WardrobeStore.self) private var store
    let entry: Session

    var body: some View {
        let pieces = store.pieces(in: entry)
        HStack(alignment: .top, spacing: 14) {
            JournalEntryImage(entry: entry)
                .frame(width: 76)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.date.dayFR.uppercased())
                        .font(Theme.label)
                        .tracking(1.2)
                    if entry.isSample {
                        SampleBadge()
                    }
                }
                Text([entry.context.label, entry.place].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 14))
                Text(originLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                Text(pieces.isEmpty ? "Aucune pièce" : pieces.map { $0.type.lowercased() }.joined(separator: ", "))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 0.5)
        }
    }

    private var originLabel: String {
        if entry.outfitID != nil { return "Tenue proposée, marquée comme portée" }
        switch entry.origin {
        case .gallery: return "Retrouvée dans ta galerie"
        case .journal: return "Enregistrée à la main"
        }
    }
}

/// L'image d'une tenue portée : la photo personnelle, sinon la photo d'exemple, sinon les pièces à plat.
struct JournalEntryImage: View {
    @Environment(WardrobeStore.self) private var store
    let entry: Session

    var body: some View {
        if let data = entry.photo, let image = UIImage(data: data) {
            framed(Image(uiImage: image))
        } else if let name = entry.samplePhotoName {
            framed(Image(name))
        } else {
            OutfitFlatLay(pieces: store.pieces(in: entry), backdropHex: "F3F2EF")
        }
    }

    private func framed(_ image: Image) -> some View {
        Color.clear
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay {
                image
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
    }
}

/// Ajouter ou corriger une tenue portée : date, contexte, photo et pièces.
struct JournalEntryEditor: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let existing: Session?
    private let outfitID: UUID?
    private let note: String?
    private let onLogged: ((Session) -> Void)?

    @State private var date: Date
    @State private var context: SessionContext
    @State private var selection: Set<UUID>
    @State private var photo: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var isConfirmingDelete = false

    /// Corriger une entrée existante.
    init(entry: Session) {
        existing = entry
        outfitID = entry.outfitID
        note = nil
        onLogged = nil
        _date = State(initialValue: entry.date)
        _context = State(initialValue: entry.context)
        _selection = State(initialValue: [])
        _photo = State(initialValue: entry.photo)
    }

    /// Enregistrer une nouvelle tenue portée, éventuellement préremplie depuis une tenue proposée ou planifiée.
    init(date: Date = .now, context: SessionContext = .everyday, itemIDs: [UUID] = [], outfitID: UUID? = nil, note: String? = nil, onLogged: ((Session) -> Void)? = nil) {
        existing = nil
        self.outfitID = outfitID
        self.note = note
        self.onLogged = onLogged
        _date = State(initialValue: min(date, .now))
        _context = State(initialValue: context)
        _selection = State(initialValue: Set(itemIDs))
        _photo = State(initialValue: nil)
    }

    /// Les pièces qu'on peut cocher : le dressing actif, plus celles déjà dans l'entrée (même archivées depuis).
    private var choices: [Item] {
        let current = existing.map { store.pieces(in: $0) } ?? []
        let extra = current.filter { $0.status != .active }
        return store.activeItems + extra
    }

    var body: some View {
        NavigationStack {
            Form {
                if existing?.isSample == true {
                    Section {
                        Label("Entrée d'exemple du prototype", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                }
                if let note {
                    Section {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                }

                Section("Quand") {
                    DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "fr_FR"))
                    Picker("Contexte", selection: $context) {
                        ForEach(SessionContext.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                }

                Section("Photo (facultative)") {
                    if let data = photo, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .listRowInsets(EdgeInsets())
                    } else if let name = existing?.samplePhotoName {
                        Image(name)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .listRowInsets(EdgeInsets())
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(photo == nil ? "Ajouter une photo" : "Changer la photo", systemImage: "photo")
                    }
                    if photo != nil {
                        Button("Retirer la photo", role: .destructive) {
                            photo = nil
                            photoItem = nil
                        }
                    }
                }

                Section {
                    PieceChecklist(items: choices, selection: $selection)
                } header: {
                    Text("Pièces portées · \(selection.count)")
                } footer: {
                    Text("Cette tenue reste privée : elle n'est jamais publiée ni partagée. Chaque pièce cochée compte un port.")
                }

                if let existing {
                    Section {
                        Button("Supprimer cette entrée", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    } footer: {
                        Text(existing.origin == .gallery ? "Retrouvée dans ta galerie le \(existing.date.shortFR)." : "Enregistrée à la main.")
                    }
                }
            }
            .tint(Theme.ink)
            .navigationTitle(existing == nil ? "Tenue portée" : "Modifier la tenue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(selection.isEmpty)
                }
            }
            .confirmationDialog("Supprimer cette tenue du journal ?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    if let existing {
                        store.deleteEntry(existing)
                    }
                    dismiss()
                }
            } message: {
                Text("Les ports de ces pièces seront retirés des statistiques.")
            }
            .onAppear {
                if let existing, selection.isEmpty {
                    selection = Set(store.pieces(in: existing).map(\.id))
                }
            }
            .onChange(of: photoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    photo = try? await newValue.loadTransferable(type: Data.self)
                }
            }
        }
    }

    private func save() {
        // On garde l'ordre du dressing pour les pièces cochées.
        let itemIDs = choices.map(\.id).filter { selection.contains($0) }
        if var entry = existing {
            entry.date = date
            entry.context = context
            entry.photo = photo
            store.updateEntry(entry, itemIDs: itemIDs)
        } else {
            let session = store.logOutfit(date: date, context: context, itemIDs: itemIDs, photo: photo, outfitID: outfitID)
            onLogged?(session)
        }
        dismiss()
    }
}
