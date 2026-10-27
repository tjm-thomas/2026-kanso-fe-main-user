// Kanso: small, quiet interactions.

(function () {
  const root = document.documentElement;

  // Theme: remembered per browser, falls back to system preference.
  try {
    const saved = localStorage.getItem("kanso-theme");
    if (saved) root.dataset.theme = saved;
  } catch (_) {}

  document.querySelector(".theme-toggle").addEventListener("click", () => {
    const isDark = root.dataset.theme
      ? root.dataset.theme === "dark"
      : matchMedia("(prefers-color-scheme: dark)").matches;
    root.dataset.theme = isDark ? "light" : "dark";
    try { localStorage.setItem("kanso-theme", root.dataset.theme); } catch (_) {}
  });

  // Tokyo clock (home page only, like the board and the form below).
  const clock = document.getElementById("clock");
  if (clock) {
    const fmt = new Intl.DateTimeFormat("en-GB", {
      timeZone: "Asia/Tokyo", hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false,
    });
    const tick = () => { clock.textContent = fmt.format(new Date()); };
    tick();
    setInterval(tick, 1000);
  }

  // Status board: gently jitter latencies so the board feels alive.
  const cells = document.querySelectorAll("[data-latency]");
  const updated = document.getElementById("board-updated");
  if (updated) {
    let last = Date.now();
    setInterval(() => {
      cells.forEach((cell) => {
        const base = Number(cell.dataset.latency);
        const next = Math.max(1, Math.round(base + (Math.random() - 0.5) * base * 0.2));
        cell.textContent = next + " ms";
      });
      last = Date.now();
    }, 5000);
    setInterval(() => {
      const s = Math.round((Date.now() - last) / 1000);
      updated.textContent = s < 2 ? "just now" : s + "s ago";
    }, 1000);
  }

  // Version: written at build time to /version.txt.
  const versions = document.querySelectorAll("#version, [data-version]");
  const showVersion = (v) => versions.forEach((el) => { el.textContent = v; });
  fetch("/version.txt", { cache: "no-store" })
    .then((r) => { if (!r.ok) throw new Error(r.status); return r.text(); })
    .then((t) => showVersion(t.trim() || "dev"))
    .catch(() => showVersion("dev"));

  // Access form: client-side only.
  const form = document.querySelector(".join-form");
  const msg = document.querySelector(".form-msg");
  form?.addEventListener("submit", (e) => {
    e.preventDefault();
    const email = form.email.value.trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      msg.textContent = "Please enter a valid email address.";
      msg.classList.add("error");
      return;
    }
    msg.classList.remove("error");
    msg.textContent = "ありがとう. We'll be in touch, quietly.";
    form.reset();
  });

  // Reveal sections on scroll.
  const targets = document.querySelectorAll(".section-head, .principle, .stop, .board, .join-inner");
  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("in");
          io.unobserve(entry.target);
        }
      });
    }, { threshold: 0.15 });
    targets.forEach((t) => { t.classList.add("reveal"); io.observe(t); });
  }
})();
