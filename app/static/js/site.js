document.documentElement.classList.add("js");

const header = document.querySelector("[data-site-header]");
const menuToggle = document.querySelector("[data-menu-toggle]");
const mobileMenu = document.querySelector("[data-mobile-menu]");

if (header && menuToggle && mobileMenu) {
  const menuLinks = [...mobileMenu.querySelectorAll("a")];

  const closeMenu = ({ restoreFocus = true } = {}) => {
    mobileMenu.hidden = true;
    header.classList.remove("menu-is-open");
    document.body.classList.remove("menu-is-open");
    menuToggle.setAttribute("aria-expanded", "false");
    menuToggle.setAttribute("aria-label", "메뉴 열기");
    if (restoreFocus) menuToggle.focus();
  };

  const openMenu = () => {
    mobileMenu.hidden = false;
    header.classList.add("menu-is-open");
    document.body.classList.add("menu-is-open");
    menuToggle.setAttribute("aria-expanded", "true");
    menuToggle.setAttribute("aria-label", "메뉴 닫기");
    menuLinks[0]?.focus();
  };

  menuToggle.addEventListener("click", () => {
    if (menuToggle.getAttribute("aria-expanded") === "true") closeMenu();
    else openMenu();
  });

  mobileMenu.addEventListener("click", (event) => {
    if (event.target === mobileMenu) closeMenu();
  });

  document.addEventListener("keydown", (event) => {
    if (mobileMenu.hidden) return;
    if (event.key === "Escape") {
      closeMenu();
      return;
    }
    if (event.key !== "Tab") return;

    const focusableElements = [menuToggle, ...menuLinks];
    const currentIndex = focusableElements.indexOf(document.activeElement);
    if (event.shiftKey && currentIndex <= 0) {
      event.preventDefault();
      focusableElements.at(-1)?.focus();
    } else if (!event.shiftKey && currentIndex === focusableElements.length - 1) {
      event.preventDefault();
      focusableElements[0].focus();
    } else if (currentIndex === -1) {
      event.preventDefault();
      menuLinks[0]?.focus();
    }
  });

  window.addEventListener("resize", () => {
    if (window.matchMedia("(min-width: 761px)").matches && !mobileMenu.hidden) {
      closeMenu({ restoreFocus: false });
    }
  });
}

const filterForm = document.querySelector("[data-project-filters]");
const projectRows = [...document.querySelectorAll("[data-project-row]")];

if (filterForm && projectRows.length) {
  const queryInput = filterForm.querySelector("[data-filter-query]");
  const groupInput = filterForm.querySelector("[data-filter-group]");
  const resultCount = document.querySelector("[data-result-count]");
  const emptyMessage = document.querySelector("[data-filter-empty]");
  const submitButton = filterForm.querySelector(".filter-submit");
  const hasCompleteInventory =
    projectRows.length === Number(filterForm.dataset.totalCount);

  if (hasCompleteInventory) submitButton?.classList.add("enhanced-only");

  const normalize = (value) => value.trim().toLocaleLowerCase("ko-KR");
  const applyFilters = () => {
    const query = normalize(queryInput?.value || "");
    const group = groupInput?.value || "";
    let visibleCount = 0;

    projectRows.forEach((row) => {
      const matchesQuery = !query || normalize(row.dataset.search || "").includes(query);
      const matchesGroup = !group || row.dataset.group === group;
      const visible = matchesQuery && matchesGroup;
      row.hidden = !visible;
      if (visible) visibleCount += 1;
    });

    if (resultCount) resultCount.textContent = `${visibleCount}개의 프로젝트`;
    if (emptyMessage) emptyMessage.hidden = visibleCount !== 0;

    const params = new URLSearchParams();
    if (queryInput?.value.trim()) params.set("q", queryInput.value.trim());
    if (group) params.set("group", group);
    const nextUrl = `${window.location.pathname}${params.size ? `?${params}` : ""}`;
    window.history.replaceState({}, "", nextUrl);
  };

  let searchTimer;
  if (hasCompleteInventory) {
    queryInput?.addEventListener("input", () => {
      window.clearTimeout(searchTimer);
      searchTimer = window.setTimeout(applyFilters, 120);
    });
    groupInput?.addEventListener("change", applyFilters);
    filterForm.addEventListener("submit", (event) => {
      event.preventDefault();
      applyFilters();
    });
  }
}
