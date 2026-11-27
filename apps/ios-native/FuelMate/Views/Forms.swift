import SwiftUI

// MARK: - 充电

struct ChargeFormView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var odometer = ""
    @State private var kwh = ""
    @State private var price = ""
    @State private var socBefore = ""
    @State private var socAfter = ""

    private var valid: Bool {
        (Double(odometer) ?? 0) > 0 && (Double(kwh) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                    HStack {
                        Text("当时里程 (km)")
                        Spacer()
                        TextField("12500", text: $odometer).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
                Section("充电") {
                    numberRow("充电量 (kWh)", $kwh, "42.5")
                    numberRow("单价 (元/kWh)", $price, "1.05")
                    Text(totalText).font(.caption).foregroundStyle(.secondary)
                }
                Section("SOC（选填）") {
                    numberRow("充电前 (%)", $socBefore, "20")
                    numberRow("充电后 (%)", $socAfter, "90")
                }
            }
            .navigationTitle("记录充电")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.addCharge(date: Calc.dateFmt.string(from: date),
                                        odometer: Double(odometer) ?? 0,
                                        kwh: Double(kwh) ?? 0,
                                        price: Double(price) ?? 0,
                                        socBefore: Double(socBefore) ?? 0,
                                        socAfter: Double(socAfter) ?? 0)
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
        }
    }

    private var totalText: String {
        let k = Double(kwh) ?? 0, p = Double(price) ?? 0
        return k > 0 ? "金额 ≈ ¥" + Calc.num(k * p, 2) : "填写充电量与单价后自动算金额"
    }

    private func numberRow(_ label: String, _ text: Binding<String>, _ placeholder: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, text: text).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - 费用

struct ExpenseFormView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    private let types = ["保养", "保险", "停车", "维修", "充电服务费", "其他"]
    @State private var type = "保养"
    @State private var date = Date()
    @State private var amount = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("类型", selection: $type) {
                        ForEach(types, id: \.self) { Text($0) }
                    }
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                    HStack {
                        Text("金额 (元)")
                        Spacer()
                        TextField("420", text: $amount).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
                Section("备注") {
                    TextField("如：常规保养 + 空调滤芯", text: $notes)
                }
            }
            .navigationTitle("记录费用")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.addExpense(type: type, date: Calc.dateFmt.string(from: date),
                                         amount: Double(amount) ?? 0, notes: notes)
                        dismiss()
                    }
                    .disabled((Double(amount) ?? 0) <= 0)
                }
            }
        }
    }
}

// MARK: - 车辆

struct VehicleFormView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let editing: Vehicle?
    @State private var name = ""
    @State private var plate = ""
    @State private var model = ""
    @State private var battery = ""
    @State private var limit = ""
    @State private var price = ""
    @State private var purchaseDate = Date()
    @State private var hasPurchaseDate = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("车辆名称（如 S05）", text: $name)
                    TextField("车牌号（如 吉A·D12345）", text: $plate)
                    TextField("车型（如 520Max）", text: $model)
                    HStack {
                        Text("电池容量 (kWh)")
                        Spacer()
                        TextField("56.1", text: $battery).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
                Section("年度额度") {
                    HStack {
                        Text("每年限定里程 (km)")
                        Spacer()
                        TextField("30000，0 表示不限", text: $limit).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    }
                }
                Section("购车信息（用于持有成本）") {
                    HStack {
                        Text("购车价格 (元)")
                        Spacer()
                        TextField("129800", text: $price).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    Toggle("填写购车日期", isOn: $hasPurchaseDate)
                    if hasPurchaseDate {
                        DatePicker("购车日期", selection: $purchaseDate, displayedComponents: .date)
                    }
                }
                if let v = editing {
                    Section {
                        Button("删除该车辆", role: .destructive) {
                            store.deleteVehicle(v.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "添加车辆" : "编辑车辆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var v = editing ?? Vehicle(id: store.newVehicleId())
                        v.name = name.trimmingCharacters(in: .whitespaces)
                        v.plate = plate.trimmingCharacters(in: .whitespaces)
                        v.model = model.trimmingCharacters(in: .whitespaces)
                        v.battery = Double(battery) ?? 0
                        v.annualLimit = Double(limit) ?? 0
                        v.purchasePrice = Double(price) ?? 0
                        v.purchaseDate = hasPurchaseDate ? Calc.dateFmt.string(from: purchaseDate) : ""
                        store.saveVehicle(v)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard !loaded, let v = editing else { loaded = true; return }
                name = v.name
                plate = v.plate
                model = v.model
                battery = v.battery > 0 ? Calc.num(v.battery, 1) : ""
                limit = v.annualLimit > 0 ? String(Int(v.annualLimit)) : ""
                price = v.purchasePrice > 0 ? String(Int(v.purchasePrice)) : ""
                if let d = Calc.parse(v.purchaseDate) {
                    purchaseDate = d
                    hasPurchaseDate = true
                }
                loaded = true
            }
        }
    }
}

// MARK: - 保养提醒

struct ReminderFormView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var rule = "both"
    @State private var intervalKm = "10000"
    @State private var baseOdometer = ""
    @State private var intervalDays = "365"
    @State private var baseDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("保养项目（如 机油保养）", text: $title)
                    Picker("规则", selection: $rule) {
                        Text("按里程").tag("mileage")
                        Text("按时间").tag("date")
                        Text("两者先到").tag("both")
                    }
                    .pickerStyle(.segmented)
                }
                if rule != "date" {
                    Section("里程") {
                        HStack {
                            Text("间隔里程 (km)")
                            Spacer()
                            TextField("10000", text: $intervalKm).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("上次保养里程 (km)")
                            Spacer()
                            TextField("留空取当前里程", text: $baseOdometer).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                    }
                }
                if rule != "mileage" {
                    Section("时间") {
                        HStack {
                            Text("间隔天数")
                            Spacer()
                            TextField("365", text: $intervalDays).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        }
                        DatePicker("上次保养日期", selection: $baseDate, displayedComponents: .date)
                    }
                }
                if let preview = nextPreview {
                    Section {
                        Text("下次保养：\(preview)").font(.footnote).foregroundStyle(Theme.green)
                    }
                }
            }
            .navigationTitle("保养项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let base = Double(baseOdometer) ?? store.overview.lastOdometer
                        store.addReminder(title: title.trimmingCharacters(in: .whitespaces),
                                          ruleType: rule,
                                          intervalKm: Double(intervalKm) ?? 0,
                                          baseOdometer: base,
                                          intervalDays: Int(Double(intervalDays) ?? 0),
                                          baseDate: Calc.dateFmt.string(from: baseDate))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var nextPreview: String? {
        var parts: [String] = []
        if rule != "date", let km = Double(intervalKm), km > 0 {
            let base = Double(baseOdometer) ?? store.overview.lastOdometer
            if base > 0 { parts.append("\(Int(base + km)) km") }
        }
        if rule != "mileage", let d = Int(intervalDays), d > 0 {
            parts.append(Calc.addDays(Calc.dateFmt.string(from: baseDate), d))
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " 或 ") + (rule == "both" ? "（先到为准）" : "")
    }
}
