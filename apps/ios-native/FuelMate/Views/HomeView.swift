import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: Store
    @State private var showReminderForm = false

    private var o: Overview { store.overview }
    private var a: AnnualInfo { store.annual }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if store.vehicles.isEmpty {
                        EmptyVehicleHint()
                    } else {
                        heroCard
                        annualCard
                        reminderCard
                    }
                }
                .padding(14)
            }
            .background(Theme.bg)
            .navigationTitle("电耗管家")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showReminderForm) {
                ReminderFormView()
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(store.currentVehicle?.name ?? "未命名")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.03, green: 0.14, blue: 0.06))
                if let plate = store.currentVehicle?.plate, !plate.isEmpty {
                    Text(plate)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .foregroundStyle(Color(red: 0.03, green: 0.14, blue: 0.06))
                }
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Calc.num(o.avgConsumption, 3))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                Text("kWh/km").font(.footnote)
            }
            .foregroundStyle(Color(red: 0.03, green: 0.14, blue: 0.06))

            Text(rangeOrBattery)
                .font(.caption)
                .foregroundStyle(Color(red: 0.03, green: 0.14, blue: 0.06).opacity(0.75))

            Divider().overlay(Color.black.opacity(0.12))

            HStack(spacing: 0) {
                stat("总里程 km", "\(Int(o.totalDistance))")
                stat("电费/km", Calc.num(o.chargeCostPerKm, 2))
                stat("充电", "\(o.chargeCount) 次")
            }
        }
        .padding(18)
        .background(Theme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var rangeOrBattery: String {
        if store.estimatedRange > 0 { return "估算续航 \(store.estimatedRange) km" }
        if let b = store.currentVehicle?.battery, b > 0 { return "电池 \(Calc.num(b, 1)) kWh" }
        return "在「我的 → 车辆」填写电池容量"
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.03, green: 0.14, blue: 0.06))
            Text(label).font(.caption2).foregroundStyle(Color(red: 0.03, green: 0.14, blue: 0.06).opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var annualCard: some View {
        CardBox {
            HStack {
                Text("⏳ 年度里程倒计时").font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("\(a.year) 年度").font(.caption2).foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text("\(a.daysLeft)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.green)
                    Text("距 12-31").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(width: 64)

                VStack(alignment: .leading, spacing: 4) {
                    if a.limit > 0 {
                        Text("\(Int(a.used)) / \(Int(a.limit)) km")
                            .font(.subheadline).fontWeight(.medium)
                        Text(a.remaining >= 0
                             ? "剩余 \(Int(a.remaining)) km · 日均 \(a.dailyBudget) km"
                             : "已超 \(Int(abs(a.remaining))) km")
                            .font(.caption)
                            .foregroundStyle(a.remaining < 0 ? Theme.danger : .secondary)
                    } else {
                        Text("未设置年度额度").font(.subheadline)
                        Text("在「我的 → 车辆」填写每年限定里程").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if a.limit > 0 {
                ProgressView(value: Double(a.pct), total: 100)
                    .tint(a.pct >= 100 ? Theme.danger : (a.pct >= 80 ? Theme.warn : Theme.green))
            }
        }
    }

    private var reminderCard: some View {
        CardBox {
            SectionTitle(text: "⏰ 保养提醒", trailing: "＋ 添加") { showReminderForm = true }

            if store.reminders.isEmpty {
                Text("暂无保养提醒").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(store.reminders) { r in
                    let st = Calc.reminderState(r, currentOdo: o.lastOdometer)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(r.title).font(.subheadline).fontWeight(.medium)
                            Spacer()
                            Text(Calc.statusText(st.status))
                                .font(.caption2)
                                .foregroundStyle(st.status == "expired" ? Theme.danger : (st.status == "warn" ? Theme.warn : Theme.green))
                        }
                        Text(line(r, st)).font(.caption2).foregroundStyle(.secondary)
                        if r.ruleType != "date" {
                            ProgressView(value: Double(st.kmPct), total: 100)
                                .tint(st.kmPct >= 80 ? Theme.danger : Theme.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func line(_ r: Reminder, _ st: ReminderState) -> String {
        var parts: [String] = []
        if st.nextOdo > 0 { parts.append("下次 \(Int(st.nextOdo)) km") }
        if !st.nextDate.isEmpty { parts.append(st.nextDate) }
        if st.kmRemaining != 999999 {
            parts.append(st.kmRemaining >= 0 ? "剩 \(Int(st.kmRemaining)) km" : "已超 \(Int(abs(st.kmRemaining))) km")
        }
        if st.daysRemaining != 999999 {
            parts.append(st.daysRemaining >= 0 ? "剩 \(st.daysRemaining) 天" : "已超 \(abs(st.daysRemaining)) 天")
        }
        return parts.joined(separator: " · ")
    }
}

struct EmptyVehicleHint: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "car.fill").font(.system(size: 40)).foregroundStyle(Theme.green)
            Text("还没有车辆").font(.headline)
            Text("到「我的」页添加车辆后开始记录").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}
