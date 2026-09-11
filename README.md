# Sinereh VPN — Production-oriented baseline

این نسخه بر اساس کد قبلی بازطراحی شده و هدف آن تبدیل پروژه از Prototype به یک پایه قابل نگهداری برای Release است.

## تغییرات مهم

- `flutter_v2ray_client` روی نسخه `3.4.1` پین شده.
- `V2ray` به‌صورت strongly typed استفاده می‌شود.
- خطاها به‌صورت typed مدیریت می‌شوند.
- `AppState` هنوز برای سادگی Provider را نگه می‌دارد، اما منطق اتصال، ساب‌اسکریپشن و latency از هم جدا شده‌اند.
- تست سرورها concurrency محدود دارد.
- failover و auto-switch دارای cooldown و hysteresis هستند.
- یک failure منفرد دیگر باعث failover فوری نمی‌شود.
- `QUERY_ALL_PACKAGES` حذف شده است.
- URL ساب‌اسکریپشن در UI به‌صورت کامل نمایش داده نمی‌شود.
- parser به schemes ثابت محدود نیست؛ هر لینکی که خود plugin بتواند parse کند پذیرفته می‌شود.
- تنظیمات هنگام load اعتبارسنجی و clamp می‌شوند.
- وضعیت VPN به enum داخلی تبدیل می‌شود.
- APK و AAB در CI ساخته می‌شوند.
- برای Release واقعی، signing باید با GitHub Secrets تنظیم شود.

## اجرا

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Release

قبل از انتشار واقعی:

1. یک keystore اختصاصی بساز.
2. `android/key.properties` را خارج از Git نگه دار.
3. secrets مربوط به signing را در GitHub Actions قرار بده.
4. `flutter build appbundle --release` را اجرا کن.
5. روی حداقل Android نسخه هدف، اتصال، قطع اتصال، sleep/wake، reboot، failover و subscription refresh را تست کن.

## نکته

این repository یک baseline مهندسی‌شده است؛ هیچ کدی را بدون اجرای `flutter analyze`, `flutter test` و تست واقعی روی دستگاه نباید «کاملاً تست‌شده» فرض کرد.

## Toolchain

CI is pinned to Flutter 3.47.0, the stable release line available in August 2026. Flutter's official archive identifies 3.47 as the August 2026 stable release. 
