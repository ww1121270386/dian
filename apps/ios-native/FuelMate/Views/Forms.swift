import SwiftUI

// MARK: - 充电（新增 / 编辑）

struct ChargeFormView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let editing: Charge?

    @State private var date: Date
    @State private var odometer: String
    @State private var kwh: String
    @State private var price: String
    @State private var socBefore: String
    @State private var socAfter: String

    init(editing: Charge? = nil) {
        self.editing = editing
        _date = State(initialValue: editing.flatMap { Calc.parse($0.date) } ?? Date())
        _odometer = State(initialValue: editing.map { String(Int($0.odometer)) } ?? "")
        _kwh = State(initialValue: editing.map { Calc.num($0.kwh, 2) } ?? "")
        _price = State(initialValue: editing.map { Calc.num($0.price, 2) } ?? "")
        _socBefore = State(initialValue: (editing?.socBefore ?? 0) > 0 ? String(Int(editing!.socBefore)) : "")
        _socAfter = State(initialValue: (editing?.socAfter ?? 0) > 0 ? String(Int(editing!.socAfter)) : "")
    }

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
                if let c = editing {
                    Section {
                        Button("删除这条记录", role: .destructive) {
                            store.deleteCharge(c.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "记录充电" : "编辑充电")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let d = Calc.dateFmt.string(from: date)
                        if var c = editing {
                            c.date = d
                            c.odometer = Double(odometer) ?? 0
                            c.kwh = Double(kwh) ?? 0
                            c.price = Double(price) ?? 0
                            c.socBefore = Double(socBefore) ?? 0
                            c.socAfter = Double(socAfter) ?? 0
                            store.updateCharge(c)
                        } else {
                            store.addCharge(date: d,
                                            odometer: Double(odometer) ?? 0,
                                            kwh: Double(kwh) ?? 0,
                                            price: Double(price) ?? 0,
                                            socBefore: Double(socBefore) ?? 0,
                                            socAfter: Double(socAfter) ?? 0)
                        }
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

// MARK: - 费用（新增 / 编辑，含同步提醒）

struct ExpenseFormView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let editing: Expense?

    @State private var type: String
    @State private var date: Date
    @State private var amount: String
    @State private var notes: String
    @State private var syncOn: Bool
    @State private var syncReminderId: Int
    @State private var syncOdo: String

    init(editing: Expense? = nil) {
        self.editing = editing
        _type = State(initialValue: editing?.type ?? "保养")
        _date = State(initialValue: editing.flatMap { Calc.parse($0.date) } ?? Date())
        _amount = State(initialValue: editing.map { Calc.num($0.amount, 2) } ?? "")
        _notes = State(initialValue: editing?.notes ?? "")
        _syncOn = State(initialValue: false)
        _syncReminderId = State(initialValue: 0)
        _syncOdo = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("类型", selection: $type) {
                        ForEach(store.expenseTypes, id: \.self) { Text($0) }
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
                if !store.reminders.isEmpty {
                    Section {
                        Toggle("同步提醒", isOn: $syncOn)
                        if syncOn {
                            Picker("关联提醒", selection: $syncReminderId) {
                                ForEach(store.reminders) { r in
                                    Text(r.title).tag(r.id)
                                }
                            }
                            HStack {
                                Text("本次里程 (km)")
                                Spacer()
                                TextField("默认当前里程", text: $syncOdo)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    } footer: {
                        Text("把上次里程/日期更新为本次")
                    }
                }
            }
            .navigationTitle(editing == nil ? "记录费用" : "编辑费用")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled((Double(amount) ?? 0) <= 0)
                }
            }
            .onAppear {
                if let e = editing {
                    if let linked = store.reminderLinked(to: e.type) {
                        syncOn = true
                        syncReminderId = linked.id
                    }
                } else {
                    syncPick(for: type)
                }
                if syncOdo.isEmpty, store.overview.lastOdometer > 0 {
                    syncOdo = String(Int(store.overview.lastOdometer))
                }
            }
            .onChange(of: type) { newValue in
                syncPick(for: newValue)
            }
        }
    }

    /// 选中的费用类型若被提醒关联，则自动开启同步并选中该提醒
    private func syncPick(for newType: String) {
        if let linked = store.reminderLinked(to: newType) {
            syncOn = true
            syncReminderId = linked.id
        } else {
            syncOn = false
            if syncReminderId == 0 { syncReminderId = store.reminders.first?.id ?? 0 }
        }
    }

    private func save() {
        let d = Calc.dateFmt.string(from: date)
        let amt = Double(amount) ?? 0
        var expenseId = editing?.id ?? 0

        if var e = editing {
            e.type = type
            e.date = d
            e.amount = amt
            e.notes = notes
            store.updateExpense(e)
        } else {
            expenseId = store.newId()
            let e = Expense(id: expenseId, vehicleId: store.currentVehicleId,
                            type: type, date: d, amount: amt, notes: notes)
            store.updateExpense(e)
        }

        if syncOn, syncReminderId > 0 {
            let odo = Double(syncOdo) ?? store.overview.lastOdometer
            store.applyReminderFromExpense(id: syncReminderId, odometer: odo, date: d)
        }
        dismiss()
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

// MARK: - 提醒（新增 / 编辑）

struct ReminderFormView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let editing: Reminder?

    @State private var title: String
    @State private var rule: String
    @State private var intervalKm: String
    @State private var baseOdometer: String
    @State private var intervalDays: String
    @State private var baseDate: Date
    @State private var expenseType: String

    init(editing: Reminder? = nil) {
        self.editing = editing
        _title = State(initialValue: editing?.title ?? "")
        _rule = State(initialValue: editing?.ruleType ?? "both")
        _intervalKm = State(initialValue: editing.map { String(Int($0.intervalKm)) } ?? "10000")
        _baseOdometer = State(initialValue: (editing?.baseOdometer ?? 0) > 0 ? String(Int(editing!.baseOdometer)) : "")
        _intervalDays = State(initialValue: editing.map { String($0.intervalDays) } ?? "365")
        _baseDate = State(initialValue: editing.flatMap { Calc.parse($0.baseDate) } ?? Date())
        _expenseType = State(initialValue: editing?.expenseType ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("提醒名称（如 机油保养）", text: $title)
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
                            Text("上次里程 (km)")
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
                        DatePicker("上次日期", selection: $baseDate, displayedComponents: .date)
                    }
                }
                Section {
                    Picker("关联费用类型", selection: $expenseType) {
                        Text("不关联").tag("")
                        ForEach(store.expenseTypes, id: \.self) { Text($0).tag($0) }
                    }
                } footer: {
                    Text(expenseType.isEmpty
                         ? "不关联时，费用里需手动打开「同步提醒」"
                         : "在费用里记「\(expenseType)」时会自动带出这个提醒，并用本次里程更新基准")
                }
                if let preview = nextPreview {
                    Section {
                        Text("下次提醒：\(preview)").font(.footnote).foregroundStyle(Theme.green)
                    }
                }
                if let r = editing {
                    Section {
                        Button("删除这条提醒", role: .destructive) {
                            store.deleteReminder(r.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "新建提醒" : "编辑提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let base = Double(baseOdometer) ?? store.overview.lastOdometer
                        let newTitle = title.trimmingCharacters(in: .whitespaces)
                        if var r = editing {
                            r.title = newTitle
                            r.ruleType = rule
                            r.intervalKm = Double(intervalKm) ?? 0
                            r.baseOdometer = base
                            r.intervalDays = Int(Double(intervalDays) ?? 0)
                            r.baseDate = Calc.dateFmt.string(from: baseDate)
                            r.expenseType = expenseType.isEmpty ? nil : expenseType
                            store.updateReminder(r)
                        } else {
                            store.addReminder(title: newTitle,
                                              ruleType: rule,
                                              intervalKm: Double(intervalKm) ?? 0,
                                              baseOdometer: base,
                                              intervalDays: Int(Double(intervalDays) ?? 0),
                                              baseDate: Calc.dateFmt.string(from: baseDate),
                                              expenseType: expenseType)
                        }
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
