// Prevent browser scroll-restoration flicker on refresh
if ('scrollRestoration' in history) {
  history.scrollRestoration = 'manual';
}

// Enable smooth scrolling only after initial page render to prevent reload animation flicker
window.addEventListener('load', () => {
  document.documentElement.style.scrollBehavior = 'smooth';
});

// ==========================================================
// Caelaris Linux — Apple Interactive Scripts
// ==========================================================

document.addEventListener('DOMContentLoaded', () => {
  initThemeToggle();
  initMobileMenu();
  initDesktopSwitcher();
  initArchSwitcher();
  initFaqAccordion();
  initCopyButtons();
  initInstallGuideTabs();
  initServerTabs();
  initSpotlightEffect();
  initScrollAnimations();
});

// 1. Apple Dark / Light Mode Switcher with Persistence
function initThemeToggle() {
  const toggleBtn = document.getElementById('theme-toggle');
  if (!toggleBtn) return;

  function getPreferredTheme() {
    const saved = localStorage.getItem('caelaris-theme');
    if (saved) return saved;
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  function applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('caelaris-theme', theme);
  }

  // Set initial theme
  const currentTheme = getPreferredTheme();
  applyTheme(currentTheme);

  // Toggle on click
  toggleBtn.addEventListener('click', () => {
    const active = document.documentElement.getAttribute('data-theme') || 'dark';
    const next = active === 'dark' ? 'light' : 'dark';
    applyTheme(next);
  });

  // Listen to OS theme changes if user has no saved preference
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
    if (!localStorage.getItem('caelaris-theme')) {
      applyTheme(e.matches ? 'dark' : 'light');
    }
  });

  // Keyboard shortcut: Press "d" to toggle theme (when not in an input)
  window.addEventListener('keydown', (e) => {
    if (e.key === 'd' || e.key === 'D') {
      const tag = document.activeElement ? document.activeElement.tagName.toLowerCase() : '';
      if (tag !== 'input' && tag !== 'textarea') {
        const active = document.documentElement.getAttribute('data-theme') || 'dark';
        applyTheme(active === 'dark' ? 'light' : 'dark');
      }
    }
  });
}

// 2. Interactive Desktop Showcase Switcher (KDE vs GNOME)
function initDesktopSwitcher() {
  const tabs = document.querySelectorAll('.de-tab[data-de]');
  const previews = document.querySelectorAll('.desktop-preview');

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const targetDe = tab.getAttribute('data-de');
      if (!targetDe) return;

      tabs.forEach(t => t.classList.remove('active'));
      previews.forEach(p => p.classList.remove('active'));

      tab.classList.add('active');
      const activePreview = document.getElementById(`preview-${targetDe}`);
      if (activePreview) {
        activePreview.classList.add('active', 'tab-switched');
      }
    });
  });
}

// 3. Installation Guide Tabs
function initInstallGuideTabs() {
  const guideTabs = document.querySelectorAll('.guide-tab');
  const guidePanels = document.querySelectorAll('.guide-panel');

  guideTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const target = tab.getAttribute('data-guide');

      guideTabs.forEach(t => t.classList.remove('active'));
      guidePanels.forEach(p => p.classList.remove('active'));

      tab.classList.add('active');
      const activePanel = document.getElementById(`guide-${target}`);
      if (activePanel) {
        activePanel.classList.add('active', 'tab-switched');
      }
    });
  });
}

// 4. FAQ Accordion (Smooth Expand / Collapse)
function initFaqAccordion() {
  const faqItems = document.querySelectorAll('.faq-item');

  faqItems.forEach(item => {
    const question = item.querySelector('.faq-question');
    if (!question) return;

    question.addEventListener('click', () => {
      const isOpen = item.classList.contains('open');

      // Close all other items
      faqItems.forEach(i => i.classList.remove('open'));

      if (!isOpen) {
        item.classList.add('open');
      }
    });
  });
}

// 5. One-Click Copy Buttons with Haptic-Like Feedback
function initCopyButtons() {
  const copyButtons = document.querySelectorAll('.copy-trigger');

  copyButtons.forEach(btn => {
    btn.addEventListener('click', async () => {
      const textToCopy = btn.getAttribute('data-copy');
      if (!textToCopy) return;

      try {
        await navigator.clipboard.writeText(textToCopy);
        const originalText = btn.innerHTML;
        btn.innerHTML = `<span>✔ Copied!</span>`;
        btn.style.color = 'var(--status-green)';

        setTimeout(() => {
          btn.innerHTML = originalText;
          btn.style.color = '';
        }, 2000);
      } catch (err) {
        console.error('Failed to copy: ', err);
      }
    });
  });
}

// 6. Open / Close Modal Helper for Windows Split ISO Reassembly
function openCombineModal() {
  const modal = document.getElementById('combine-modal');
  if (modal) {
    modal.style.display = 'flex';
  }
}

function closeCombineModal() {
  const modal = document.getElementById('combine-modal');
  if (modal) {
    modal.style.display = 'none';
  }
}

// Close modals when clicking outside
window.addEventListener('click', (e) => {
  const combineModal = document.getElementById('combine-modal');
  if (e.target === combineModal) {
    closeCombineModal();
  }
});

// 7. Architecture Switcher (x86_64, Pi, ARM64 PC, Server, Cloud)
function initArchSwitcher() {
  const tabs = document.querySelectorAll('.arch-tab');
  const panels = document.querySelectorAll('.arch-panel');

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const arch = tab.getAttribute('data-arch');

      tabs.forEach(t => t.classList.remove('active'));
      panels.forEach(p => p.classList.remove('active'));

      tab.classList.add('active');
      const targetPanel = document.getElementById(`arch-panel-${arch}`);
      if (targetPanel) {
        targetPanel.classList.add('active', 'tab-switched');
      }
    });
  });
}

// 8. Server & Headless Installation Tabs
function initServerTabs() {
  const serverTabs = document.querySelectorAll('.server-tab');
  const serverPanels = document.querySelectorAll('.server-panel');

  serverTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const target = tab.getAttribute('data-server');

      serverTabs.forEach(t => t.classList.remove('active'));
      serverPanels.forEach(p => p.classList.remove('active'));

      tab.classList.add('active');
      const activePanel = document.getElementById(`server-${target}`);
      if (activePanel) {
        activePanel.classList.add('active', 'tab-switched');
      }
    });
  });
}

// 9. Mobile Navigation Drawer Toggle
function initMobileMenu() {
  const toggle = document.getElementById('nav-toggle');
  const navLinks = document.getElementById('nav-links');
  if (!toggle || !navLinks) return;

  toggle.addEventListener('click', (e) => {
    e.stopPropagation();
    toggle.classList.toggle('open');
    navLinks.classList.toggle('open');
  });

  navLinks.querySelectorAll('.nav-link').forEach(link => {
    link.addEventListener('click', () => {
      toggle.classList.remove('open');
      navLinks.classList.remove('open');
    });
  });

  document.addEventListener('click', (e) => {
    if (!navLinks.contains(e.target) && !toggle.contains(e.target)) {
      toggle.classList.remove('open');
      navLinks.classList.remove('open');
    }
  });
}

// 10. Apple Glassmorphic Interactive Card Spotlight
function initSpotlightEffect() {
  const cards = document.querySelectorAll('.feature-card, .download-tile');

  cards.forEach(card => {
    card.addEventListener('mousemove', (e) => {
      const rect = card.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      card.style.setProperty('--spotlight-x', `${x}px`);
      card.style.setProperty('--spotlight-y', `${y}px`);
    });
  });
}

// 11. Subtle Scroll Reveal Animations
function initScrollAnimations() {
  const elements = document.querySelectorAll('.feature-card, .download-card-main, .comparison-table-wrapper, .section-header');

  elements.forEach(el => {
    el.classList.add('reveal-on-scroll');
  });

  if (!('IntersectionObserver' in window)) {
    elements.forEach(el => el.classList.add('is-visible'));
    return;
  }

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('is-visible');
        observer.unobserve(entry.target);
      }
    });
  }, {
    threshold: 0.12,
    rootMargin: '0px 0px -40px 0px'
  });

  elements.forEach(el => observer.observe(el));
}
