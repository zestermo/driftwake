// The site's JSON feeds for the companion app, built from the hand-written pages (no dependencies):
//   node tools/dev/build_feeds.mjs        writes web/site/feeds/{posts,releases,home,guide}.json
// deploy-web.yml runs it before every deploy. It throws when a page doesn't match the pattern it reads.
import { readFileSync, writeFileSync, mkdirSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const SITE_URL = 'https://driftwake.fun';
const LINKS = [
	{ label: 'Website', url: SITE_URL },
	{ label: 'GitHub', url: 'https://github.com/zestermo/driftwake' },
];

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const site = join(root, 'web', 'site');
const out = join(site, 'feeds');

const ENTITIES = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', middot: '·', mdash: '—', ndash: '–', hellip: '…', rsquo: '’', lsquo: '‘', rdquo: '”', ldquo: '“', times: '×' };
const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

function fail(where, what) {
	throw new Error(`build_feeds: ${where}: ${what}`);
}

function one(html, re, where, what) {
	const m = html.match(re);
	if (!m) fail(where, `no ${what}`);
	return m[1];
}

function text(html) {
	return html
		.replace(/<[^>]+>/g, '')
		.replace(/&(#\d+|[a-z]+);/g, (all, name) => {
			if (name[0] === '#') return String.fromCodePoint(Number(name.slice(1)));
			if (!(name in ENTITIES)) fail('text', `unknown entity ${all}`);
			return ENTITIES[name];
		})
		.replace(/\s+/g, ' ')
		.trim();
}

// "October 21, 2026" -> "2026-10-21", "April 2026" -> "2026-04"
function isoDate(s, where) {
	const m = s.match(/^([A-Z][a-z]+) (?:(\d{1,2}), )?(\d{4})$/);
	if (!m || !MONTHS.includes(m[1])) fail(where, `can't read the date "${s}"`);
	const mm = String(MONTHS.indexOf(m[1]) + 1).padStart(2, '0');
	return m[2] ? `${m[3]}-${mm}-${m[2].padStart(2, '0')}` : `${m[3]}-${mm}`;
}

// the app shows this HTML away from the site, so root-relative links and images get the site's origin
function absolute(html) {
	return html
		.replace(/(\s(?:href|src)=")\/(?!\/)/g, `$1${SITE_URL}/`)
		.replace(/(\ssrcset=")([^"]*)"/g, (all, attr, list) => attr + list.replace(/(^|,\s*)\/(?!\/)/g, `$1${SITE_URL}/`) + '"');
}

// download buttons stay on the site: the app doesn't hand out the game
function dropButtons(html) {
	return html.replace(/\s*<p><a class="btn[^"]*"[^>]*>[\s\S]*?<\/a><\/p>/g, '');
}

function compareVersions(a, b) {
	const pa = a.split('.').map(Number), pb = b.split('.').map(Number);
	for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
		const d = (pa[i] ?? 0) - (pb[i] ?? 0);
		if (d) return d;
	}
	return 0;
}

function buildReleases() {
	const where = 'releases/index.html';
	const html = readFileSync(join(site, 'releases', 'index.html'), 'utf8');
	const sections = [...html.matchAll(/<section class="panel notes version( unstable)?" id="v[\d-]+"[^>]*>([\s\S]*?)<\/section>/g)];
	if (!sections.length) fail(where, 'no version sections');
	return sections.map(([, unstable, body]) => {
		const version = one(body, /<h2[^>]*>v([\d.]+)/, where, 'version heading');
		const at = `${where} v${version}`;
		const title = text(one(body, /<p class="tagline">([\s\S]*?)<\/p>/, at, 'tagline'));
		const date = isoDate(text(one(body, /<p class="date">([\s\S]*?)<\/p>/, at, 'date')).split(' · ')[0], at);
		const notes = dropButtons(body.slice(body.indexOf('<p class="date">')).replace(/^<p class="date">[\s\S]*?<\/p>/, '')).trim();
		if (!notes.includes('<ul>')) fail(at, 'no list of changes');
		const intro = notes.match(/^<p>([\s\S]*?)<\/p>/);
		const post = body.match(/href="\/news\/([a-z0-9-]+)\/"/);
		const highlights = [...notes.matchAll(/<li><b>([\s\S]*?)<\/b>/g)].map((m) => text(m[1]).replace(/\.$/, ''));
		return {
			version,
			date,
			title,
			summary: intro ? text(intro[1]).replace(/\s*Read [^.]*\.?$/, '') : '',
			notes_html: absolute(notes),
			highlights,
			unstable: Boolean(unstable),
			post: post ? post[1] : null,
		};
	// newest first whatever the page's order (the unstable builds are folded below the stable line there)
	}).sort((a, b) => b.version.split('.').map(Number).reduce((d, n, i) => d || n - (a.version.split('.').map(Number)[i] || 0), 0) || b.version.length - a.version.length);
}

function buildPosts(releases) {
	const unstable = new Set(releases.filter((r) => r.unstable).map((r) => r.version));
	const dir = join(site, 'news');
	const posts = readdirSync(dir, { withFileTypes: true })
		.filter((d) => d.isDirectory() && existsSync(join(dir, d.name, 'index.html')))
		.map((d) => {
			const where = `news/${d.name}`;
			const html = readFileSync(join(dir, d.name, 'index.html'), 'utf8');
			const head = one(html, /<header class="page-head">([\s\S]*?)<\/header>/, where, 'page head');
			const title = text(one(head, /<h1>([\s\S]*?)<\/h1>/, where, 'title'));
			const date = isoDate(text(one(head, /<p class="date">([\s\S]*?)<\/p>/, where, 'date')).split(' · ').pop(), where);
			const summary = text(one(head, /<\/h1>\s*<p>([\s\S]*?)<\/p>/, where, 'summary'));
			const cover = one(html, /<meta property="og:image" content="([^"]+)"/, where, 'og:image');
			const body = one(html, /<main id="main" class="article">([\s\S]*?)<\/main>/, where, 'article');
			const version = title.match(/^v([\d.]+):/);
			return {
				slug: d.name,
				title,
				date,
				summary,
				cover,
				body_html: absolute(dropButtons(body)).trim(),
				tags: version ? ['release'] : [],
				version: version ? version[1] : null,
				unstable: version ? unstable.has(version[1]) : false,
			};
		});
	if (!posts.length) fail('news', 'no posts');
	return posts.sort((a, b) => b.date.localeCompare(a.date) || compareVersions(b.version ?? '0', a.version ?? '0'));
}

function buildHome() {
	const where = 'index.html';
	const html = readFileSync(join(site, 'index.html'), 'utf8');
	return {
		tagline: text(one(html, /<p class="tag">([\s\S]*?)<\/p>/, where, 'tag')),
		hook: text(one(html, /<p class="hook">([\s\S]*?)<\/p>/, where, 'hook')),
		pitch: text(one(html, /<p class="pitch">([\s\S]*?)<\/p>/, where, 'pitch')),
		hero_image: SITE_URL + one(html, /<img class="hero-bg" src="([^"]+)"/, where, 'hero image'),
		links: LINKS,
	};
}

// the app's field guide: the home page's clips, screenshots, features and controls
function buildGuide() {
	const where = 'index.html';
	const html = readFileSync(join(site, 'index.html'), 'utf8');
	const section = (cls) => one(html, new RegExp(`<div class="${cls}">([\\s\\S]*?)</div>\\s*</section>`), where, `.${cls}`);
	const attr = (tag, name, at) => one(tag, new RegExp(`\\s${name}="([^"]*)"`), at, name);
	const clips = [...section('clips').matchAll(/<figure class="clip">(<img[^>]+>)<figcaption><b>([\s\S]*?)<\/b>([\s\S]*?)<\/figcaption><\/figure>/g)].map(([, img, title, rest]) => ({
		poster: SITE_URL + attr(img, 'src', 'clip'),
		gif: SITE_URL + attr(img, 'data-gif', 'clip'),
		alt: text(attr(img, 'alt', 'clip')),
		title: text(title).replace(/\.$/, ''),
		text: text(rest),
	}));
	const shots = [...section('shots').matchAll(/<figure>(<img[^>]+>)<figcaption>([\s\S]*?)<\/figcaption><\/figure>/g)].map(([, img, caption]) => {
		const src = attr(img, 'src', 'shot');
		return { image: SITE_URL + src, thumb: SITE_URL + src.replace(/\.jpg$/, '-640.jpg'), alt: text(attr(img, 'alt', 'shot')), caption: text(caption) };
	});
	const features = [...section('grid').matchAll(/<div><h3>([\s\S]*?)<\/h3><p>([\s\S]*?)<\/p><\/div>/g)].map(([, title, body]) => ({ title: text(title), text: text(body) }));
	const table = one(html, /<section class="panel controls"[\s\S]*?<table>([\s\S]*?)<\/table>/, where, 'controls table');
	const controls = [...table.matchAll(/<th>([\s\S]*?)<\/th><td>([\s\S]*?)<\/td>/g)].map(([, action, keys]) => ({ action: text(action), keys: text(keys) }));
	const notes = text(one(html, /<\/table>\s*<p class="small">([\s\S]*?)<\/p>/, where, 'controls note'));
	if (!clips.length || !shots.length || !features.length || !controls.length) fail(where, 'an empty guide section');
	return { clips, shots, features, controls, notes };
}

const releases = buildReleases();
const posts = buildPosts(releases);
const home = buildHome();
const guide = buildGuide();
mkdirSync(out, { recursive: true });
for (const [name, data] of Object.entries({ posts, releases, home, guide })) {
	writeFileSync(join(out, `${name}.json`), JSON.stringify(data, null, '\t') + '\n');
}
console.log(`build_feeds: ${posts.length} posts, ${releases.length} releases -> web/site/feeds/`);
