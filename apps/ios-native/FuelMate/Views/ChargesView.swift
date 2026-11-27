import SwiftUI
import Charts

struct ChargesView: View {
    @EnvironmentObject private var store: Store
    @State private var showForm = false
    @State private var editing: Charge? = nil

    private var segs: [Seg] { Calc.segments(store.charges) }

    private var consumptionMap: [Int: Double] {
        var m: [Int: Double] = [:]
        for s in segs where s.consumption > 0 { m[s.chargeId] = s.consumption }
        return m
    }

    var body: some View {
        NavigationStack {
            List {
                if !segs.isEmpty {
                    Section {
                        Chart(segs) { s in
                            BarMark(
                                x: .value("日期", String(s.date.suffix(5))),
                                y: .value("电耗", s.consumption)
                            )
                            .foregroundStyle(Theme.green.gradient)
                            .cornerRadius(4)
                        }
                        .chartYAxisLabel("kWh/km")
                        .frame(height: 180)
                        .padding(.vertical, 6)
                    } header: {
                        Text("电耗趋势（相邻两次充电）")
                    }
                }

                Section {
                    if store.charges.isEmpty {
                        Text("还没有充电记录").font(.footnote).foregroundStyle(.secondary)
                    } else {
                        ForEach(store.charges) { c in
                            let cons = consumptionMap[c.id] ?? -1
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(c.date).font(.subheadline).fontWeight(.medium)
                                    Spacer()
                                    Text("¥" + Calc.num(c.amount, 2)).font(.subheadline).fontWeight(.medium)
                                }
                                HStack(spacing: 6) {
                                    Text("\(Int(c.odometer)) km · \(Calc.num(c.kwh, 1)) kWh")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    if c.socAfter > 0 {
                                        Text(c.socBefore > 0 ? "\(Int(c.socBefore))%→\(Int(c.socAfter))%" : "充至 \(Int(c.socAfter))%")
                                            .font(.caption2)
                                            .foregroundStyle(Theme.green)
                                    }
                                }
                                HStack(spacing: 6) {
                                    Text(cons > 0 ? "电耗 \(Calc.num(cons, 3)) kWh/km" : "电耗 —")
                                        .font(.caption2)
                                        .foregroundStyle(cons > 0 ? Theme.green : .secondary)
                                    Spacer()
                                    Text("¥\(Calc.num(c.price, 2)) / kWh")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = c }
                        }
                        .onDelete { idx in
                            for i in idx { store.deleteCharge(store.charges[i].id) }
                        }
                    }
                } header: {
                    HStack {
                        Text("充电记录")
                        Spacer()
                        Text("共 \(store.charges.count) 次 / \(Int(store.overview.totalKwh)) kWh · 点击可编辑")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(item: $editing) { c in ChargeFormView(editing: c) }
            .navigationTitle("充电")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editing = nil
                        showForm = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showForm) { ChargeFormView() }
            .overlay {
                if store.vehicles.isEmpty {
                    Text("请先在「我的」添加车辆").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
}
