<?php
// admin/sidebar.php
// On desktop: shows as a fixed left column (same as before).
// On mobile / WebView: sidebar collapses; a hamburger button appears at the
// top so the content fills the whole screen without scrolling past the menu.
$currentPage = basename($_SERVER['PHP_SELF']);
?>

<style>
/* ── Desktop sidebar (unchanged) ───────────────────────── */
.sidebar {
    min-height: 100vh;
    background: linear-gradient(180deg, #2c3e50 0%, #3498db 100%);
    position: sticky;
    top: 0;
}
.sidebar a {
    color: white;
    padding: 15px;
    text-decoration: none;
    display: block;
    transition: 0.3s;
    border-left: 4px solid transparent;
}
.sidebar a:hover  { background: rgba(255,255,255,0.1); padding-left: 25px; }
.sidebar a.active { background: rgba(255,255,255,0.2); border-left-color: #f1c40f; }

/* ── Mobile toolbar ─────────────────────────────────────── */
.mobile-topbar {
    display: none;
    background: linear-gradient(90deg, #2c3e50 0%, #3498db 100%);
    padding: 10px 16px;
    align-items: center;
    justify-content: space-between;
    position: sticky;
    top: 0;
    z-index: 1040;
}
.mobile-topbar .app-title { color: white; font-weight: 700; font-size: 1rem; margin: 0; }
.hamburger-btn {
    background: none; border: none; cursor: pointer; padding: 4px 8px;
}
.hamburger-btn span {
    display: block; width: 24px; height: 2px;
    background: white; margin: 5px 0; border-radius: 2px;
    transition: 0.3s;
}

/* ── Offcanvas sidebar (mobile only) ────────────────────── */
.offcanvas-sidebar {
    position: fixed; top: 0; left: -280px; width: 280px; height: 100vh;
    background: linear-gradient(180deg, #2c3e50 0%, #3498db 100%);
    z-index: 1055; transition: left 0.3s ease; overflow-y: auto;
}
.offcanvas-sidebar.open { left: 0; }
.offcanvas-overlay {
    display: none; position: fixed; inset: 0;
    background: rgba(0,0,0,0.5); z-index: 1050;
}
.offcanvas-overlay.open { display: block; }
.offcanvas-sidebar a {
    color: white; padding: 15px 20px; text-decoration: none;
    display: block; transition: 0.3s; border-left: 4px solid transparent;
}
.offcanvas-sidebar a:hover  { background: rgba(255,255,255,0.1); padding-left: 28px; }
.offcanvas-sidebar a.active { background: rgba(255,255,255,0.2); border-left-color: #f1c40f; }
.offcanvas-close {
    background: none; border: none; color: white; font-size: 1.4rem;
    position: absolute; top: 12px; right: 14px; cursor: pointer; line-height: 1;
}
.offcanvas-header {
    padding: 20px 16px 10px; position: relative;
    border-bottom: 1px solid rgba(255,255,255,0.15); margin-bottom: 8px;
}

/* ── Switch layouts at 768 px ───────────────────────────── */
@media (max-width: 767.98px) {
    /* Hide desktop sidebar column */
    .sidebar-col { display: none !important; }
    /* Content takes full width */
    .content-col { width: 100% !important; max-width: 100% !important; padding: 12px !important; }
    /* Show the mobile top bar */
    .mobile-topbar { display: flex; }
    /* Give the outer row no gutters on mobile */
    .admin-row { margin: 0 !important; }
}
</style>

<!-- ── Mobile top bar (hidden on desktop) ─────────────── -->
<div class="mobile-topbar">
    <p class="app-title"><i class="fas fa-motorcycle me-2"></i>Motorist Admin</p>
    <button class="hamburger-btn" id="hamburgerBtn" aria-label="Open menu">
        <span></span><span></span><span></span>
    </button>
</div>

<!-- ── Offcanvas overlay ───────────────────────────────── -->
<div class="offcanvas-overlay" id="offcanvasOverlay"></div>

<!-- ── Offcanvas sidebar panel ────────────────────────── -->
<div class="offcanvas-sidebar" id="offcanvasSidebar">
    <div class="offcanvas-header">
        <button class="offcanvas-close" id="offcanvasClose" aria-label="Close menu">&times;</button>
        <div class="text-center pt-2">
            <i class="fas fa-motorcycle fa-2x text-white"></i>
            <p class="text-white mt-1 mb-0 fw-semibold">Motorist System</p>
        </div>
    </div>
    <a href="index.php"               class="<?php echo $currentPage === 'index.php'              ? 'active' : ''; ?>"><i class="fas fa-tachometer-alt me-2"></i>Dashboard</a>
    <a href="add_motorist.php"        class="<?php echo $currentPage === 'add_motorist.php'       ? 'active' : ''; ?>"><i class="fas fa-user-plus me-2"></i>Add Motorist</a>
    <a href="add_motorbike.php"       class="<?php echo $currentPage === 'add_motorbike.php'      ? 'active' : ''; ?>"><i class="fas fa-plus-circle me-2"></i>Add Motorbike</a>
    <a href="view_motorists.php"      class="<?php echo $currentPage === 'view_motorists.php'     ? 'active' : ''; ?>"><i class="fas fa-users me-2"></i>View All</a>
    <a href="reports.php"             class="<?php echo $currentPage === 'reports.php'            ? 'active' : ''; ?>"><i class="fas fa-chart-bar me-2"></i>Reports</a>
    <a href="user_communications.php" class="<?php echo $currentPage === 'user_communications.php'? 'active' : ''; ?>"><i class="fas fa-envelope-open-text me-2"></i>User Communications</a>
    <a href="profile.php"             class="<?php echo $currentPage === 'profile.php'            ? 'active' : ''; ?>"><i class="fas fa-user-circle me-2"></i>Profile</a>
    <a href="logout.php"><i class="fas fa-sign-out-alt me-2"></i>Logout</a>
</div>

<!-- ── Desktop sidebar (inside Bootstrap col, hidden on mobile via CSS) ── -->
<div class="col-md-2 p-0 sidebar sidebar-col">
    <div class="text-center py-4">
        <i class="fas fa-motorcycle fa-3x text-white"></i>
        <h5 class="text-white mt-2">Motorist System</h5>
    </div>
    <a href="index.php"               class="<?php echo $currentPage === 'index.php'              ? 'active' : ''; ?>"><i class="fas fa-tachometer-alt me-2"></i>Dashboard</a>
    <a href="add_motorist.php"        class="<?php echo $currentPage === 'add_motorist.php'       ? 'active' : ''; ?>"><i class="fas fa-user-plus me-2"></i>Add Motorist</a>
    <a href="add_motorbike.php"       class="<?php echo $currentPage === 'add_motorbike.php'      ? 'active' : ''; ?>"><i class="fas fa-plus-circle me-2"></i>Add Motorbike</a>
    <a href="view_motorists.php"      class="<?php echo $currentPage === 'view_motorists.php'     ? 'active' : ''; ?>"><i class="fas fa-users me-2"></i>View All</a>
    <a href="reports.php"             class="<?php echo $currentPage === 'reports.php'            ? 'active' : ''; ?>"><i class="fas fa-chart-bar me-2"></i>Reports</a>
    <a href="user_communications.php" class="<?php echo $currentPage === 'user_communications.php'? 'active' : ''; ?>"><i class="fas fa-envelope-open-text me-2"></i>User Communications</a>
    <a href="profile.php"             class="<?php echo $currentPage === 'profile.php'            ? 'active' : ''; ?>"><i class="fas fa-user-circle me-2"></i>Profile</a>
    <a href="logout.php"><i class="fas fa-sign-out-alt me-2"></i>Logout</a>
</div>

<script>
(function () {
    var btn     = document.getElementById('hamburgerBtn');
    var sidebar = document.getElementById('offcanvasSidebar');
    var overlay = document.getElementById('offcanvasOverlay');
    var close   = document.getElementById('offcanvasClose');

    function openMenu()  { sidebar.classList.add('open'); overlay.classList.add('open'); }
    function closeMenu() { sidebar.classList.remove('open'); overlay.classList.remove('open'); }

    if (btn)     btn.addEventListener('click', openMenu);
    if (close)   close.addEventListener('click', closeMenu);
    if (overlay) overlay.addEventListener('click', closeMenu);

    // Close when a nav link is tapped (navigates away anyway, but feels snappier)
    var links = sidebar ? sidebar.querySelectorAll('a') : [];
    links.forEach(function(link) { link.addEventListener('click', closeMenu); });
})();
</script>
