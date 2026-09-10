<?php
require_once __DIR__ . '/config.php';
requireLogin();
$user_id = getCurrentUserId();
$errors = [];
$message = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $subject = trim($_POST['subject'] ?? '');
    $msg = trim($_POST['message'] ?? '');
    if (empty($subject) || empty($msg)) {
        $errors[] = 'Please provide both subject and message.';
    } else {
        $stmt = executeQuery($conn, "INSERT INTO complaints (user_id, subject, message) VALUES (?, ?, ?)", '', [$user_id, $subject, $msg]);
        if ($stmt) {
            $message = 'Complaint submitted. Admin will respond shortly.';

            // Notify admin users by email (best-effort)
            $adminRes = $conn->query("SELECT email, full_name FROM users WHERE role = 'admin' AND email IS NOT NULL");
            if ($adminRes) {
                foreach ($adminRes->fetch_all() as $adminRow) {
                    $adminEmail = $adminRow['email'];
                    $subjectAdmin = 'New complaint submitted by user ID ' . (int)$user_id;
                    $bodyAdmin = '<p>A new complaint was submitted by user ID ' . htmlspecialchars($user_id) . '.</p>';
                    $bodyAdmin .= '<p><strong>Subject:</strong> ' . htmlspecialchars($subject) . '</p>';
                    $bodyAdmin .= '<p><strong>Message:</strong><br>' . nl2br(htmlspecialchars($msg)) . '</p>';
                    $bodyAdmin .= '<p>View it in the admin area: ' . SITE_URL . 'admin/complaints.php</p>';
                    sendEmailNotification($adminEmail, $subjectAdmin, $bodyAdmin);
                }
            }
        } else {
            $errors[] = 'Unable to submit complaint.';
        }
    }
}

$complaints = getUserComplaints($conn, $user_id);
?>
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Complaints - <?php echo SITE_NAME; ?></title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
</head>
<body class="bg-light">
<div class="container py-4">
    <div class="d-flex justify-content-between align-items-center mb-3">
        <h3>My Complaints</h3>
        <div>
            <a href="dashboard.php" class="btn btn-secondary">Dashboard</a>
            <a href="logout.php" class="btn btn-danger">Logout</a>
        </div>
    </div>

    <?php if (!empty($errors)): ?>
        <div class="alert alert-danger"><ul class="mb-0"><?php foreach ($errors as $e) echo '<li>'.htmlspecialchars($e).'</li>'; ?></ul></div>
    <?php endif; ?>
    <?php if ($message): ?><div class="alert alert-success"><?php echo htmlspecialchars($message); ?></div><?php endif; ?>

    <div class="card mb-4">
        <div class="card-body">
            <h5 class="card-title">Submit a Complaint</h5>
            <form method="POST" action="">
                <div class="mb-3">
                    <label class="form-label">Subject</label>
                    <input type="text" name="subject" class="form-control" required>
                </div>
                <div class="mb-3">
                    <label class="form-label">Message</label>
                    <textarea name="message" class="form-control" rows="4" required></textarea>
                </div>
                <button class="btn btn-primary">Send Complaint</button>
            </form>
        </div>
    </div>

    <?php if (empty($complaints)): ?>
        <p class="text-muted">You have not submitted any complaints yet.</p>
    <?php else: ?>
        <div class="list-group">
            <?php foreach ($complaints as $c): ?>
                <div class="list-group-item">
                    <div class="d-flex justify-content-between">
                        <div>
                            <h6 class="mb-1"><?php echo htmlspecialchars($c['subject']); ?></h6>
                            <small class="text-muted"><?php echo htmlspecialchars($c['message']); ?></small>
                        </div>
                        <div class="text-end">
                            <span class="badge bg-info"><?php echo htmlspecialchars(ucfirst($c['status'])); ?></span>
                            <div><small><?php echo htmlspecialchars($c['created_at']); ?></small></div>
                        </div>
                    </div>
                </div>
            <?php endforeach; ?>
        </div>
    <?php endif; ?>

</div>
</body>
</html>
