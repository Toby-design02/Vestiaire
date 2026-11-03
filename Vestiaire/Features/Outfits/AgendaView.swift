import SwiftUI

/// Agenda : les tenues programmées, les événements et les voyages.
/// Une tenue planifiée ne compte comme portée qu'après « Marquer comme portée ».
struct AgendaView: View {
    @Environment(WardrobeStore.self) private var store

    @State private var month = Date.now
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var newPlan: DateRequest?
    @State private var editedPlan: PlannedOutfit?
    @State private var newEvent: DateRequest?

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Agenda")
                    .font(Theme.title(32))
                Text("Programme une tenue pour un jour à venir, crée un événement ou prépare la valise d'un voyage.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }

            HStack(spacing: 8) {
                Button("Planifier une tenue") {
                    newPlan = DateRequest(date: max(selectedDay, today))
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Nouvel événement") {
                    newEvent = DateRequest(date: max(selectedDay, today))
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            MonthCalendar(month: $month, selection: $selectedDay) { day in
                let hasPlan = !store.plans(on: day).isEmpty
                return DayMarker(
                    hasOutfit: hasPlan,
                    isMissingOutfit: !hasPlan && day >= today,
                    hasEvent: !store.events(on: day).isEmpty
                )
            }
            CalendarLegend(outfitLabel: "Tenue planifiée")

            selectedDayPanel

            eventsSection(title: "À venir", events: store.upcomingEvents(), empty: "Aucun événement à venir. Crée-en un pour y rattacher tes tenues : un dîner, une semaine chargée, un voyage.")
            let past = store.pastEvents()
            if !past.isEmpty {
                eventsSection(title: "Voyages et événements passés", events: past, empty: "")
            }
        }
        .padding(.horizontal, 16)
        .sheet(item: $newPlan) { request in
            PlanEditor(date: request.date)
        }
        .sheet(item: $editedPlan) { plan in
            PlanEditor(plan: plan)
        }
        .sheet(item: $newEvent) { request in
            EventEditor(start: request.date)
        }
    }

    // MARK: - Jour choisi

    private var selectedDayPanel: some View {
        let plans = store.plans(on: selectedDay)
        let events = store.events(on: selectedDay)
        return VStack(alignment: .leading, spacing: 0) {
            SectionLabel(selectedDay.dayFR)
                .padding(.bottom, 4)
            ForEach(events) { event in
                NavigationLink(value: WardrobeRoute.event(event.id)) {
                    EventRow(event: event)
                }
                .buttonStyle(.plain)
            }
            if plans.isEmpty {
                Text(selectedDay >= today ? "Aucune tenue prévue ce jour-là." : "Aucune tenue n'était planifiée ce jour-là.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                    .padding(.vertical, 12)
            }
            ForEach(plans) { plan in
                PlanRow(plan: plan) {
                    editedPlan = plan
                }
            }
            if selectedDay >= today {
                Button("Planifier une tenue ce jour-là") {
                    newPlan = DateRequest(date: selectedDay)
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 12)
            }
        }
    }

    private func eventsSection(title: String, events: [WardrobeEvent], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title)
                .padding(.bottom, 4)
            if events.isEmpty {
                Text(empty)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                    .padding(.vertical, 12)
            }
            ForEach(events) { event in
                NavigationLink(value: WardrobeRoute.event(event.id)) {
                    EventRow(event: event)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Une ligne d'événement : nom, dates, nombre de tenues prévues.
struct EventRow: View {
    @Environment(WardrobeStore.self) private var store
    let event: WardrobeEvent

    var body: some View {
        let planned = store.plans(for: event).count
        HStack(spacing: 12) {
            Image(systemName: event.kind == .travel ? "suitcase" : "calendar")
                .font(.system(size: 16, weight: .light))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(event.name)
                        .font(.system(size: 15, weight: .medium))
                    if event.isSample {
                        SampleBadge()
                    }
                }
                Text([dateRangeLabel(event.start, event.end), event.place, planned == 0 ? "aucune tenue prévue" : (planned == 1 ? "1 tenue prévue" : "\(planned) tenues prévues")].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(Theme.muted)
        }
        .foregroundStyle(Theme.ink)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 0.5)
        }
    }
}

/// Une tenue planifiée : ses pièces, son statut, et les actions (modifier, marquer comme portée).
struct PlanRow: View {
    @Environment(WardrobeStore.self) private var store
    let plan: PlannedOutfit
    let onEdit: () -> Void

    @State private var isMarkingWorn = false

    var body: some View {
        let pieces = plan.itemIDs.compactMap { store.item(id: $0) }
        let outfit = plan.outfitID.flatMap { store.generatedOutfit(id: $0) }
        let canMarkWorn = plan.wornSessionID == nil && plan.date <= .now
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(outfit.map { "\($0.occasion.label) · \($0.style.label)" } ?? "Tenue composée à la main")
                    .font(.system(size: 14, weight: .medium))
                if plan.isSample {
                    SampleBadge()
                }
                Spacer()
                Button("Modifier", action: onEdit)
                    .font(.system(size: 12))
                    .underline()
                    .foregroundStyle(Theme.ink)
            }
            if pieces.isEmpty {
                Text("Aucune pièce : modifie la tenue pour en choisir.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.accent)
            } else {
                PieceStrip(pieces: pieces)
            }
            if let tryOn = outfit?.tryOn {
                Text("Avec une pièce que tu n'as pas encore : \(tryOn.description)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent)
            }
            if plan.wornSessionID != nil {
                Label("Portée et ajoutée au journal", systemImage: "checkmark")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.positive)
            } else if canMarkWorn {
                Button("Marquer comme portée") {
                    isMarkingWorn = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 0.5)
        }
        .sheet(isPresented: $isMarkingWorn) {
            JournalEntryEditor(
                date: plan.date,
                context: outfit.map { SessionContext($0.occasion) } ?? .everyday,
                itemIDs: plan.itemIDs.filter { store.item(id: $0)?.status == .active },
                outfitID: plan.outfitID
            ) { session in
                var updated = plan
                updated.wornSessionID = session.id
                store.update(updated)
            }
        }
    }
}

/// Programmer une tenue existante (ou des pièces) pour un jour, éventuellement rattachée à un événement.
struct PlanEditor: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let existing: PlannedOutfit?

    @State private var date: Date
    @State private var outfitID: UUID?
    @State private var selection: Set<UUID>
    @State private var eventID: UUID?
    @State private var isConfirmingDelete = false

    init(plan: PlannedOutfit) {
        existing = plan
        _date = State(initialValue: plan.date)
        _outfitID = State(initialValue: plan.outfitID)
        _selection = State(initialValue: Set(plan.itemIDs))
        _eventID = State(initialValue: plan.eventID)
    }

    init(date: Date, outfit: GeneratedOutfit? = nil, eventID: UUID? = nil) {
        existing = nil
        _date = State(initialValue: date)
        _outfitID = State(initialValue: outfit?.id)
        _selection = State(initialValue: Set(outfit?.itemIDs ?? []))
        _eventID = State(initialValue: eventID)
    }

    private var choices: [Item] {
        let extra = selection.compactMap { store.item(id: $0) }.filter { $0.status != .active }
        return store.activeItems + extra
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Quand") {
                    DatePicker("Date", selection: $date, in: (existing == nil ? Calendar.current.startOfDay(for: .now) : .distantPast)..., displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "fr_FR"))
                    Picker("Événement", selection: $eventID) {
                        Text("Aucun").tag(UUID?.none)
                        ForEach(store.events.sorted { $0.start < $1.start }) { event in
                            Text(event.name).tag(Optional(event.id))
                        }
                    }
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.visibleGeneratedOutfits) { outfit in
                                Button {
                                    outfitID = outfit.id
                                    selection = Set(outfit.itemIDs.filter { store.item(id: $0)?.status == .active })
                                } label: {
                                    GeneratedOutfitImage(outfit: outfit)
                                        .frame(width: 84)
                                        .overlay(Rectangle().stroke(outfitID == outfit.id ? Theme.ink : .clear, lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Partir d'une tenue proposée")
                } footer: {
                    Text(store.visibleGeneratedOutfits.isEmpty ? "Aucune tenue proposée pour l'instant : choisis les pièces ci-dessous." : "Ou choisis les pièces une à une ci-dessous.")
                }

                Section {
                    PieceChecklist(items: choices, selection: $selection)
                } header: {
                    Text("Pièces · \(selection.count)")
                } footer: {
                    Text("Planifier ne compte pas comme un port. Le jour venu, touche « Marquer comme portée ».")
                }

                if existing != nil {
                    Section {
                        Button("Supprimer ce planning", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    }
                }
            }
            .tint(Theme.ink)
            .navigationTitle(existing == nil ? "Planifier" : "Modifier le planning")
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
            .confirmationDialog("Supprimer ce planning ?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    if let existing {
                        store.deletePlan(existing)
                    }
                    dismiss()
                }
            }
            .onChange(of: selection) { _, newValue in
                // Si on retouche les pièces, la tenue n'est plus exactement celle proposée.
                if let outfitID, let outfit = store.generatedOutfit(id: outfitID), !Set(outfit.itemIDs).isSuperset(of: newValue) {
                    self.outfitID = nil
                }
            }
        }
    }

    private func save() {
        let itemIDs = choices.map(\.id).filter { selection.contains($0) }
        if var plan = existing {
            plan.date = Calendar.current.startOfDay(for: date)
            plan.itemIDs = itemIDs
            plan.outfitID = outfitID
            plan.eventID = eventID
            store.update(plan)
        } else {
            store.plan(itemIDs: itemIDs, on: date, outfitID: outfitID, eventID: eventID)
        }
        dismiss()
    }
}

/// Créer ou modifier un événement : nom, type, dates de début et de fin, lieu.
struct EventEditor: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let existing: WardrobeEvent?

    @State private var name: String
    @State private var kind: EventKind
    @State private var start: Date
    @State private var end: Date
    @State private var place: String

    init(event: WardrobeEvent) {
        existing = event
        _name = State(initialValue: event.name)
        _kind = State(initialValue: event.kind)
        _start = State(initialValue: event.start)
        _end = State(initialValue: event.end)
        _place = State(initialValue: event.place ?? "")
    }

    init(start: Date) {
        existing = nil
        _name = State(initialValue: "")
        _kind = State(initialValue: .general)
        _start = State(initialValue: start)
        _end = State(initialValue: start)
        _place = State(initialValue: "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom (ex : mariage de Léa)", text: $name)
                    Picker("Type", selection: $kind) {
                        ForEach(EventKind.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("Lieu (facultatif)", text: $place)
                }
                Section {
                    DatePicker("Début", selection: $start, displayedComponents: .date)
                    DatePicker("Fin", selection: $end, in: start..., displayedComponents: .date)
                } footer: {
                    if kind == .travel {
                        Text("Pour un voyage, tu pourras préparer ta valise à partir des tenues de chaque jour.")
                    }
                }
                .environment(\.locale, Locale(identifier: "fr_FR"))
            }
            .tint(Theme.ink)
            .navigationTitle(existing == nil ? "Nouvel événement" : "Modifier l'événement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onChange(of: start) { _, newValue in
                if end < newValue { end = newValue }
            }
        }
    }

    private func save() {
        let trimmedPlace = place.trimmingCharacters(in: .whitespacesAndNewlines)
        var event = existing ?? WardrobeEvent(name: trimmedName, start: start, end: end)
        event.name = trimmedName
        event.kind = kind
        event.start = Calendar.current.startOfDay(for: start)
        event.end = Calendar.current.startOfDay(for: max(start, end))
        event.place = trimmedPlace.isEmpty ? nil : trimmedPlace
        store.save(event)
        dismiss()
    }
}
