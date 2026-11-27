import Foundation

// MARK: - 模型（未填写的数值统一 0，字符串 ''）

struct Vehicle: Identifiable, Codable, Equatable {
    var id: Int
    var name: String = ""
    var plate: String = ""
    var model: String = ""
    var battery: Double = 0
    var annualLimit: Double = 0
    var purchasePrice: Double = 0
    var purchaseDate: String = ""
}

struct Charge: Identifiable, Codable, Equatable {
    var id: Int
    var vehicleId: Int
    var date: String
    var odometer: Double
    var kwh: Double
    var price: Double
    var socBefore: Double = 0
    var socAfter: Double = 0

    var amount: Double { (kwh * price * 100).rounded() / 100 }
}

struct Expense: Identifiable, Codable, Equatable {
    var id: Int
    var vehicleId: Int
    var type: String
    var date: String
    var amount: Double
    var notes: String = ""
}

struct Reminder: Identifiable, Codable, Equatable {
    var id: Int
    var vehicleId: Int
    var title: String
    var ruleType: String   // mileage | date | both
    var intervalKm: Double = 0
    var baseOdometer: Double = 0
    var intervalDays: Int = 0
    var baseDate: String = ""
}

// MARK: - 计算结果

struct Seg: Identifiable {
    var id: Int { chargeId }
    let chargeId: Int
    let date: String
    let odometer: Double
    let distance: Double
    let kwh: Double
    let consumption: Double
}

struct Overview {
    var chargeCount = 0
    var totalDistance: Double = 0
    var totalKwh: Double = 0
    var totalChargeCost: Double = 0
    var totalOtherCost: Double = 0
    var totalCost: Double = 0
    var avgConsumption: Double = -1
    var lastConsumption: Double = -1
    var chargeCostPerKm: Double = -1
    var allCostPerKm: Double = -1
    var lastOdometer: Double = 0
}

struct AnnualInfo {
    var year: Int
    var used: Double
    var limit: Double
    var remaining: Double
    var daysLeft: Int
    var dailyBudget: Int
    var pct: Int
}

struct ReminderState {
    var nextOdo: Double = 0
    var nextDate: String = ""
    var kmRemaining: Double = 999999
    var daysRemaining: Int = 999999
    var kmPct: Int = 0
    var daysPct: Int = 0
    var status: String = "ok"
}

struct Ownership {
    var days: Int
    var perDay: Double
    var perKm: Double
}

// MARK: - 持久化容器

struct AppData: Codable {
    var vehicles: [Vehicle] = []
    var charges: [Charge] = []
    var expenses: [Expense] = []
    var reminders: [Reminder] = []
    var currentVehicleId: Int = 0
    var seq: Int = 0
}
