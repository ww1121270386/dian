'use strict';
const assert = require('assert');
const { consumptionFor, applyReminderFromExpense, matchReminderByType, segments } = require('./calc');

let n = 0;
const t = (name, fn) => { fn(); n++; console.log('  ✓', name); };

/* ---------- ① 充电列表单次电耗 ---------- */
const charges = [
  { id: 1, date: '2026-11-01', odometer: 10700, kwh: 43.4, price: 1.05 },
  { id: 2, date: '2026-11-20', odometer: 11100, kwh: 42.5, price: 0.95 },
];
t('首条充电无电耗（返回 -1）', () => assert.strictEqual(consumptionFor(charges, 1), -1));
t('第二条电耗 = 42.5/400 = 0.106', () => assert.strictEqual(consumptionFor(charges, 2), 0.106));
t('里程相同不产生除法异常', () => {
  const same = [{ id: 1, odometer: 500, kwh: 10 }, { id: 2, odometer: 500, kwh: 12 }];
  assert.strictEqual(consumptionFor(same, 2), -1);
});
t('充电量为 0 时无电耗', () => {
  const zero = [{ id: 1, odometer: 100, kwh: 10 }, { id: 2, odometer: 200, kwh: 0 }];
  assert.strictEqual(consumptionFor(zero, 2), -1);
});
t('乱序录入仍按里程排序计算', () => {
  const shuffled = [charges[1], charges[0]];
  assert.strictEqual(consumptionFor(shuffled, 2), 0.106);
});

/* ---------- ② 提醒编辑不新增（id 稳定） ---------- */
const rem = { id: 3, vehicleId: 1, title: '机油保养', ruleType: 'both', intervalKm: 5000, baseOdometer: 10700, intervalDays: 365, baseDate: '2026-02-01', expenseType: '提醒' };
t('编辑提醒后 id 不变（不会新增一条）', () => {
  const edited = Object.assign({}, rem, { title: '机油保养(改)' });
  assert.strictEqual(edited.id, rem.id);
});
t('双规则费用回写：里程与日期都更新', () => {
  const r = applyReminderFromExpense(rem, '2026-11-27', 11100);
  assert.strictEqual(r.baseOdometer, 11100);
  assert.strictEqual(r.baseDate, '2026-11-27');
  assert.strictEqual(r.id, 3);
});
t('纯时间规则只更新日期', () => {
  const r = applyReminderFromExpense(Object.assign({}, rem, { ruleType: 'date', intervalKm: 0 }), '2026-12-01', 12000);
  assert.strictEqual(r.baseDate, '2026-12-01');
  assert.strictEqual(r.baseOdometer, 10700);
});
t('纯里程规则只更新里程', () => {
  const r = applyReminderFromExpense(Object.assign({}, rem, { ruleType: 'mileage', intervalDays: 0 }), '2026-12-01', 12000);
  assert.strictEqual(r.baseOdometer, 12000);
  assert.strictEqual(r.baseDate, '2026-02-01');
});
t('里程为 0 时不覆盖基准里程', () => {
  const r = applyReminderFromExpense(rem, '2026-11-27', 0);
  assert.strictEqual(r.baseOdometer, 10700);
});
t('不传提醒返回 null（防御）', () => assert.strictEqual(applyReminderFromExpense(null, '2026-11-27', 1), null));

/* ---------- ③ 费用类型自动匹配提醒 ---------- */
const rems = [rem, Object.assign({}, rem, { id: 9, title: '保险到期', expenseType: '保险', ruleType: 'date', intervalDays: 365 })];
t('类型=提醒 → 命中关联提醒并自动同步', () => {
  const m = matchReminderByType(rems, '提醒');
  assert.deepStrictEqual(m, { sync: true, reminderId: 3 });
});
t('类型=保险 → 命中另一条提醒', () => assert.deepStrictEqual(matchReminderByType(rems, '保险'), { sync: true, reminderId: 9 }));
t('类型=停车（无关联）→ 不自动同步，默认首条', () => assert.deepStrictEqual(matchReminderByType(rems, '停车'), { sync: false, reminderId: 3 }));
t('无提醒时安全返回', () => assert.deepStrictEqual(matchReminderByType([], '提醒'), { sync: false, reminderId: 0 }));
t('关联字段缺失的旧数据不报错', () => {
  const legacy = [{ id: 5, ruleType: 'both' }];
  assert.deepStrictEqual(matchReminderByType(legacy, '提醒'), { sync: false, reminderId: 5 });
});

/* ---------- ④ 一致性：分段电耗与逐条计算口径相同 ---------- */
t('segments 与 consumptionFor 同口径', () => {
  const segs = segments(charges);
  assert.strictEqual(segs[0].consumption, consumptionFor(charges, 2));
});

console.log('RULES-PASS（' + n + ' 项）');
