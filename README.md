# fileshare

A new Flutter project.

## Flutter Version
```powershell
Flutter 3.38.3 • channel stable • https://mirrors.tuna.tsinghua.edu.cn/git/flutter-sdk.git
Framework • revision 19074d12f7 (12 months ago) • 2025-11-20 17:53:13 -0500
Engine • hash 8bf2090718fea3655f466049a757f823898f0ad1 (revision 13e658725d) (11 months ago) • 2025-11-20 20:19:23.000Z
Tools • Dart 3.10.1 • DevTools 2.51.1
```

## Windows系统网络模式设置为专用 否则无法发现

## 安卓端接收到的文件默认保存在这里：
```text
/storage/emulated/0/Android/data/cn.mingao.fileshare/files/Download
```
## NSIS 脚本按程序加防火墙规则
```powershell
netsh advfirewall firewall add rule name="MyLanShare" dir=in program="$INSTDIR\MyLanShare.exe" action=allow
```

## 签名
```powershell
keytool -importkeystore -srckeystore C:\Users\ming_\source\fileshare\fileShare-keystore.jks -destkeystore C:\Users\ming_\source\fileshare\fileShare-keystore.jks -deststoretype pkcs12
```

or

```powershell
keytool -genkey -v -keystore C:\Users\ming_\source\fileshare\fileShare-keystore.jks `
        -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 `
        -alias fileShare
```

