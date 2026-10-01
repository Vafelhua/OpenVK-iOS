# Сборка .ipa через GitHub Actions

Сборка iOS-приложения требует macOS. Поэтому проект собирается в CI на macOS-раннере GitHub Actions.

## Стоимость

| Тип репозитория | macOS-мин | Стоимость |
|---|---|---|
| **Публичный** | безлимитно | **0 ₽** |
| Приватный | 2000 бесплатных мин/мес, macOS считается как 10 | 2000/10 = 200 мин macOS в месяц бесплатно |

Вывод: **для публичного репозитория это полностью бесплатно.** Сборка занимает 3–5 минут.

## Как запустить

1. Залейте папку `OpenVK-iOS` в репозиторий (в корень репозитория, без вложенной папки — либо поправьте пути в workflow).
2. Откройте вкладку **Actions** → запустите workflow `Build IPA` (или он запустится сам при push в `main`).
3. Когда сборка станет зелёной, скачайте артефакт `OpenVK-unsigned-ipa` (вкладка Artifacts внизу запуска).

Готовый файл: `OpenVK-unsigned.ipa` внутри `.zip`-артефакта.

## Установка unsigned IPA на iPhone

Подписанный сертификатом Apple IPA поставить нельзя, поэтому есть два пути:

- **Sideloadly** (Windows, бесплатно) — подключите iPhone, введите Apple ID, приложение переподпишет `.ipa` под ваш бесплатный аккаунт (7 дней, потом повторяйте).
- **AltStore** — то же самое, но на самом iPhone.
- **Cydia / TrollStore / jailbreak** — можно поставить как есть, без переподписи.

Установка требует, чтобы iPhone был в режиме доверия (Настройки → Основные → Обновление ПО → Доверие этому компьютеру).

## Подписанный IPA (для установки без переподписи)

Понадобится Apple Developer Account ($99/год, физическое лицо) + Ad Hoc-профиль с UDID вашего iPhone.

Добавьте в репозитории **Settings → Secrets and variables → Actions**:

| Секрет | Значение |
|---|---|
| `DEVELOPMENT_TEAM` | ID команды (10 символов) |
| `APPLE_CERTIFICATE_BASE64` | base64 от `.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | пароль `.p12` |
| `PROVISIONING_PROFILE_BASE64` | base64 от `.mobileprovision` |
| `PROVISIONING_PROFILE_NAME` | имя профиля, например `OpenVK AdHoc` |
| `KEYCHAIN_PASSWORD` | любой пароль для CI keychain |

И **Variables** (не секреты): `ENABLE_SIGNING = true`.

Как получить base64 на Windows (PowerShell):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("cert.p12")) | Out-File -NoNewline cert.b64
[Convert]::ToBase64String([IO.File]::ReadAllBytes("profile.mobileprovision")) | Out-File -NoNewline profile.b64
```

Артефакт `OpenVK-signed-ipa` ставится на устройство напрямую (AirDrop/Finder), пока профиль действителен.