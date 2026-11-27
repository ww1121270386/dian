/**
 * App 引导脚本（内嵌版专用）
 * 职责：确定 NAS 服务地址 → 注入 window.FM_SERVER → 健康检查 → 失败时给出设置入口
 * 不依赖任何框架，必须在 app.js 之前执行。
 */
(function () {
  'use strict';

  var KEY = 'fm_server_url';
  var DEFAULT_URL = 'http://192.168.1.100:3280';

  function normalize(v) {
    var u = String(v || '').trim();
    if (!u) return '';
    if (!/^https?:\/\//i.test(u)) u = 'http://' + u;
    return u.replace(/\/+$/, '');
  }

  function saved() {
    try { return normalize(localStorage.getItem(KEY)); } catch (e) { return ''; }
  }

  function persist(u) {
    try { localStorage.setItem(KEY, u); } catch (e) { /* ignore */ }
  }

  function css() {
    var style = document.createElement('style');
    style.textContent = [
      '.fm-boot{position:fixed;inset:0;z-index:99999;display:flex;align-items:center;justify-content:center;',
      'background:linear-gradient(150deg,#48C572,#1CAB5C 52%,#0F9149);font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;padding:22px}',
      '.fm-card{width:100%;max-width:400px;background:#fff;border-radius:20px;padding:24px 20px 18px;box-shadow:0 16px 36px rgba(6,60,30,.28)}',
      '.fm-logo{width:62px;height:62px;border-radius:18px;margin:0 auto 12px;background:linear-gradient(150deg,#48C572,#0F9149);',
      'display:flex;align-items:center;justify-content:center;font-size:32px;color:#fff;font-weight:800}',
      '.fm-h1{font-size:18px;font-weight:700;text-align:center;margin:0 0 6px;color:#10261A}',
      '.fm-sub{font-size:12.5px;color:#7b8089;text-align:center;line-height:1.6;margin:0 0 18px}',
      '.fm-label{font-size:12.5px;color:#5b6068;display:block;margin-bottom:6px}',
      '.fm-input{width:100%;height:44px;padding:0 13px;font-size:15px;border:1px solid #e3e6ea;border-radius:11px;',
      'background:#fafbfc;color:#1a1d21;outline:none;box-sizing:border-box}',
      '.fm-input:focus{border-color:#1CAB5C;background:#fff}',
      '.fm-btn{width:100%;height:46px;margin-top:14px;border:0;border-radius:11px;background:#1CAB5C;color:#fff;',
      'font-size:15px;font-weight:600;box-sizing:border-box}',
      '.fm-btn.ghost{background:#F1F2F5;color:#333;margin-top:8px}',
      '.fm-msg{font-size:12.5px;text-align:center;margin-top:10px;min-height:16px;color:#e5484d}',
      '.fm-gear{position:fixed;right:14px;bottom:88px;z-index:9998;width:42px;height:42px;border-radius:50%;border:0;',
      'background:rgba(0,0,0,.35);color:#fff;font-size:18px;line-height:42px;text-align:center;backdrop-filter:blur(4px)}',
      '.fm-banner{position:fixed;left:0;right:0;top:0;z-index:9999;background:#e5484d;color:#fff;font-size:13px;',
      'padding:10px 14px;display:flex;align-items:center;justify-content:space-between;gap:10px}',
      '.fm-banner button{border:0;background:rgba(255,255,255,.22);color:#fff;font-size:12.5px;padding:6px 12px;border-radius:8px}'
    ].join('');
    document.head.appendChild(style);
  }

  function showSetup(message) {
    css();
    var old = document.querySelector('.fm-boot');
    if (old) old.remove();

    var wrap = document.createElement('div');
    wrap.className = 'fm-boot';
    wrap.innerHTML =
      '<div class="fm-card">' +
      '<div class="fm-logo">⚡</div>' +
      '<h1 class="fm-h1">电耗管家</h1>' +
      '<p class="fm-sub">填写 NAS 上电耗管家的访问地址<br>例如 http://192.168.1.10:3280</p>' +
      '<label class="fm-label">服务器地址</label>' +
      '<input class="fm-input" id="fmUrlInput" type="url" inputmode="url" spellcheck="false" placeholder="' + DEFAULT_URL + '">' +
      '<button class="fm-btn" id="fmSave">保存并连接</button>' +
      '<button class="fm-btn ghost" id="fmTest">测试连接</button>' +
      '<div class="fm-msg" id="fmMsg"></div>' +
      '</div>';
    document.body.appendChild(wrap);

    var input = wrap.querySelector('#fmUrlInput');
    var msg = wrap.querySelector('#fmMsg');
    input.value = saved() || DEFAULT_URL;

    function probe(url) {
      return fetch(url + '/api/health', { method: 'GET' })
        .then(function (r) { return r.ok ? r.json() : Promise.reject(new Error('HTTP ' + r.status)); })
        .then(function (d) { return d && d.app === 'fuel-mate'; });
    }

    wrap.querySelector('#fmTest').onclick = function () {
      var u = normalize(input.value);
      if (!u) { msg.textContent = '请填写地址'; return; }
      msg.style.color = '#5b6068';
      msg.textContent = '正在测试…';
      probe(u).then(function (ok) {
        msg.style.color = ok ? '#1CAB5C' : '#e5484d';
        msg.textContent = ok ? '连接成功' : '已连通但不是电耗管家服务';
      }).catch(function () {
        msg.style.color = '#e5484d';
        msg.textContent = '连接失败，请检查地址与网络';
      });
    };

    wrap.querySelector('#fmSave').onclick = function () {
      var u = normalize(input.value);
      if (!u) { msg.textContent = '请填写地址'; return; }
      msg.style.color = '#5b6068';
      msg.textContent = '正在连接…';
      probe(u).then(function (ok) {
        if (!ok) throw new Error('not-fuel-mate');
        persist(u);
        location.reload();
      }).catch(function () {
        msg.style.color = '#e5484d';
        msg.textContent = '连接失败，请确认手机与该地址在同一网络';
      });
    };

    if (message) { msg.textContent = message; }
  }

  function banner(text) {
    css();
    if (document.querySelector('.fm-banner')) return;
    var bar = document.createElement('div');
    bar.className = 'fm-banner';
    bar.innerHTML = '<span>' + text + '</span><button>设置地址</button>';
    bar.querySelector('button').onclick = function () { showSetup(''); };
    document.body.appendChild(bar);
  }

  function gear() {
    css();
    var btn = document.createElement('button');
    btn.className = 'fm-gear';
    btn.type = 'button';
    btn.title = '服务器设置';
    btn.textContent = '⚙';
    btn.onclick = function () { showSetup(''); };
    document.body.appendChild(btn);
  }

  var server = saved();
  if (!server) {
    // 首次启动：先给设置界面
    window.FM_SERVER = '';
    document.addEventListener('DOMContentLoaded', function () { showSetup(''); });
  } else {
    window.FM_SERVER = server;
    document.addEventListener('DOMContentLoaded', function () {
      gear();
      fetch(server + '/api/health')
        .then(function (r) { if (!r.ok) throw new Error('bad'); return r.json(); })
        .then(function (d) { if (!d || d.app !== 'fuel-mate') throw new Error('bad'); })
        .catch(function () { banner('无法连接 ' + server + '，数据可能无法加载'); });
    });
  }
})();
