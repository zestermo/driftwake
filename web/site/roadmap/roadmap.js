// The roadmap timeline: builds a card per version from roadmap.json, scrolls the track (wheel, drag, swipe, arrow
// keys), and opens a card into the detail panel. Wide screens get one horizontal track; at phone width (<= 640px)
// the CSS turns it vertical and the page scrolls as usual.
(() => {
	const CW = 220;      // card width (matches .tl --cw)
	const STEP = 150;    // distance between neighbouring nodes; cards alternate above and below, so same-side cards sit 300 apart
	const PAD = 80;      // track padding at either end
	const GH = "https://github.com/zestermo/driftwake/releases/tag/v";
	const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
	const STATUS = { building: "Being built", planned: "Planned", goal: "The goal" };
	const NOTE = {
		building: "Being built now. The name and the final list come with the release.",
		planned: "Planned. Plans change at sea, so treat this as a heading, not a promise.",
		goal: "The destination. Everything before it is the voyage.",
	};

	const scroller = document.querySelector(".tl");
	const track = document.querySelector(".tl-track");
	const dialog = document.querySelector(".tl-dialog");
	const wide = matchMedia("(min-width: 641px)");
	const still = matchMedia("(prefers-reduced-motion: reduce)");
	let versions = [];
	let hereIdx = 0;
	let current = -1;

	const el = (tag, cls, text) => {
		const e = document.createElement(tag);
		if (cls) e.className = cls;
		if (text != null) e.textContent = text;
		return e;
	};
	const label = (v) => (/^\d/.test(v.v) ? "v" + v.v : v.v.charAt(0).toUpperCase() + v.v.slice(1));
	const slug = (v) => "v" + v.v.replace(/\./g, "-");
	const shipped = (v) => v.status === "shipped";
	const when = (v) => {
		if (!v.date) return STATUS[v.status] || "";
		const [y, m, d] = v.date.split("-").map(Number);
		return d ? `${MONTHS[m - 1]} ${d}, ${y}` : `${MONTHS[m - 1]} ${y}`;
	};
	// "forest" -> /img/forest-640.jpg (card) and /img/forest.jpg (panel); clips have one size
	const src = (name, small) => (name.startsWith("clips/") || !small ? `/img/${name}.jpg` : `/img/${name}-640.jpg`);

	// ---- building the track ----
	function picture(v, small) {
		if (!v.img) {
			const b = el("span", "tl-blank");
			b.append(el("b", null, "?"), document.createTextNode("Uncharted"));
			return b;
		}
		const wrap = el("span", "tl-pic");
		const img = el("img");
		img.src = src(v.img, small);
		img.alt = small ? "" : v.alt || "";
		img.width = 640;
		img.height = 360;
		img.loading = "lazy";
		img.decoding = "async";
		img.draggable = false;
		wrap.append(img);
		if (!shipped(v)) wrap.append(el("span", "tl-stamp", STATUS[v.status]));
		return wrap;
	}

	function build() {
		let x = PAD;
		const frag = document.createDocumentFragment();
		versions.forEach((v, i) => {
			if (i > 0) x += STEP * (v.gap ? 2 : 1);
			v.x = x;
		});
		versions.forEach((v, i) => {
			const next = versions[i + 1];
			const li = el("li", `tl-item s-${v.status} ${i % 2 ? "is-down" : "is-up"}`);
			li.style.setProperty("--x", v.x + "px");
			li.style.setProperty("--i", i);
			if (next) {
				const seg = el("span", "tl-seg" + (shipped(next) ? "" : " is-plan"));
				li.style.setProperty("--seg", next.x - v.x + "px");
				li.append(seg);
				if (next.gap) li.append(el("span", "tl-gap", next.gap));
			}
			li.append(el("span", "tl-stem"), el("span", "tl-node"));
			if (i === hereIdx) {
				li.classList.add("is-here");
				li.append(el("span", "tl-here", "You are here"));
			}
			const float = el("div", "tl-float");
			const a = el("a", "tl-card");
			a.href = "#" + slug(v);
			a.id = "card-" + slug(v);
			a.draggable = false;
			a.dataset.i = i;
			a.setAttribute("aria-haspopup", "dialog");
			const meta = el("span", "tl-meta");
			meta.append(el("span", "tl-v", label(v)), el("span", "tl-date", when(v)));
			a.append(picture(v, true), meta, el("span", "tl-name", v.name), el("span", "tl-headline", v.headline));
			if (i === hereIdx) a.setAttribute("aria-description", "You are here: the latest release");
			float.append(a);
			li.append(float);
			frag.append(li);
		});
		track.append(frag);
		track.style.setProperty("--w", versions[versions.length - 1].x + CW + PAD + "px");
	}

	// ---- scrolling the wide track: one eased position the wheel, keys and jumps all steer ----
	let pos = 0, target = 0, raf = 0;
	const maxScroll = () => scroller.scrollWidth - scroller.clientWidth;
	const clamp = (n) => Math.max(0, Math.min(maxScroll(), n));
	function tick() {
		const d = target - pos;
		if (Math.abs(d) < 0.5) {
			pos = target;
			scroller.scrollLeft = pos;
			raf = 0;
			return;
		}
		pos += d * 0.16;
		scroller.scrollLeft = pos;
		raf = requestAnimationFrame(tick);
	}
	function glide(to, instant) {
		target = clamp(to);
		if (instant || still.matches) {
			cancelAnimationFrame(raf);
			raf = 0;
			pos = target;
			scroller.scrollLeft = pos;
			return;
		}
		if (!raf) {
			pos = scroller.scrollLeft;
			raf = requestAnimationFrame(tick);
		}
	}
	function stopGlide() {
		cancelAnimationFrame(raf);
		raf = 0;
		pos = target = scroller.scrollLeft;
	}
	function show(i, instant) {
		const v = versions[i];
		if (!v) return;
		if (wide.matches) {
			glide(v.x + CW / 2 - scroller.clientWidth / 2, instant);
		} else {
			const card = track.children[i];
			card.scrollIntoView({ block: "center", behavior: instant || still.matches ? "auto" : "smooth" });
		}
	}

	// the sea behind the cards drifts at two slower rates
	function parallax() {
		if (!wide.matches) return;
		const s = scroller.scrollLeft;
		scroller.style.backgroundPosition = `${-s * 0.25}px 30px, ${-s * 0.5}px 0`;
	}
	scroller.addEventListener("scroll", () => {
		if (!raf) pos = target = scroller.scrollLeft;
		parallax();
	}, { passive: true });

	scroller.addEventListener("wheel", (e) => {
		if (!wide.matches || e.ctrlKey) return;
		const sideways = Math.abs(e.deltaX) > Math.abs(e.deltaY);
		let d = sideways ? e.deltaX : e.deltaY;
		if (e.deltaMode === 1) d *= 32;
		else if (e.deltaMode === 2) d *= scroller.clientWidth;
		const from = raf ? target : scroller.scrollLeft;
		// at either end the wheel goes back to scrolling the page
		if ((d < 0 && from <= 0) || (d > 0 && from >= maxScroll() - 1)) return;
		e.preventDefault();
		if (sideways) {
			stopGlide();
			scroller.scrollLeft += d;
		} else {
			glide(from + d * 1.4);
		}
	}, { passive: false });

	// drag with the mouse or a pen (touch swipes scroll natively); a drag never opens the card it started on
	let drag = null, eatClick = false;
	scroller.addEventListener("pointerdown", (e) => {
		if (!wide.matches || e.pointerType === "touch" || e.button !== 0) return;
		stopGlide();
		drag = { id: e.pointerId, x: e.clientX, left: scroller.scrollLeft, moved: false, lx: e.clientX, lt: e.timeStamp, v: 0 };
	});
	scroller.addEventListener("pointermove", (e) => {
		if (!drag || e.pointerId !== drag.id) return;
		const dx = e.clientX - drag.x;
		if (!drag.moved && Math.abs(dx) > 6) {
			drag.moved = true;
			scroller.setPointerCapture(drag.id);
			scroller.classList.add("is-dragging");
		}
		if (!drag.moved) return;
		const dt = Math.max(1, e.timeStamp - drag.lt);
		drag.v = drag.v * 0.6 + ((e.clientX - drag.lx) / dt) * 0.4;
		drag.lx = e.clientX;
		drag.lt = e.timeStamp;
		pos = target = scroller.scrollLeft = drag.left - dx;
	});
	const endDrag = () => {
		if (!drag) return;
		if (drag.moved) {
			scroller.classList.remove("is-dragging");
			eatClick = true;
			setTimeout(() => { eatClick = false; }, 0);
			glide(scroller.scrollLeft - drag.v * 220); // a little momentum
		}
		drag = null;
	};
	scroller.addEventListener("pointerup", endDrag);
	scroller.addEventListener("pointercancel", endDrag);
	scroller.addEventListener("click", (e) => {
		if (eatClick) {
			e.preventDefault();
			e.stopPropagation();
			eatClick = false;
		}
	}, true);
	scroller.addEventListener("dragstart", (e) => e.preventDefault());

	// ---- keys: arrows walk the cards; with nothing focused they scroll the track ----
	const cards = () => track.querySelectorAll(".tl-card");
	function focusCard(i) {
		const list = cards();
		i = Math.max(0, Math.min(list.length - 1, i));
		list[i].focus({ preventScroll: true });
		show(i);
	}
	track.addEventListener("keydown", (e) => {
		const card = e.target.closest(".tl-card");
		if (!card) return;
		const i = Number(card.dataset.i);
		const go = { ArrowRight: i + 1, ArrowDown: i + 1, ArrowLeft: i - 1, ArrowUp: i - 1, Home: 0, End: versions.length - 1 }[e.key];
		if (go === undefined) return;
		e.preventDefault();
		focusCard(go);
	});
	track.addEventListener("focusin", (e) => {
		const card = e.target.closest(".tl-card");
		if (card && wide.matches) {
			// keep the browser's own jump from fighting the glide
			scroller.scrollLeft = pos;
			show(Number(card.dataset.i));
		}
	});
	document.addEventListener("keydown", (e) => {
		if (dialog.open || !wide.matches || e.altKey || e.ctrlKey || e.metaKey) return;
		const a = document.activeElement;
		if (a && a !== document.body && a !== scroller) return;
		const d = { ArrowRight: 1, ArrowLeft: -1 }[e.key];
		if (!d) return;
		e.preventDefault();
		glide((raf ? target : scroller.scrollLeft) + d * STEP * 2);
	});

	document.querySelector(".tl-jumps").addEventListener("click", (e) => {
		const b = e.target.closest("[data-jump]");
		if (!b) return;
		const i = { first: 0, here: hereIdx, last: versions.length - 1 }[b.dataset.jump];
		show(i);
		cards()[i].focus({ preventScroll: true });
	});

	// ---- the detail panel ----
	const $ = (id) => document.getElementById(id);
	function media(v) {
		const box = $("tl-d-media");
		box.replaceChildren();
		const pics = v.img ? [[v.img, v.alt || ""]].concat(v.shots || []) : [];
		if (!pics.length) {
			box.append(picture(v, false));
			return;
		}
		const main = el("img");
		main.width = 1600;
		main.height = 900;
		const pick = (k) => {
			main.src = src(pics[k][0], false);
			main.alt = pics[k][1];
			thumbs.querySelectorAll("button").forEach((b, j) => b.setAttribute("aria-pressed", j === k));
		};
		const thumbs = el("div", "tl-thumbs");
		if (pics.length > 1) {
			pics.forEach(([name, alt], k) => {
				const b = el("button");
				b.type = "button";
				b.setAttribute("aria-label", "Show: " + alt);
				const t = el("img");
				t.src = src(name, true);
				t.alt = "";
				t.width = 640;
				t.height = 360;
				b.append(t);
				b.addEventListener("click", () => pick(k));
				thumbs.append(b);
			});
		}
		box.append(main);
		pick(0);
		if (pics.length > 1) box.append(thumbs);
		if (v.clip) box.append(clip(v));
	}
	// a clip: its still, and a Play button that swaps in the gif (like the site's clips.js)
	function clip(v) {
		const fig = el("figure", "clip");
		const img = el("img");
		img.src = `/img/clips/${v.clip}.jpg`;
		img.alt = v.clipAlt || "";
		img.width = 640;
		img.height = 360;
		const btn = el("button", "clip-btn", "Play");
		btn.type = "button";
		btn.setAttribute("aria-label", "Play: " + (v.clipAlt || "clip"));
		btn.addEventListener("click", () => {
			const on = !fig.dataset.playing;
			fig.dataset.playing = on ? "1" : "";
			btn.textContent = on ? "Pause" : "Play";
			btn.setAttribute("aria-label", (on ? "Pause: " : "Play: ") + (v.clipAlt || "clip"));
			if (!on) {
				img.src = `/img/clips/${v.clip}.jpg`;
				return;
			}
			const gif = new Image();
			gif.onload = () => { if (fig.dataset.playing) img.src = gif.src; };
			gif.src = `/img/clips/${v.clip}.gif`;
		});
		fig.append(img, btn);
		return fig;
	}
	function link(href, text, cls) {
		const a = el("a", cls, text);
		a.href = href;
		if (href.startsWith("http")) a.rel = "noopener";
		return a;
	}
	function open(i, instant) {
		const v = versions[i];
		if (!v) return;
		current = i;
		dialog.classList.toggle("is-unbuilt", !shipped(v));
		$("tl-d-v").textContent = label(v);
		$("tl-d-status").textContent = i === hereIdx ? "You are here" : shipped(v) ? "Shipped" : STATUS[v.status];
		$("tl-d-date").textContent = v.date ? when(v) : "";
		$("tl-d-name").textContent = v.name;
		$("tl-d-head").textContent = v.headline;
		media(v);
		const items = shipped(v) ? v.added : v.plan;
		$("tl-d-list-h").textContent = shipped(v) ? "What it added" : "What's planned";
		$("tl-d-list").replaceChildren(...(items || []).map(([t, d]) => {
			const li = el("li");
			li.append(el("b", null, t + "."));
			if (d) li.append(" " + d);
			return li;
		}));
		const pics = !shipped(v) && v.img ? " The picture is from the current build, not this version." : "";
		const early = v.img && v.img.startsWith("early/") ? "Screenshots from v1.5 and v1.6." : "";
		$("tl-d-note").textContent = shipped(v) ? early : NOTE[v.status] + pics;
		const links = $("tl-d-links");
		links.replaceChildren();
		if (v.news) links.append(link(v.news, "Read the post", "btn"));
		if (shipped(v)) links.append(link("/releases/#" + slug(v), "Release notes"));
		if (v.github) links.append(link(GH + v.v, "GitHub release"));
		dialog.querySelectorAll(".tl-step").forEach((b) => {
			const n = versions[i + Number(b.dataset.step)];
			b.hidden = !n;
			if (n) b.textContent = b.dataset.step === "1" ? `${label(n)} ${n.name} ▸` : `◂ ${label(n)} ${n.name}`;
		});
		history.replaceState(null, "", "#" + slug(v));
		if (!dialog.open) dialog.showModal();
		dialog.scrollTop = 0;
		show(i, instant);
	}
	dialog.addEventListener("close", () => {
		history.replaceState(null, "", location.pathname + location.search);
		const card = cards()[current];
		if (card) card.focus({ preventScroll: true });
	});
	dialog.querySelector(".tl-close").addEventListener("click", () => dialog.close());
	dialog.addEventListener("click", (e) => { if (e.target === dialog) dialog.close(); }); // the backdrop
	dialog.querySelector(".tl-d-nav").addEventListener("click", (e) => {
		const b = e.target.closest(".tl-step");
		if (b) open(current + Number(b.dataset.step));
	});
	dialog.addEventListener("keydown", (e) => {
		if (e.target.closest("button, a") && (e.key === " " || e.key === "Enter")) return;
		const d = { ArrowRight: 1, ArrowLeft: -1 }[e.key];
		if (d && versions[current + d]) {
			e.preventDefault();
			open(current + d);
		}
	});
	track.addEventListener("click", (e) => {
		const card = e.target.closest(".tl-card");
		if (!card) return;
		e.preventDefault();
		open(Number(card.dataset.i));
	});

	wide.addEventListener("change", () => show(hereIdx, true));
	// a link to another card (#v1-10) from anywhere on the page
	addEventListener("hashchange", () => {
		const i = fromHash();
		if (i >= 0 && i !== current) open(i);
	});

	const fromHash = () => versions.findIndex((v) => "#" + slug(v) === location.hash);
	fetch("/roadmap/roadmap.json")
		.then((r) => {
			if (!r.ok) throw new Error(r.status);
			return r.json();
		})
		.then((data) => {
			versions = data.versions;
			hereIdx = Math.max(0, versions.findIndex((v) => v.v === data.here));
			build();
			const i = fromHash();
			// wide: the track opens on the marker; phones start at the top like any page
			if (wide.matches || i >= 0) show(i >= 0 ? i : hereIdx, true);
			parallax();
			if (i >= 0) open(i, true);
		})
		.catch(() => {
			$("tl-error").hidden = false;
			document.querySelector(".tl-bar").hidden = true;
		});
})();
