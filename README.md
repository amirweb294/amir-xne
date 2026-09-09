# X-Net روی Railway

## فایل‌ها — همین ۴ تا رو push کن

```
Dockerfile
start.sh
nginx.conf.template
README.md
```

## دیپلوی

**۱. Railway → New Project → Deploy from GitHub repo**

**۲. بعد از deploy → Settings → Networking → Generate Domain**

**۳. Volume (ضروری — بدون این هر redeploy دیتا پاک میشه)**
Service → Volumes → Add Volume → Mount Path: `/opt/xnet`

**۴. آدرس پنل را از لاگ بخوان**
```
╔═══════════════════════════════════════════════╗
║  Panel URL path : /abc123def456/      ║
╚═══════════════════════════════════════════════╝
```
پس آدرس پنل:
```
https://YOUR-APP.up.railway.app/abc123def456/
```
یوزر: `admin` | پسورد: `Admin@Railway1`

## ساخت Inbound

| فیلد | مقدار |
|------|-------|
| Protocol | VLESS |
| Listen Port | **8080** |
| Network | ws |
| Security | none |
| Path | مثلاً `/vl` |

## لینک کلاینت
```
vless://UUID@YOUR-APP.up.railway.app:443?encryption=none&security=tls&sni=YOUR-APP.up.railway.app&fp=chrome&type=ws&host=YOUR-APP.up.railway.app&path=%2Fvl#XNet
```
