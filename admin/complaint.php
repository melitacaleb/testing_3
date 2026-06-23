<?php
require_once __DIR__ . '/config.php';

if (!isset($_GET['id']) || !is_numeric($_GET['id'])) {
    header('Location: complaints.php');
    exit;
}

$id = (int)$_GET['id'];
$complaint = getComplaintById($conn, $id);
if (!$complaint) {
    header('Location: complaints.php');
    exit;
}

$errors = [];
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $status = $_POST['status'] ?? 'open';
    $admin_response = trim($_POST['admin_response'] ?? '');
    $responder_id = $_SESSION['user_id'] ?? null;

    if (updateComplaintResponse($conn, $id, $status, $admin_response, $responder_id)) {
        if (!empty($complaint['email']) && !empty($admin_response)) {
            $to = $complaint['email'];
            $subject = "Response to your complaint #" . $complaint['id'];
            $body = '<p>Dear ' . htmlspecialchars($complaint['full_name'] ?? 'User') . ',</p>';
            $body .= '<p>Your complaint (ID: ' . htmlspecialchars($complaint['id']) . ') has a new response from the admin.</p>';
            $body .= '<h4>Response</h4><div>' . nl2br(htmlspecialchars($admin_response)) . '</div>';
            $body .= '<p>Status: ' . htmlspecialchars($status) . '</p>';
            $body .= '<p>Regards,<br>' . (defined('SITE_NAME') ? SITE_NAME : ($_SERVER['SERVER_NAME'] ?? 'Admin')) . '</p>';
            sendEmailNotification($to, $subject, $body);
        }
        header('Location: complaints.php');
        exit;
    } else {
        $errors[] = 'Failed to update complaint. Try again.';
    }
}
?>
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>Complaint #<?php echo htmlspecialchars($complaint['id']); ?> - Admin</title>
</head>
<body>
<h1>Complaint #<?php echo htmlspecialchars($complaint['id']); ?></h1>
<p><a href="complaints.php">Back to list</a></p>
<?php if ($errors): ?>
    <div style="color:red;"><?php echo implode('<br>', array_map('htmlspecialchars', $errors)); ?></div>
<?php endif; ?>
<div>
    <strong>From:</strong> <?php echo htmlspecialchars($complaint['full_name'] ?? 'Guest'); ?> (<?php echo htmlspecialchars($complaint['email'] ?? ''); ?>)<br>
    <strong>Subject:</strong> <?php echo htmlspecialchars($complaint['subject']); ?><br>
    <strong>Submitted:</strong> <?php echo htmlspecialchars($complaint['created_at']); ?><br>
    <hr>
    <p><?php echo nl2br(htmlspecialchars($complaint['message'])); ?></p>
</div>
<form method="post">
    <div>
        <label for="status">Status</label>
        <select name="status" id="status">
            <option value="open" <?php echo ($complaint['status']==='open')? 'selected' : ''; ?>>Open</option>
            <option value="in_progress" <?php echo ($complaint['status']==='in_progress')? 'selected' : ''; ?>>In Progress</option>
            <option value="resolved" <?php echo ($complaint['status']==='resolved')? 'selected' : ''; ?>>Resolved</option>
            <option value="closed" <?php echo ($complaint['status']==='closed')? 'selected' : ''; ?>>Closed</option>
        </select>
    </div>
    <div>
        <label for="admin_response">Response / Notes</label><br>
        <textarea name="admin_response" id="admin_response" rows="6" cols="60"><?php echo htmlspecialchars($complaint['admin_response'] ?? ''); ?></textarea>
    </div>
    <div>
        <button type="submit">Save</button>
    </div>
</form>
<?php if (!empty($complaint['admin_response'])): ?>
    <hr>
    <h3>Previous Response</h3>
    <div><?php echo nl2br(htmlspecialchars($complaint['admin_response'])); ?></div>
    <p><em>Responded at: <?php echo htmlspecialchars($complaint['responded_at'] ?? ''); ?></em></p>
<?php endif; ?>
</body>
</html>
