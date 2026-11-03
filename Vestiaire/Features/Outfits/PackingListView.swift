import SwiftUI

/// Un événement : ses jours, les tenues prévues chaque jour, et pour un voyage, l'accès à la valise.
struct EventDetailView: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let eventID: UUID

    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var newPlan: DateRequest?
    @State private var editedPlan: PlannedOutfit?

    var body: some View {
        if let event = store.event(id: eventID) {
            content(event)
        } else {
            Text("Cet événement a été supprimé.")
                .foregroundStyle(Theme.muted)
        }
    }

    private func content(_ event: WardrobeEvent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        SectionLabel(event.kind.label)
                        if event.isSample {
                            SampleBadge()
                        }
                    }
                    Text(event.name)
                        .font(Theme.title(32))
                    Text([dateRangeLabel(event.start, event.end), event.place].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                }

                if event.kind == .travel {
                    NavigationLink(value: WardrobeRoute.packing(event.id)) {
                        HStack {
                            Image(systemName: "suitcase")
                            Text("Préparer ma valise")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.paper)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 17)
                        .background(Theme.ink)
                    }
                    .buttonStyle(.plain)
                }

                DayByDayPlans(event: event, onAdd: { day in
                    newPlan = DateRequest(date: day)
                }, onEdit: { plan in
                    editedPlan = plan
                })

                VStack(spacing: 10) {
                    Button("Modifier l'événement") { isEditing = true }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Supprimer l'événement") { isConfirmingDelete = true }
                        .font(.system(size: 13))
                        .underline()
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 6)
                }
            }
            .padding(20)
        }
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditing) {
            EventEditor(event: event)
        }
        .sheet(item: $newPlan) { request in
            PlanEditor(date: request.date, eventID: event.id)
        }
        .sheet(item: $editedPlan) { plan in
            PlanEditor(plan: plan)
        }
        .confirmationDialog("Supprimer « \(event.name) » ?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                store.deleteEvent(event)
                dismiss()
            }
        } message: {
            Text("Les tenues planifiées restent dans l'agenda. La valise de cet événement est supprimée.")
        }
    }
}

/// Les jours d'un événement, avec les tenues prévues ; les jours sans tenue sont signalés.
struct DayByDayPlans: View {
    @Environment(WardrobeStore.self) private var store
    let event: WardrobeEvent
    let onAdd: (Date) -> Void
    let onEdit: (PlannedOutfit) -> Void

    var body: some View {
        let plans = store.plans(for: event)
        let today = Calendar.current.startOfDay(for: .now)
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Tenues jour par jour")
                .padding(.bottom, 4)
            ForEach(event.days(), id: \.self) { day in
                let dayPlans = plans.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(day.dayFR.capitalized)
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        if day >= today {
                            Button {
                                onAdd(day)
                            } label: {
                                Label("Ajouter", systemImage: "plus")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(Theme.ink)
                        }
                    }
                    .padding(.top, 14)
                    if dayPlans.isEmpty {
                        Text("Aucune tenue prévue ce jour-là")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.accent)
                            .padding(.bottom, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Theme.line).frame(height: 0.5)
                            }
                    }
                    ForEach(dayPlans) { plan in
                        PlanRow(plan: plan) { onEdit(plan) }
                    }
                }
            }
        }
    }
}

/// La valise d'un voyage : les tenues de chaque jour, la liste dédupliquée des pièces à emporter,
/// les ajouts à la main, et ce qui manque au dressing (signalé, jamais ajouté automatiquement).
struct PackingListView: View {
    @Environment(WardrobeStore.self) private var store
    let eventID: UUID

    @State private var newExtra = ""
    @State private var newPlan: DateRequest?
    @State private var editedPlan: PlannedOutfit?
    @State private var newWish: Wish?

    var body: some View {
        if let event = store.event(id: eventID) {
            content(event)
        } else {
            Text("Ce voyage a été supprimé.")
                .foregroundStyle(Theme.muted)
        }
    }

    private func content(_ event: WardrobeEvent) -> some View {
        let list = store.packingList(for: event)
        let required = store.requiredItems(for: event)
        let packedCount = required.filter { list.packedItemIDs.contains($0.id) }.count + list.extras.filter(\.isPacked).count
        let total = required.count + list.extras.count
        let isPast = event.end < Calendar.current.startOfDay(for: .now)
        return ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        SectionLabel(isPast ? "Valise · voyage passé" : "Ma valise")
                        if event.isSample {
                            SampleBadge()
                        }
                    }
                    Text(event.name)
                        .font(Theme.title(32))
                    Text([dateRangeLabel(event.start, event.end), event.place].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                    if total > 0 {
                        Text("\(packedCount) / \(total) dans la valise")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.top, 4)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Theme.line)
                                Rectangle().fill(Theme.ink)
                                    .frame(width: geometry.size.width * Double(packedCount) / Double(max(total, 1)))
                            }
                        }
                        .frame(height: 3)
                    }
                }

                DayByDayPlans(event: event, onAdd: { day in
                    newPlan = DateRequest(date: day)
                }, onEdit: { plan in
                    editedPlan = plan
                })

                piecesSection(event, required: required, list: list)
                missingSection(event)
                extrasSection(event, list: list)
            }
            .padding(20)
        }
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $newPlan) { request in
            PlanEditor(date: request.date, eventID: event.id)
        }
        .sheet(item: $editedPlan) { plan in
            PlanEditor(plan: plan)
        }
        .sheet(item: $newWish) { wish in
            WishEditor(draft: wish)
        }
    }

    private func piecesSection(_ event: WardrobeEvent, required: [Item], list: PackingList) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Pièces à emporter · \(required.count)")
                .padding(.bottom, 4)
            if required.isEmpty {
                Text("Associe une tenue à chaque jour : la liste des pièces se remplit toute seule, sans doublon.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                    .padding(.vertical, 12)
            }
            ForEach(required) { item in
                let isPacked = list.packedItemIDs.contains(item.id)
                Button {
                    store.togglePacked(item, for: event)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isPacked ? "checkmark.square.fill" : "square")
                            .font(.system(size: 18, weight: .light))
                        ProductImage(item: item)
                            .frame(width: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(item.type) \(item.colors.first?.lowercased() ?? "")")
                                .font(.system(size: 14))
                                .strikethrough(isPacked)
                            Text(item.brand?.name ?? "Sans marque")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.line).frame(height: 0.5)
                }
            }
        }
    }

    @ViewBuilder
    private func missingSection(_ event: WardrobeEvent) -> some View {
        let missing = store.missingPieces(for: event)
        if !missing.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("Manque au dressing")
                    .padding(.bottom, 4)
                Text("Ces pièces sont dans tes tenues, mais pas dans ton dressing actif. Elles ne sont pas ajoutées à la valise.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .padding(.bottom, 6)
                ForEach(missing, id: \.self) { piece in
                    switch piece {
                    case .notActive(let item):
                        HStack(spacing: 12) {
                            ProductImage(item: item)
                                .frame(width: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.type) \(item.colors.first?.lowercased() ?? "")")
                                    .font(.system(size: 14))
                                Text(item.status == .archived ? "Archivée : restaure-la depuis les Archives ou change de tenue." : "Plus dans ton vestiaire : change de tenue.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(.vertical, 8)
                    case .notOwned(let tryOn):
                        let alreadyWished = store.wishes.contains { $0.description.lowercased() == tryOn.description.lowercased() }
                        HStack(spacing: 12) {
                            ProductImage(item: tryOn.item)
                                .frame(width: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tryOn.description)
                                    .font(.system(size: 14))
                                Text("Pas encore dans ton dressing")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.accent)
                            }
                            Spacer()
                            if alreadyWished {
                                Text("Dans tes envies")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.muted)
                            } else {
                                Button("Ajouter à mes envies") {
                                    newWish = Wish(description: tryOn.description, photo: tryOn.photo)
                                }
                                .font(.system(size: 12))
                                .underline()
                                .foregroundStyle(Theme.ink)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    private func extrasSection(_ event: WardrobeEvent, list: PackingList) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Ajouté à la main")
                .padding(.bottom, 4)
            ForEach(list.extras) { extra in
                HStack(spacing: 12) {
                    Button {
                        store.toggleExtra(extra, for: event)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: extra.isPacked ? "checkmark.square.fill" : "square")
                                .font(.system(size: 18, weight: .light))
                            Text(extra.name)
                                .font(.system(size: 14))
                                .strikethrough(extra.isPacked)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button {
                        store.removeExtra(extra, from: event)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .light))
                    }
                    .accessibilityLabel("Retirer \(extra.name)")
                }
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.line).frame(height: 0.5)
                }
            }
            HStack(spacing: 10) {
                TextField("Trousse de toilette, chargeur…", text: $newExtra)
                    .font(.system(size: 14))
                    .onSubmit { addExtra(to: event) }
                Button("Ajouter") { addExtra(to: event) }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .disabled(newExtra.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.line).frame(height: 1)
            }
        }
    }

    private func addExtra(to event: WardrobeEvent) {
        let name = newExtra.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        store.addExtra(name, to: event)
        newExtra = ""
    }
}
