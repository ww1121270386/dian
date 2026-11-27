'use strict';

/**
 * 首页可复用组件模块
 * reminder-list : 保养提醒模块（含里程 / 时间进度条）
 * recent-records: 最近记录模块（纯展示，数据由父组件预处理）
 */
(function () {
  const STATUS_TEXT = { expired: '已到期', due_soon: '即将到期', ok: '正常' };

  /* ---------- 保养提醒 ---------- */
  const ReminderList = {
    name: 'ReminderList',
    props: {
      reminders: { type: Array, default: () => [] },
    },
    emits: ['edit', 'add'],
    methods: {
      statusText(r) {
        return STATUS_TEXT[r.status] || '正常';
      },
      /** 下次保养：里程 + 日期（后端已按规则计算） */
      nextText(r) {
        const parts = [];
        if (r.nextDueOdometer != null) parts.push(`${Math.round(r.nextDueOdometer)} km`);
        if (r.nextDueDate) parts.push(r.nextDueDate);
        return parts.length ? `下次 ${parts.join(' · ')}` : '';
      },
      /** 按规则生成进度条数据：里程条 / 时间条 */
      bars(r) {
        const out = [];
        if (r.rule_type !== 'date' && r.interval_km > 0 && r.base_odometer != null) {
          out.push(this.makeBar({
            key: 'km',
            label: '里程',
            interval: r.interval_km,
            remaining: r.kmRemaining,
            unit: 'km',
            total: r.interval_km,
            base: r.base_odometer,
          }));
        }
        if (r.rule_type !== 'mileage' && r.interval_days > 0 && r.base_date) {
          out.push(this.makeBar({
            key: 'day',
            label: '时间',
            interval: r.interval_days,
            remaining: r.daysRemaining,
            unit: '天',
            total: r.interval_days,
            base: r.base_date,
          }));
        }
        return out;
      },
      makeBar({ key, label, interval, remaining, unit, total, base }) {
        if (remaining == null) {
          return { key, label, pct: 0, tone: 'ok', text: '暂无数据', value: '' };
        }
        const used = interval - remaining;
        const pct = Math.max(0, Math.min(100, (used / interval) * 100));
        const tone = remaining <= 0 ? 'danger' : pct >= 70 ? 'warn' : 'ok';
        const text = remaining <= 0 ? `已超 ${Math.abs(Math.round(remaining))} ${unit}` : `剩 ${Math.round(remaining)} ${unit}`;
        const value = unit === 'km'
          ? `${Math.round(base)}→${Math.round(base + total)}`
          : base;
        return { key, label, pct: Math.round(pct), tone, text, value };
      },
    },
    template: `
      <div class="card module">
        <div class="module-head">
          <span class="module-title">⏰ 保养提醒</span>
          <button class="btn btn-sm btn-ghost" @click="$emit('add')">＋ 添加</button>
        </div>
        <div v-if="!reminders.length" class="empty">暂无提醒，可添加如「年度保养 每 10000km」</div>
        <div v-for="r in reminders" :key="r.id" class="remind-item" @click="$emit('edit', r)">
          <div class="remind-top">
            <div class="remind-name">{{ r.title }}</div>
            <span class="badge" :class="r.status">{{ statusText(r) }}</span>
          </div>
          <div class="remind-next" v-if="nextText(r)">{{ nextText(r) }}</div>
          <div class="bar-row" v-for="b in bars(r)" :key="b.key">
            <div class="bar-label">{{ b.label }}</div>
            <div class="bar-track" :title="b.value">
              <div class="bar-fill" :class="b.tone" :style="{ width: b.pct + '%' }"></div>
            </div>
            <div class="bar-value" :class="'is-' + b.tone">{{ b.text }}</div>
          </div>
        </div>
      </div>
    `,
  };

  /* ---------- 年度里程倒计时 ---------- */
  const AnnualCountdown = {
    name: 'AnnualCountdown',
    props: {
      annual: { type: Object, default: null },
    },
    computed: {
      pct() {
        return this.annual && this.annual.pct != null ? this.annual.pct : 0;
      },
      tone() {
        if (!this.annual || this.annual.limit == null) return 'ok';
        if (this.annual.used >= this.annual.limit) return 'danger';
        return this.pct >= 80 ? 'warn' : 'ok';
      },
      over() {
        return !!(this.annual && this.annual.remaining != null && this.annual.remaining < 0);
      },
      hint() {
        if (!this.annual) return '';
        if (this.over) return `已超出年度额度 ${this.km(-this.annual.remaining)} km`;
        if (!this.annual.daysLeft) return '本年度已结束，额度即将重置';
        return `按剩余天数折算，平均每天可行驶约 ${this.km(this.annual.dailyBudget)} km`;
      },
      periodText() {
        if (!this.annual) return '';
        return `${this.annual.yearStart.slice(5)} ~ ${this.annual.yearEnd.slice(5)}`;
      },
      /** 往年里程（不含当前年，最多 3 条） */
      historyText() {
        const h = (this.annual && this.annual.history) || [];
        return h
          .filter((x) => x.year !== this.annual.year)
          .slice(0, 3)
          .map((x) => `${x.year} 年 ${this.km(x.distance)} km`)
          .join(' · ');
      },
    },
    methods: {
      km(n) {
        return Number(n || 0).toLocaleString('zh-CN');
      },
    },
    template: `
      <div class="card module countdown">
        <div class="module-head">
          <span class="module-title">⏳ 年度里程倒计时</span>
          <span class="cd-tag">{{ annual.year }} 年度 · {{ periodText }}</span>
        </div>
        <div class="cd-main">
          <div class="cd-days">
            <b>{{ annual.daysLeft }}</b><span>天</span>
            <em>距 {{ annual.yearEnd.slice(5) }}</em>
          </div>
          <div class="cd-grid">
            <div><b>{{ km(annual.used) }} / {{ km(annual.limit) }}</b><span>已行驶 / 额度 (km)</span></div>
            <div><b :class="{ 'is-danger': over }">{{ over ? '-' + km(-annual.remaining) : km(annual.remaining) }}</b><span>{{ over ? '已超额 (km)' : '剩余额度 (km)' }}</span></div>
            <div><b>{{ annual.dailyBudget ? km(annual.dailyBudget) : '—' }}</b><span>日均可用 (km)</span></div>
          </div>
        </div>
        <div class="bar-track cd-track">
          <div class="bar-fill" :class="tone" :style="{ width: pct + '%' }"></div>
        </div>
        <div class="cd-hint" :class="{ 'is-danger': over }">{{ hint }}</div>
        <div class="cd-sync" v-if="annual.currentOdometer != null">
          当前里程 {{ km(annual.currentOdometer) }} km<template v-if="annual.lastChargeDate">（{{ annual.lastChargeDate.slice(5) }} 充电）</template>
          · 起点 {{ annual.baselineOdometer != null ? km(annual.baselineOdometer) : '—' }} km
          → 已行驶 {{ km(annual.used) }} km
        </div>
        <div class="cd-history" v-if="historyText">历年里程：{{ historyText }}</div>
      </div>
    `,
  };

  /* ---------- 最近记录 ---------- */
  const RecentRecords = {
    name: 'RecentRecords',
    props: {
      records: { type: Array, default: () => [] },
    },
    template: `
      <div class="card module">
        <div class="module-head">
          <span class="module-title">📋 最近记录</span>
        </div>
        <div v-if="!records.length" class="empty">还没有记录，点击右下角 ＋ 添加充电记录</div>
        <div v-for="r in records" :key="r.kind + r.id" class="record">
          <div class="rec-ico">{{ r.icon }}</div>
          <div class="rec-main">
            <div class="rec-title">{{ r.title }} <span class="rec-date">{{ r.date }}</span></div>
            <div class="rec-sub">{{ r.sub }}</div>
          </div>
          <div class="rec-amount">{{ r.amountText }}</div>
        </div>
      </div>
    `,
  };

  window.FMComponents = { ReminderList, AnnualCountdown, RecentRecords };
})();
