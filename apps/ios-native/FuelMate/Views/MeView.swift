import SwiftUI

struct MeView: View {
    @EnvironmentObject private var store: Store
    @State private var showVehicleForm = false
    @State private var editing: Vehicle? = nil
    @State private var newType = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.vehicles) { v in
                        HStack(spacing: 10) {
                                Image(systemName: "car.fill").foregroundStyle(Theme.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(v.name).font(.subheadline).fontWeight(.medium)
                                        if v.id == store.currentVehicleId {
                                            Text("当前")
                                                .font(.caption2)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Theme.greenLight)
                                                .foregroundStyle(Theme.green)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                        }
                                    }
                                    Text([v.model, v.plate].filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    editing = v
                                    showVehicleForm = true
                                } label: {
                                    Image(systemName: "square.and.pencil")
                                }
                                .buttonStyle(.borderless)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { store.selectVehicle(v.id) }
                    }
                    .onDelete { idx in
                        for i in idx { store.deleteVehicle(store.vehicles[i].id) }
                    }
                } header: {
                    HStack {
                        Text("车辆")
                        Spacer()
                        Button("＋ 添加") {
                            editing = nil
                            showVehicleForm = true
                        }
                        .font(.caption)
                        .foregroundStyle(Theme.green)
                    }
                }

                Section {
                    if let v = store.currentVehicle, v.purchasePrice > 0 {
                        let own = store.ownership
                        HStack {
                            statBox("元/天", Calc.num(own.perDay, 2), "车价÷\(own.days)天")
                            statBox("元/km", Calc.num(own.perKm, 2), "车价÷里程")
                        }
                        Text("含购车总成本 ¥\(Calc.num(v.purchasePrice + store.overview.totalCost, 0))（购车+电费+杂费）")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("在车辆编辑里填写购车价格与日期后可看持有成本")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("持有成本")
                }

                Section {
                    ForEach(store.expenseTypes, id: \.self) { t in
                        HStack {
                            Text(t).font(.subheadline)
                            Spacer()
                            if store.expenseTypes.count > 1 {
                                Button {
                                    store.removeExpenseType(t)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red.opacity(0.75))
                            }
                        }
                    }
                    HStack {
                        TextField("新增项目，如 洗车", text: $newType)
                        Button("添加") {
                            store.addExpenseType(newType)
                            newType = ""
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Theme.green)
                        .disabled(newType.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    HStack {
                        Text("费用项目")
                        Spacer()
                        Text("\(store.expenseTypes.count) 项 · 与提醒共用")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    HStack {
                        Text("电耗口径").font(.caption)
                        Spacer()
                        Text("kWh/km（每公里耗电）").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("数据存储").font(.caption)
                        Spacer()
                        Text("仅本机").font(.caption).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showVehicleForm) {
                VehicleFormView(editing: editing)
            }
        }
    }

    private func statBox(_ label: String, _ value: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded))
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(sub).font(.caption2).foregroundStyle(Theme.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
