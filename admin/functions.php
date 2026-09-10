<?php
/**
 * admin/functions.php - admin-area-specific helpers (session keys: user_id/user_role)
 */

function isLoggedIn()
{
    return isset($_SESSION['user_id']) && !empty($_SESSION['user_id']);
}

function isAdmin()
{
    return isset($_SESSION['user_role']) && $_SESSION['user_role'] == 'admin';
}

function requireLogin()
{
    if (!isLoggedIn()) {
        $_SESSION['error_message'] = 'Please login to access this page';
        header('Location: login.php');
        exit();
    }
}

function requireAdmin()
{
    requireLogin();
    if (!isAdmin()) {
        $_SESSION['error_message'] = 'Access denied. Admin privileges required.';
        header('Location: index.php');
        exit();
    }
}

function getUserByEmail($conn, $email)
{
    $stmt = executeQuery($conn, "SELECT * FROM users WHERE email = ? LIMIT 1", 's', [$email]);
    return $stmt ? $stmt->fetch_assoc() : null;
}

function getUserReceipts($conn, $user_id)
{
    $stmt = executeQuery($conn, "SELECT * FROM receipts WHERE user_id = ? ORDER BY created_at DESC", 'i', [$user_id]);
    return $stmt ? $stmt->fetch_all() : [];
}

function getUserCitations($conn, $user_id)
{
    $stmt = executeQuery($conn, "SELECT * FROM citations WHERE user_id = ? ORDER BY issued_at DESC", 'i', [$user_id]);
    return $stmt ? $stmt->fetch_all() : [];
}

function getUserComplaints($conn, $user_id)
{
    $stmt = executeQuery($conn, "SELECT * FROM complaints WHERE user_id = ? ORDER BY created_at DESC", 'i', [$user_id]);
    return $stmt ? $stmt->fetch_all() : [];
}

function getAllUserAccounts($conn)
{
    $stmt = $conn->query("SELECT id, full_name, email FROM user_account WHERE status = 'active' ORDER BY full_name ASC");
    return $stmt ? $stmt->fetch_all() : [];
}

function getUserAccountById($conn, $id)
{
    return getRecordById($conn, 'user_account', $id);
}

function createReceipt($conn, $user_id, $title, $amount, $description, $issued_by = 'System Admin')
{
    $sql = "INSERT INTO receipts (user_id, title, amount, description, issued_by) VALUES (?, ?, ?, ?, ?)";
    $stmt = executeQuery($conn, $sql, '', [$user_id, $title, $amount, $description, $issued_by]);
    return (bool) $stmt;
}

function getAllComplaints($conn)
{
    $sql = "SELECT c.*, u.full_name, u.email FROM complaints c LEFT JOIN user_account u ON c.user_id = u.id ORDER BY c.created_at DESC";
    $stmt = $conn->query($sql);
    return $stmt ? $stmt->fetch_all() : [];
}

function getComplaintById($conn, $id)
{
    $sql = "SELECT c.*, u.full_name, u.email FROM complaints c LEFT JOIN user_account u ON c.user_id = u.id WHERE c.id = ? LIMIT 1";
    $stmt = executeQuery($conn, $sql, 'i', [$id]);
    return $stmt ? $stmt->fetch_assoc() : null;
}

function updateComplaintResponse($conn, $id, $status, $admin_response, $responder_id = null)
{
    $sql = "UPDATE complaints SET status = ?, admin_response = ?, responder_id = ?, responded_at = NOW() WHERE id = ?";
    $stmt = executeQuery($conn, $sql, '', [$status, $admin_response, $responder_id, $id]);
    return (bool) $stmt;
}

function getDashboardStats($conn)
{
    $stats = [];

    $result = $conn->query("SELECT COUNT(*) as count FROM motorists WHERE status = 'active'");
    $stats['total_motorists'] = (int) $result->fetch_assoc()['count'];

    $result = $conn->query("SELECT COUNT(*) as count FROM motorbikes WHERE status = 'active'");
    $stats['total_bikes'] = (int) $result->fetch_assoc()['count'];

    $result = $conn->query("SELECT purpose, COUNT(*) as count FROM motorbikes WHERE status = 'active' GROUP BY purpose");
    $stats['purpose'] = [];
    foreach ($result->fetch_all() as $row) {
        $stats['purpose'][$row['purpose']] = (int) $row['count'];
    }

    $result = $conn->query("SELECT COUNT(*) as count FROM motorbikes WHERE purpose = 'hire' AND status = 'active'");
    $stats['hire_count'] = (int) $result->fetch_assoc()['count'];

    $result = $conn->query("SELECT AVG(hire_rate) as avg_rate FROM hire_details");
    $stats['avg_hire_rate'] = $result->fetch_assoc()['avg_rate'] ?? 0;

    $result = $conn->query("SELECT COUNT(*) as count FROM motorists WHERE date_registered >= NOW() - INTERVAL '7 days'");
    $stats['recent_registrations'] = (int) $result->fetch_assoc()['count'];

    return $stats;
}

function getMotoristStats($conn, $motorist_id)
{
    $stats = [];

    $stmt = executeQuery($conn, "SELECT COUNT(*) as count FROM motorbikes WHERE motorist_id = ?", 'i', [$motorist_id]);
    $stats['total_bikes'] = (int) $stmt->fetch_assoc()['count'];

    $stmt = executeQuery($conn, "SELECT COUNT(*) as count FROM motorbikes WHERE motorist_id = ? AND status = 'active'", 'i', [$motorist_id]);
    $stats['active_bikes'] = (int) $stmt->fetch_assoc()['count'];

    $stmt = executeQuery($conn, "SELECT COUNT(*) as count FROM motorbikes WHERE motorist_id = ? AND purpose = 'commercial'", 'i', [$motorist_id]);
    $stats['commercial_bikes'] = (int) $stmt->fetch_assoc()['count'];

    $stmt = executeQuery($conn, "SELECT COUNT(*) as count FROM motorbikes WHERE motorist_id = ? AND purpose = 'hire'", 'i', [$motorist_id]);
    $stats['hire_bikes'] = (int) $stmt->fetch_assoc()['count'];

    return $stats;
}
