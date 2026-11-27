import Foundation
import SwiftUI

@MainActor
final class Store: ObservableObject {
    @Published private(set) var data = AppData()

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("fuelmate.json")
    }

    init() { load() }

    // MARK: - 读写

    private func load() {
        guard let raw = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode(AppData.self, from: raw) {
            data = decoded
            return
        }
        // 兼容缺字段的旧文件
        if let obj = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] {
            var d = AppData()
            if let arr = obj["vehicles"] as? [[String: Any]] { d.vehicles = Store.decode(arr) }
            if let arr = obj["charges"] as? [[String: Any]] { d.charges = Store.decode(arr) }
            if let arr = obj["expenses"] as? [[String: Any]] { d.expenses = Store.decode(arr) }
            if let arr = obj["reminders"] as? [[String: Any]] { d.reminders = Store.decode(arr) }
            d.expenseTypes = obj["expenseTypes"] as? [String]
            d.currentVehicleId = obj["currentVehicleId"] as? Int ?? 0
            d.seq = obj["seq"] as? Int ?? 0
            data = d
        }
    }

    private static func decode<T: Decodable>(_ arr: [[String: Any]]) -> [T] {
        guard let data = try? JSONSerialization.data(withJSONObject: arr) else { return [] }
        return (try? JSONDecoder().decode([T].self, from: data)) ?? []
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let raw = try? encoder.encode(data) else { return }
        try? raw.write(to: fileURL, options: .atomic)
    }

    private func nextId() -> Int {
        data.seq += 1
        return data.seq
    }

    // MARK: - 派生数据

    var vehicles: [Vehicle] { data.vehicles }

    var currentVehicle: Vehicle? {
        data.vehicles.first { $0.id == data.currentVehicleId } ?? data.vehicles.first
    }

    var currentVehicleId: Int { currentVehicle?.id ?? 0 }

    var charges: [Charge] {
        data.charges.filter { $0.vehicleId == currentVehicleId }.sorted { $0.odometer > $1.odometer }
    }

    var expenses: [Expense] {
        data.expenses.filter { $0.vehicleId == currentVehicleId }.sorted { $0.date > $1.date }
    }

    var reminders: [Reminder] {
        data.reminders.filter { $0.vehicleId == currentVehicleId }
    }

    var overview: Overview { Calc.overview(charges, expenses) }

    var annual: AnnualInfo { Calc.annual(charges, limit: currentVehicle?.annualLimit ?? 0) }

    var ownership: Ownership {
        guard let v = currentVehicle else { return Ownership(days: 0, perDay: 0, perKm: 0) }
        return Calc.ownership(v, distance: overview.totalDistance)
    }

    var estimatedRange: Int {
        guard let v = currentVehicle else { return 0 }
        let soc = charges.first { $0.socAfter > 0 }?.socAfter ?? 0
        return Calc.estimatedRange(v, socAfter: soc, avgConsumption: overview.avgConsumption)
    }

    // MARK: - 车辆

    func saveVehicle(_ v: Vehicle) {
        if let idx = data.vehicles.firstIndex(where: { $0.id == v.id }) {
            data.vehicles[idx] = v
        } else {
            var nv = v
            if nv.id == 0 { nv.id = nextId() }
            data.vehicles.append(nv)
        }
        if data.currentVehicleId == 0 {
            data.currentVehicleId = data.vehicles.last?.id ?? 0
        }
        persist()
    }

    func newVehicleId() -> Int { nextId() }

    func selectVehicle(_ id: Int) {
        data.currentVehicleId = id
        persist()
    }

    func deleteVehicle(_ id: Int) {
        data.vehicles.removeAll { $0.id == id }
        data.charges.removeAll { $0.vehicleId == id }
        data.expenses.removeAll { $0.vehicleId == id }
        data.reminders.removeAll { $0.vehicleId == id }
        if data.currentVehicleId == id {
            data.currentVehicleId = data.vehicles.first?.id ?? 0
        }
        persist()
    }

    // MARK: - 充电

    func addCharge(date: String, odometer: Double, kwh: Double, price: Double, socBefore: Double, socAfter: Double) {
        let c = Charge(id: nextId(), vehicleId: currentVehicleId, date: date,
                       odometer: odometer, kwh: kwh, price: price,
                       socBefore: socBefore, socAfter: socAfter)
        data.charges.append(c)
        persist()
    }

    func deleteCharge(_ id: Int) {
        data.charges.removeAll { $0.id == id }
        persist()
    }

    func updateCharge(_ c: Charge) {
        if let i = data.charges.firstIndex(where: { $0.id == c.id }) {
            data.charges[i] = c
        } else {
            data.charges.append(c)
        }
        persist()
    }

    // MARK: - 费用

    func addExpense(type: String, date: String, amount: Double, notes: String) {
        let e = Expense(id: nextId(), vehicleId: currentVehicleId, type: type,
                        date: date, amount: amount, notes: notes)
        data.expenses.append(e)
        persist()
    }

    func deleteExpense(_ id: Int) {
        data.expenses.removeAll { $0.id == id }
        persist()
    }

    func updateExpense(_ e: Expense) {
        if let i = data.expenses.firstIndex(where: { $0.id == e.id }) {
            data.expenses[i] = e
        } else {
            data.expenses.append(e)
        }
        persist()
    }

    // MARK: - 费用项目（可自定义）

    static let defaultTypes = ["保养", "保险", "停车", "维修", "充电服务费", "其他"]

    var expenseTypes: [String] {
        if let list = data.expenseTypes, !list.isEmpty { return list }
        return Store.defaultTypes
    }

    func addExpenseType(_ name: String) {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, !expenseTypes.contains(n) else { return }
        var list = expenseTypes
        list.append(n)
        data.expenseTypes = list
        persist()
    }

    func removeExpenseType(_ name: String) {
        var list = expenseTypes
        guard list.count > 1 else { return }
        list.removeAll { $0 == name }
        data.expenseTypes = list
        persist()
    }

    // MARK: - 保养

    func addReminder(title: String, ruleType: String, intervalKm: Double,
                     baseOdometer: Double, intervalDays: Int, baseDate: String,
                     expenseType: String = "") {
        let r = Reminder(id: nextId(), vehicleId: currentVehicleId, title: title,
                         ruleType: ruleType, intervalKm: intervalKm,
                         baseOdometer: baseOdometer, intervalDays: intervalDays, baseDate: baseDate,
                         expenseType: expenseType.isEmpty ? nil : expenseType)
        data.reminders.append(r)
        persist()
    }

    func updateReminder(_ r: Reminder) {
        if let i = data.reminders.firstIndex(where: { $0.id == r.id }) {
            data.reminders[i] = r
        } else {
            data.reminders.append(r)
        }
        persist()
    }

    func newId() -> Int { nextId() }

    /// 记账时把提醒基准推进到本次（与鸿蒙一致的联动口径）
    func applyReminderFromExpense(id: Int, odometer: Double, date: String) {
        guard let i = data.reminders.firstIndex(where: { $0.id == id }) else { return }
        var r = data.reminders[i]
        if r.ruleType != "date", odometer > 0 { r.baseOdometer = odometer }
        if r.ruleType != "mileage" { r.baseDate = date }
        data.reminders[i] = r
        persist()
    }

    /// 按费用类型找已关联的提醒（无则 nil）
    func reminderLinked(to type: String) -> Reminder? {
        guard !type.isEmpty else { return nil }
        return reminders.first { ($0.expenseType ?? "") == type }
    }

    func completeReminder(_ r: Reminder) {
        guard let idx = data.reminders.firstIndex(where: { $0.id == r.id }) else { return }
        var nr = data.reminders[idx]
        if nr.ruleType != "date" {
            nr.baseOdometer = overview.lastOdometer
        }
        if nr.ruleType != "mileage" {
            nr.baseDate = Calc.today()
        }
        data.reminders[idx] = nr
        persist()
    }

    func deleteReminder(_ id: Int) {
        data.reminders.removeAll { $0.id == id }
        persist()
    }
}
