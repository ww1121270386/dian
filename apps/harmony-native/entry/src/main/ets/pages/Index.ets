import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import bundleManager from '@ohos.bundle.bundleManager';
import {
  AnnualInfo,
  annualInfo,
  Charge,
  estimatedRange,
  Expense,
  fmtNum,
  Overview,
  overview,
  Seg,
  segments,
  Ownership,
  ownership,
  Reminder,
  ReminderState,
  reminderState,
  statusText,
  todayStr,
  Vehicle,
} from '../model/Calc';
import { Repo } from '../store/Repo';

const GREEN: string = '#1CAB5C';
const GREEN_LIGHT: string = '#E8F7EE';
const TEXT2: string = '#8A8F99';
const LINE: string = '#EDEFF2';
const INK: string = '#08240F';
const BG: string = '#F5F6F8';

@Entry
@Component
struct Index {
  @State tab: number = 0;
  @State loading: boolean = true;
  @State appVersion: string = '';

  @State vehicles: Vehicle[] = [];
  @State currentId: number = 0;
  @State charges: Charge[] = [];
  @State expenses: Expense[] = [];
  @State reminders: Reminder[] = [];

  @State showCharge: boolean = false;
  @State fDate: string = todayStr();
  @State fOdo: string = '';
  @State fKwh: string = '';
  @State fPrice: string = '';
  @State fSocBefore: string = '';
  @State fSocAfter: string = '';

  @State showExpense: boolean = false;
  @State eType: string = '保养';
  @State eDate: string = todayStr();
  @State eAmount: string = '';
  @State eNotes: string = '';
  @State eSync: boolean = false;
  @State eSyncReminderId: number = 0;
  @State eSyncOdo: string = '';
  @State eEditingId: number = 0;
  @State cEditingId: number = 0;
  @State expenseTypes: string[] = ['保养', '保险', '停车', '维修', '其他'];
  @State fabPressed: boolean = false;

  private ctxSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private trendCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.ctxSettings);
  @State newTypeName: string = '';
  @State rEditingId: number = 0;

  @State showVehicle: boolean = false;
  @State vName: string = '';
  @State vPlate: string = '';
  @State vModel: string = '';
  @State vBattery: string = '';
  @State vLimit: string = '';
  @State vPrice: string = '';
  @State vDate: string = '';

  @State showReminder: boolean = false;
  @State rTitle: string = '';
  @State rRule: string = 'both';
  @State rKm: string = '';
  @State rBaseOdo: string = '';
  @State rDays: string = '365';
  @State rBaseDate: string = todayStr();
  @State rExpenseType: string = '';

  aboutToAppear(): void {
    this.bootstrap();
  }

  private async bootstrap(): Promise<void> {
    this.loadAppVersion();
    const repo: Repo = Repo.get();
    await repo.init(getContext(this) as common.UIAbilityContext);
    this.vehicles = await repo.vehicles();
    const ctx = getContext(this) as common.UIAbilityContext;
    if (ctx.applicationInfo.debug && this.vehicles.length === 0 && !(await repo.isDemoSeeded())) {
      await repo.seedDemo();
      this.vehicles = await repo.vehicles();
    }
    this.expenseTypes = await repo.expenseTypes();
    this.currentId = await repo.currentVehicleId();
    if (this.vehicles.length === 0) {
      this.loading = false;
      this.showVehicle = true;
      return;
    }
    if (!this.vehicles.some((v: Vehicle) => v.id === this.currentId)) {
      this.currentId = this.vehicles[0].id;
      await repo.setCurrentVehicleId(this.currentId);
    }
    await this.reload();
    this.loading = false;
  }

  private loadAppVersion(): void {
    try {
      bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
        .then((info: bundleManager.BundleInfo) => {
          this.appVersion = info.versionName + ' (' + info.versionCode + ')';
        })
        .catch(() => { this.appVersion = ''; });
    } catch (e) {
      this.appVersion = '';
    }
  }

  private async reload(): Promise<void> {
    const repo: Repo = Repo.get();
    this.charges = await repo.charges(this.currentId);
    this.expenses = await repo.expenses(this.currentId);
    this.reminders = await repo.reminders(this.currentId);
    setTimeout(() => { this.drawTrend(); }, 220);
  }

  /** 电耗趋势折线图（相邻两次充电） */
  private drawTrend(): void {
    const segs: Seg[] = segments(this.charges);
    const w: number = this.trendCtx.width;
    const h: number = this.trendCtx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    this.trendCtx.clearRect(0, 0, w, h);
    if (segs.length === 0) {
      return;
    }

    const padL: number = 38;
    const padR: number = 12;
    const padT: number = 14;
    const padB: number = 18;
    const innerW: number = w - padL - padR;
    const innerH: number = h - padT - padB;

    let maxV: number = 0;
    let minV: number = 999;
    for (const s of segs) {
      if (s.consumption > maxV) {
        maxV = s.consumption;
      }
      if (s.consumption < minV) {
        minV = s.consumption;
      }
    }
    const pad: number = (maxV - minV) < 0.02 ? 0.012 : (maxV - minV) * 0.3;
    maxV = maxV + pad;
    minV = Math.max(0, minV - pad);
    const span: number = maxV - minV <= 0 ? 1 : maxV - minV;

    // 网格
    this.trendCtx.strokeStyle = '#EDEFF2';
    this.trendCtx.lineWidth = 1;
    for (let i = 0; i <= 2; i++) {
      const y: number = padT + innerH * i / 2;
      this.trendCtx.beginPath();
      this.trendCtx.moveTo(padL, y);
      this.trendCtx.lineTo(w - padR, y);
      this.trendCtx.stroke();
    }

    // 坐标标注
    this.trendCtx.fillStyle = '#9AA0A8';
    this.trendCtx.font = '10vp sans-serif';
    this.trendCtx.fillText(fmtNum(maxV, 3), 2, padT + 3);
    this.trendCtx.fillText(fmtNum(minV, 3), 2, padT + innerH + 3);

    // 折线 + 数据点
    this.trendCtx.strokeStyle = '#1CAB5C';
    this.trendCtx.lineWidth = 2.5;
    this.trendCtx.beginPath();
    for (let i = 0; i < segs.length; i++) {
      const x: number = padL + (segs.length === 1 ? innerW / 2 : innerW * i / (segs.length - 1));
      const y: number = padT + innerH * (1 - (segs[i].consumption - minV) / span);
      if (i === 0) {
        this.trendCtx.moveTo(x, y);
      } else {
        this.trendCtx.lineTo(x, y);
      }
    }
    this.trendCtx.stroke();

    this.trendCtx.fillStyle = '#1CAB5C';
    for (let i = 0; i < segs.length; i++) {
      const x: number = padL + (segs.length === 1 ? innerW / 2 : innerW * i / (segs.length - 1));
      const y: number = padT + innerH * (1 - (segs[i].consumption - minV) / span);
      this.trendCtx.beginPath();
      this.trendCtx.arc(x, y, 3, 0, Math.PI * 2);
      this.trendCtx.fill();
    }
  }

  @Builder
  trendChart() {
    Column({ space: 8 }) {
      Row() {
        Text('电耗趋势').fontSize(13).fontWeight(FontWeight.Medium)
        Blank()
        Text('kWh/km · 相邻两次充电').fontSize(10.5).fontColor(TEXT2)
      }
      .width('100%')

      Canvas(this.trendCtx)
        .width('100%')
        .height(134)
        .backgroundColor('#FAFBFC')
        .borderRadius(12)
        .onReady(() => { this.drawTrend(); })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(16)
  }

  private currentVehicle(): Vehicle {
    const hit: Vehicle | undefined = this.vehicles.find((v: Vehicle) => v.id === this.currentId);
    if (hit !== undefined) {
      return hit;
    }
    return { id: 0, name: '', plate: '', model: '', battery: 0, annualLimit: 0, purchasePrice: 0, purchaseDate: '' };
  }

  private ov(): Overview {
    return overview(this.charges, this.expenses);
  }

  private annual(): AnnualInfo {
    return annualInfo(this.charges, this.currentVehicle().annualLimit, new Date());
  }

  private own(): Ownership {
    return ownership(this.currentVehicle().purchasePrice, this.currentVehicle().purchaseDate, this.ov().totalDistance);
  }

  private currentOdo(): number {
    return this.ov().lastOdometer;
  }

  private rangeKm(): number {
    let soc: number = 0;
    for (const c of this.charges) {
      if (c.socAfter > 0) {
        soc = c.socAfter;
        break;
      }
    }
    return estimatedRange(this.currentVehicle().battery, soc, this.ov().avgConsumption);
  }

  private stateOf(r: Reminder): ReminderState {
    return reminderState(r, this.currentOdo(), new Date());
  }

  private async saveCharge(): Promise<void> {
    const odo: number = Number(this.fOdo);
    const kwh: number = Number(this.fKwh);
    if (!(odo > 0) || !(kwh > 0)) {
      promptAction.showToast({ message: '请填写里程与充电量' });
      return;
    }
    const repo: Repo = Repo.get();
    const editing: number = this.cEditingId;
    const id: number = editing > 0 ? editing : await repo.nextId();
    const item: Charge = {
      id: id,
      vehicleId: this.currentId,
      date: this.fDate,
      odometer: odo,
      kwh: kwh,
      price: Number(this.fPrice) || 0,
      socBefore: Number(this.fSocBefore) || 0,
      socAfter: Number(this.fSocAfter) || 0,
    };
    if (editing > 0) {
      await repo.updateCharge(item);
    } else {
      await repo.addCharge(item);
    }
    this.cEditingId = 0;
    this.showCharge = false;
    this.fOdo = '';
    this.fKwh = '';
    this.fPrice = '';
    this.fSocBefore = '';
    this.fSocAfter = '';
    await this.reload();
    promptAction.showToast({ message: editing > 0 ? '已更新' : '已保存' });
  }

  private async saveExpense(): Promise<void> {
    const amount: number = Number(this.eAmount);
    if (!(amount > 0)) {
      promptAction.showToast({ message: '请填写金额' });
      return;
    }
    const repo: Repo = Repo.get();
    const editing: number = this.eEditingId;
    const id: number = editing > 0 ? editing : await repo.nextId();
    const expenseDate: string = this.eDate;
    const item: Expense = {
      id: id,
      vehicleId: this.currentId,
      type: this.eType,
      date: expenseDate,
      amount: amount,
      notes: this.eNotes,
    };
    if (editing > 0) {
      await repo.updateExpense(item);
    } else {
      await repo.addExpense(item);
    }

    // 保养费用联动：把选中提醒的上次保养里程/日期更新为本次
    let synced = false;
    if (this.eSync && this.eSyncReminderId > 0) {
      const target: Reminder | undefined = this.reminders.find((r: Reminder) => r.id === this.eSyncReminderId);
      if (target !== undefined) {
        const odo: number = Number(this.eSyncOdo) || this.currentOdo();
        const nr: Reminder = {
          id: target.id,
          vehicleId: target.vehicleId,
          title: target.title,
          ruleType: target.ruleType,
          intervalKm: target.intervalKm,
          baseOdometer: target.ruleType !== 'date' && odo > 0 ? odo : target.baseOdometer,
          intervalDays: target.intervalDays,
          baseDate: target.ruleType !== 'mileage' ? expenseDate : target.baseDate,
          expenseType: target.expenseType !== undefined ? target.expenseType : '',
        };
        await repo.updateReminder(nr);
        synced = true;
      }
    }

    this.showExpense = false;
    this.eAmount = '';
    this.eNotes = '';
    this.eSync = false;
    this.eEditingId = 0;
    await this.reload();
    promptAction.showToast({ message: synced ? '已保存，保养提醒已更新' : (editing > 0 ? '已更新' : '已保存') });
  }

  private async saveVehicle(): Promise<void> {
    if (this.vName.trim().length === 0) {
      promptAction.showToast({ message: '请填写车辆名称' });
      return;
    }
    const repo: Repo = Repo.get();
    let id: number = this.currentId;
    if (id === 0) {
      id = await repo.nextId();
    }
    const v: Vehicle = {
      id: id,
      name: this.vName.trim(),
      plate: this.vPlate.trim(),
      model: this.vModel.trim(),
      battery: Number(this.vBattery) || 0,
      annualLimit: Number(this.vLimit) || 0,
      purchasePrice: Number(this.vPrice) || 0,
      purchaseDate: this.vDate,
    };
    const list: Vehicle[] = this.vehicles.slice();
    const idx: number = list.findIndex((x: Vehicle) => x.id === id);
    if (idx >= 0) {
      list[idx] = v;
    } else {
      list.push(v);
    }
    await repo.saveVehicles(list);
    this.vehicles = list;
    this.currentId = id;
    await repo.setCurrentVehicleId(id);
    this.showVehicle = false;
    await this.reload();
    promptAction.showToast({ message: '已保存' });
  }

  private async saveReminder(): Promise<void> {
    if (this.rTitle.trim().length === 0) {
      promptAction.showToast({ message: '请填写保养项目' });
      return;
    }
    const repo: Repo = Repo.get();
    const editing: number = this.rEditingId;
    const id: number = editing > 0 ? editing : await repo.nextId();
    const item: Reminder = {
      id: id,
      vehicleId: this.currentId,
      title: this.rTitle.trim(),
      ruleType: this.rRule,
      intervalKm: Number(this.rKm) || 0,
      baseOdometer: Number(this.rBaseOdo) || 0,
      intervalDays: Number(this.rDays) || 0,
      baseDate: this.rBaseDate,
      expenseType: this.rExpenseType,
    };
    if (editing > 0) {
      await repo.updateReminder(item);
    } else {
      await repo.addReminder(item);
    }
    this.rEditingId = 0;
    this.showReminder = false;
    this.rTitle = '';
    this.rKm = '';
    this.rBaseOdo = '';
    await this.reload();
    promptAction.showToast({ message: editing > 0 ? '已更新' : '已添加' });
  }

  private async addExpenseType(): Promise<void> {
    const name: string = this.newTypeName.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: '请输入项目名称' });
      return;
    }
    if (this.expenseTypes.indexOf(name) >= 0) {
      promptAction.showToast({ message: '该项目已存在' });
      return;
    }
    const list: string[] = this.expenseTypes.slice();
    list.push(name);
    await Repo.get().saveExpenseTypes(list);
    this.expenseTypes = list;
    this.eType = name;
    this.newTypeName = '';
    this.syncPickForType(name);
    promptAction.showToast({ message: '已添加项目' });
  }

  private async removeExpenseType(name: string): Promise<void> {
    if (this.expenseTypes.length <= 1) {
      promptAction.showToast({ message: '至少保留一个项目' });
      return;
    }
    const list: string[] = this.expenseTypes.filter((t: string) => t !== name);
    await Repo.get().saveExpenseTypes(list);
    this.expenseTypes = list;
    if (this.eType === name) {
      this.eType = list[0];
    }
    promptAction.showToast({ message: '已删除项目' });
  }

  /** 提醒的关联费用类型候选：与费用栏目同一份列表 */
  private reminderTypeOptions(): string[] {
    const list: string[] = [''];
    for (const t of this.expenseTypes) {
      list.push(t);
    }
    if (this.rExpenseType.length > 0 && list.indexOf(this.rExpenseType) < 0) {
      list.push(this.rExpenseType);
    }
    return list;
  }

  private prepareCharge(): void {
    this.cEditingId = 0;
    this.fDate = todayStr();
    this.fOdo = this.currentOdo() > 0 ? String(this.currentOdo()) : '';
    this.fKwh = '';
    this.fPrice = '';
    this.fSocBefore = '';
    this.fSocAfter = '';
    this.showCharge = true;
  }

  private prepareExpense(): void {
    this.eEditingId = 0;
    this.eDate = todayStr();
    this.eType = this.expenseTypes.length > 0 ? this.expenseTypes[0] : '保养';
    this.eAmount = '';
    this.eNotes = '';
    this.eSyncOdo = this.currentOdo() > 0 ? String(this.currentOdo()) : '';
    this.syncPickForType('保养');
    this.showExpense = true;
  }

  /** 选中的费用类型若被提醒关联，则自动勾选同步并选中该提醒 */
  private syncPickForType(type: string): void {
    const hit: Reminder | undefined = this.reminders.find((r: Reminder) =>
      r.expenseType !== undefined && r.expenseType.length > 0 && r.expenseType === type);
    if (hit !== undefined) {
      this.eSync = true;
      this.eSyncReminderId = hit.id;
    } else {
      this.eSync = false;
      this.eSyncReminderId = this.reminders.length > 0 ? this.reminders[0].id : 0;
    }
  }

  private prepareReminder(): void {
    this.rEditingId = 0;
    this.rTitle = '';
    this.rRule = 'both';
    this.rKm = '';
    this.rBaseOdo = this.currentOdo() > 0 ? String(this.currentOdo()) : '';
    this.rDays = '365';
    this.rBaseDate = todayStr();
    this.rExpenseType = '';
    this.showReminder = true;
  }

  private prepareVehicle(): void {
    this.vName = '';
    this.vPlate = '';
    this.vModel = '';
    this.vBattery = '';
    this.vLimit = '';
    this.vPrice = '';
    this.vDate = '';
    this.currentId = 0;
    this.showVehicle = true;
  }

  /** 记录按钮（按当前页签决定新增哪类数据） */
  private openCreate(): void {
    if (this.vehicles.length === 0) {
      this.prepareVehicle();
      return;
    }
    if (this.tab === 1) {
      this.prepareCharge();
    } else if (this.tab === 2) {
      this.prepareExpense();
    } else if (this.tab === 0) {
      this.prepareReminder();
    } else {
      this.prepareVehicle();
    }
  }

  /** 单次充电的电耗（kWh/km），首条或无有效里程返回 -1 */
  private consumptionFor(c: Charge): number {
    const asc: Charge[] = this.charges.slice().sort((a: Charge, b: Charge) => a.odometer - b.odometer);
    const idx: number = asc.findIndex((x: Charge) => x.id === c.id);
    if (idx <= 0) {
      return -1;
    }
    const dist: number = asc[idx].odometer - asc[idx - 1].odometer;
    if (dist <= 0 || !(asc[idx].kwh > 0)) {
      return -1;
    }
    return Math.round((asc[idx].kwh / dist) * 1000) / 1000;
  }

  private formTitle(): string {
    if (this.showCharge) {
      return this.cEditingId > 0 ? '编辑充电' : '记录充电';
    }
    if (this.showExpense) {
      return this.eEditingId > 0 ? '编辑费用' : '记录费用';
    }
    if (this.showVehicle) {
      return '车辆信息';
    }
    return this.rEditingId > 0 ? '编辑提醒' : '新建提醒';
  }

  private closeForms(): void {
    this.showCharge = false;
    this.showExpense = false;
    this.showVehicle = false;
    this.showReminder = false;
  }

  private saveCurrent(): void {
    if (this.showCharge) {
      this.saveCharge();
    } else if (this.showExpense) {
      this.saveExpense();
    } else if (this.showVehicle) {
      this.saveVehicle();
    } else {
      this.saveReminder();
    }
  }

  private anyFormOpen(): boolean {
    return this.showCharge || this.showExpense || this.showVehicle || this.showReminder;
  }

  @Builder
  labeledField(label: string, value: string, placeholder: string, numeric: boolean, onChange: (v: string) => void) {
    Column({ space: 5 }) {
      Text(label).fontSize(12).fontColor(TEXT2).width('100%')
      TextInput({ text: value, placeholder: placeholder })
        .type(numeric ? InputType.Number : InputType.Normal)
        .height(40)
        .backgroundColor('#F7F8FA')
        .borderRadius(10)
        .fontSize(14)
        .onChange((v: string) => { onChange(v); })
    }
    .width('100%')
  }

  @Builder
  cardTitle(icon: Resource, title: string) {
    Row({ space: 7 }) {
      SymbolGlyph(icon)
        .fontSize(18)
        .fontColor([GREEN])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      Text(title).fontSize(14).fontWeight(FontWeight.Medium)
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  plusLink(label: string, onTap: () => void) {
    Row({ space: 4 }) {
      SymbolGlyph($r('sys.symbol.plus_circle'))
        .fontSize(16)
        .fontColor([GREEN])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      Text(label).fontSize(12.5).fontColor(GREEN)
    }
    .alignItems(VerticalAlign.Center)
    .onClick(() => { onTap(); })
  }

  @Builder
  heroStat(label: string, value: string) {
    Column({ space: 3 }) {
      Text(value)
        .fontSize(21)
        .fontWeight(FontWeight.Bolder)
        .fontColor(Color.White)
      Text(label)
        .fontSize(12.5)
        .fontWeight(FontWeight.Medium)
        .fontColor('#DDFFFFFF')
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  statTile(label: string, value: string, sub: string) {
    Column({ space: 2 }) {
      Text(value).fontSize(20).fontWeight(FontWeight.Bolder).fontColor('#04170A')
      Text(label).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#04170A')
      if (sub.length > 0) {
        Text(sub).fontSize(10).fontColor(GREEN)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  tabItem(idx: number, icon: Resource, iconFill: Resource, label: string) {
    Column({ space: 4 }) {
      SymbolGlyph(this.tab === idx ? iconFill : icon)
        .fontSize(24)
        .fontColor([this.tab === idx ? GREEN : '#4B5158'])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      Text(label)
        .fontSize(10.5)
        .fontWeight(this.tab === idx ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.tab === idx ? GREEN : '#4B5158')
    }
    .layoutWeight(1)
    .padding({ top: 4, bottom: 4 })
    .onClick(() => { this.tab = idx; })
  }

  @Builder
  barRow(label: string, pct: number, color: string) {
    Row({ space: 6 }) {
      Text(label).fontSize(9.5).fontColor(TEXT2).width(22)
      Progress({ value: pct, total: 100, type: ProgressType.Linear })
        .color(color)
        .height(4)
        .layoutWeight(1)
      Text(pct + '%').fontSize(9.5).fontColor(TEXT2).width(30).textAlign(TextAlign.End)
    }
    .width('100%')
  }

  @Builder
  heroCard() {
    Column({ space: 10 }) {
      Row() {
        Text(this.currentVehicle().name.length > 0 ? this.currentVehicle().name : '未命名车辆')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        if (this.currentVehicle().plate.length > 0) {
          Text(this.currentVehicle().plate)
            .fontSize(11)
            .fontColor(INK)
            .backgroundColor('#AAFFFFFF')
            .borderRadius(5)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .margin({ left: 6 })
        }
        Blank()
      }
      .width('100%')

      Row() {
        Text(fmtNum(this.ov().avgConsumption, 3))
          .fontSize(34)
          .fontWeight(FontWeight.Bolder)
          .fontColor(Color.White)
        Text(' kWh/km').fontSize(12).fontColor(Color.White).opacity(0.88)
      }
      .alignItems(VerticalAlign.Bottom)
      .width('100%')

      Text(this.rangeKm() > 0
        ? '估算续航 ' + this.rangeKm() + ' km'
        : (this.currentVehicle().battery > 0 ? '电池 ' + this.currentVehicle().battery + ' kWh' : '未填写电池容量'))
        .fontSize(12)
        .fontColor(Color.White)
        .opacity(0.85)
        .width('100%')

      Divider().color('#33FFFFFF')

      Row() {
        this.heroStat('总里程 km', String(this.ov().totalDistance))
        this.heroStat('电费/km 元', fmtNum(this.ov().chargeCostPerKm, 2))
        this.heroStat('充电次数', String(this.ov().chargeCount))
      }
      .width('100%')
    }
    .padding(18)
    .width('100%')
    .borderRadius(18)
    .linearGradient({
      angle: 150,
      colors: [['#48C572', 0.0], ['#1CAB5C', 0.52], ['#0F9149', 1.0]],
    })
  }

  @Builder
  annualCard() {
    Column({ space: 8 }) {
      Row() {
        this.cardTitle($r('sys.symbol.hourglass'), '年度里程倒计时')
        Blank()
        Text(this.annual().year + ' 年度').fontSize(11).fontColor(TEXT2)
      }
      .width('100%')

      Row({ space: 14 }) {
        Column({ space: 2 }) {
          Text(String(this.annual().daysLeft)).fontSize(30).fontWeight(FontWeight.Bolder).fontColor(GREEN)
          Text('距 12-31').fontSize(10).fontColor(TEXT2)
        }
        .width(62)

        Column({ space: 4 }) {
          Text(this.currentVehicle().annualLimit > 0
            ? this.annual().used + ' / ' + this.currentVehicle().annualLimit + ' km'
            : '未设置年度额度')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
          Text(this.currentVehicle().annualLimit > 0
            ? (this.annual().remaining >= 0
              ? '剩余 ' + this.annual().remaining + ' km · 日均 ' + this.annual().dailyBudget + ' km'
              : '已超 ' + Math.abs(this.annual().remaining) + ' km')
            : '在「我的 → 车辆」填写每年限定里程')
            .fontSize(11.5)
            .fontColor(this.currentVehicle().annualLimit > 0 && this.annual().remaining < 0 ? '#E5484D' : TEXT2)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      if (this.currentVehicle().annualLimit > 0) {
        Progress({ value: this.annual().pct, total: 100, type: ProgressType.Linear })
          .color(this.annual().pct >= 100 ? '#E5484D' : (this.annual().pct >= 80 ? '#F5A623' : GREEN))
          .height(6)
          .width('100%')
      }
    }
    .padding(16)
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(16)
  }

  private reminderLine(r: Reminder): string {
    const st: ReminderState = this.stateOf(r);
    const parts: string[] = [];
    if (st.nextOdo > 0) {
      parts.push('下次 ' + st.nextOdo + ' km');
    }
    if (st.nextDate.length > 0) {
      parts.push(st.nextDate);
    }
    if (st.kmRemaining !== 999999) {
      parts.push(st.kmRemaining >= 0 ? '剩 ' + st.kmRemaining + ' km' : '已超 ' + Math.abs(st.kmRemaining) + ' km');
    }
    if (st.daysRemaining !== 999999) {
      parts.push(st.daysRemaining >= 0 ? '剩 ' + st.daysRemaining + ' 天' : '已超 ' + Math.abs(st.daysRemaining) + ' 天');
    }
    return parts.join(' · ');
  }

  @Builder
  reminderCard() {
    Column({ space: 10 }) {
      Row() {
        this.cardTitle($r('sys.symbol.alarm'), '提醒')
        Blank()
        Text(this.reminders.length > 0 ? this.reminders.length + ' 项 · 点击可编辑' : '')
          .fontSize(11)
          .fontColor(TEXT2)
      }
      .width('100%')

      if (this.reminders.length === 0) {
        Text('暂无提醒').fontSize(12.5).fontColor(TEXT2).width('100%').padding({ top: 4 })
      } else {
        ForEach(this.reminders, (r: Reminder, index: number) => {
          Column({ space: 4 }) {
            Row() {
              Text(r.title).fontSize(14).fontWeight(FontWeight.Medium)
              Blank()
              Text(statusText(this.stateOf(r).status))
                .fontSize(10.5)
                .fontColor(this.stateOf(r).status === 'expired' ? '#E5484D'
                  : (this.stateOf(r).status === 'warn' ? '#C7791A' : GREEN))
            }
            .width('100%')

            Text(this.reminderLine(r)).fontSize(11.5).fontColor(TEXT2).width('100%')

            if (r.ruleType !== 'date' && r.intervalKm > 0) {
              this.barRow('里程', this.stateOf(r).kmPct, this.stateOf(r).kmPct >= 80 ? '#E5484D' : GREEN)
            }
            if (r.ruleType !== 'mileage' && r.intervalDays > 0) {
              this.barRow('时间', this.stateOf(r).daysPct, this.stateOf(r).daysPct >= 80 ? '#E5484D' : '#4C8DF6')
            }
          if (index < this.reminders.length - 1) {
            Divider()
              .color('#E8EAEE')
              .strokeWidth(1)
              .margin({ top: 10, bottom: 2 })
          }

          }
          .padding({ top: 4, bottom: 6 })
          .onClick(() => {
            this.rEditingId = r.id;
            this.rTitle = r.title;
            this.rRule = r.ruleType;
            this.rKm = String(r.intervalKm);
            this.rBaseOdo = String(r.baseOdometer);
            this.rDays = String(r.intervalDays);
            this.rBaseDate = r.baseDate;
            this.rExpenseType = r.expenseType !== undefined ? r.expenseType : '';
            this.showReminder = true;
          })
        }, (r: Reminder) => String(r.id))
      }
    }
    .padding(16)
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(16)
  }

  @Builder
  chargeTab() {
    Column({ space: 10 }) {
      Row() {
        this.cardTitle($r('sys.symbol.bolt'), '充电记录')
        Blank()
        Text(this.charges.length > 0 ? '共 ' + this.charges.length + ' 次' : '')
          .fontSize(11)
          .fontColor(TEXT2)
      }
      .width('100%')

      if (segments(this.charges).length > 0) {
        this.trendChart()
      }

      if (this.charges.length === 0) {
        Text('还没有充电记录，点右上角记录第一笔').fontSize(12.5).fontColor(TEXT2).width('100%')
      } else {
        ForEach(this.charges, (c: Charge) => {
          Column({ space: 3 }) {
            Row() {
              Text(c.date).fontSize(13.5).fontWeight(FontWeight.Medium)
              Blank()
              Text('¥' + fmtNum(c.kwh * c.price, 2)).fontSize(13.5).fontWeight(FontWeight.Medium)
            }
            .width('100%')
            Row() {
              Text(c.odometer + ' km · ' + fmtNum(c.kwh, 2) + ' kWh')
                .fontSize(11.5)
                .fontColor(TEXT2)
              Blank()
              if (c.socAfter > 0) {
                Text((c.socBefore > 0 ? c.socBefore + '%→' : '充至 ') + c.socAfter + '%')
                  .fontSize(11)
                  .fontColor(GREEN)
              }
            }
            .width('100%')
            Row() {
              Text(this.consumptionFor(c) > 0 ? '电耗 ' + fmtNum(this.consumptionFor(c), 3) + ' kWh/km' : '电耗 —')
                .fontSize(11)
                .fontColor(this.consumptionFor(c) > 0 ? GREEN : TEXT2)
              Blank()
              Text('¥' + fmtNum(c.price, 2) + ' / kWh').fontSize(10.5).fontColor(TEXT2)
            }
            .width('100%')
          }
          .padding({ top: 8, bottom: 8 })
          .border({ width: { bottom: 1 }, color: LINE })
          .onClick(() => {
            this.cEditingId = c.id;
            this.fDate = c.date;
            this.fOdo = String(c.odometer);
            this.fKwh = String(c.kwh);
            this.fPrice = c.price > 0 ? String(c.price) : '';
            this.fSocBefore = c.socBefore > 0 ? String(c.socBefore) : '';
            this.fSocAfter = c.socAfter > 0 ? String(c.socAfter) : '';
            this.showCharge = true;
          })
        }, (c: Charge) => String(c.id))
      }
    }
    .padding(16)
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(16)
  }

  @Builder
  expenseTab() {
    Column({ space: 10 }) {
      Row() {
        this.cardTitle($r('sys.symbol.doc_text'), '费用记录')
        Blank()
        Text('点击条目可编辑')
          .fontSize(11)
          .fontColor(TEXT2)
      }
      .width('100%')

      if (this.expenses.length === 0) {
        Text('还没有费用记录').fontSize(12.5).fontColor(TEXT2).width('100%')
      } else {
        ForEach(this.expenses, (e: Expense) => {
          Row() {
            Column({ space: 2 }) {
              Text(e.type + (e.notes.length > 0 ? ' · ' + e.notes : '')).fontSize(13.5)
              Text(e.date).fontSize(11.5).fontColor(TEXT2)
            }
            .alignItems(HorizontalAlign.Start)
            Blank()
            Text('¥' + fmtNum(e.amount, 2)).fontSize(13.5).fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          .border({ width: { bottom: 1 }, color: LINE })
          .onClick(() => {
            this.eEditingId = e.id;
            this.eType = e.type;
            this.eDate = e.date;
            this.eAmount = String(e.amount);
            this.eNotes = e.notes;
            this.eSyncOdo = this.currentOdo() > 0 ? String(this.currentOdo()) : '';
            this.syncPickForType(e.type);
            this.showExpense = true;
          })
        }, (e: Expense) => String(e.id))
      }
    }
    .padding(16)
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(16)
  }

  @Builder
  meTab() {
    Column({ space: 12 }) {
      Column({ space: 10 }) {
        Row() {
          this.cardTitle($r('sys.symbol.car'), '车辆')
          Blank()
          this.plusLink('添加', () => {
              this.vName = '';
              this.vPlate = '';
              this.vModel = '';
              this.vBattery = '';
              this.vLimit = '';
              this.vPrice = '';
              this.vDate = '';
              this.currentId = 0;
              this.showVehicle = true;
            })
        }
        .width('100%')

        ForEach(this.vehicles, (v: Vehicle) => {
          Row({ space: 10 }) {
            Column({ space: 2 }) {
              Row({ space: 6 }) {
                Text(v.name).fontSize(13.5).fontWeight(FontWeight.Medium)
                if (v.id === this.currentId) {
                  Text('当前')
                    .fontSize(10)
                    .fontColor(GREEN)
                    .backgroundColor(GREEN_LIGHT)
                    .borderRadius(4)
                    .padding({ left: 4, right: 4 })
                }
              }
              Text((v.model.length > 0 ? v.model + ' · ' : '') + (v.plate.length > 0 ? v.plate : '未填车牌'))
                .fontSize(11.5)
                .fontColor(TEXT2)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('编辑')
              .fontSize(12)
              .fontColor(GREEN)
              .onClick(() => {
                this.vName = v.name;
                this.vPlate = v.plate;
                this.vModel = v.model;
                this.vBattery = v.battery > 0 ? String(v.battery) : '';
                this.vLimit = v.annualLimit > 0 ? String(v.annualLimit) : '';
                this.vPrice = v.purchasePrice > 0 ? String(v.purchasePrice) : '';
                this.vDate = v.purchaseDate;
                this.currentId = v.id;
                this.showVehicle = true;
              })
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })
          .onClick(async () => {
            this.currentId = v.id;
            await Repo.get().setCurrentVehicleId(v.id);
            await this.reload();
          })
        }, (v: Vehicle) => String(v.id))
      }
      .padding(16)
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(16)

      Column({ space: 10 }) {
        Row() {
          this.cardTitle($r('sys.symbol.label'), '费用项目')
          Blank()
          Text(this.expenseTypes.length + ' 项').fontSize(11).fontColor(TEXT2)
        }
        .width('100%')

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.expenseTypes, (t: string) => {
            Row({ space: 5 }) {
              Text(t).fontSize(12.5).fontColor('#333333')
              Text('×').fontSize(13).fontColor(TEXT2)
            }
            .padding({ left: 10, right: 8, top: 5, bottom: 5 })
            .backgroundColor('#F1F2F5')
            .borderRadius(8)
            .margin({ right: 8, bottom: 8 })
            .onClick(() => { this.removeExpenseType(t); })
          }, (t: string) => 'me-' + t)
        }
        .width('100%')

        Row({ space: 8 }) {
          TextInput({ text: this.newTypeName, placeholder: '新增项目，如 洗车' })
            .layoutWeight(1)
            .height(38)
            .fontSize(13)
            .backgroundColor('#F7F8FA')
            .borderRadius(10)
            .onChange((v: string) => { this.newTypeName = v; })
          Button('添加')
            .height(38)
            .fontSize(13)
            .backgroundColor(GREEN)
            .onClick(() => { this.addExpenseType(); })
        }
        .width('100%')

        Text('点项目删除（至少保留 1 个）；此列表与费用表单、提醒关联类型共用')
          .fontSize(10.5)
          .fontColor(TEXT2)
          .width('100%')
      }
      .padding(16)
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(16)

      Column({ space: 8 }) {
        Row() {
          this.cardTitle($r('sys.symbol.wallet'), '持有成本')
          Blank()
          Text(this.currentVehicle().purchasePrice > 0 ? '元/天 · 元/km' : '未填购车价').fontSize(11).fontColor(TEXT2)
        }
        .width('100%')

        if (this.currentVehicle().purchasePrice > 0) {
          Row() {
            this.statTile('元/天', fmtNum(this.own().perDay, 2), '车价÷' + this.own().days + '天')
            this.statTile('元/km', fmtNum(this.own().perKm, 2), '车价÷里程')
          }
          .width('100%')
          Text('含购车总成本 ' + fmtNum(this.currentVehicle().purchasePrice + this.ov().totalCost, 0) + ' 元')
            .fontSize(11.5)
            .fontColor(TEXT2)
            .width('100%')
        } else {
          Text('在车辆编辑里填写购车价格与日期后可查看').fontSize(12).fontColor(TEXT2).width('100%')
        }
      }
      .padding(16)
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(16)

      Text(this.appVersion.length > 0 ? 'v' + this.appVersion + ' · 数据仅保存在本机' : '数据仅保存在本机 · 电耗口径 kWh/km')
        .fontSize(11)
        .fontColor(TEXT2)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 2, bottom: 16 })
    }
  }

  @Builder
  chargeFormFields() {
    Column({ space: 10 }) {
      this.labeledField('日期', this.fDate, 'YYYY-MM-DD', false, (v: string) => { this.fDate = v; })
      this.labeledField('当时里程 (km)', this.fOdo, '如 12500', true, (v: string) => { this.fOdo = v; })
      this.labeledField('充电量 (kWh)', this.fKwh, '如 42.5', true, (v: string) => { this.fKwh = v; })
      this.labeledField('单价 (元/kWh)', this.fPrice, '如 1.05', true, (v: string) => { this.fPrice = v; })
      Row({ space: 10 }) {
        Column() {
          this.labeledField('充电前 SOC(%)', this.fSocBefore, '20', true, (v: string) => { this.fSocBefore = v; })
        }.layoutWeight(1)
        Column() {
          this.labeledField('充电后 SOC(%)', this.fSocAfter, '90', true, (v: string) => { this.fSocAfter = v; })
        }.layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  expenseFormFields() {
    Column({ space: 10 }) {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.expenseTypes, (t: string) => {
          Text(t)
            .fontSize(12.5)
            .fontColor(this.eType === t ? Color.White : '#333333')
            .backgroundColor(this.eType === t ? GREEN : '#F1F2F5')
            .borderRadius(8)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.eType = t;
              this.syncPickForType(t);
            })
        }, (t: string) => t)
      }
      .width('100%')

      this.labeledField('日期', this.eDate, 'YYYY-MM-DD', false, (v: string) => { this.eDate = v; })
      this.labeledField('金额 (元)', this.eAmount, '如 420', true, (v: string) => { this.eAmount = v; })
      this.labeledField('备注', this.eNotes, '选填', false, (v: string) => { this.eNotes = v; })

      if (this.reminders.length > 0) {
        Column({ space: 8 }) {
          Row() {
            Column({ space: 2 }) {
              Text('同步提醒').fontSize(13).fontWeight(FontWeight.Medium)
              Text('把上次里程/日期更新为本次').fontSize(10.5).fontColor(TEXT2)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.eSync })
              .selectedColor(GREEN)
              .onChange((on: boolean) => { this.eSync = on; })
          }
          .width('100%')

          if (this.eSync) {
            Row({ space: 8 }) {
              ForEach(this.reminders, (r: Reminder) => {
                Text(r.title)
                  .fontSize(12)
                  .fontColor(this.eSyncReminderId === r.id ? Color.White : '#333333')
                  .backgroundColor(this.eSyncReminderId === r.id ? GREEN : '#F1F2F5')
                  .borderRadius(8)
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .onClick(() => { this.eSyncReminderId = r.id; })
              }, (r: Reminder) => String(r.id))
            }
            .width('100%')
            this.labeledField('本次里程 (km)', this.eSyncOdo, '默认当前里程', true, (v: string) => { this.eSyncOdo = v; })
          }
        }
        .padding(12)
        .width('100%')
        .backgroundColor('#F7F8FA')
        .borderRadius(12)
      }
    }
    .width('100%')
  }

  @Builder
  vehicleFormFields() {
    Column({ space: 10 }) {
      this.labeledField('车辆名称', this.vName, '如 S05', false, (v: string) => { this.vName = v; })
      this.labeledField('车牌号', this.vPlate, '吉A·D12345', false, (v: string) => { this.vPlate = v; })
      this.labeledField('车型', this.vModel, '如 520Max', false, (v: string) => { this.vModel = v; })
      this.labeledField('电池容量 (kWh)', this.vBattery, '如 56.1', true, (v: string) => { this.vBattery = v; })
      this.labeledField('每年限定里程 (km)', this.vLimit, '如 30000，0 表示不限', true, (v: string) => { this.vLimit = v; })
      Row({ space: 10 }) {
        Column() {
          this.labeledField('购车价格 (元)', this.vPrice, '如 129800', true, (v: string) => { this.vPrice = v; })
        }.layoutWeight(1)
        Column() {
          this.labeledField('购车日期', this.vDate, 'YYYY-MM-DD', false, (v: string) => { this.vDate = v; })
        }.layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  reminderFormFields() {
    Column({ space: 10 }) {
      this.labeledField('提醒名称', this.rTitle, '如 机油保养', false, (v: string) => { this.rTitle = v; })
      Row({ space: 8 }) {
        ForEach(['mileage', 'date', 'both'], (rule: string) => {
          Text(rule === 'mileage' ? '按里程' : (rule === 'date' ? '按时间' : '两者'))
            .fontSize(12.5)
            .fontColor(this.rRule === rule ? Color.White : '#333333')
            .backgroundColor(this.rRule === rule ? GREEN : '#F1F2F5')
            .borderRadius(8)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .onClick(() => { this.rRule = rule; })
        }, (rule: string) => rule)
      }
      .width('100%')

      if (this.rRule !== 'date') {
        Row({ space: 10 }) {
          Column() {
            this.labeledField('间隔里程 (km)', this.rKm, '如 10000', true, (v: string) => { this.rKm = v; })
          }.layoutWeight(1)
          Column() {
            this.labeledField('上次里程 (km)', this.rBaseOdo, '默认当前', true, (v: string) => { this.rBaseOdo = v; })
          }.layoutWeight(1)
        }
        .width('100%')
      }
      if (this.rRule !== 'mileage') {
        Row({ space: 10 }) {
          Column() {
            this.labeledField('间隔天数', this.rDays, '如 365', true, (v: string) => { this.rDays = v; })
          }.layoutWeight(1)
          Column() {
            this.labeledField('上次日期', this.rBaseDate, 'YYYY-MM-DD', false, (v: string) => { this.rBaseDate = v; })
          }.layoutWeight(1)
        }
        .width('100%')
      }

      Column({ space: 6 }) {
        Text('关联费用类型（选填）').fontSize(12).fontColor(TEXT2).width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.reminderTypeOptions(), (t: string) => {
            Text(t.length === 0 ? '不关联' : t)
              .fontSize(12)
              .fontColor(this.rExpenseType === t ? Color.White : '#333333')
              .backgroundColor(this.rExpenseType === t ? GREEN : '#F1F2F5')
              .borderRadius(8)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .margin({ right: 8, bottom: 8 })
              .onClick(() => { this.rExpenseType = t; })
          }, (t: string) => 'rt-' + t)
        }
        .width('100%')
        Text(this.rExpenseType.length > 0
          ? '在费用里记「' + this.rExpenseType + '」时会自动带出这个提醒，并用本次里程更新基准'
          : '选项与费用栏目一致；不关联时需在费用里手动打开「同步提醒」')
          .fontSize(10.5)
          .fontColor(TEXT2)
          .width('100%')
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  fabBtn() {
    Button() {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(26)
        .fontColor([Color.White])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
    }
    .width(56)
    .height(56)
    .borderRadius(28)
    .backgroundColor(GREEN)
    .shadow({ radius: 16, color: '#661CAB5C', offsetX: 0, offsetY: 5 })
    .position({ right: 20, bottom: 104 })
    .scale({ x: this.fabPressed ? 0.92 : 1, y: this.fabPressed ? 0.92 : 1 })
    .animation({ duration: 180, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.fabPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.fabPressed = false;
      }
    })
    .onClick(() => { this.openCreate(); })
  }

  @Builder
  formOverlay() {
    Column() {
      Column({ space: 12 }) {
        Text(this.formTitle()).fontSize(17).fontWeight(FontWeight.Bold).width('100%')

        if (this.showCharge) {
          this.chargeFormFields()
        } else if (this.showExpense) {
          this.expenseFormFields()
        } else if (this.showVehicle) {
          this.vehicleFormFields()
        } else {
          this.reminderFormFields()
        }

        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .backgroundColor('#F1F2F5')
            .fontColor('#333333')
            .onClick(() => { this.closeForms(); })
          Button('保存')
            .layoutWeight(1)
            .backgroundColor(GREEN)
            .onClick(() => { this.saveCurrent(); })
        }
        .width('100%')
        .margin({ top: 6 })
      }
      .padding(20)
      .width('90%')
      .backgroundColor(Color.White)
      .borderRadius(18)
      .constraintSize({ maxHeight: '86%' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack() {
      Column() {
        if (this.loading) {
          LoadingProgress().width(48).height(48)
        } else {
          Scroll() {
            Column({ space: 12 }) {
              if (this.tab === 0) {
                this.heroCard()
                this.annualCard()
                this.reminderCard()
              } else if (this.tab === 1) {
                this.chargeTab()
              } else if (this.tab === 2) {
                this.expenseTab()
              } else {
                this.meTab()
              }
            }
            .padding({ left: 14, right: 14, top: 12, bottom: 150 })
            .width('100%')
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)

          Row() {
            this.tabItem(0, $r('sys.symbol.house'), $r('sys.symbol.house_fill'), '首页')
            this.tabItem(1, $r('sys.symbol.bolt'), $r('sys.symbol.bolt_fill'), '充电')
            this.tabItem(2, $r('sys.symbol.doc_text'), $r('sys.symbol.doc_text_fill'), '费用')
            this.tabItem(3, $r('sys.symbol.person'), $r('sys.symbol.person_fill'), '我的')
          }
          .width('86%')
          .padding({ top: 10, bottom: 10, left: 6, right: 6 })
          .backgroundColor(Color.White)
          .borderRadius(36)
          .shadow({ radius: 22, color: '#1A101828', offsetX: 0, offsetY: 8 })
          .margin({ bottom: 16 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(BG)

      if (!this.loading && !this.anyFormOpen()) {
        this.fabBtn()
      }

      if (this.anyFormOpen()) {
        this.formOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }
}
