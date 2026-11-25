# AyoCuci Release Smoke Checklist

Use this checklist before sharing a release APK/AAB or after backend deploy.

## Setup

- Install fresh build, do not rely on an existing app install.
- Test once on stable Wi-Fi and once with Wi-Fi toggled off/on.
- Use an account with an active outlet and sample transaction data.

## Authentication

- Email/password login succeeds.
- Google login succeeds and lands on the expected outlet.
- Logout clears the session and returns to the login screen.
- Expired/invalid session shows a friendly message, not a raw server error.

## Home

- Splash screen does not block too long on slow network.
- Home opens with outlet profile, today's income, status summary, and content banners.
- Promo/info images render and remain visible when switching tabs.
- With network off after a successful load, home still shows the last successful data.

## Status

- Status tabs load queue data.
- Pull-to-refresh works.
- With unstable network, the last queue/summary data stays visible and retry does not show raw exception text.

## Reports

- Finance dashboard opens.
- Omset, pendapatan, pengeluaran, laba rugi, piutang, transaksi, and pelanggan reports load.
- Slow network shows skeleton/loading states, then cached last data when available.
- Error states show friendly copy and a working retry button.

## Images

- Outlet logo/profile image loads from OSS.
- Content/banner images load from OSS variants.
- Notification image loads in list and detail.
- Nota logo preview loads.
- Bukti topup koin/addon/pengeluaran thumbnail loads and fullscreen preview opens.

## Core Transaction Flow

- Create transaction.
- Add service/item/parfum and customer.
- Save transaction.
- Pay/settle transaction.
- Print/share nota screen opens without broken logo.

## Uploads

- Upload outlet image.
- Upload nota logo.
- Upload expense proof.
- Upload coin/addon payment proof.
- New upload URL points to OSS and image can be opened.

## Release Config

- `GOOGLE_CLIENT_ID` points to the current web OAuth client.
- Android debug/release SHA-1 are registered in Firebase/Google Cloud.
- `version` in `pubspec.yaml` has a higher build number than the previous release.
- Backend production env has the same `GOOGLE_CLIENT_ID`.
