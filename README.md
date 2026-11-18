# fileshare

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

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

