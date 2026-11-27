import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { Charge, Expense, Reminder, Vehicle } from '../model/Calc';

const PREF_NAME: string = 'fuelmate_native';
const K_VEHICLES: string = 'vehicles';
const K_CHARGES: string = 'charges';
const K_EXPENSES: string = 'expenses';
const K_REMINDERS: string = 'reminders';
const K_SEQ: string = 'seq';
const K_CURRENT: string = 'currentVehicleId';
const K_TYPES: string = 'expenseTypes';
const K_SEEDED: string = 'demoSeeded';
const DEFAULT_TYPES: string = '["保养","保险","停车","维修","其他"]';

/**
 * 本地存储：preferences 存 JSON。
 * 数据量在千条级以内，读入内存后由 Calc 计算，无需 RDB 的查询能力。
 */
export class Repo {
  private static inst: Repo = new Repo();
  private pref: preferences.Preferences | null = null;

  static get(): Repo {
    return Repo.inst;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.pref === null) {
      this.pref = await preferences.getPreferences(context, PREF_NAME);
    }
  }

  private async readRaw(key: string, fallback: string): Promise<string> {
    if (this.pref === null) {
      return fallback;
    }
    const v = await this.pref.get(key, fallback);
    return String(v);
  }

  private async writeRaw(key: string, value: string): Promise<void> {
    if (this.pref === null) {
      return;
    }
    await this.pref.put(key, value);
    await this.pref.flush();
  }

  async nextId(): Promise<number> {
    const raw = await this.readRaw(K_SEQ, '0');
    const n = Number(raw) + 1;
    await this.writeRaw(K_SEQ, String(n));
    return n;
  }

  /* ---------- 车辆 ---------- */
  async vehicles(): Promise<Vehicle[]> {
    const s = await this.readRaw(K_VEHICLES, '[]');
    try {
      return JSON.parse(s) as Vehicle[];
    } catch (e) {
      return [];
    }
  }

  async saveVehicles(list: Vehicle[]): Promise<void> {
    await this.writeRaw(K_VEHICLES, JSON.stringify(list));
  }

  async currentVehicleId(): Promise<number> {
    const raw = await this.readRaw(K_CURRENT, '0');
    return Number(raw);
  }

  async setCurrentVehicleId(id: number): Promise<void> {
    await this.writeRaw(K_CURRENT, String(id));
  }

  /* ---------- 首次启动示例数据 ---------- */
  async isDemoSeeded(): Promise<boolean> {
    const raw = await this.readRaw(K_SEEDED, '0');
    return raw === '1';
  }

  async markDemoSeeded(): Promise<void> {
    await this.writeRaw(K_SEEDED, '1');
  }

  /** 灌入一套演示数据（仅首次启动、且无车辆时调用） */
  async seedDemo(): Promise<void> {
    const vehicles: Vehicle[] = [
      { id: 1, name: '深蓝 S05', plate: '吉A·D12345', model: '520Max', battery: 56.1,
        annualLimit: 6000, purchasePrice: 129800, purchaseDate: '2025-11-27' },
      { id: 2, name: 'Model 3', plate: '京B·66666', model: '长续航', battery: 60,
        annualLimit: 20000, purchasePrice: 0, purchaseDate: '' },
    ];
    const charges: Charge[] = [
      { id: 1, vehicleId: 1, date: '2026-08-05', odometer: 10250, kwh: 38.6, price: 1.02, socBefore: 22, socAfter: 92 },
      { id: 2, vehicleId: 1, date: '2026-08-22', odometer: 10610, kwh: 40.2, price: 0.98, socBefore: 18, socAfter: 95 },
      { id: 3, vehicleId: 1, date: '2026-09-08', odometer: 11000, kwh: 41.8, price: 1.05, socBefore: 20, socAfter: 96 },
      { id: 4, vehicleId: 1, date: '2026-09-26', odometer: 11420, kwh: 43.1, price: 0.92, socBefore: 15, socAfter: 93 },
      { id: 5, vehicleId: 1, date: '2026-10-15', odometer: 11860, kwh: 44.6, price: 1.08, socBefore: 19, socAfter: 97 },
      { id: 6, vehicleId: 1, date: '2026-11-02', odometer: 12280, kwh: 42.9, price: 0.95, socBefore: 21, socAfter: 94 },
      { id: 7, vehicleId: 1, date: '2026-11-18', odometer: 12720, kwh: 43.5, price: 1.02, socBefore: 17, socAfter: 95 },
      { id: 8, vehicleId: 1, date: '2026-12-05', odometer: 13100, kwh: 45.0, price: 0.88, socBefore: 14, socAfter: 96 },
    ];
    const expenses: Expense[] = [
      { id: 11, vehicleId: 1, type: '保养', date: '2026-10-15', amount: 420, notes: '常规保养' },
      { id: 12, vehicleId: 1, type: '保险', date: '2026-11-01', amount: 3800, notes: '商业险' },
      { id: 13, vehicleId: 1, type: '停车', date: '2026-11-20', amount: 60, notes: '月卡' },
      { id: 14, vehicleId: 1, type: '洗车', date: '2026-12-01', amount: 35, notes: '精洗' },
      { id: 15, vehicleId: 1, type: '维修', date: '2026-09-20', amount: 280, notes: '补胎' },
    ];
    const reminders: Reminder[] = [
      { id: 21, vehicleId: 1, title: '机油保养', ruleType: 'both', intervalKm: 5000, baseOdometer: 10250, intervalDays: 365, baseDate: '2026-08-05', expenseType: '保养' },
      { id: 22, vehicleId: 1, title: '年检', ruleType: 'both', intervalKm: 5000, baseOdometer: 10250, intervalDays: 365, baseDate: '2026-01-15', expenseType: '' },
      { id: 23, vehicleId: 1, title: '保险到期', ruleType: 'date', intervalKm: 0, baseOdometer: 0, intervalDays: 365, baseDate: '2025-12-01', expenseType: '保险' },
      { id: 24, vehicleId: 1, title: '轮胎换位', ruleType: 'mileage', intervalKm: 10000, baseOdometer: 8000, intervalDays: 0, baseDate: '', expenseType: '维修' },
    ];
    await this.saveVehicles(vehicles);
    await this.writeRaw(K_CHARGES, JSON.stringify(charges));
    await this.writeRaw(K_EXPENSES, JSON.stringify(expenses));
    await this.writeRaw(K_REMINDERS, JSON.stringify(reminders));
    await this.saveExpenseTypes(['保养', '保险', '停车', '维修', '洗车', '充电服务费']);
    await this.writeRaw(K_SEQ, '100');
    await this.setCurrentVehicleId(1);
    await this.markDemoSeeded();
  }

  /* ---------- 费用项目（可自定义） ---------- */
  async expenseTypes(): Promise<string[]> {
    const raw = await this.readRaw(K_TYPES, DEFAULT_TYPES);
    try {
      const list = JSON.parse(raw) as string[];
      return list.length > 0 ? list : JSON.parse(DEFAULT_TYPES) as string[];
    } catch (e) {
      return JSON.parse(DEFAULT_TYPES) as string[];
    }
  }

  async saveExpenseTypes(list: string[]): Promise<void> {
    await this.writeRaw(K_TYPES, JSON.stringify(list));
  }

  /* ---------- 充电 ---------- */
  async charges(vehicleId: number): Promise<Charge[]> {
    const s = await this.readRaw(K_CHARGES, '[]');
    let all: Charge[] = [];
    try {
      all = JSON.parse(s) as Charge[];
    } catch (e) {
      all = [];
    }
    return all
      .filter((c: Charge) => c.vehicleId === vehicleId)
      .sort((a: Charge, b: Charge) => b.odometer - a.odometer);
  }

  async allCharges(): Promise<Charge[]> {
    const s = await this.readRaw(K_CHARGES, '[]');
    try {
      return JSON.parse(s) as Charge[];
    } catch (e) {
      return [];
    }
  }

  async addCharge(c: Charge): Promise<void> {
    const all = await this.allCharges();
    all.push(c);
    await this.writeRaw(K_CHARGES, JSON.stringify(all));
  }

  async updateCharge(c: Charge): Promise<void> {
    const all = await this.allCharges();
    const idx = all.findIndex((x: Charge) => x.id === c.id);
    if (idx >= 0) {
      all[idx] = c;
    } else {
      all.push(c);
    }
    await this.writeRaw(K_CHARGES, JSON.stringify(all));
  }

  async deleteCharge(id: number): Promise<void> {
    const all = (await this.allCharges()).filter((c: Charge) => c.id !== id);
    await this.writeRaw(K_CHARGES, JSON.stringify(all));
  }

  /* ---------- 费用 ---------- */
  async allExpenses(): Promise<Expense[]> {
    const s = await this.readRaw(K_EXPENSES, '[]');
    try {
      return JSON.parse(s) as Expense[];
    } catch (e) {
      return [];
    }
  }

  async expenses(vehicleId: number): Promise<Expense[]> {
    const all = await this.allExpenses();
    return all
      .filter((e: Expense) => e.vehicleId === vehicleId)
      .sort((a: Expense, b: Expense) => (a.date < b.date ? 1 : -1));
  }

  async addExpense(e: Expense): Promise<void> {
    const all = await this.allExpenses();
    all.push(e);
    await this.writeRaw(K_EXPENSES, JSON.stringify(all));
  }

  async updateExpense(e: Expense): Promise<void> {
    const all = await this.allExpenses();
    const idx = all.findIndex((x: Expense) => x.id === e.id);
    if (idx >= 0) {
      all[idx] = e;
    } else {
      all.push(e);
    }
    await this.writeRaw(K_EXPENSES, JSON.stringify(all));
  }

  async deleteExpense(id: number): Promise<void> {
    const all = (await this.allExpenses()).filter((e: Expense) => e.id !== id);
    await this.writeRaw(K_EXPENSES, JSON.stringify(all));
  }

  /* ---------- 保养提醒 ---------- */
  async allReminders(): Promise<Reminder[]> {
    const s = await this.readRaw(K_REMINDERS, '[]');
    try {
      return JSON.parse(s) as Reminder[];
    } catch (e) {
      return [];
    }
  }

  async reminders(vehicleId: number): Promise<Reminder[]> {
    const all = await this.allReminders();
    return all.filter((r: Reminder) => r.vehicleId === vehicleId);
  }

  async addReminder(r: Reminder): Promise<void> {
    const all = await this.allReminders();
    all.push(r);
    await this.writeRaw(K_REMINDERS, JSON.stringify(all));
  }

  async updateReminder(r: Reminder): Promise<void> {
    const all = await this.allReminders();
    const idx = all.findIndex((x: Reminder) => x.id === r.id);
    if (idx >= 0) {
      all[idx] = r;
    } else {
      all.push(r);
    }
    await this.writeRaw(K_REMINDERS, JSON.stringify(all));
  }

  async deleteReminder(id: number): Promise<void> {
    const all = (await this.allReminders()).filter((r: Reminder) => r.id !== id);
    await this.writeRaw(K_REMINDERS, JSON.stringify(all));
  }

  /** 删除车辆时的级联清理 */
  async deleteVehicle(id: number): Promise<void> {
    const vs = (await this.vehicles()).filter((v: Vehicle) => v.id !== id);
    await this.saveVehicles(vs);
    const cs = (await this.allCharges()).filter((c: Charge) => c.vehicleId !== id);
    await this.writeRaw(K_CHARGES, JSON.stringify(cs));
    const es = (await this.allExpenses()).filter((e: Expense) => e.vehicleId !== id);
    await this.writeRaw(K_EXPENSES, JSON.stringify(es));
    const rs = (await this.allReminders()).filter((r: Reminder) => r.vehicleId !== id);
    await this.writeRaw(K_REMINDERS, JSON.stringify(rs));
  }
}
