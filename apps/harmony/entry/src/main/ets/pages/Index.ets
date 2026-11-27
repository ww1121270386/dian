import web_webview from '@ohos.web.webview';
import preferences from '@ohos.data.preferences';
import promptAction from '@ohos.promptAction';

const PREF_NAME: string = 'fuelmate_pref';
const KEY_URL: string = 'server_url';
const DEFAULT_URL: string = 'http://192.168.1.100:3280';

@Entry
@Component
struct Index {
  @State serverUrl: string = '';
  @State inputUrl: string = '';
  @State booting: boolean = true;
  @State showSetup: boolean = false;
  @State loadFailed: boolean = false;
  private controller: web_webview.WebviewController = new web_webview.WebviewController();

  aboutToAppear(): void {
    this.readSavedUrl();
  }

  private async readSavedUrl(): Promise<void> {
    try {
      const pref = await preferences.getPreferences(getContext(this), PREF_NAME);
      const saved = await pref.get(KEY_URL, DEFAULT_URL);
      this.serverUrl = String(saved);
    } catch (e) {
      this.serverUrl = DEFAULT_URL;
    }
    this.inputUrl = this.serverUrl;
    this.booting = false;
  }

  private async saveUrl(): Promise<void> {
    let u: string = this.inputUrl.trim();
    if (u.length === 0) {
      promptAction.showToast({ message: '请输入服务器地址' });
      return;
    }
    if (!/^https?:\/\//.test(u)) {
      u = 'http://' + u;
    }
    try {
      const pref = await preferences.getPreferences(getContext(this), PREF_NAME);
      await pref.put(KEY_URL, u);
      await pref.flush();
      this.serverUrl = u;
      this.inputUrl = u;
      this.showSetup = false;
      this.loadFailed = false;
      promptAction.showToast({ message: '已保存，正在加载' });
    } catch (e) {
      promptAction.showToast({ message: '保存失败，请重试' });
    }
  }

  @Builder
  setupPanel() {
    Column({ space: 14 }) {
      Text('服务器地址')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .width('100%')
      Text('填写电耗管家所在设备地址，例如 http://192.168.1.10:3280')
        .fontSize(12)
        .fontColor('#8A8F99')
        .width('100%')
      TextInput({ text: this.inputUrl, placeholder: DEFAULT_URL })
        .type(InputType.URL)
        .height(44)
        .onChange((v: string) => { this.inputUrl = v; })
      Row({ space: 10 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor('#F1F2F5')
          .fontColor('#333')
          .onClick(() => { this.showSetup = false; })
        Button('保存并打开')
          .layoutWeight(1)
          .backgroundColor('#1CAB5C')
          .onClick(() => { this.saveUrl(); })
      }
      .width('100%')
    }
    .padding(20)
    .width('88%')
    .backgroundColor(Color.White)
    .borderRadius(16)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.booting) {
        LoadingProgress().width(56).height(56)
      } else {
        Web({ src: this.serverUrl, controller: this.controller })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .mixedMode(MixedMode.All)
          .onPageEnd(() => { this.loadFailed = false; })
          .onErrorReceive(() => { this.loadFailed = true; })
          .width('100%')
          .height('100%')

        if (this.loadFailed) {
          Column({ space: 12 }) {
            Text('无法连接服务器').fontSize(16).fontWeight(FontWeight.Medium)
            Text(this.serverUrl).fontSize(12).fontColor('#8A8F99')
            Button('修改地址').backgroundColor('#1CAB5C').onClick(() => { this.showSetup = true; })
            Button('重试').backgroundColor('#F1F2F5').fontColor('#333').onClick(() => {
              this.loadFailed = false;
              this.controller.loadUrl(this.serverUrl);
            })
          }
          .padding(24)
          .backgroundColor(Color.White)
          .borderRadius(16)
          .width('84%')
        }

        // 右下角设置入口
        Button('⚙')
          .fontSize(18)
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor('#00000055')
          .fontColor(Color.White)
          .position({ right: 16, bottom: 96 })
          .onClick(() => { this.showSetup = true; })
      }

      if (this.showSetup) {
        Column() {
          this.setupPanel()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#00000066')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {})
      }
    }
    .width('100%')
    .height('100%')
  }
}
