'use strict';
const assert = require('assert');
const { segments, overview, annual, reminderNext, ownership } = require('./calc');

const charges = [
  { date: '2026-01-10', odometer: 10000, kwh: 38.2, price: 0.98 },
  { date: '2026-03-01', odometer: 10350, kwh: 42.5, price: 1.15 },
  { date: '2026-05-01', odometer: 10700, kwh: 43.4, price: 0.62 },
];
const segs = segments(charges);
assert.deepStrictEqual(segs.map((s) => s.consumption), [0.121, 0.124]);
const ov = overview(charges, [{ amount: 4200 }]);
assert.strictEqual(ov.totalDistance, 700);
assert.strictEqual(ov.avgConsumption, 0.123);
assert.strictEqual(ov.chargeCostPerKm, 0.16);
assert.strictEqual(ov.allCostPerKm, 6.16);

const a = annual(charges, 30000, new Date('2026-11-16T00:00:00'));
assert.strictEqual(a.used, 700);
assert.strictEqual(a.daysLeft, 45);
assert.strictEqual(a.dailyBudget, 651);

const r = reminderNext({ ruleType: 'both', intervalKm: 5000, baseOdometer: 10000, intervalDays: 365, baseDate: '2026-05-01' }, 10700, new Date('2026-11-16T00:00:00'));
assert.strictEqual(r.nextOdo, 15000);
assert.strictEqual(r.nextDate, '2027-05-01');
assert.strictEqual(r.kmRemaining, 4300);
assert.strictEqual(r.status, 'ok');

const r2 = reminderNext({ ruleType: 'mileage', intervalKm: 600, baseOdometer: 10000 }, 10700, new Date('2026-11-16T00:00:00'));
assert.strictEqual(r2.status, 'expired');

const o = ownership(129800, '2025-11-16', 700, new Date('2026-11-16T00:00:00'));
assert.strictEqual(o.days, 366);
assert.strictEqual(o.perDay, 354.64);
assert.strictEqual(o.perKm, 185.43);

console.log('CALC-SPEC-PASS');
