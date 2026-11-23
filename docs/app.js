// CSwapBar site interactions. Plain JS, no dependencies.
(() => {
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // ── Scroll reveal ─────────────────────────────────────────
  const reveals = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window && !reduceMotion) {
    const io = new IntersectionObserver((entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add("in");
          io.unobserve(entry.target);
        }
      }
    }, { threshold: 0.15, rootMargin: "0px 0px -40px 0px" });
    reveals.forEach((el) => io.observe(el));
  } else {
    reveals.forEach((el) => el.classList.add("in"));
  }

  // ── Card spotlight (border glow follows the pointer) ──────
  document.querySelectorAll(".card").forEach((card) => {
    card.addEventListener("pointermove", (e) => {
      const r = card.getBoundingClientRect();
      card.style.setProperty("--mx", `${e.clientX - r.left}px`);
      card.style.setProperty("--my", `${e.clientY - r.top}px`);
    });
  });

  // ── Tabs (layouts + first-launch steps) ───────────────────
  document.querySelectorAll(".tabs").forEach((tabs) => {
    const buttons = [...tabs.querySelectorAll("button")];
    const select = (btn) => {
      buttons.forEach((b) => b.setAttribute("aria-selected", String(b === btn)));
      if (btn.dataset.shot) {
        const img = document.getElementById("layout-shot");
        img.style.opacity = "0";
        img.style.transform = "translateY(8px)";
        const next = new Image();
        next.onload = () => {
          img.src = btn.dataset.shot;
          img.alt = btn.dataset.alt || "";
          requestAnimationFrame(() => { img.style.opacity = "1"; img.style.transform = "none"; });
        };
        next.src = btn.dataset.shot;
      }
      if (btn.dataset.panel) {
        buttons.forEach((b) => {
          const panel = document.getElementById(b.dataset.panel);
          if (!panel) return;
          const active = b === btn;
          panel.classList.toggle("is-active", active);
          panel.setAttribute("aria-hidden", String(!active));
          panel.querySelectorAll("button, a").forEach((el) => { el.tabIndex = active ? 0 : -1; });
        });
      }
    };
    buttons.forEach((btn, i) => {
      btn.addEventListener("click", () => select(btn));
      btn.addEventListener("keydown", (e) => {
        if (e.key !== "ArrowRight" && e.key !== "ArrowLeft") return;
        const next = buttons[(i + (e.key === "ArrowRight" ? 1 : buttons.length - 1)) % buttons.length];
        next.focus();
        select(next);
      });
    });
  });

  // ── Theme marquee (colors mirror ThemePalette.swift) ──────
  const themes = [
    ["Atelier Dark", "Warm charcoal", "#191817", "#252321", "#F0E8DE", "#D77D60", ["#89A77D", "#D4A66E", "#D96D63"]],
    ["macOS Widgets", "System colors", "#1C1C1E", "#2C2C2E", "#FFFFFF", "#409CFF", ["#30D158", "#FFD60A", "#FF453A"]],
    ["Sky", "Vivid gradient", "#18418E", "#2B4A85", "#FFFFFF", "#FFFFFF", ["#7EF0A0", "#FFE070", "#FF9C9C"]],
    ["Midnight", "Navy, indigo", "#0E1320", "#161D2D", "#E6EAF3", "#9B97FF", ["#5FCBA4", "#E8BC62", "#F26C68"]],
    ["Paper", "Crisp white", "#F5F6F8", "#FFFFFF", "#1C1F24", "#2F63E0", ["#24804F", "#8F6A0C", "#C0352D"]],
    ["Forest", "Pine, brass", "#121815", "#1A231E", "#E7EEE6", "#D0AE6E", ["#8CC07D", "#DDB765", "#DD6A61"]],
    ["Sunset", "Vivid gradient", "#7A2852", "#793855", "#FFFFFF", "#FFFFFF", ["#8CF0A8", "#FFE07A", "#FFA3A3"]],
    ["Espresso", "Roasted brown", "#1A1411", "#241C18", "#F3E9E1", "#D9A066", ["#8FB77F", "#E0B566", "#E06C62"]],
    ["Lavender", "Soft lilac", "#F3F1F8", "#FFFFFF", "#221E2E", "#6C4FD6", ["#2B8050", "#8A6410", "#BD3548"]],
    ["Ocean", "Deep sea", "#0C1719", "#132225", "#E3F0F1", "#4FD1C5", ["#6CD39A", "#E8C064", "#F07068"]],
    ["Aurora", "Vivid gradient", "#0E4442", "#334762", "#FFFFFF", "#FFFFFF", ["#7CF0B4", "#FFE27A", "#FF9AA0"]],
    ["Plum", "Dark plum", "#1A1219", "#241A23", "#F2E8F0", "#E58FB4", ["#7FC4A0", "#E5BC6A", "#F0727A"]],
    ["Sandstone", "Sunlit beige", "#F4EEE4", "#FCF8F2", "#2B241C", "#A4502A", ["#4E7A3F", "#8C6514", "#B0372E"]],
    ["Graphite", "Cool grey", "#161719", "#202124", "#ECEDEF", "#8EA7FF", ["#6CC08E", "#E0B65E", "#EB6A62"]],
    ["Ember", "Glowing orange", "#121110", "#1B1A18", "#F2EFEA", "#FF8A3D", ["#7DC383", "#E8BD5A", "#F2665C"]],
    ["Mint", "Fresh mint", "#EFF6F2", "#FFFFFF", "#18241D", "#1F7A57", ["#2C7D45", "#8A6611", "#BD3A33"]],
    ["High Contrast", "Maximum legibility", "#000000", "#0D0D0D", "#FFFFFF", "#5CB8FF", ["#5EE38A", "#FFD24D", "#FF6B6B"]],
  ];
  const track = document.getElementById("theme-track");
  if (track) {
    const widths = ["42%", "71%", "93%"];
    const make = ([name, tag, bg, surface, text, accent, usage]) => {
      const el = document.createElement("div");
      el.className = "swatch";
      el.style.background = bg;
      el.style.color = text;
      el.style.setProperty("--track", text === "#FFFFFF" || text.startsWith("#E") || text.startsWith("#F") ? "rgba(255,255,255,.14)" : "rgba(0,0,0,.08)");
      el.innerHTML = `
        <div class="bars" style="background:${surface};box-shadow:inset 0 0 0 1px ${accent}55">
          ${usage.map((c, i) => `<div class="bar"><i style="width:${widths[i]};background:${c}"></i></div>`).join("")}
        </div>
        <b>${name}</b><small>${tag}</small>`;
      return el;
    };
    // Two copies for a seamless loop.
    [...themes, ...themes].forEach((t) => track.appendChild(make(t)));
  }

  // ── Privacy Mode demo ─────────────────────────────────────
  const toggle = document.getElementById("privacy-toggle");
  const demo = document.getElementById("privacy-demo");
  const applyPrivacy = (on) => {
    demo.classList.toggle("masked", on);
    demo.querySelectorAll("[data-real]").forEach((el) => {
      el.textContent = on ? el.dataset.masked : el.dataset.real;
      el.classList.remove("swap-in");
      void el.offsetWidth; // restart animation
      el.classList.add("swap-in");
    });
  };
  if (toggle && demo) {
    toggle.addEventListener("change", () => applyPrivacy(toggle.checked));
    // ⇧⌘P (or Ctrl+Shift+P) toggles it, like the app.
    document.addEventListener("keydown", (e) => {
      if (e.shiftKey && (e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "p") {
        e.preventDefault();
        toggle.checked = !toggle.checked;
        applyPrivacy(toggle.checked);
      }
    });
  }

  // ── Copy buttons ──────────────────────────────────────────
  document.querySelectorAll(".copy").forEach((btn) => {
    btn.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(btn.dataset.copy);
        btn.textContent = "Copied";
        btn.classList.add("done");
        setTimeout(() => { btn.textContent = "Copy"; btn.classList.remove("done"); }, 1600);
      } catch {
        btn.textContent = "Select & copy";
      }
    });
  });
})();
