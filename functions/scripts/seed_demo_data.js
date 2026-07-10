#!/usr/bin/env node
/* eslint-disable no-console */

/**
 * Seeds demo content into an existing family for beta testing.
 *
 * Usage examples:
 *   node scripts/seed_demo_data.js --family-id <FAMILY_ID>
 *   node scripts/seed_demo_data.js --join-code ABC123
 *
 * Optional:
 *   --wipe-demo   Deletes previous docs with demoSeed=true before seeding.
 */

const admin = require('firebase-admin');
const fs = require('fs');

function parseArgs(argv) {
  const out = { wipeDemo: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--family-id') out.familyId = argv[++i];
    else if (arg === '--join-code') out.joinCode = (argv[++i] || '').toUpperCase();
    else if (arg === '--wipe-demo') out.wipeDemo = true;
    else if (arg === '--service-account') out.serviceAccount = argv[++i];
    else if (arg === '--project-id') out.projectId = argv[++i];
  }
  return out;
}

function daysAgo(days, hour = 10) {
  const d = new Date();
  d.setDate(d.getDate() - days);
  d.setHours(hour, 0, 0, 0);
  return d;
}

async function resolveFamilyRef(db, opts) {
  if (opts.familyId) {
    const ref = db.collection('families').doc(opts.familyId);
    const snap = await ref.get();
    if (!snap.exists) throw new Error(`Family not found for id: ${opts.familyId}`);
    return ref;
  }

  if (opts.joinCode) {
    const q = await db
      .collection('families')
      .where('joinCode', '==', opts.joinCode)
      .limit(1)
      .get();
    if (q.empty) throw new Error(`Family not found for join code: ${opts.joinCode}`);
    return q.docs[0].ref;
  }

  throw new Error('Provide either --family-id or --join-code.');
}

async function wipeDemoDocs(familyRef) {
  const subcollections = [
    'stories',
    'tasks',
    'calendar_events',
    'predictions',
    'time_travel_entries',
    'creative_submissions',
  ];
  for (const name of subcollections) {
    const snap = await familyRef
      .collection(name)
      .where('demoSeed', '==', true)
      .get();
    for (const doc of snap.docs) {
      if (name === 'stories') {
        const comments = await doc.ref.collection('comments').get();
        for (const c of comments.docs) {
          await c.ref.delete();
        }
      }
      await doc.ref.delete();
    }
  }

  const chatSnap = await familyRef.collection('chats').doc('main').collection('messages')
    .where('demoSeed', '==', true)
    .get();
  for (const m of chatSnap.docs) {
    await m.ref.delete();
  }
}

function pick(members, idx) {
  return members[idx % members.length];
}

async function seedFamilyDemo(db, familyRef, members) {
  const familyId = familyRef.id;
  const now = new Date();
  const emails = members.map((m) => m.email);

  await familyRef.set(
    {
      memberCount: members.length,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  for (const m of members) {
    await db.collection('users').doc(m.uid).set(
      {
        email: m.email,
        familyId,
        displayName: m.displayName,
        greeting: m.greeting || '',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  // Chat meta + messages
  const membersMap = {};
  const readThrough = {};
  for (const m of members) {
    membersMap[m.uid] = {
      email: m.email,
      name: m.displayName,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    readThrough[m.uid] = admin.firestore.Timestamp.fromDate(daysAgo(0, 9));
  }
  await familyRef.collection('chats').doc('main').set(
    {
      members: membersMap,
      readThrough,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const chatMessages = [
    { d: 2, text: 'Welcome to our beta family space.' },
    { d: 2, text: 'Please test chat, tasks, and diary flow today.' },
    { d: 1, text: 'I added a memory from yesterday evening.' },
    { d: 0, text: 'Can someone submit one sample task?' },
    { d: 0, text: 'Done. Looks smooth on my phone.' },
  ];
  for (let i = 0; i < chatMessages.length; i += 1) {
    const msg = chatMessages[i];
    const author = pick(members, i);
    await familyRef.collection('chats').doc('main').collection('messages').add({
      text: msg.text,
      authorUid: author.uid,
      authorName: author.displayName,
      createdAt: admin.firestore.Timestamp.fromDate(daysAgo(msg.d, 10 + i)),
      type: 'text',
      reactions: {},
      demoSeed: true,
    });
  }

  // Stories + comments
  const storySeeds = [
    {
      title: 'Weekend breakfast',
      body: 'We all sat together and planned the week. It felt calm and positive.',
      mood: 'calm',
      d: 3,
    },
    {
      title: 'Evening walk',
      body: 'Shared stories while walking and clicked a few photos.',
      mood: 'happy',
      d: 1,
    },
    {
      title: 'Tiny celebration',
      body: 'Wrapped up tasks and celebrated with dessert.',
      mood: 'proud',
      d: 0,
    },
  ];

  for (let i = 0; i < storySeeds.length; i += 1) {
    const s = storySeeds[i];
    const author = pick(members, i);
    const tagged = emails.filter((e) => e !== author.email).slice(0, 2);
    const storyRef = await familyRef.collection('stories').add({
      title: s.title,
      body: s.body,
      mood: s.mood,
      authorUid: author.uid,
      authorName: author.displayName,
      authorEmail: author.email,
      taggedEmails: tagged,
      imageUrls: [],
      videoUrls: [],
      reactions: {},
      commentCount: 1,
      createdAt: admin.firestore.Timestamp.fromDate(daysAgo(s.d, 18 - i)),
      demoSeed: true,
    });
    const commenter = pick(members, i + 1);
    await storyRef.collection('comments').add({
      text: 'Nice one, this is perfect for beta testing.',
      authorUid: commenter.uid,
      authorName: commenter.displayName,
      createdAt: admin.firestore.Timestamp.fromDate(daysAgo(s.d, 19 - i)),
      demoSeed: true,
    });
  }

  // Tasks
  const taskSeeds = [
    { title: 'Test chat notifications', status: 'pending', d: 0, dueOffset: 1 },
    { title: 'Submit one diary memory', status: 'submitted', d: 1, dueOffset: 2 },
    { title: 'Verify profile greeting', status: 'approved', d: 2, dueOffset: 0 },
  ];
  for (let i = 0; i < taskSeeds.length; i += 1) {
    const t = taskSeeds[i];
    const assigner = pick(members, i);
    const assignee = pick(members, i + 1);
    const created = daysAgo(t.d, 11 + i);
    const due = new Date(created);
    due.setDate(due.getDate() + t.dueOffset + 1);

    const payload = {
      title: t.title,
      description: 'Sample beta task seeded for feedback collection.',
      assignerUid: assigner.uid,
      assignerEmail: assigner.email,
      assignerName: assigner.displayName,
      assigneeUid: assignee.uid,
      assigneeEmail: assignee.email,
      assigneeName: assignee.displayName,
      participantEmails: [assigner.email, assignee.email].sort(),
      dueAt: admin.firestore.Timestamp.fromDate(due),
      rewardPoints: 15 + i * 5,
      status: t.status,
      createdAt: admin.firestore.Timestamp.fromDate(created),
      demoSeed: true,
    };
    if (t.status === 'submitted' || t.status === 'approved') {
      payload.submittedAt = admin.firestore.Timestamp.fromDate(now);
      payload.submittedNote = 'Completed in beta check.';
    }
    if (t.status === 'approved') {
      payload.resolvedAt = admin.firestore.Timestamp.fromDate(now);
    }
    await familyRef.collection('tasks').add(payload);
  }

  // Calendar events
  const eventSeeds = [
    { title: 'Family beta check-in', days: 1, allDay: false, type: 'reminder' },
    { title: 'Weekend plan', days: 3, allDay: true, type: 'other' },
  ];
  for (let i = 0; i < eventSeeds.length; i += 1) {
    const e = eventSeeds[i];
    const creator = pick(members, i);
    const start = new Date();
    start.setDate(start.getDate() + e.days);
    start.setHours(e.allDay ? 9 : 19, 0, 0, 0);
    await familyRef.collection('calendar_events').add({
      title: e.title,
      description: 'Seeded event for beta testing.',
      startAt: admin.firestore.Timestamp.fromDate(start),
      endAt: null,
      allDay: e.allDay,
      eventType: e.type,
      creatorUid: creator.uid,
      creatorName: creator.displayName,
      creatorEmail: creator.email,
      participantEmails: emails,
      demoSeed: true,
    });
  }

  // Member stats
  for (let i = 0; i < members.length; i += 1) {
    const m = members[i];
    await familyRef.collection('member_stats').doc(m.uid).set(
      {
        email: m.email,
        displayName: m.displayName,
        points: 40 + i * 15,
        storiesCreated: 1 + (i % 2),
        gamesWon: i % 2,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  console.log(`Demo data seeded for family ${familyId}.`);
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (!opts.familyId && !opts.joinCode) {
    throw new Error('Missing target. Use --family-id <id> or --join-code <code>.');
  }

  if (opts.serviceAccount) {
    const raw = fs.readFileSync(opts.serviceAccount, 'utf8');
    const json = JSON.parse(raw);
    admin.initializeApp({
      credential: admin.credential.cert(json),
      projectId: opts.projectId || json.project_id,
    });
  } else {
    admin.initializeApp();
  }
  const db = admin.firestore();

  const familyRef = await resolveFamilyRef(db, opts);
  const membersSnap = await familyRef.collection('members').orderBy('joinedAt').get();
  if (membersSnap.empty) {
    throw new Error('Family has no members; create/join members before seeding.');
  }

  const members = membersSnap.docs.map((d) => {
    const data = d.data();
    const email = (data.email || '').toLowerCase().trim();
    const displayName = (data.displayName || '').trim();
    return {
      uid: d.id,
      email,
      displayName: displayName || email.split('@')[0] || 'Member',
      greeting: (data.greeting || '').trim(),
    };
  }).filter((m) => m.email.length > 0);

  if (members.length < 2) {
    throw new Error('Need at least 2 members in family to seed realistic demo data.');
  }

  if (opts.wipeDemo) {
    await wipeDemoDocs(familyRef);
    console.log('Previous demo docs removed.');
  }

  await seedFamilyDemo(db, familyRef, members);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
