نصب و آپدیت Lemon Studio
=========================

نصب (بار اول)
1) پوشه‌ی این zip را باز کن (Extract).
2) روی Install-or-Update.bat دابل‌کلیک کن.
3) اگر ویندوز اجازه خواست (UAC)، تأیید کن. فقط برای نصب Visual C++ Build Tools لازم است و فقط اگر قبلاً نصب نباشد.
4) صبر کن. بار اول ممکن است ۳۰ تا ۶۰ دقیقه طول بکشد (کامپایل کامل برنامه و همه‌ی پلاگین‌ها).

مسیر نصب:  C:\DAW\Image-Line\Lemon-Studio
  bin\lemonstudio.exe       برنامه‌ی اصلی (میانبر روی دسکتاپ هم ساخته می‌شود)
  src\                      سورس (git clone)
  backups\                  نسخه‌های قبلی برنامه و تنظیمات (۳ تای آخر)
  logs\                     لاگ هر اجرا
  Start-Lemon-Agent-Mode.bat   اجرا با control plane برای ایجنت (پورت 7777، سطح propose)

آپدیت
- هر وقت خواستی دوباره Install-or-Update.bat را اجرا کن (نسخه‌ی کپی‌شده‌اش در پوشه‌ی نصب هم هست).
- اسکریپت اول تغییرات جدید سازنده را با git بررسی می‌کند. اگر چیزی عوض نشده باشد کاری نمی‌کند.
- اگر تغییر بود، لیست تغییرات را نشان می‌دهد، از برنامه و تنظیماتت بک‌آپ می‌گیرد، می‌سازد و فقط اگر build موفق بود
  برنامه‌ی جدید جایگزین می‌شود. اگر شکست بخورد، سورس برمی‌گردد و نسخه‌ی قبلی کار می‌کند.
- Lemon Studio باید موقع آپدیت بسته باشد.

فقط بررسی (بدون تغییر):  Check-Only.bat

سوئیچ‌ها (اختیاری، در cmd):
  Install-or-Update.bat -NoPlugins     پلاگین‌ها را نساز
  Install-or-Update.bat -Force         حتی اگر به‌روز است دوباره بساز
  Install-or-Update.bat -Root D:\Path  مسیر نصب دیگر

پلاگین‌ها در FL Studio
پلاگین‌های Lemon در پوشه‌ی کاربر نصب می‌شوند:
  %LOCALAPPDATA%\Programs\Common\VST3
این مسیر را در FL Studio: Options > Manage plugins > Plugin search paths اضافه کن و Find plugins بزن.

برگشت به نسخه‌ی قبل
فایل‌های backups\lemonstudio-XXXX.exe را می‌توانی جای bin\lemonstudio.exe کپی کنی.

اگر خطا داد: فایل آخر پوشه‌ی logs را برای من بفرست.
