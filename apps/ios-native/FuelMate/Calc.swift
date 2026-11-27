import Foundation

enum Calc {
    static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func today() -> String { dateFmt.string(from: Date()) }

    static func parse(_ s: String) -> Date? { dateFmt.date(from: s) }

    static func addDays(_ base: String, _ days: Int) -> String {
        guard let d = parse(base) else { return "" }
        guard let r = Calendar.current.date(byAdding: .day, value: days, to: d) else { return "" }
        return dateFmt.string(from: r)
    }

    static func daysBetween(_ from: String, _ to: String) -> Int {
        guard let a = parse(from), let b = parse(to) else { return 0 }
        let cal = Calendar.current
        let d1 = cal.startOfDay(for: a)
        let d2 = cal.startOfDay(for: b)
        return cal.dateComponents([.day], from: d1, to: d2).day ?? 0
    }

    static func round2(_ n: Double) -> Double { (n * 100).rounded() / 100 }
    static func round3(_ n: Double) -> Double { (n * 1000).rounded() / 1000 }

    /// 相邻两次充电的电耗分段（kWh/km），首条仅作起点
    static func segments(_ charges: [Charge]) -> [Seg] {
        let asc = charges.sorted { $0.odometer < $1.odometer }
        guard asc.count > 1 else { return [] }
        var out: [Seg] = []
        for i in 1..<asc.count {
            let prev = asc[i - 1], cur = asc[i]
            let dist = cur.odometer - prev.odometer
            if dist <= 0 || cur.kwh <= 0 { continue }
            out.append(Seg(chargeId: cur.id,
                           date: cur.date,
                           odometer: round2(cur.odometer),
                           distance: round2(dist),
                           kwh: round2(cur.kwh),
                           consumption: round3(cur.kwh / dist)))
        }
        return out
    }

    static func overview(_ charges: [Charge], _ expenses: [Expense]) -> Overview {
        var o = Overview()
        let asc = charges.sorted { $0.odometer < $1.odometer }
        let segs = segments(asc)
        o.chargeCount = charges.count
        o.lastOdometer = asc.last?.odometer ?? 0
        if let first = asc.first, let last = asc.last {
            o.totalDistance = round2(last.odometer - first.odometer)
        }
        o.totalKwh = round2(charges.reduce(0) { $0 + $1.kwh })
        o.totalChargeCost = round2(charges.reduce(0) { $0 + $1.kwh * $1.price })
        o.totalOtherCost = round2(expenses.reduce(0) { $0 + $1.amount })
        o.totalCost = round2(o.totalChargeCost + o.totalOtherCost)
        let segDist = segs.reduce(0) { $0 + $1.distance }
        let segKwh = segs.reduce(0) { $0 + $1.kwh }
        o.avgConsumption = segDist > 0 ? round3(segKwh / segDist) : -1
        o.lastConsumption = segs.last?.consumption ?? -1
        o.chargeCostPerKm = o.totalDistance > 0 ? round2(o.totalChargeCost / o.totalDistance) : -1
        o.allCostPerKm = o.totalDistance > 0 ? round2(o.totalCost / o.totalDistance) : -1
        return o
    }

    /// 年度周期里程：年初基准取上一年最后一条记录，否则取当年首条
    static func annual(_ charges: [Charge], limit: Double) -> AnnualInfo {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let start = "\(year)-01-01"
        let end = "\(year)-12-31"
        let inYear = charges.filter { $0.date >= start && $0.date <= end }.sorted { $0.odometer < $1.odometer }
        let before = charges.filter { $0.date < start }.sorted { $0.date < $1.date }

        var base: Double? = nil
        if let lastBefore = before.last {
            base = lastBefore.odometer
        } else if let firstInYear = inYear.first {
            base = firstInYear.odometer
        }
        let maxOdo = inYear.last?.odometer
        let used: Double = {
            guard let b = base, let m = maxOdo else { return 0 }
            return max(0, round2(m - b))
        }()

        let today = cal.startOfDay(for: Date())
        let endOfYear = cal.date(from: DateComponents(year: year, month: 12, day: 31)) ?? today
        let daysLeft = max(0, cal.dateComponents([.day], from: today, to: endOfYear).day ?? 0)
        let remaining = limit > 0 ? round2(limit - used) : 0
        let daily = (remaining > 0 && daysLeft > 0) ? Int((remaining / Double(daysLeft)).rounded()) : 0
        let pct = limit > 0 ? min(100, Int(((used / limit) * 100).rounded())) : 0
        return AnnualInfo(year: year, used: used, limit: limit, remaining: remaining,
                          daysLeft: daysLeft, dailyBudget: daily, pct: pct)
    }

    static func reminderState(_ r: Reminder, currentOdo: Double) -> ReminderState {
        var s = ReminderState()
        let useKm = r.ruleType != "date" && r.intervalKm > 0
        let useDate = r.ruleType != "mileage" && r.intervalDays > 0 && !r.baseDate.isEmpty

        if useKm {
            s.nextOdo = round2(r.baseOdometer + r.intervalKm)
            if currentOdo > 0 {
                s.kmRemaining = round2(s.nextOdo - currentOdo)
                s.kmPct = min(100, max(0, Int((((currentOdo - r.baseOdometer) / r.intervalKm) * 100).rounded())))
            }
        }
        if useDate {
            s.nextDate = addDays(r.baseDate, r.intervalDays)
            if !s.nextDate.isEmpty {
                s.daysRemaining = daysBetween(today(), s.nextDate)
                let passed = r.intervalDays - s.daysRemaining
                s.daysPct = min(100, max(0, Int(((Double(passed) / Double(r.intervalDays)) * 100).rounded())))
            }
        }

        if (useKm && currentOdo > 0 && s.kmRemaining < 0) || (useDate && s.daysRemaining < 0) {
            s.status = "expired"
        } else if s.kmPct >= 80 || s.daysPct >= 80 {
            s.status = "warn"
        }
        return s
    }

    static func ownership(_ v: Vehicle, distance: Double) -> Ownership {
        guard v.purchasePrice > 0 else { return Ownership(days: 0, perDay: 0, perKm: 0) }
        var days = 0
        if !v.purchaseDate.isEmpty {
            days = max(1, daysBetween(v.purchaseDate, today()) + 1)
        }
        return Ownership(days: days,
                         perDay: days > 0 ? round2(v.purchasePrice / Double(days)) : 0,
                         perKm: distance > 0 ? round2(v.purchasePrice / distance) : 0)
    }

    static func estimatedRange(_ v: Vehicle, socAfter: Double, avgConsumption: Double) -> Int {
        guard v.battery > 0, socAfter > 0, avgConsumption > 0 else { return 0 }
        return Int(((v.battery * socAfter / 100) / avgConsumption).rounded())
    }

    static func statusText(_ s: String) -> String {
        switch s {
        case "expired": return "已到期"
        case "warn": return "临近"
        default: return "正常"
        }
    }

    static func num(_ v: Double, _ digits: Int) -> String {
        v < 0 ? "—" : String(format: "%.\(digits)f", v)
    }
}
