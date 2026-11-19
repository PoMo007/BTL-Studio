نصب و آپدیت Lemon Studio (نسخه‌ی BTL)
======================================

دیگر هیچ کامپایلری لازم نیست (نه Git، نه Rust، نه Visual C++). GitHub برنامه را می‌سازد و اسکریپت فقط فایل آماده را دانلود می‌کند.

نصب (بار اول)
1) پوشه‌ی installer را از مخزن BTL-Studio بگیر (Code > Download ZIP) و Extract کن.
2) روی Install-or-Update.bat دابل‌کلیک کن.
3) صبر کن. چند دقیقه بیشتر طول نمی‌کشد (دانلود حدود ۹۰ مگابایت).

مسیر نصب:  C:\DAW\Image-Line\Lemon-Studio
  bin\lemonstudio.exe          برنامه‌ی اصلی (میانبر روی دسکتاپ هم ساخته می‌شود)
  agent\                       ایجنت (از مخزن BTL-Studio، بدون نیاز به git)
  backups\                     نسخه‌های قبلی برنامه و تنظیمات (۳ تای آخر)
  logs\                        لاگ هر اجرا
  Start-Lemon-Agent-Mode.bat   اجرا با control plane برای ایجنت (پورت 7777، سطح propose)

آپدیت
- هر وقت خواستی دوباره Install-or-Update.bat را اجرا کن (کپی آن در پوشه‌ی نصب هم هست).
- اسکریپت آخرین build (release با نام latest) را از GitHub بررسی می‌کند و با sha256 فایل را تأیید می‌کند.
- اگر نسخه‌ی جدیدی بود، از برنامه و تنظیماتت بک‌آپ می‌گیرد و جایگزین می‌کند. اگر چیزی عوض نشده باشد کاری نمی‌کند.
- Lemon Studio باید موقع آپدیت بسته باشد.

فقط بررسی (بدون تغییر):  Check-Only.bat

سوئیچ‌ها (اختیاری، در cmd):
  Install-or-Update.bat -NoPlugins     پلاگین‌ها را نصب نکن
  Install-or-Update.bat -Force         حتی اگر به‌روز است دوباره نصب کن
  Install-or-Update.bat -Root D:\Path  مسیر نصب دیگر

پلاگین‌ها در FL Studio
پلاگین‌های VST3 و CLAP در پوشه‌ی کاربر نصب می‌شوند:
  %LOCALAPPDATA%\Programs\Common\VST3
این مسیر را در FL Studio: Options > Manage plugins > Plugin search paths اضافه کن و Find plugins بزن.

برگشت به نسخه‌ی قبل
فایل‌های backups\lemonstudio-XXXX.exe را می‌توانی جای bin\lemonstudio.exe کپی کنی.

روش قدیمی (کند، فقط در صورت نیاز)
Build-From-Source.bat برنامه را روی خود کامپیوتر کامپایل می‌کند (۳۰ تا ۶۰ دقیقه، نیاز به Git/Rust/C++).
فقط وقتی استفاده کن که دانلود آماده کار نکرد.

اگر خطا داد: فایل آخر پوشه‌ی logs را برای من بفرست.
