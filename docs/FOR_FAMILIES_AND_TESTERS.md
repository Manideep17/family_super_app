# FAM — guide for families and testers

**Printable PDF:** [FOR_FAMILIES_AND_TESTERS.pdf](FOR_FAMILIES_AND_TESTERS.pdf) — same content, designed for reading on paper or sharing as an attachment.

To regenerate the PDF after editing the Markdown (or the HTML source), from the app root run:

```bash
bash scripts/render_family_guide_pdf.sh
```

Requires **Google Chrome** (or Chromium) on your machine. The layout lives in `docs/print/family_guide.html`.

---

This document is for **people using the app**, not developers. It describes what FAM is, how to get started, and what you can do today—including recent improvements.

---

## What is FAM?

**FAM** is a private app for **one family at a time**. Each family has its own space: shared chat, a diary of memories, tasks, a calendar, photos in a vault, light games, and a home dashboard. Only people who join **your** family with your **invite code** can see that family’s content.

---

## How to install the app

- **Android (beta):** You may receive an **APK** file from whoever runs the project. Install it, allow installation from that source if Android asks, then open **FAM**. Step-by-step install tips are in [BETA_TESTER_GUIDE.md](BETA_TESTER_GUIDE.md).
- **iOS:** Your host may give you a build via **Xcode** (USB to a Mac), **TestFlight**, or the **App Store** later. See **iOS: what to expect** below.

If anything fails at install time, contact the person who shared the build with you.

### iOS: what to expect

- **Xcode / USB:** Common for early testing. You may need to **trust the developer** on the device: Settings → General → VPN & Device Management.
- **TestFlight:** Needs an **Apple Developer Program** membership and App Store Connect. Not every team has this on day one — ask your host.
- **Simulator (Mac):** Useful for screenshots or quick checks; most families install on a **physical iPhone** instead.

---

## Accounts: sign in, sign up, and recovery

You can use FAM in either of these ways:

1. **Email and password**  
   - On the first screen, use the segments at the top: **Sign in** or **Create account**.  
   - **Create account:** enter email and password (at least 6 characters), then create your account.  
   - **Sign in:** same screen, choose **Sign in**, then enter your email and password.

2. **Google**  
   - Tap **Continue with Google** and pick the Google account you want to use.

**Forgot your password?**  
Choose **Sign in**, enter your **email**, then tap **Forgot password?** You’ll get a reset link if that email is registered.

**Email verification**  
If you signed up with **email and password**, you may see a reminder to **verify your email** (before or after you join a family). Check your inbox for Firebase’s link, or tap **Resend verification email** if you need a new one. Google sign-in does not use this flow.

---

## Families: create, join, and invite

After you sign in:

- **Create a family** — You pick a family name; the app gives you a **6-character invite code**. Share that code only with people you trust.
- **Join a family** — Enter the code someone gave you, then set how you want your name to appear.

Each account is in **one family at a time** in normal use. Family data (chat, diary, tasks, etc.) is **not** visible to other families.

**Invite links:** Your host may share a **6-character code**, a **tap-to-open link** (`famsuperapp://…`), or an **https link** once the project has set up App Links. All of these should end up filling in the join code for you when you open FAM.

**Leaving a family** is available from **My family** in the menu (see below). Read any warning the app shows before you confirm.

---

## Where things live in the app

### Bottom tabs (main bar)

| Tab | What it’s for |
|-----|----------------|
| **Home** | Your dashboard: greeting, streaks, quick actions, recent memories, tasks that need you, upcoming events, and optional **family announcement** (see below). |
| **Chat** | Family group chat. |
| **Diary** | Family memories (stories); you can add new ones from here or from Home. |
| **Tasks** | Chores and to-dos between family members, with points when completed as designed. |

### Menu (three lines / “hamburger”)

Open the **menu** from the top-left on the main screens. From there you can reach things like:

- **My profile** — Photo (when uploads are enabled), display name, greeting, **FAM coins**, and optional **family title** (see below).
- **My family** — Invite code, member list, **home announcement** (whoever edits it), and leave family.
- **Family polls** — Quick votes (two options) for the whole family.
- **Send feedback** — Opens your **email app** with a subject line so you can tell the host what worked or what broke.
- **Timeline, calendar, vault, leaderboard, predictions, games, insights** — Explore memories over time, events, shared media, points, fun guesses, mini-games, and mood-style summaries (depending on what your family uses).

---

## Features you can use today (overview)

These are the main areas families use; not every household will touch all of them.

- **Chat** — Text messages for everyone in the family.
- **Diary** — Longer “memory” posts with mood and optional photos; readable in the diary feed and timeline.
- **Tasks** — Someone assigns a task, someone else completes it; approvals and **reward points** can apply.
- **Calendar** — Shared events.
- **Vault** — Shared media when the build allows uploads.
- **Gamification** — **Points** for activity, a **leaderboard**, and **badges** for milestones (for example stories written or games won).
- **Predictions** — Light “guess what happens” style fun for the family.
- **Games hub** — Mini-games (for example memory and family trivia-style games); some entries may be marked as coming later.
- **Home dashboard** — Pull-to-refresh, quick links to common actions, and summaries like “this week” and “needs your attention.”

Exact labels may change slightly as the app is polished, but the ideas stay the same.

---

## What’s new or improved (recent updates)

These items were added to make the app clearer and more “family-shaped” for daily use:

### Clearer sign-in and account help

- **Sign in** and **Create account** are obvious choices on one screen (you don’t have to hunt for “new user” in small text).
- **Forgot password** works from the sign-in flow (email/password accounts).
- **Resend verification email** appears when your email/password account is not yet verified.

### Family announcement on Home

- Any family member can set a **short announcement** that appears on the **Home** tab for everyone (for example “Movie night Saturday” or “Grandma visiting”).
- Edit it under **Menu → My family → Home announcement** (tap to edit, save when done). There is a sensible length limit so it stays easy to read.

### Family polls

- Under **Menu → Family polls** (and a **Polls** shortcut on Home), you can start a **simple two-option vote** (for example “Pizza or tacos?”).
- Everyone in the family can tap **A** or **B**. Counts update for the family.
- The person who created a poll can **delete** it when it’s no longer needed.

### FAM coins and family titles

- **FAM coins** are a light, in-app “thank you” balance (not real money). You earn coins from things like tasks, diary posts, and games, depending on how your family uses the app.
- In **My profile**, you’ll see your **FAM coins** and can pick an optional **family title** from a preset list (for example “Snack captain” or “Story keeper”). Titles show on the **leaderboard** so everyone can see the fun labels.
- Extra **badges** can appear when you hit certain milestones (for example coin milestones on top of the existing point badges).

### Send feedback

- **Menu → Send feedback** opens your mail app with a ready-made subject so you can describe a problem or idea. You choose who to send it to (often the person who gave you the app).

---

## Privacy (plain language)

- Your **family’s** chats, diary, tasks, and other family data are meant to be visible **only to members of that family**, not to strangers or other families.
- The **invite code** is like a key: anyone you give it to can try to join—only share it with people you trust.
- If you use **Google** sign-in, Google’s normal account rules apply in addition to FAM.

For technical security rules, the people who operate Firebase for this project rely on the configuration described in the project’s developer docs.

---

## What’s still “beta” or evolving

It’s normal for early versions to be rough. In particular:

- **Push notifications** may depend on device settings, battery savers, and whether the host has set up server-side automation. You might not get reminders for everything yet.
- **AI-heavy** features (automatic weekly summaries, smart coaching) are **not** promised in the current open-source scope; the app focuses on things families do together manually.
- **Stricter anti-cheat** for points is still a product/engineering topic; treat points and coins as **fun**, not financial value.

If something feels wrong or confusing, use **Send feedback** or tell your host directly.

---

## Quick checklist for testers

1. Install the build you were given.  
2. **Sign in** or **Create account**, or use **Google**.  
3. **Create** or **join** a family with the **6-character code**.  
4. Try **Home** (including **Polls** and any **announcement**), **Chat**, **Diary**, and **Tasks**.  
5. Open **My profile** and **My family** once.  
6. Send **feedback** if anything breaks or feels unclear.

More install detail: [BETA_TESTER_GUIDE.md](BETA_TESTER_GUIDE.md).  
For whoever prepares builds: [BETA_RELEASE_RUNBOOK.md](BETA_RELEASE_RUNBOOK.md).

---

## Questions?

Ask the **person who shared FAM** with you (the “host”). They can forward technical issues to whoever maintains the Firebase project and the app code.
