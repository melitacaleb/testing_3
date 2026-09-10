<?php
/**
 * includes/helpers.php
 * Generic helpers shared by both admin/ and users/ areas.
 * Session-aware auth helpers (isLoggedIn/isAdmin/etc.) live in
 * admin/functions.php and users/functions.php instead, because the two
 * areas intentionally use different session keys.
 */

function sanitize($data)
{
    if (is_array($data)) {
        return array_map('sanitize', $data);
    }
    return htmlspecialchars(trim($data), ENT_QUOTES, 'UTF-8');
}

function validateEmail($email)
{
    return filter_var($email, FILTER_VALIDATE_EMAIL) !== false;
}

function validatePhone($phone)
{
    return (bool) preg_match('/^(07|01)\d{8}$/', preg_replace('/[^0-9]/', '', $phone));
}

function validateLicense($license)
{
    return (bool) preg_match('/^[A-Z]{2,3}[\s-]?\d{5,7}$/', strtoupper($license));
}

function validateRegistration($registration)
{
    return (bool) preg_match('/^[K][A-Z]{2}\s?\d{3}[A-Z]$/', strtoupper($registration));
}

function generateCSRFToken()
{
    if (!isset($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

function verifyCSRFToken($token)
{
    return isset($_SESSION['csrf_token']) && hash_equals($_SESSION['csrf_token'], (string)$token);
}

/**
 * Execute a prepared statement. $params is a plain positional array
 * matching '?' placeholders in $sql. The $types argument is accepted for
 * backwards compatibility with the old mysqli call sites but is ignored.
 *
 * @return CompatStatement|false
 */
function executeQuery($conn, $sql, $types = '', $params = [])
{
    try {
        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            throw new Exception("Prepare failed: " . $conn->error);
        }
        if (!$stmt->execute($params)) {
            throw new Exception("Execute failed");
        }
        return $stmt;
    } catch (Exception $e) {
        error_log("Query execution error: " . $e->getMessage());
        return false;
    }
}

function getRecordById($conn, $table, $id)
{
    $table = preg_replace('/[^a-zA-Z0-9_]/', '', $table); // table names can't be bound params
    $sql = "SELECT * FROM {$table} WHERE id = ? LIMIT 1";
    $stmt = executeQuery($conn, $sql, 'i', [$id]);
    return $stmt ? $stmt->fetch_assoc() : null;
}

function recordExists($conn, $table, $field, $value, $exclude_id = 0)
{
    $table = preg_replace('/[^a-zA-Z0-9_]/', '', $table);
    $field = preg_replace('/[^a-zA-Z0-9_]/', '', $field);
    $sql = "SELECT id FROM {$table} WHERE {$field} = ? AND id != ? LIMIT 1";
    $stmt = executeQuery($conn, $sql, 'si', [$value, $exclude_id]);
    return $stmt ? ($stmt->num_rows > 0) : false;
}

function formatPurpose($purpose)
{
    $purposes = [
        'commercial' => 'Commercial',
        'personal_transport' => 'Personal Transport',
        'hire' => 'On Hire',
    ];
    return $purposes[$purpose] ?? ucfirst($purpose);
}

function getPurposeBadgeClass($purpose)
{
    switch ($purpose) {
        case 'commercial': return 'bg-danger';
        case 'personal_transport': return 'bg-success';
        case 'hire': return 'bg-warning text-dark';
        default: return 'bg-secondary';
    }
}

function getStatusBadgeClass($status)
{
    switch ($status) {
        case 'active': return 'bg-success';
        case 'inactive': return 'bg-secondary';
        case 'suspended': return 'bg-danger';
        case 'pending': return 'bg-warning text-dark';
        case 'paid': return 'bg-info';
        case 'overdue': return 'bg-danger';
        default: return 'bg-secondary';
    }
}

function formatDate($date, $format = 'd M Y')
{
    if (empty($date) || $date == '0000-00-00') {
        return 'N/A';
    }
    return date($format, strtotime($date));
}

function formatCurrency($amount, $currency = 'KES')
{
    if ($amount === null || $amount === '') {
        return 'N/A';
    }
    return $currency . ' ' . number_format($amount, 2);
}

function formatPhone($phone)
{
    $phone = preg_replace('/[^0-9]/', '', $phone);
    if (strlen($phone) == 10) {
        return substr($phone, 0, 3) . ' ' . substr($phone, 3, 3) . ' ' . substr($phone, 6, 4);
    }
    return $phone;
}

function truncateText($text, $length = 50, $suffix = '...')
{
    if (strlen($text) <= $length) {
        return $text;
    }
    return substr($text, 0, $length) . $suffix;
}

function paginate($current_page, $total_pages, $url_pattern = '?page=%d')
{
    if ($total_pages <= 1) {
        return '';
    }
    $html = '<nav><ul class="pagination justify-content-center">';
    $prev_class = $current_page <= 1 ? 'disabled' : '';
    $html .= '<li class="page-item ' . $prev_class . '">';
    $html .= '<a class="page-link" href="' . sprintf($url_pattern, $current_page - 1) . '">Previous</a></li>';
    $start = max(1, $current_page - 2);
    $end = min($total_pages, $current_page + 2);
    for ($i = $start; $i <= $end; $i++) {
        $active_class = $i == $current_page ? 'active' : '';
        $html .= '<li class="page-item ' . $active_class . '">';
        $html .= '<a class="page-link" href="' . sprintf($url_pattern, $i) . '">' . $i . '</a></li>';
    }
    $next_class = $current_page >= $total_pages ? 'disabled' : '';
    $html .= '<li class="page-item ' . $next_class . '">';
    $html .= '<a class="page-link" href="' . sprintf($url_pattern, $current_page + 1) . '">Next</a></li>';
    $html .= '</ul></nav>';
    return $html;
}

function showAlert($message, $type = 'info', $dismissible = true)
{
    $icons = [
        'success' => 'check-circle',
        'danger' => 'exclamation-circle',
        'warning' => 'exclamation-triangle',
        'info' => 'info-circle',
    ];
    $icon = $icons[$type] ?? 'info-circle';
    $dismissible_class = $dismissible ? 'alert-dismissible fade show' : '';
    $html = '<div class="alert alert-' . $type . ' ' . $dismissible_class . '" role="alert">';
    $html .= '<i class="fas fa-' . $icon . ' me-2"></i>' . $message;
    if ($dismissible) {
        $html .= '<button type="button" class="btn-close" data-bs-dismiss="alert"></button>';
    }
    $html .= '</div>';
    return $html;
}

function actionButtons($id, $view_url = '', $edit_url = '', $delete_url = '')
{
    $html = '<div class="btn-group-action d-flex gap-1">';
    if ($view_url) {
        $html .= '<a href="' . sprintf($view_url, $id) . '" class="btn-action btn-view" title="View" data-bs-toggle="tooltip"><i class="fas fa-eye"></i></a>';
    }
    if ($edit_url) {
        $html .= '<a href="' . sprintf($edit_url, $id) . '" class="btn-action btn-edit" title="Edit" data-bs-toggle="tooltip"><i class="fas fa-edit"></i></a>';
    }
    if ($delete_url) {
        $html .= '<button type="button" class="btn-action btn-delete" title="Delete" data-bs-toggle="tooltip" onclick="confirmDelete(' . $id . ')"><i class="fas fa-trash"></i></button>';
    }
    $html .= '</div>';
    return $html;
}

function uploadFile($file, $target_dir, $allowed_types = [], $max_size = 5242880)
{
    $response = ['success' => false, 'message' => '', 'path' => ''];
    if (!isset($file) || $file['error'] != UPLOAD_ERR_OK) {
        $response['message'] = 'No file uploaded or upload error';
        return $response;
    }
    if ($file['size'] > $max_size) {
        $response['message'] = 'File size exceeds limit of ' . ($max_size / 1048576) . 'MB';
        return $response;
    }
    $file_type = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    if (!empty($allowed_types) && !in_array($file_type, $allowed_types)) {
        $response['message'] = 'File type not allowed. Allowed types: ' . implode(', ', $allowed_types);
        return $response;
    }
    if (!file_exists($target_dir)) {
        mkdir($target_dir, 0777, true);
    }
    $new_filename = uniqid() . '_' . date('Ymd') . '.' . $file_type;
    $target_path = $target_dir . '/' . $new_filename;
    if (move_uploaded_file($file['tmp_name'], $target_path)) {
        $response['success'] = true;
        $response['message'] = 'File uploaded successfully';
        $response['path'] = $target_path;
    } else {
        $response['message'] = 'Failed to move uploaded file';
    }
    return $response;
}

function deleteFile($file_path)
{
    if (file_exists($file_path) && is_file($file_path)) {
        return unlink($file_path);
    }
    return false;
}

function setFlashMessage($key, $message, $type = 'info')
{
    $_SESSION['flash'][$key] = ['message' => $message, 'type' => $type];
}

function getFlashMessage($key)
{
    if (isset($_SESSION['flash'][$key])) {
        $message = $_SESSION['flash'][$key];
        unset($_SESSION['flash'][$key]);
        return $message;
    }
    return null;
}

function exportToCSV($data, $headers = [], $filename = 'export.csv')
{
    header('Content-Type: text/csv');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    $output = fopen('php://output', 'w');
    if (!empty($headers)) {
        fputcsv($output, $headers);
    }
    foreach ($data as $row) {
        fputcsv($output, $row);
    }
    fclose($output);
    exit();
}

function generateRandomString($length = 10)
{
    $characters = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    $charLen = strlen($characters);
    $randomString = '';
    for ($i = 0; $i < $length; $i++) {
        $randomString .= $characters[random_int(0, $charLen - 1)];
    }
    return $randomString;
}

function daysBetween($date1, $date2)
{
    $d1 = new DateTime($date1);
    $d2 = new DateTime($date2);
    return $d1->diff($d2)->days;
}

function calculateAge($dob)
{
    $birthday = new DateTime($dob);
    $today = new DateTime();
    return $today->diff($birthday)->y;
}

function debug($data, $die = true)
{
    echo '<pre>';
    print_r($data);
    echo '</pre>';
    if ($die) {
        die();
    }
}

function getClientIP()
{
    foreach (['HTTP_CLIENT_IP', 'HTTP_X_FORWARDED_FOR', 'HTTP_X_FORWARDED', 'HTTP_FORWARDED_FOR', 'HTTP_FORWARDED', 'REMOTE_ADDR'] as $key) {
        if (!empty($_SERVER[$key])) {
            return $_SERVER[$key];
        }
    }
    return 'UNKNOWN';
}

function getSystemVersion()
{
    return defined('SITE_VERSION') ? SITE_VERSION : '2.0.0';
}

function getCurrentYear()
{
    return date('Y');
}

function sendEmailNotification($to, $subject, $htmlBody, $from = null)
{
    if (empty($to)) {
        return false;
    }
    $from = $from ?: ('no-reply@' . ($_SERVER['SERVER_NAME'] ?? 'localhost'));
    $headers = "MIME-Version: 1.0\r\n";
    $headers .= "Content-type: text/html; charset=utf-8\r\n";
    $headers .= "From: " . $from . "\r\n";

    $sent = @mail($to, $subject, $htmlBody, $headers);
    if (!$sent) {
        $log = sprintf("%s | MAIL_FAIL to=%s subject=%s\n", date('c'), $to, $subject);
        @file_put_contents(__DIR__ . '/../logs/mail_fail.log', $log, FILE_APPEND);
    }
    return $sent;
}

function logActivity($conn, $action, $description, $user_id = null)
{
    if (!$user_id && isset($_SESSION['user_id'])) {
        $user_id = $_SESSION['user_id'];
    }
    $ip = getClientIP();
    $user_agent = $_SERVER['HTTP_USER_AGENT'] ?? '';
    $sql = "INSERT INTO activity_log (user_id, action, description, ip_address, user_agent) VALUES (?, ?, ?, ?, ?)";
    executeQuery($conn, $sql, '', [$user_id, $action, $description, $ip, $user_agent]);
}
