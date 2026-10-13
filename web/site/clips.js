(() => {
	const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
	const set = (fig, on) => {
		const img = fig.querySelector("img");
		const btn = fig.querySelector(".clip-btn");
		fig.dataset.playing = on ? "1" : "";
		btn.textContent = on ? "Pause" : "Play";
		btn.setAttribute("aria-label", (on ? "Pause: " : "Play: ") + img.dataset.name);
		if (!on) {
			img.src = img.dataset.poster;
			return;
		}
		const gif = new Image();
		gif.onload = () => { if (fig.dataset.playing) img.src = gif.src; };
		gif.src = img.dataset.gif;
	};
	const seen = new IntersectionObserver((list) => {
		for (const e of list) {
			if (e.isIntersecting) {
				seen.unobserve(e.target);
				set(e.target, true);
			}
		}
	}, { rootMargin: "200px" });
	for (const fig of document.querySelectorAll("figure.clip")) {
		const img = fig.querySelector("img");
		img.dataset.poster = img.getAttribute("src");
		const btn = document.createElement("button");
		btn.type = "button";
		btn.className = "clip-btn";
		btn.addEventListener("click", () => set(fig, !fig.dataset.playing));
		fig.append(btn);
		set(fig, false);
		if (!still) seen.observe(fig);
	}
})();
