/**
 * 数据模型与业务算法（与 fpk 版 H5 口径一致，已用 JS 基准单测锁定）
 * 约定：未填写的数值统一用 0 表示，字符串用 ''。
 */

export interface Vehicle {
  id: number;
  name: string;
  plate: string;
  model: string;
  battery: number;        // kWh，0=未填
  annualLimit: number;    // 每年限定里程 km，0=不限
  purchasePrice: number;  // 购车价，0=未填
  purchaseDate: string;   // YYYY-MM-DD，''=未填
}

export interface Charge {
  id: number;
  vehicleId: number;
  date: string;
  odometer: number;
  kwh: number;
  price: number;
  socBefore: number;      // %，0=未填
  socAfter: number;
}

export interface Expense {
  id: number;
  vehicleId: number;
  type: string;
  date: string;
  amount: number;
  notes: string;
}

export interface Reminder {
  id: number;
  vehicleId: number;
  title: string;
  ruleType: string;       // 'mileage' | 'date' | 'both'
  intervalKm: number;
  baseOdometer: number;
  intervalDays: number;
  baseDate: string;
  expenseType: string;   // 关联的费用类型，''=不关联
}

export interface Seg {
  date: string;
  odometer: number;
  distance: number;
  kwh: number;
  consumption: number;
}

export interface Overview {
  chargeCount: number;
  totalDistance: number;
  totalKwh: number;
  totalChargeCost: number;
  totalOtherCost: number;
  totalCost: number;
  avgConsumption: number;     // kWh/km，-1=无数据
  lastConsumption: number;
  chargeCostPerKm: number;    // -1=无数据
  allCostPerKm: number;
  lastOdometer: number;
}

export interface AnnualInfo {
  year: number;
  used: number;
  limit: number;
  remaining: number;
  daysLeft: number;
  dailyBudget: number;
  pct: number;
}

export interface ReminderState {
  nextOdo: number;      // 0=无
  nextDate: string;
  kmRemaining: number;  // 999999=无
  daysRemaining: number;
  kmPct: number;
  daysPct: number;
  status: string;       // 'ok' | 'warn' | 'expired'
}

export interface Ownership {
  days: number;
  perDay: number;
  perKm: number;
}

export function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

export function round3(n: number): number {
  return Math.round(n * 1000) / 1000;
}

export function todayStr(): string {
  const d = new Date();
  return dateStr(d);
}

export function dateStr(d: Date): string {
  const p = (x: number): string => (x < 10 ? '0' + x : String(x));
  return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate());
}

export function addDays(base: string, days: number): string {
  if (!base) {
    return '';
  }
  const d = new Date(base + 'T00:00:00');
  d.setDate(d.getDate() + days);
  return dateStr(d);
}

export function daysBetween(from: string, to: string): number {
  const a = new Date(from + 'T00:00:00').getTime();
  const b = new Date(to + 'T00:00:00').getTime();
  return Math.round((b - a) / 86400000);
}

/** 相邻两次充电的电耗分段（按里程升序，首条仅作起点） */
export function segments(charges: Charge[]): Seg[] {
  const asc: Charge[] = charges.slice().sort((a: Charge, b: Charge) => a.odometer - b.odometer);
  const out: Seg[] = [];
  for (let i = 1; i < asc.length; i++) {
    const prev: Charge = asc[i - 1];
    const cur: Charge = asc[i];
    const dist: number = cur.odometer - prev.odometer;
    if (dist <= 0 || cur.kwh <= 0) {
      continue;
    }
    out.push({
      date: cur.date,
      odometer: round2(cur.odometer),
      distance: round2(dist),
      kwh: round2(cur.kwh),
      consumption: round3(cur.kwh / dist),
    });
  }
  return out;
}

export function overview(charges: Charge[], expenses: Expense[]): Overview {
  const asc: Charge[] = charges.slice().sort((a: Charge, b: Charge) => a.odometer - b.odometer);
  const segs: Seg[] = segments(asc);
  let dist = 0;
  if (asc.length >= 2) {
    dist = round2(asc[asc.length - 1].odometer - asc[0].odometer);
  }
  let segDist = 0;
  let segKwh = 0;
  for (const s of segs) {
    segDist += s.distance;
    segKwh += s.kwh;
  }
  let chargeCost = 0;
  let kwhSum = 0;
  for (const c of charges) {
    chargeCost += c.kwh * c.price;
    kwhSum += c.kwh;
  }
  chargeCost = round2(chargeCost);
  let otherCost = 0;
  for (const e of expenses) {
    otherCost += e.amount;
  }
  otherCost = round2(otherCost);
  return {
    chargeCount: charges.length,
    totalDistance: dist,
    totalKwh: round2(kwhSum),
    totalChargeCost: chargeCost,
    totalOtherCost: otherCost,
    totalCost: round2(chargeCost + otherCost),
    avgConsumption: segDist > 0 ? round3(segKwh / segDist) : -1,
    lastConsumption: segs.length > 0 ? segs[segs.length - 1].consumption : -1,
    chargeCostPerKm: dist > 0 ? round2(chargeCost / dist) : -1,
    allCostPerKm: dist > 0 ? round2((chargeCost + otherCost) / dist) : -1,
    lastOdometer: asc.length > 0 ? asc[asc.length - 1].odometer : 0,
  };
}

/** 年度周期里程：年初基准取上一年最后一条记录，否则取当年首条 */
export function annualInfo(charges: Charge[], limit: number, today: Date): AnnualInfo {
  const y: number = today.getFullYear();
  const start: string = y + '-01-01';
  const end: string = y + '-12-31';
  const inYear: Charge[] = charges
    .filter((c: Charge) => c.date >= start && c.date <= end)
    .sort((a: Charge, b: Charge) => a.odometer - b.odometer);
  const before: Charge[] = charges
    .filter((c: Charge) => c.date < start)
    .sort((a: Charge, b: Charge) => (a.date === b.date ? a.odometer - b.odometer : (a.date < b.date ? -1 : 1)));

  let base = 0;
  let hasBase = false;
  if (before.length > 0) {
    base = before[before.length - 1].odometer;
    hasBase = true;
  } else if (inYear.length > 0) {
    base = inYear[0].odometer;
    hasBase = true;
  }
  const max = inYear.length > 0 ? inYear[inYear.length - 1].odometer : -1;
  const used: number = hasBase && max >= 0 ? Math.max(0, round2(max - base)) : 0;

  const yearEnd = new Date(y, 11, 31);
  const today0 = new Date(y, today.getMonth(), today.getDate());
  const daysLeft: number = Math.max(0, Math.round((yearEnd.getTime() - today0.getTime()) / 86400000));
  const remaining: number = limit > 0 ? round2(limit - used) : 0;
  const dailyBudget: number = remaining > 0 && daysLeft > 0 ? Math.round(remaining / daysLeft) : 0;
  return {
    year: y,
    used: used,
    limit: limit,
    remaining: remaining,
    daysLeft: daysLeft,
    dailyBudget: dailyBudget,
    pct: limit > 0 ? Math.min(100, Math.round((used / limit) * 100)) : 0,
  };
}

export function reminderState(r: Reminder, currentOdo: number, today: Date): ReminderState {
  const useKm: boolean = r.ruleType !== 'date' && r.intervalKm > 0;
  const useDate: boolean = r.ruleType !== 'mileage' && r.intervalDays > 0 && r.baseDate.length > 0;

  const nextOdo: number = useKm ? round2(r.baseOdometer + r.intervalKm) : 0;
  const nextDate: string = useDate ? addDays(r.baseDate, r.intervalDays) : '';

  const kmRemaining: number = useKm && currentOdo > 0 ? round2(nextOdo - currentOdo) : 999999;
  const daysRemaining: number = useDate ? daysBetween(todayStr(), nextDate) : 999999;

  const kmPct: number = useKm && currentOdo > 0
    ? Math.min(100, Math.max(0, Math.round(((currentOdo - r.baseOdometer) / r.intervalKm) * 100)))
    : 0;
  const daysPct: number = useDate && daysRemaining !== 999999
    ? Math.min(100, Math.max(0, Math.round(((r.intervalDays - daysRemaining) / r.intervalDays) * 100)))
    : 0;

  let status = 'ok';
  if ((useKm && currentOdo > 0 && kmRemaining < 0) || (useDate && daysRemaining < 0)) {
    status = 'expired';
  } else if (kmPct >= 80 || daysPct >= 80) {
    status = 'warn';
  }
  return {
    nextOdo: nextOdo,
    nextDate: nextDate,
    kmRemaining: kmRemaining,
    daysRemaining: daysRemaining,
    kmPct: kmPct,
    daysPct: daysPct,
    status: status,
  };
}

export function ownership(price: number, purchaseDate: string, distance: number): Ownership {
  if (price <= 0) {
    return { days: 0, perDay: 0, perKm: 0 };
  }
  let days = 0;
  if (purchaseDate.length > 0) {
    days = Math.max(1, daysBetween(purchaseDate, todayStr()) + 1);
  }
  return {
    days: days,
    perDay: days > 0 ? round2(price / days) : 0,
    perKm: distance > 0 ? round2(price / distance) : 0,
  };
}

export function estimatedRange(battery: number, socAfter: number, avgConsumption: number): number {
  if (battery <= 0 || socAfter <= 0 || avgConsumption <= 0) {
    return 0;
  }
  return Math.round((battery * socAfter / 100) / avgConsumption);
}

export function fmtNum(n: number, digits: number): string {
  if (n < 0) {
    return '—';
  }
  return n.toFixed(digits);
}

export function statusText(s: string): string {
  if (s === 'expired') {
    return '已到期';
  }
  if (s === 'warn') {
    return '临近';
  }
  return '正常';
}
