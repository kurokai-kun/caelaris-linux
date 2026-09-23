// ==========================================================
// Caelaris Linux - Interactive Scripts
// ==========================================================

document.addEventListener('DOMContentLoaded', () => {
  initMobileMenu();
  initDesktopSwitcher();
  initArchSwitcher();
  initFaqAccordion();
  initCopyButtons();
  initInstallGuideTabs();
  initServerTabs();
});

// 1. Interactive Desktop Showcase Switcher (KDE vs GNOME)
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
        activePreview.classList.add('active');
      }
    });
  });
}

// 2. Installation Guide Tabs
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
        activePanel.classList.add('active');
      }
    });
  });
}

// 3. FAQ Accordion
function initFaqAccordion() {
  const faqItems = document.querySelectorAll('.faq-item');

  faqItems.forEach(item => {
    const question = item.querySelector('.faq-question');
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

// 4. One-Click Copy Buttons
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
        btn.style.color = '#34d399';

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

// 5. Open Modal Helper for Windows Reassembly
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

// 6. Open Modal Helper for Cloud ISO Mirrors
function openCloudModal() {
  const modal = document.getElementById('cloud-modal');
  if (modal) {
    modal.style.display = 'flex';
  }
}

function closeCloudModal() {
  const modal = document.getElementById('cloud-modal');
  if (modal) {
    modal.style.display = 'none';
  }
}

// Close modals when clicking outside of them
window.addEventListener('click', (e) => {
  const combineModal = document.getElementById('combine-modal');
  if (e.target === combineModal) {
    closeCombineModal();
  }
  const cloudModal = document.getElementById('cloud-modal');
  if (e.target === cloudModal) {
    closeCloudModal();
  }
});

// 6. Architecture Switcher (x86_64 vs ARM64)
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
        targetPanel.classList.add('active');
      }
    });
  });
}

// 7. Server & Headless Installation Tabs
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
        activePanel.classList.add('active');
      }
    });
  });
}

// 8. Mobile Navigation Drawer Toggle
function initMobileMenu() {
  const toggle = document.getElementById('nav-toggle');
  const navLinks = document.getElementById('nav-links');
  if (!toggle || !navLinks) return;

  toggle.addEventListener('click', (e) => {
    e.stopPropagation();
    toggle.classList.toggle('open');
    navLinks.classList.toggle('open');
  });

  // Close menu when clicking any nav link
  navLinks.querySelectorAll('.nav-link').forEach(link => {
    link.addEventListener('click', () => {
      toggle.classList.remove('open');
      navLinks.classList.remove('open');
    });
  });

  // Close menu when clicking outside
  document.addEventListener('click', (e) => {
    if (!navLinks.contains(e.target) && !toggle.contains(e.target)) {
      toggle.classList.remove('open');
      navLinks.classList.remove('open');
    }
  });
}

