'use strict';
/* 业务算法基准（与 fpk 版本一致）：两端原生实现须给出相同结果 */

const round2 = (n) => Math.round(n * 100) / 100;
const round3 = (n) => Math.round(n * 1000) / 1000;

/** 相邻两次充电的电耗分段（kWh/km），首条为起点 */
function segments(charges) {
  const asc = [...charges].sort((a, b) => a.odometer - b.odometer || a.date.localeCompare(b.date));
  const out = [];
  for (let i = 1; i < asc.length; i++) {
    const prev = asc[i - 1], cur = asc[i];
    const dist = cur.odometer - prev.odometer;
    if (dist <= 0 || !(cur.kwh > 0)) continue;
    out.push({ date: cur.date, odometer: round2(cur.odometer), distance: round2(dist), kwh: round2(cur.kwh), consumption: round3(cur.kwh / dist) });
  }
  return out;
}

function overview(charges, expenses) {
  const asc = [...charges].sort((a, b) => a.odometer - b.odometer);
  const segs = segments(asc);
  const first = asc.length ? asc[0].odometer : null;
  const last = asc.length ? asc[asc.length - 1].odometer : null;
  const dist = first != null ? round2(last - first) : 0;
  const segDist = segs.reduce((s, x) => s + x.distance, 0);
  const segKwh = segs.reduce((s, x) => s + x.kwh, 0);
  const chargeCost = round2(charges.reduce((s, c) => s + c.kwh * c.price, 0));
  const otherCost = round2(expenses.reduce((s, e) => s + e.amount, 0));
  return {
    chargeCount: charges.length,
    totalDistance: dist,
    totalKwh: round2(charges.reduce((s, c) => s + c.kwh, 0)),
    totalChargeCost: chargeCost,
    totalOtherCost: otherCost,
    totalCost: round2(chargeCost + otherCost),
    avgConsumption: segDist > 0 ? round3(segKwh / segDist) : null,
    lastConsumption: segs.length ? segs[segs.length - 1].consumption : null,
    chargeCostPerKm: dist > 0 ? round2(chargeCost / dist) : null,
    allCostPerKm: dist > 0 ? round2((chargeCost + otherCost) / dist) : null,
    lastOdometer: last,
  };
}

/** 年度周期里程：年初基准取上一年最后一条记录，否则取当年首条 */
function annual(charges, limit, today) {
  const y = today.getFullYear();
  const yStart = `${y}-01-01`, yEnd = `${y}-12-31`;
  const inYear = charges.filter((c) => c.date >= yStart && c.date <= yEnd).sort((a, b) => a.odometer - b.odometer);
  const before = charges.filter((c) => c.date < yStart).sort((a, b) => a.date.localeCompare(b.date) || a.odometer - b.odometer);
  const base = before.length ? before[before.length - 1].odometer : (inYear.length ? inYear[0].odometer : null);
  const max = inYear.length ? inYear[inYear.length - 1].odometer : null;
  const used = base != null && max != null ? Math.max(0, round2(max - base)) : 0;
  const yearEndDate = new Date(y, 11, 31);
  const today0 = new Date(y, today.getMonth(), today.getDate());
  const daysLeft = Math.max(0, Math.round((yearEndDate - today0) / 86400000));
  const remaining = limit != null ? round2(limit - used) : null;
  const dailyBudget = remaining != null && remaining > 0 && daysLeft > 0 ? Math.round(remaining / daysLeft) : 0;
  return { year: y, used, limit, remaining, daysLeft, dailyBudget, pct: limit ? Math.min(100, Math.round((used / limit) * 100)) : null };
}

/** 保养下次到期：里程/日期/双规则 */
function reminderNext(r, currentOdo, today) {
  const nextOdo = r.ruleType !== 'date' && r.intervalKm ? round2(r.baseOdometer + r.intervalKm) : null;
  let nextDate = null;
  if (r.ruleType !== 'mileage' && r.intervalDays && r.baseDate) {
    const d = new Date(r.baseDate + 'T00:00:00');
    d.setDate(d.getDate() + r.intervalDays);
    nextDate = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  }
  const kmRemaining = nextOdo != null && currentOdo != null ? round2(nextOdo - currentOdo) : null;
  const daysRemaining = nextDate ? Math.round((new Date(nextDate + 'T00:00:00') - new Date(today.getFullYear(), today.getMonth(), today.getDate())) / 86400000) : null;
  const kmPct = nextOdo != null && r.intervalKm ? Math.min(100, Math.round(((currentOdo - r.baseOdometer) / r.intervalKm) * 100)) : null;
  const daysPct = nextDate && r.intervalDays ? Math.min(100, Math.round(((r.intervalDays - (daysRemaining ?? 0)) / r.intervalDays) * 100)) : null;
  let status = 'ok';
  if ((kmRemaining != null && kmRemaining < 0) || (daysRemaining != null && daysRemaining < 0)) status = 'expired';
  else if ((kmPct ?? 0) >= 80 || (daysPct ?? 0) >= 80) status = 'warn';
  return { nextOdo, nextDate, kmRemaining, daysRemaining, kmPct, daysPct, status };
}

/** 持有成本 */
function ownership(price, purchaseDate, distance, today) {
  if (price == null) return { days: null, perDay: null, perKm: null };
  let days = null;
  if (purchaseDate) {
    const d0 = new Date(purchaseDate + 'T00:00:00');
    const t0 = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    days = Math.max(1, Math.round((t0 - d0) / 86400000) + 1);
  }
  return { days, perDay: days ? round2(price / days) : null, perKm: distance > 0 ? round2(price / distance) : null };
}

module.exports = { segments, overview, annual, reminderNext, ownership, round2, round3 };

/** 单条充电的电耗（对应 ArkTS consumptionFor），首条/异常返回 -1 */
function consumptionFor(charges, id) {
  const asc = [...charges].sort((a, b) => a.odometer - b.odometer);
  const idx = asc.findIndex((c) => c.id === id);
  if (idx <= 0) return -1;
  const dist = asc[idx].odometer - asc[idx - 1].odometer;
  if (dist <= 0 || !(asc[idx].kwh > 0)) return -1;
  return Math.round((asc[idx].kwh / dist) * 1000) / 1000;
}

/** 费用保存时按提醒规则回写基准（对应 Index.saveExpense 的联动分支），返回新对象，id 不变 */
function applyReminderFromExpense(reminder, expenseDate, odo) {
  if (!reminder) return null;
  const useKm = reminder.ruleType !== 'date' && odo > 0;
  const useDate = reminder.ruleType !== 'mileage';
  return Object.assign({}, reminder, {
    baseOdometer: useKm ? odo : reminder.baseOdometer,
    baseDate: useDate ? expenseDate : reminder.baseDate,
  });
}

/** 费用类型选中时自动匹配提醒（对应 syncPickForType） */
function matchReminderByType(reminders, type) {
  const hit = reminders.find((r) => r.expenseType && r.expenseType === type);
  if (hit) return { sync: true, reminderId: hit.id };
  return { sync: false, reminderId: reminders.length ? reminders[0].id : 0 };
}

module.exports.consumptionFor = consumptionFor;
module.exports.applyReminderFromExpense = applyReminderFromExpense;
module.exports.matchReminderByType = matchReminderByType;
