// CSwapBar site interactions. Plain JS, no dependencies.
(() => {
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const $ = (s, root = document) => root.querySelector(s);
  const $$ = (s, root = document) => [...root.querySelectorAll(s)];

  /** Runs `fn(el)` once when `el` scrolls into view. */
  const onceVisible = (el, fn, threshold = 0.25) => {
    if (!el) return;
    if (!("IntersectionObserver" in window)) return fn(el);
    const io = new IntersectionObserver((entries) => {
      entries.forEach((e) => { if (e.isIntersecting) { io.unobserve(e.target); fn(e.target); } });
    }, { threshold });
    io.observe(el);
  };

  /** Calls `fn(visible)` whenever `el` enters or leaves the viewport. */
  const watchVisible = (el, fn, threshold = 0.3) => {
    if (!el || !("IntersectionObserver" in window)) return;
    new IntersectionObserver((entries) => entries.forEach((e) => fn(e.isIntersecting)), { threshold }).observe(el);
  };

  // ── Headline: split into words that rise in one by one ────
  $$(".split-words").forEach((h) => {
    let i = 0;
    const wrap = (node) => {
      [...node.childNodes].forEach((child) => {
        if (child.nodeType === Node.TEXT_NODE) {
          const frag = document.createDocumentFragment();
          child.textContent.split(/(\s+)/).forEach((part) => {
            if (!part) return;
            if (/^\s+$/.test(part)) { frag.appendChild(document.createTextNode(part)); return; }
            const span = document.createElement("span");
            span.className = "w";
            span.style.setProperty("--i", i++);
            span.textContent = part;
            frag.appendChild(span);
          });
          child.replaceWith(frag);
        } else if (child.nodeType === Node.ELEMENT_NODE && child.tagName !== "BR") {
          wrap(child);
        }
      });
    };
    wrap(h);
    // Give the accent words one shared gradient: each word shows its own slice of it.
    const fit = () => $$(".accent-text", h).forEach((accent) => {
      const box = accent.getBoundingClientRect();
      $$(".w", accent).forEach((word) => {
        const r = word.getBoundingClientRect();
        word.style.backgroundSize = `${box.width}px 100%`;
        word.style.backgroundPosition = `${box.left - r.left}px 0`;
      });
    });
    fit();
    addEventListener("resize", fit);
    if (document.fonts) document.fonts.ready.then(fit);
    // Animate in on the next frames; the timer makes sure the words always appear.
    requestAnimationFrame(() => requestAnimationFrame(() => h.classList.add("in")));
    setTimeout(() => h.classList.add("in"), 400);
  });

  // ── Scroll reveal ─────────────────────────────────────────
  if (reduceMotion) {
    $$(".reveal").forEach((el) => el.classList.add("in"));
  } else {
    $$(".reveal").forEach((el) => onceVisible(el, (t) => t.classList.add("in"), 0.15));
  }

  // ── Scroll progress + nav state ───────────────────────────
  const progress = $(".progress");
  const onScroll = () => {
    const max = document.documentElement.scrollHeight - innerHeight;
    if (progress) progress.style.setProperty("--progress", max > 0 ? (scrollY / max).toFixed(4) : 0);
  };
  addEventListener("scroll", onScroll, { passive: true });
  addEventListener("resize", onScroll);
  onScroll();

  const navLinks = $$(".nav nav a");
  navLinks.forEach((link) => {
    const section = document.querySelector(link.getAttribute("href"));
    watchVisible(section, (visible) => {
      if (visible) navLinks.forEach((l) => l.classList.toggle("active", l === link));
    }, 0.35);
  });

  // ── Hero: device tilt with the cursor ─────────────────────
  const device = $("#device");
  if (device && !reduceMotion && matchMedia("(pointer: fine)").matches) {
    const wrap = device.parentElement;
    wrap.addEventListener("pointermove", (e) => {
      const r = wrap.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width - 0.5;
      const y = (e.clientY - r.top) / r.height - 0.5;
      device.style.setProperty("--ry", `${(x * 7).toFixed(2)}deg`);
      device.style.setProperty("--rx", `${(-y * 5).toFixed(2)}deg`);
    });
    wrap.addEventListener("pointerleave", () => {
      device.style.setProperty("--ry", "0deg");
      device.style.setProperty("--rx", "0deg");
    });
  }

  // ── Live menu bar: usage drifts around the active account's value, clock ticks ──
  const pct = $("#mb-pct");
  const clock = $("#mb-clock");
  const islandPct = $(".isl-pct");
  const islandRing = $(".isl-ring");
  let base = 42;
  let usage = 42;
  const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const showUsage = () => {
    if (pct) pct.textContent = `${usage}%`;
    if (islandPct) islandPct.textContent = `${usage}%`;
    if (islandRing) islandRing.style.setProperty("--p", usage);
  };
  const setBase = (value) => { base = value; usage = value; showUsage(); };
  const tick = () => {
    const now = new Date();
    const time = `${days[now.getDay()]} ${now.getHours() % 12 || 12}:${String(now.getMinutes()).padStart(2, "0")}`;
    if (clock) clock.textContent = time;
    $$(".isl-clock").forEach((c) => { c.textContent = time; });
    if (!reduceMotion) {
      usage = Math.max(base - 3, Math.min(base + 3, usage + (Math.random() < 0.55 ? 1 : -1)));
      showUsage();
    }
  };
  tick();
  setInterval(tick, 2600);

  // ── Hero demo: open the popover, switch accounts, open Settings ──
  const pop = $("#demo-popover");
  const screenEl = pop && pop.closest(".screen");
  if (pop && screenEl && !reduceMotion) {
    pop.classList.remove("open");   // without JS it stays open as a still
    const cursor = $("#demo-cursor");
    const ripple = $("#demo-click");
    const status = $("#demo-status");
    const gear = $("#demo-gear");
    const settings = $("#demo-settings");
    const cards = $$(".dp-card", pop);
    const wait = (ms) => new Promise((r) => setTimeout(r, ms));
    const centerOf = (el) => {
      const s = screenEl.getBoundingClientRect();
      const r = el.getBoundingClientRect();
      return [r.left - s.left + r.width / 2, r.top - s.top + r.height / 2];
    };
    const moveTo = async (el, dx = 0, dy = 0) => {
      const [x, y] = centerOf(el);
      cursor.style.left = `${x + dx}px`;
      cursor.style.top = `${y + dy}px`;
      await wait(950);
    };
    const tap = async (el) => {
      const [x, y] = centerOf(el);
      ripple.style.left = `${x}px`;
      ripple.style.top = `${y}px`;
      ripple.classList.remove("go");
      void ripple.offsetWidth;
      ripple.classList.add("go");
      el.classList.add("pressed");
      await wait(180);
      el.classList.remove("pressed");
    };
    const setActive = (index) => {
      cards.forEach((card, j) => {
        card.classList.toggle("active", j === index);
        const current = $(".dp-badge, .dp-switch", card);
        let next;
        if (j === index) {
          next = document.createElement("span");
          next.className = "dp-badge";
          next.textContent = "Active";
        } else {
          next = document.createElement("button");
          next.type = "button";
          next.tabIndex = -1;
          next.className = "dp-switch";
          next.dataset.switch = String(j);
          next.textContent = "Switch";
        }
        current.replaceWith(next);
      });
    };
    let visible = false;
    let running = false;
    const play = async () => {
      if (running) return;
      running = true;
      while (visible) {
        setActive(0);
        setBase(42);
        pop.classList.remove("open");
        settings.classList.remove("open");
        cursor.style.left = "56%";
        cursor.style.top = "62%";
        cursor.classList.add("on");
        await wait(800);

        // 1. Click the menu bar item: the popover drops open.
        await moveTo(status, 6, 8);
        await tap(status);
        pop.classList.add("open");
        await wait(1400);

        // 2. Switch to Work: spinner, then a check, then the highlight moves.
        const target = $('[data-switch="1"]', pop);
        await moveTo(target, 8, 8);
        await tap(target);
        target.classList.add("busy");
        target.textContent = "Switching…";
        await wait(1100);
        target.classList.remove("busy");
        target.classList.add("done");
        target.textContent = "✓ Switched";
        setBase(18);
        await wait(650);
        setActive(1);
        await wait(1500);

        // 3. Open Settings from the gear.
        await moveTo(gear, 6, 8);
        await tap(gear);
        gear.classList.add("pressed");
        pop.classList.remove("open");
        await wait(260);
        settings.classList.add("open");
        gear.classList.remove("pressed");
        await moveTo(settings, 140, 70);
        await wait(1900);

        // 4. Close and start over.
        settings.classList.remove("open");
        cursor.classList.remove("on");
        await wait(1300);
      }
      running = false;
    };
    watchVisible(screenEl, (v) => { visible = v; if (v) play(); }, 0.35);
  }

  // ── Stats count up ────────────────────────────────────────
  $$("[data-count]").forEach((el) => {
    const target = Number(el.dataset.count);
    const prefix = el.dataset.prefix || "";
    const suffix = el.dataset.suffix || "";
    if (reduceMotion) return;
    el.innerHTML = `${prefix}0${suffix}`;
    onceVisible(el, () => {
      const start = performance.now();
      const step = (t) => {
        const k = Math.min(1, (t - start) / 1100);
        const eased = 1 - Math.pow(1 - k, 3);
        el.innerHTML = `${prefix}${Math.round(target * eased)}${suffix}`;
        if (k < 1) requestAnimationFrame(step);
      };
      requestAnimationFrame(step);
    }, 0.6);
  });

  // ── Bento: cursor spotlight ───────────────────────────────
  $$(".tile").forEach((tile) => {
    tile.addEventListener("pointermove", (e) => {
      const r = tile.getBoundingClientRect();
      tile.style.setProperty("--mx", `${e.clientX - r.left}px`);
      tile.style.setProperty("--my", `${e.clientY - r.top}px`);
    });
  });

  // ── Bento: notification banner cycling ────────────────────
  const toast = $("#toast");
  if (toast) {
    const messages = [
      ["Usage threshold reached", "Work has reached 95% 5-hour usage."],
      ["Usage limit reached", "Team has hit its 5-hour limit. Resets in 2h 49m."],
      ["Account switched", "Claude Code is now using Personal."],
      ["Login needed", "Lab needs a new login before CSwap can use it."],
    ];
    let n = 0;
    const show = () => {
      const [title, body] = messages[n++ % messages.length];
      $("#toast-title").textContent = title;
      $("#toast-body").textContent = body;
      toast.classList.add("show");
      setTimeout(() => toast.classList.remove("show"), 3000);
    };
    if (reduceMotion) {
      toast.classList.add("show");
    } else {
      let timer;
      watchVisible(toast.closest(".tile"), (visible) => {
        clearInterval(timer);
        if (visible) { show(); timer = setInterval(show, 4000); }
      });
    }
  }

  // ── Bento: keycaps press ⌃⌥⌘C ─────────────────────────────
  const keys = $$(".key");
  if (keys.length && !reduceMotion) {
    let timer;
    const play = () => {
      keys.forEach((k, i) => setTimeout(() => k.classList.add("down"), i * 160));
      setTimeout(() => keys.forEach((k) => k.classList.remove("down")), keys.length * 160 + 700);
    };
    watchVisible(keys[0].closest(".tile"), (visible) => {
      clearInterval(timer);
      if (visible) { play(); timer = setInterval(play, 3200); }
    });
  }

  // ── Bento: sparkline draws once visible ───────────────────
  $$(".tile").forEach((tile) => { if ($(".spark", tile)) onceVisible(tile, (t) => t.classList.add("in"), 0.4); });

  // ── Bento: theme swatches shifting ────────────────────────
  const swatches = $$(".swatches i");
  if (swatches.length) {
    const palettes = [
      ["#000000", "#2997ff", "#5ee38a", "#ffd24d", "#ff6b6b", "#141414", "#ffffff", "#1f1f21"],
      ["#18418e", "#7ef0a0", "#ffe070", "#ff9c9c", "#2b4a85", "#ffffff", "#0e2a5c", "#9fb6e0"],
      ["#191817", "#d77d60", "#89a77d", "#d4a66e", "#d96d63", "#252321", "#f0e8de", "#3c3732"],
      ["#0e1320", "#9b97ff", "#5fcba4", "#e8bc62", "#f26c68", "#161d2d", "#e6eaf3", "#2a3550"],
      ["#f5f6f8", "#2f63e0", "#24804f", "#8f6a0c", "#c0352d", "#ffffff", "#1c1f24", "#d6dae2"],
    ];
    let p = 0;
    const paint = () => {
      const palette = palettes[p++ % palettes.length];
      swatches.forEach((s, i) => setTimeout(() => s.style.setProperty("--c", palette[i]), i * 70));
    };
    paint();
    if (!reduceMotion) {
      let timer;
      watchVisible(swatches[0].closest(".tile"), (visible) => {
        clearInterval(timer);
        if (visible) timer = setInterval(paint, 2200);
      });
    }
  }

  // ── Bento: update downloads, then each check passes ───────
  const update = $(".update-demo");
  if (update) {
    const bar = $(".update-bar i", update);
    const status = $(".update-status", update);
    const checks = $$(".update-checks li", update);
    const run = () => {
      checks.forEach((c) => c.classList.remove("ok"));
      status.textContent = "Downloading…";
      let u = 0;
      bar.style.setProperty("--u", "0%");
      const dl = setInterval(() => {
        u = Math.min(100, u + 7 + Math.random() * 9);
        bar.style.setProperty("--u", `${u}%`);
        if (u >= 100) {
          clearInterval(dl);
          status.textContent = "Verifying…";
          checks.forEach((c, i) => setTimeout(() => c.classList.add("ok"), 350 + i * 380));
          setTimeout(() => { status.textContent = "Ready · Install and Restart"; }, 350 + checks.length * 380);
        }
      }, 140);
    };
    if (reduceMotion) {
      bar.style.setProperty("--u", "100%");
      checks.forEach((c) => c.classList.add("ok"));
      status.textContent = "Ready";
    } else {
      let timer;
      watchVisible(update.closest(".tile"), (visible) => {
        clearInterval(timer);
        if (visible) { run(); timer = setInterval(run, 6500); }
      });
    }
  }

  // ── Usage Island replica ──────────────────────────────────
  const island = $("#island-demo");
  if (island) {
    let touched = false;
    const set = (open) => {
      island.classList.toggle("open", open);
      island.setAttribute("aria-expanded", String(open));
    };
    island.addEventListener("pointerenter", (e) => { if (e.pointerType === "mouse") { touched = true; set(true); } });
    island.addEventListener("pointerleave", (e) => { if (e.pointerType === "mouse") set(false); });
    island.addEventListener("click", (e) => {
      if (e.pointerType === "mouse") return;   // hover already handles mice
      touched = true;
      set(!island.classList.contains("open"));
    });
    island.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") { e.preventDefault(); touched = true; set(!island.classList.contains("open")); }
      if (e.key === "Escape") set(false);
    });
    // Plays itself once when it comes into view, until you try it.
    if (!reduceMotion) {
      onceVisible(island.parentElement, () => {
        setTimeout(() => { if (!touched) set(true); }, 900);
        setTimeout(() => { if (!touched) set(false); }, 4200);
      }, 0.5);
    }
  }

  // ── Tabs (layouts autoplay + first-launch steps) ──────────
  $$(".tabs").forEach((tabs) => {
    const buttons = $$("button", tabs);
    const select = (btn) => {
      buttons.forEach((b) => b.setAttribute("aria-selected", String(b === btn)));
      if (btn.dataset.shot) {
        const img = $("#layout-shot");
        img.style.opacity = "0";
        img.style.transform = "translateY(10px) scale(.98)";
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
    let userPicked = false;
    buttons.forEach((btn, i) => {
      btn.addEventListener("click", () => { userPicked = true; select(btn); });
      btn.addEventListener("keydown", (e) => {
        if (e.key !== "ArrowRight" && e.key !== "ArrowLeft") return;
        const next = buttons[(i + (e.key === "ArrowRight" ? 1 : buttons.length - 1)) % buttons.length];
        userPicked = true;
        next.focus();
        select(next);
      });
    });
    // Layout tabs cycle on their own while in view, until you pick one.
    if (buttons[0] && buttons[0].dataset.shot && !reduceMotion) {
      let timer;
      watchVisible(tabs.closest("section"), (visible) => {
        clearInterval(timer);
        if (!visible) return;
        timer = setInterval(() => {
          if (userPicked) return clearInterval(timer);
          const current = buttons.findIndex((b) => b.getAttribute("aria-selected") === "true");
          select(buttons[(current + 1) % buttons.length]);
        }, 3200);
      });
    }
  });

  // ── Theme marquee (colors mirror ThemePalette.swift) ──────
  const themes = [
    ["High Contrast", "Maximum legibility", "#000000", "#141414", "#FFFFFF", "#2997FF", ["#5EE38A", "#FFD24D", "#FF6B6B"]],
    ["Your theme", "Five colors, yours", "#12151C", "#1D212B", "#ECEEF3", "#7AA2F7", ["#89A77D", "#D4A66E", "#D96D63"]],
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
  ];
  const track = $("#theme-track");
  if (track) {
    const widths = ["42%", "71%", "93%"];
    const make = ([name, tag, bg, surface, text, accent, usageColors]) => {
      const el = document.createElement("div");
      el.className = "swatch";
      el.style.background = bg;
      el.style.color = text;
      el.style.setProperty("--track", text === "#FFFFFF" || text.startsWith("#E") || text.startsWith("#F") ? "rgba(255,255,255,.14)" : "rgba(0,0,0,.08)");
      el.innerHTML = `
        <div class="bars" style="background:${surface};box-shadow:inset 3px 0 0 ${accent}">
          ${usageColors.map((c, i) => `<div class="bar"><i style="width:${widths[i]};background:${c}"></i></div>`).join("")}
        </div>
        <b>${name}</b><small>${tag}</small>`;
      return el;
    };
    [...themes, ...themes].forEach((t) => track.appendChild(make(t)));
  }

  // ── Privacy Mode demo ─────────────────────────────────────
  const toggle = $("#privacy-toggle");
  const demo = $("#privacy-demo");
  const applyPrivacy = (on) => {
    demo.classList.toggle("masked", on);
    $$("[data-real]", demo).forEach((el) => {
      el.textContent = on ? el.dataset.masked : el.dataset.real;
      el.classList.remove("swap-in");
      void el.offsetWidth; // restart animation
      el.classList.add("swap-in");
    });
  };
  if (toggle && demo) {
    let touched = false;
    toggle.addEventListener("change", () => { touched = true; applyPrivacy(toggle.checked); });
    // ⌃⌥⌘P (like the app's global shortcut) or ⇧⌘P / Ctrl+Shift+P toggles it.
    document.addEventListener("keydown", (e) => {
      const key = e.code === "KeyP" || e.key.toLowerCase() === "p";
      const global = e.ctrlKey && e.altKey && e.metaKey;
      const popover = e.shiftKey && (e.metaKey || e.ctrlKey);
      if (key && (global || popover)) {
        e.preventDefault();
        touched = true;
        toggle.checked = !toggle.checked;
        applyPrivacy(toggle.checked);
      }
    });
    // Shows itself once: on, then off again, unless you've tried it.
    if (!reduceMotion) {
      onceVisible(demo, () => {
        setTimeout(() => { if (!touched) { toggle.checked = true; applyPrivacy(true); } }, 1000);
        setTimeout(() => { if (!touched) { toggle.checked = false; applyPrivacy(false); } }, 3800);
      }, 0.6);
    }
  }

  // ── Copy buttons ──────────────────────────────────────────
  $$(".copy").forEach((btn) => {
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
