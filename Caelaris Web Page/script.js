// ==========================================================
// Caelaris Linux - Interactive Scripts
// ==========================================================

document.addEventListener('DOMContentLoaded', () => {
  initDesktopSwitcher();
  initFaqAccordion();
  initCopyButtons();
  initInstallGuideTabs();
});

// 1. Interactive Desktop Showcase Switcher (KDE vs GNOME)
function initDesktopSwitcher() {
  const tabs = document.querySelectorAll('.de-tab');
  const previews = document.querySelectorAll('.desktop-preview');

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const targetDe = tab.getAttribute('data-de');

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

// Close modal when clicking outside of it
window.addEventListener('click', (e) => {
  const modal = document.getElementById('combine-modal');
  if (e.target === modal) {
    closeCombineModal();
  }
});
