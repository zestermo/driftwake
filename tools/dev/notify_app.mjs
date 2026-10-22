// Pushes the companion app's notifications for what a deploy made new (no dependencies):
//   node tools/dev/notify_app.mjs <live-dir> [--dry-run]
// <live-dir> holds driftwake.fun's posts.json / releases.json from before the deploy; anything in
// web/site/feeds that isn't there gets one push. A re-run finds it already live and sends nothing; with
// no live feeds at all (the first deploy that has them) nothing is sent. FIREBASE_SERVICE_ACCOUNT holds
// the service account JSON. The app's scripts/send-push.mjs sends the same message shape by hand.
import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createSign } from 'node:crypto';

const [liveDir, flag] = process.argv.slice(2);
if (!liveDir) throw new Error('usage: notify_app.mjs <live-dir> [--dry-run]');
const dryRun = flag === '--dry-run';
const feeds = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'web', 'site', 'feeds');
const read = (dir, name) => JSON.parse(readFileSync(join(dir, name), 'utf8'));

if (!existsSync(join(liveDir, 'posts.json')) || !existsSync(join(liveDir, 'releases.json'))) {
	console.log('notify_app: no live feeds yet, so nothing is new');
	process.exit(0);
}

const livePosts = new Set(read(liveDir, 'posts.json').map((p) => p.slug));
const liveReleases = new Set(read(liveDir, 'releases.json').map((r) => r.version));
const messages = [
	...read(feeds, 'releases.json')
		.filter((r) => !liveReleases.has(r.version))
		.map((r) => ({
			topic: 'releases',
			title: r.unstable ? `Unstable build: Driftwake v${r.version}` : `Driftwake v${r.version} is out`,
			body: r.summary ? `${r.title}. ${r.summary}` : r.title,
			route: `/tabs/news/releases/${r.version}`,
		})),
	...read(feeds, 'posts.json')
		.filter((p) => !livePosts.has(p.slug))
		.map((p) => ({ topic: 'news', title: p.title, body: p.summary, route: `/tabs/news/${p.slug}` })),
];

if (!messages.length) {
	console.log('notify_app: nothing new');
	process.exit(0);
}
if (dryRun) {
	for (const m of messages) console.log(`notify_app (dry run): ${m.topic}: ${m.title} -> ${m.route}`);
	process.exit(0);
}

if (!process.env.FIREBASE_SERVICE_ACCOUNT) throw new Error('FIREBASE_SERVICE_ACCOUNT is not set');
const account = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

async function accessToken() {
	const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
	const now = Math.floor(Date.now() / 1000);
	const head = b64({ alg: 'RS256', typ: 'JWT' });
	const claims = b64({ iss: account.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging', aud: account.token_uri, iat: now, exp: now + 3600 });
	const sig = createSign('RSA-SHA256').update(`${head}.${claims}`).sign(account.private_key, 'base64url');
	const res = await fetch(account.token_uri, {
		method: 'POST',
		headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
		body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${head}.${claims}.${sig}` }),
	});
	if (!res.ok) throw new Error(`notify_app: token: HTTP ${res.status} ${await res.text()}`);
	return (await res.json()).access_token;
}

const token = await accessToken();
for (const m of messages) {
	const res = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
		method: 'POST',
		headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
		body: JSON.stringify({
			message: {
				topic: m.topic,
				notification: { title: m.title, body: m.body },
				data: { route: m.route },
				android: { priority: 'high', notification: { channel_id: 'driftwake_updates' } },
			},
		}),
	});
	if (!res.ok) throw new Error(`notify_app: ${m.topic} "${m.title}": HTTP ${res.status} ${await res.text()}`);
	console.log(`notify_app: sent ${m.topic}: ${m.title}`);
}
