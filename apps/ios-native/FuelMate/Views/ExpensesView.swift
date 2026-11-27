import SwiftUI

struct ExpensesView: View {
    @EnvironmentObject private var store: Store
    @State private var showForm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("电费").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("¥" + Calc.num(store.overview.totalChargeCost, 0)).fontWeight(.medium)
                    }
                    HStack {
                        Text("杂费").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("¥" + Calc.num(store.overview.totalOtherCost, 0)).fontWeight(.medium)
                    }
                    HStack {
                        Text("合计").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("¥" + Calc.num(store.overview.totalCost, 0)).fontWeight(.semibold)
                            .foregroundStyle(Theme.green)
                    }
                }

                Section {
                    if store.expenses.isEmpty {
                        Text("还没有费用记录").font(.footnote).foregroundStyle(.secondary)
                    } else {
                        ForEach(store.expenses) { e in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e.type + (e.notes.isEmpty ? "" : " · " + e.notes))
                                        .font(.subheadline)
                                    Text(e.date).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("¥" + Calc.num(e.amount, 2)).font(.subheadline).fontWeight(.medium)
                            }
                        }
                        .onDelete { idx in
                            for i in idx { store.deleteExpense(store.expenses[i].id) }
                        }
                    }
                } header: {
                    Text("费用明细")
                }
            }
            .navigationTitle("费用")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showForm = true } label: { Image(systemName: "plus.circle.fill") }
                }
            }
            .sheet(isPresented: $showForm) { ExpenseFormView() }
        }
    }
}
