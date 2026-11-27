#!/usr/bin/env python3
"""校验 iOS unsigned ipa：结构 / Info.plist / 架构 / 签名状态"""
import sys, os, zipfile, plistlib, struct, io

ARCH = {
    b'\xcf\xfa\xed\xfe': 'x86_64',
    b'\xce\xfa\xed\xfe': 'i386',
    b'\xfe\xed\xfa\xce': 'arm (32)',
    b'\xfe\xed\xfa\xcf': 'arm64',
    b'\xca\xfe\xba\xbe': 'fat (universal)',
}

def main(path):
    if not os.path.exists(path):
        print(f'❌ 文件不存在: {path}'); return 1
    size = os.path.getsize(path)
    print(f'文件: {os.path.basename(path)}  ({size/1024:.1f} KB)')
    if not zipfile.is_zipfile(path):
        print('❌ 不是 zip/ipa 格式'); return 1

    z = zipfile.ZipFile(path)
    names = z.namelist()
    apps = sorted({n.split('/')[1] for n in names if n.startswith('Payload/') and n.count('/') >= 1 and n.split('/')[1].endswith('.app')})
    print(f'Payload 内 app: {apps or "❌ 缺失"}')
    if not apps:
        print('❌ 结构错误：应有 Payload/<Name>.app/'); return 1

    app = apps[0]
    info_path = f'Payload/{app}/Info.plist'
    if info_path in names:
        raw = z.read(info_path)
        try:
            info = plistlib.loads(raw)
            print(f'Bundle ID        : {info.get("CFBundleIdentifier")}')
            print(f'版本             : {info.get("CFBundleShortVersionString")} ({info.get("CFBundleVersion")})')
            print(f'最低系统         : iOS {info.get("MinimumOSVersion")}')
            print(f'显示名           : {info.get("CFBundleDisplayName") or info.get("CFBundleName")}')
            exe = info.get('CFBundleExecutable', app[:-4])
        except Exception as e:
            print(f'⚠️ Info.plist 解析失败: {e}'); exe = app[:-4]
    else:
        print('❌ 缺少 Info.plist'); return 1

    # 可执行文件架构
    bin_path = f'Payload/{app}/{exe}'
    if bin_path in names:
        head = z.read(bin_path)[:4]
        print(f'可执行架构       : {ARCH.get(head, "未知 " + head.hex())}')
    else:
        print(f'⚠️ 未找到可执行文件 {bin_path}')

    # 签名状态
    has_mp = any(n.startswith(f'Payload/{app}/embedded.mobileprovision') for n in names)
    has_sig = any(f'Payload/{app}/_CodeSignature/CodeResources' == n for n in names)
    print(f'描述文件         : {"有" if has_mp else "无（unsigned，符合预期）"}')
    print(f'_CodeSignature   : {"有" if has_sig else "无（unsigned，符合预期）"}')

    # 图标资源
    icons = [n for n in names if n.startswith(f'Payload/{app}/') and 'AppIcon' in n][:3]
    print(f'图标资源         : {len(icons)} 个（示例: {icons[0].split("/")[-1] if icons else "无"}）')

    print('\n✅ 结构校验通过' if not has_mp and not has_sig else '\n⚠️ 含签名材料，可能已重签')
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else 'FuelMate-native-unsigned.ipa'))
