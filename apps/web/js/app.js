'use strict';

/* ========== 常量与工具 ========== */
const { createApp } = Vue;

const API = (window.FM_SERVER || '') + '/api';
const TYPE_ICONS = {
  保养: '🔧', 保险: '🛡️', 维修: '🛠️', 停车: '🅿️', 过路: '🛣️',
  洗车: '🧽', 违章: '⚠️', 装饰: '✨', 其他: '📦', 充电: '🔌',
};
const STATUS_ORDER = { expired: 0, due_soon: 1, ok: 2 };
const PALETTE = ['#f6821f', '#4f7cff', '#30a46c', '#e5484d', '#b7791f', '#805ad5', '#38b2ac', '#ed8936', '#a0aec0'];

function fmt(n, d = 2) {
  if (n === null || n === undefined || isNaN(Number(n))) return '—';
  return Number(n).toFixed(d);
}
function todayStr() {
  const d = new Date();
  const p = (x) => String(x).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}
async function api(path, opts = {}) {
  const res = await fetch(API + path, {
    headers: { 'Content-Type': 'application/json' },
    ...opts,
  });
  let data = {};
  try { data = await res.json(); } catch (e) { /* ignore */ }
  if (!res.ok) throw new Error(data.error || '请求失败');
  return data;
}

/* ========== 应用 ========== */
const app = createApp({
  data() {
    return {
      tab: 'home',
      tabs: [
        { key: 'home', icon: '🏠', label: '首页' },
        { key: 'charge', icon: '⚡', label: '充电' },
        { key: 'cost', icon: '🧾', label: '费用' },
        { key: 'stats', icon: '📊', label: '统计' },
        { key: 'me', icon: '⚙️', label: '我的' },
      ],
      vehicles: [],
      currentVehicleId: null,
      charges: [],
      expenses: [],
      reminders: [],
      categories: [],
      stats: null,
      expenseFilter: '全部',
      modal: null,
      editingId: null,
      toast: null,
      newCategoryName: '',
      editingCategoryId: null,
      editingCategoryName: '',
      formCurrentOdo: null,
      vehicleForm: { name: '', plate: '', model: '', battery: '', annual_km_limit: '', purchase_price: '', purchase_date: '' },
      chargeForm: { date: '', odometer: '', kwh: '', price: '', total_cost: '', soc_before: '', soc_after: '', station: '', notes: '' },
      expenseForm: { type: '保养', date: '', odometer: '', amount: '', notes: '', sync_on: false, sync_ids: [] },
      reminderForm: { title: '', rule_type: 'mileage', interval_km: '', interval_days: '', base_odometer: '', base_date: '', notes: '' },
    };
  },

  computed: {
    currentVehicle() {
      return this.vehicles.find((v) => v.id === this.currentVehicleId) || null;
    },
    ov() {
      return this.stats ? this.stats.overview : null;
    },
    hasSegments() {
      return !!(this.stats && this.stats.segments.length);
    },
    annual() {
      return this.stats ? this.stats.annual : null;
    },
    /** 保养表单实时预览：下次保养里程 / 日期 */
    reminderPreview() {
      const f = this.reminderForm;
      const parts = [];
      if (f.rule_type !== 'date' && f.interval_km > 0 && f.base_odometer !== '' && f.base_odometer != null) {
        parts.push(`${Math.round(Number(f.base_odometer) + Number(f.interval_km))} km`);
      }
      if (f.rule_type !== 'mileage' && f.interval_days > 0 && f.base_date) {
        const d = new Date(f.base_date + 'T00:00:00');
        if (!isNaN(d.getTime())) {
          d.setDate(d.getDate() + Math.round(Number(f.interval_days)));
          const p = (x) => String(x).padStart(2, '0');
          parts.push(`${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`);
        }
      }
      if (!parts.length) return '';
      return parts.join(' 或 ') + (f.rule_type === 'both' ? '（先到为准）' : '');
    },
    /* 首页常驻提醒列表：按严重度排序（已到期 → 即将到期 → 正常） */
    sortedReminders() {
      return [...this.reminders].sort((a, b) => (STATUS_ORDER[a.status] ?? 3) - (STATUS_ORDER[b.status] ?? 3));
    },
    expenseTypes() {
      return this.categories.map((c) => c.name);
    },
    expenseFilterOptions() {
      return ['全部', ...this.expenseTypes];
    },
    filteredExpenses() {
      return this.expenseFilter === '全部'
        ? this.expenses
        : this.expenses.filter((e) => e.type === this.expenseFilter);
    },
    recentRecords() {
      // 仅做展示数据准备，渲染交给 recent-records 组件
      const a = this.charges.map((c) => ({
        kind: '充电', id: c.id, date: c.date, icon: '⚡', title: '充电',
        sub: `${fmt(c.odometer, 0)} km · ${fmt(c.kwh, 2)}kWh` + (this.socText(c) ? ` · ${this.socText(c)}` : '') + (c.station ? ` · ${c.station}` : ''),
        amountText: `¥${fmt(c.total_cost, 2)}`,
      }));
      const b = this.expenses.map((e) => ({
        kind: '费用', id: e.id, date: e.date, icon: this.typeIcon(e.type), title: e.type,
        sub: e.notes || (e.odometer ? `${fmt(e.odometer, 0)} km` : '—'),
        amountText: `¥${fmt(e.amount, 2)}`,
      }));
      return [...a, ...b].sort((x, y) => y.date.localeCompare(x.date)).slice(0, 6);
    },
  },

  watch: {
    tab(v) {
      if (v === 'stats') this.renderCharts();
    },
    currentVehicleId(v) {
      localStorage.setItem('fm_vehicle', v);
      this.loadVehicleData();
    },
    'chargeForm.kwh'() { this.syncChargeTotal(); },
    'chargeForm.price'() { this.syncChargeTotal(); },
    // 切换费用类型：保养时默认开启「同步保养里程与日期」，并预选相关提醒
    'expenseForm.type'(v) {
      if (this.editingId) return;
      if (v === '保养' && this.reminders.length) {
        this.expenseForm.sync_on = true;
        if (!this.expenseForm.sync_ids.length) this.expenseForm.sync_ids = this.defaultSyncIds();
      } else {
        this.expenseForm.sync_on = false;
        this.expenseForm.sync_ids = [];
      }
    },
  },

  async mounted() {
    if (window.Chart) {
      Chart.defaults.color = '#8a919e';
      Chart.defaults.font.family = getComputedStyle(document.body).fontFamily;
    }
    await this.loadVehicles();
    const saved = Number(localStorage.getItem('fm_vehicle'));
    if (this.vehicles.length) {
      const hit = this.vehicles.find((v) => v.id === saved);
      this.currentVehicleId = hit ? hit.id : this.vehicles[0].id;
    }
  },

  methods: {
    fmt,
    typeIcon(t) { return TYPE_ICONS[t] || '📦'; },
    /** 充电前/后 SOC 展示 */
    socText(c) {
      const b = c.soc_before;
      const a = c.soc_after;
      if (b != null && a != null) return `${b}%→${a}%`;
      if (a != null) return `充至 ${a}%`;
      if (b != null) return `起充 ${b}%`;
      return '';
    },

    /* ---------- 数据加载 ---------- */
    async loadVehicles() {
      this.vehicles = await api('/vehicles');
    },
    async loadVehicleData() {
      if (!this.currentVehicleId) return;
      const id = this.currentVehicleId;
      try {
        const [charges, expenses, reminders, stats, categories] = await Promise.all([
          api(`/charges?vehicleId=${id}`),
          api(`/expenses?vehicleId=${id}`),
          api(`/reminders?vehicleId=${id}`),
          api(`/stats?vehicleId=${id}`),
          api('/categories'),
        ]);
        // 防止切换车辆后旧响应覆盖
        if (id !== this.currentVehicleId) return;
        this.charges = charges;
        this.expenses = expenses;
        this.reminders = reminders;
        this.stats = stats;
        this.categories = categories;
        if (this.tab === 'stats') this.renderCharts();
      } catch (e) {
        this.toastMsg(e.message, 'error');
      }
    },
    async refreshAll() {
      await Promise.all([this.loadVehicles(), this.loadVehicleData()]);
    },

    /* ---------- 车辆 ---------- */
    openVehicleForm(v = null) {
      this.editingId = v ? v.id : null;
      this.vehicleForm = {
        name: v ? v.name : '',
        plate: v ? v.plate : '',
        model: v ? v.model : '',
        battery: v && v.battery != null ? v.battery : '',
        annual_km_limit: v && v.annual_km_limit != null ? v.annual_km_limit : '',
        purchase_price: v && v.purchase_price != null ? v.purchase_price : '',
        purchase_date: v && v.purchase_date ? v.purchase_date : '',
      };
      this.modal = 'vehicle';
    },
    editVehicle(v) { this.openVehicleForm(v); },
    async saveVehicle() {
      if (!this.vehicleForm.name) return this.toastMsg('请填写车辆昵称', 'error');
      const body = JSON.stringify(this.vehicleForm);
      try {
        if (this.editingId) await api('/vehicles/' + this.editingId, { method: 'PUT', body });
        else {
          const r = await api('/vehicles', { method: 'POST', body });
          this.currentVehicleId = r.id;
        }
        this.closeModal();
        this.toastMsg('已保存');
        await this.refreshAll();
      } catch (e) { this.toastMsg(e.message, 'error'); }
    },
    async deleteVehicle(id) {
      if (!confirm('删除车辆将同时删除其所有充电、费用与提醒记录，且不可恢复。确定删除？')) return;
      try {
        await api('/vehicles/' + id, { method: 'DELETE' });
        this.closeModal();
        this.toastMsg('车辆已删除');
        this.currentVehicleId = null;
        await this.loadVehicles();
        if (this.vehicles.length) this.currentVehicleId = this.vehicles[0].id;
      } catch (e) { this.toastMsg(e.message, 'error'); }
    },

    /* ---------- 充电 ---------- */
    openChargeForm(c = null) {
      this.editingId = c ? c.id : null;
      const last = this.charges[0]; // 列表按里程倒序，第一条为最近一次
      this.chargeForm = {
        date: c ? c.date : todayStr(),
        odometer: c ? c.odometer : (this.ov && this.ov.lastOdometer != null ? this.ov.lastOdometer : ''),
        kwh: c ? c.kwh : '',
        price: c ? c.price : (last ? last.price : ''),
        total_cost: c ? c.total_cost : '',
        soc_before: c && c.soc_before != null ? c.soc_before : '',
        soc_after: c && c.soc_after != null ? c.soc_after : '',
        station: c ? c.station : (last ? last.station : ''),
        notes: c ? c.notes : '',
      };
      this.modal = 'charge';
    },
    editCharge(c) { this.openChargeForm(c); },
    syncChargeTotal() {
      const { kwh, price } = this.chargeForm;
      if (typeof kwh === 'number' && typeof price === 'number') {
        this.chargeForm.total_cost = Math.round(kwh * price * 100) / 100;
      }
    },
    async saveCharge() {
      const c = this.chargeForm;
      if (!c.date) return this.toastMsg('请选择日期', 'error');
      if (!(c.odometer > 0)) return this.toastMsg('请填写有效里程', 'error');
      if (!(c.kwh > 0)) return this.toastMsg('请填写充电量', 'error');
      if (!(c.price >= 0) || c.price === '') return this.toastMsg('请填写电价', 'error');
      const body = JSON.stringify({
        vehicle_id: this.currentVehicleId, date: c.date, odometer: c.odometer,
        kwh: c.kwh, price: c.price, total_cost: c.total_cost,
        soc_before: c.soc_before === '' ? null : c.soc_before,
        soc_after: c.soc_after === '' ? null : c.soc_after,
        station: c.station, notes: c.notes,
      });
      try {
        if (this.editingId) await api('/charges/' + this.editingId, { method: 'PUT', body });
        else await api('/charges', { method: 'POST', body });
        this.closeModal();
        this.toastMsg('充电记录已保存');
        await this.loadVehicleData();
      } catch (e) { this.toastMsg(e.message, 'error'); }
    },
    async deleteCharge(id) {
      if (!confirm('确定删除这条充电记录？')) return;
      try {
        await api('/charges/' + id, { method: 'DELETE' });
        this.closeModal();
        this.toastMsg('已删除');
        await this.loadVehicleData();
      } catch (e) { this.toastMsg(e.message, 'error'); }
    },

    /* ---------- 费用 ---------- */
    /** 默认同步目标：标题含「保养」的提醒；仅一条提醒时直接选它 */
    defaultSyncIds() {
      const hit = this.reminders.filter((r) => /保养/.test(r.title));
      if (hit.length) return hit.map((r) => r.id);
      return this.reminders.length === 1 ? [this.reminders[0].id] : [];
    },
    openExpenseForm(e = null) {
      this.editingId = e ? e.id : null;
      const type = e ? e.type : '保养';
      const canSync = !e && type === '保养' && this.reminders.length > 0;
      this.expenseForm = {
        type,
        date: e ? e.date : todayStr(),
        odometer: e ? (e.odometer == null ? '' : e.odometer) : '',
        amount: e ? e.amount : '',
        notes: e ? e.notes : '',
        sync_on: canSync,
        sync_ids: canSync ? this.defaultSyncIds() : [],
      };
      this.modal = 'expense';
    },
    editExpense(e) { this.openExpenseForm(e); },
    async saveExpense() {
      const e = this.expenseForm;
      if (!e.date) return this.toastMsg('请选择日期', 'error');
      if (!(e.amount > 0)) return this.toastMsg('请填写有效金额', 'error');
      const syncIds = !this.editingId && e.sync_on ? e.sync_ids : [];
      const body = JSON.stringify({
        vehicle_id: this.currentVehicleId, type: e.type, date: e.date,
        odometer: e.odometer === '' ? null : e.odometer, amount: e.amount, notes: e.notes,
        sync_reminders: syncIds,
      });
      try {
        if (this.editingId) {
          await api('/expenses/' + this.editingId, { method: 'PUT', body });
          this.closeModal();
          this.toastMsg('费用已保存');
        } else {
          const r = await api('/expenses', { method: 'POST', body });
          this.closeModal();
          this.toastMsg(r && r.synced ? `费用已保存，并同步 ${r.synced} 项保养基准` : '费用已保存');
        }
        await this.loadVehicleData();
      } catch (er) { this.toastMsg(er.message, 'error'); }
    },
    async deleteExpense(id) {
      if (!confirm('确定删除这条费用记录？')) return;
      try {
        await api('/expenses/' + id, { method: 'DELETE' });
        this.closeModal();
        this.toastMsg('已删除');
        await this.loadVehicleData();
      } catch (er) { this.toastMsg(er.message, 'error'); }
    },

    /* ---------- 费用类型管理 ---------- */
    async openCategoryManager() {
      this.newCategoryName = '';
      this.editingCategoryId = null;
      this.editingCategoryName = '';
      this.modal = 'category';
      await this.loadCategories();
    },
    async loadCategories() {
      try {
        this.categories = await api('/categories');
      } catch (e) { this.toastMsg(e.message, 'error'); }
    },
    async refreshAfterCategoryChange() {
      this.expenseFilter = '全部';
      await this.loadVehicleData();
      if (this.modal === 'category') await this.loadCategories();
    },
    async addCategory() {
      const name = (this.newCategoryName || '').trim();
      if (!name) return this.toastMsg('请输入类型名称', 'error');
      try {
        await api('/categories', { method: 'POST', body: JSON.stringify({ name }) });
        this.newCategoryName = '';
        this.toastMsg('类型已添加');
        await this.refreshAfterCategoryChange();
      } catch (e) { this.toastMsg(e.message, 'error'); }
    },
    startRenameCategory(c) {
      this.editingCategoryId = c.id;
      this.editingCategoryName = c.name;
    },
    async saveCategoryName(c) {
      const name = (this.editingCategoryName || '').trim();
      if (!name) return this.toastMsg('类型名称不能为空', 'error');
      if (name === c.name) { this.editingCategoryId = null; return; }
      try {
        await api('/categories/' + c.id, { method: 'PUT', body: JSON.stringify({ name }) });
        this.editingCategoryId = null;
        this.toastMsg('类型已改名');
        await this.refreshAfterCategoryChange();
      } catch (e) { this.toastMsg(e.message, 'error'); }
    },
    async deleteCategory(c) {
      const used = c.usage_count > 0 ? `该类型下 ${c.usage_count} 笔记录将归入「其他」，` : '';
      if (!confirm(`${used}确定删除类型「${c.name}」？`)) return;
      try {
        const r = await api('/categories/' + c.id, { method: 'DELETE' });
        this.toastMsg(r.moved ? `已删除，${r.moved} 笔记录归入「其他」` : '类型已删除');
        await this.refreshAfterCategoryChange();
      } catch (e) { this.toastMsg(e.message, 'error'); }
    },

    /* ---------- 提醒 ---------- */
    openReminderForm(r = null) {
      this.editingId = r ? r.id : null;
      // 当前里程取充电记录（无则退回统计数据），完成保养时使用
      this.formCurrentOdo = r && r.currentOdometer != null
        ? r.currentOdometer
        : (this.ov && this.ov.lastOdometer != null ? this.ov.lastOdometer : null);
      this.reminderForm = {
        title: r ? r.title : '',
        rule_type: r ? r.rule_type : 'mileage',
        interval_km: r && r.interval_km != null ? r.interval_km : '',
        interval_days: r && r.interval_days != null ? r.interval_days : '',
        base_odometer: r && r.base_odometer != null
          ? r.base_odometer
          : (this.formCurrentOdo != null ? Math.round(this.formCurrentOdo) : ''),
        base_date: r && r.base_date ? r.base_date : todayStr(),
        notes: r ? r.notes : '',
      };
      this.modal = 'reminder';
    },
    editReminder(r) { this.openReminderForm(r); },
    async saveReminder() {
      const r = this.reminderForm;
      if (!r.title) return this.toastMsg('请填写提醒名称', 'error');
      const body = JSON.stringify({
        vehicle_id: this.currentVehicleId, title: r.title, rule_type: r.rule_type,
        interval_km: r.interval_km, interval_days: r.interval_days,
        base_odometer: r.base_odometer, base_date: r.base_date, notes: r.notes,
      });
      try {
        if (this.editingId) await api('/reminders/' + this.editingId, { method: 'PUT', body });
        else await api('/reminders', { method: 'POST', body });
        this.closeModal();
        this.toastMsg('提醒已保存');
        await this.loadVehicleData();
      } catch (e) { this.toastMsg(e.message, 'error'); }
    },
    async deleteReminder(id) {
      if (!confirm('确定删除这条提醒？')) return;
      try {
        await api('/reminders/' + id, { method: 'DELETE' });
        this.closeModal();
        this.toastMsg('已删除');
        await this.loadVehicleData();
      } catch (e) { this.toastMsg(e.message, 'error'); }
    },
    statusText(r) {
      return r.status === 'expired' ? '已到期' : r.status === 'due_soon' ? '即将到期' : '正常';
    },
    reminderRuleText(r) {
      const parts = [];
      if (r.rule_type !== 'date') parts.push(`每 ${Math.round(r.interval_km)} km`);
      if (r.rule_type !== 'mileage') parts.push(`每 ${r.interval_days} 天`);
      return parts.join(' 或 ') + (r.notes ? ` · ${r.notes}` : '');
    },
    /** 列表展示下次保养里程 / 日期 */
    reminderNextDue(r) {
      const parts = [];
      if (r.nextDueOdometer != null) parts.push(`${Math.round(r.nextDueOdometer)} km`);
      if (r.nextDueDate) parts.push(r.nextDueDate);
      return parts.length ? `下次 ${parts.join(' · ')}` : '';
    },

    /* ---------- 示例数据 / 导出 ---------- */
    async seedDemo() {
      try {
        const r = await api('/demo', { method: 'POST' });
        this.currentVehicleId = r.vehicleId;
        await this.refreshAll();
        this.toastMsg('示例数据已生成，可在「我的」中删除示例车辆');
      } catch (e) { this.toastMsg(e.message, 'error'); }
    },
    exportUrl(name) {
      return `${API}/export/${name}?vehicleId=${this.currentVehicleId}`;
    },

    /* ---------- 弹层 / Toast ---------- */
    closeModal() {
      this.modal = null;
      this.editingId = null;
    },
    toastMsg(msg, type = 'ok') {
      this.toast = { msg, type };
      clearTimeout(this._tt);
      this._tt = setTimeout(() => { this.toast = null; }, 2400);
    },

    /* ---------- 图表 ---------- */
    renderCharts() {
      if (!window.Chart || !this.stats) return;
      this.$nextTick(() => {
        if (this.hasSegments) this.drawConsumption();
        this.drawMonthly();
        if (this.stats.expenseByType.length) this.drawTypes();
      });
    },
    drawConsumption() {
      const el = this.$refs.consChart;
      if (!el) return;
      if (this._consChart) this._consChart.destroy();
      const ctx = el.getContext('2d');
      const grad = ctx.createLinearGradient(0, 0, 0, 220);
      grad.addColorStop(0, 'rgba(246,130,31,.25)');
      grad.addColorStop(1, 'rgba(246,130,31,0)');
      const segs = this.stats.segments;
      this._consChart = new Chart(el, {
        type: 'line',
        data: {
          labels: segs.map((s) => s.date.slice(5)),
          datasets: [{
            label: '电耗 (kWh/km)',
            data: segs.map((s) => s.consumption),
            borderColor: '#f6821f',
            backgroundColor: grad,
            fill: true,
            tension: 0.35,
            pointRadius: 3,
            pointBackgroundColor: '#f6821f',
            borderWidth: 2,
          }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { display: false } },
          scales: { y: { beginAtZero: true } },
        },
      });
    },
    drawMonthly() {
      const el = this.$refs.monthChart;
      if (!el) return;
      if (this._monthChart) this._monthChart.destroy();
      const m = this.stats.monthly;
      this._monthChart = new Chart(el, {
        type: 'bar',
        data: {
          labels: m.map((x) => x.month.slice(2)),
          datasets: [
            { label: '电费', data: m.map((x) => x.chargeCost), backgroundColor: '#f6821f', stack: 'a', borderRadius: 4 },
            { label: '杂费', data: m.map((x) => x.otherCost), backgroundColor: '#4f7cff', stack: 'a', borderRadius: 4 },
          ],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          scales: { x: { stacked: true, grid: { display: false } }, y: { stacked: true, beginAtZero: true } },
          plugins: { legend: { position: 'bottom', labels: { boxWidth: 12, boxHeight: 12 } } },
        },
      });
    },
    drawTypes() {
      const el = this.$refs.typeChart;
      if (!el) return;
      if (this._typeChart) this._typeChart.destroy();
      const t = this.stats.expenseByType;
      this._typeChart = new Chart(el, {
        type: 'doughnut',
        data: {
          labels: t.map((x) => x.type),
          datasets: [{
            data: t.map((x) => x.total),
            backgroundColor: t.map((_, i) => PALETTE[i % PALETTE.length]),
            borderWidth: 2,
            borderColor: '#fff',
          }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          cutout: '62%',
          plugins: { legend: { position: 'bottom', labels: { boxWidth: 12, boxHeight: 12 } } },
        },
      });
    },
  },
});

/* 首页模块化组件 */
app.component('reminder-list', window.FMComponents.ReminderList);
app.component('annual-countdown', window.FMComponents.AnnualCountdown);
app.component('recent-records', window.FMComponents.RecentRecords);

app.mount('#app');
