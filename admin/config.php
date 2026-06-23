<?php
/**
 * admin/config.php
 */

require_once __DIR__ . '/../includes/db.php';
require_once __DIR__ . '/../includes/helpers.php';

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

require_once __DIR__ . '/functions.php';

// Enforce admin access for all admin pages except login/logout
$admin_exceptions = ['login.php', 'logout.php'];
if (!in_array(basename($_SERVER['PHP_SELF']), $admin_exceptions, true)) {
    requireAdmin();
}

date_default_timezone_set('Africa/Nairobi');

// Error reporting - keep OFF (or log-only) in production on Render.
$isProd = (getenv('APP_ENV') === 'production');
error_reporting(E_ALL);
ini_set('display_errors', $isProd ? '0' : '1');
ini_set('log_errors', '1');
