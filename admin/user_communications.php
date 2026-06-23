<?php
require_once __DIR__ . '/config.php';

$users = getAllUserAccounts($conn);
$complaints = getAllComplaints($conn);
$errors = [];
$success = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $user_id = isset($_POST['user_id']) ? (int)$_POST['user_id'] : 0;
    $title = sanitize($_POST['title'] ?? '');
    $amount = filter_var($_POST['amount'] ?? '', FILTER_VALIDATE_FLOAT);
    $description = sanitize($_POST['description'] ?? '');
    $issued_by = sanitize($_POST['issued_by'] ?? ($_SESSION['user_name'] ?? 'System Admin'));

    if ($user_id <= 0) {
        $errors[] = 'Please select a valid user.';
    }
    if (empty($title)) {
        $errors[] = 'Receipt title is required.';
    }
    if ($amount === false || $amount < 0) {
        $errors[] = 'Please enter a valid receipt amount.';
    }
    if (empty($description)) {
        $errors[] = 'Receipt description is required.';
    }

    $user = getUserAccountById($conn, $user_id);

    if (!$user) {
        $errors[] = 'Selected user was not found.';
    }

    if (empty($errors)) {
        if (createReceipt($conn, $user_id, $title, $amount, $description, $issued_by)) {
            $success = 'Receipt sent successfully.';

            if (!empty($user['email'])) {
                $to = $user['email'];
                $subject = 'New receipt issued: ' . $title;
                $body = '<p>Dear ' . htmlspecialchars($user['full_name']) . ',</p>';
                $body .= '<p>A new receipt has been issued to your account.</p>';
                $body .= '<p><strong>Title:</strong> ' . htmlspecialchars($title) . '</p>';
                $body .= '<p><strong>Amount:</strong> ' . number_format($amount, 2) . '</p>';
                $body .= '<p><strong>Description:</strong><br>' . nl2br(htmlspecialchars($description)) . '</p>';
                $body .= '<p>Issued by: ' . htmlspecialchars($issued_by) . '</p>';
                $body .= '<p>Regards,<br>' . SITE_NAME . '</p>';
                sendEmailNotification($to, $subject, $body);
            }

            header('Location: user_communications.php?success=1');
            exit;
        }

        $errors[] = 'Failed to send receipt. Please try again.';
    }
}

if (isset($_GET['success']) && $_GET['success'] == '1') {
    $success = 'Receipt sent successfully.';
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>User Communications - Admin</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        .sidebar { min-height: 100vh; background: linear-gradient(180deg, #2c3e50 0%, #3498db 100%); }
        .sidebar a { color: white; padding: 15px; text-decoration: none; display: block; transition: 0.3s; }
        .sidebar a:hover { background: rgba(255,255,255,0.1); padding-left: 25px; }
        .sidebar a.active { background: rgba(255,255,255,0.2); border-left: 4px solid #f1c40f; }
    </style>
</head>
<body>
    <div class="container-fluid">
        <div class="row">
            <?php require_once __DIR__ . '/sidebar.php'; ?>
            <div class="col-md-10 p-4">
                <div class="d-flex justify-content-between align-items-center mb-4">
                    <h2><i class="fas fa-envelope-open-text me-2"></i> User Communications</h2>
                    <div>Logged in as <?php echo htmlspecialchars($_SESSION['user_name'] ?? 'Admin'); ?></div>
                </div>

                <?php if (!empty($success)): ?>
                    <div class="alert alert-success"><?php echo htmlspecialchars($success); ?></div>
                <?php endif; ?>
                <?php if (!empty($errors)): ?>
                    <div class="alert alert-danger">
                        <ul class="mb-0">
                            <?php foreach ($errors as $error): ?>
                                <li><?php echo htmlspecialchars($error); ?></li>
                            <?php endforeach; ?>
                        </ul>
                    </div>
                <?php endif; ?>

                <div class="row">
                    <div class="col-lg-6 mb-4">
                        <div class="card shadow-sm">
                            <div class="card-header bg-primary text-white">
                                <h5 class="mb-0">Send Receipt to User</h5>
                            </div>
                            <div class="card-body">
                                <form method="post" action="user_communications.php">
                                    <div class="mb-3">
                                        <label for="user_id" class="form-label">Select User</label>
                                        <select name="user_id" id="user_id" class="form-select" required>
                                            <option value="">Choose user</option>
                                            <?php foreach ($users as $user): ?>
                                                <option value="<?php echo htmlspecialchars($user['id']); ?>"><?php echo htmlspecialchars($user['full_name'] . ' (' . $user['email'] . ')'); ?></option>
                                            <?php endforeach; ?>
                                        </select>
                                    </div>
                                    <div class="mb-3">
                                        <label for="title" class="form-label">Receipt Title</label>
                                        <input type="text" name="title" id="title" class="form-control" value="<?php echo htmlspecialchars($_POST['title'] ?? ''); ?>" required>
                                    </div>
                                    <div class="mb-3">
                                        <label for="amount" class="form-label">Amount</label>
                                        <input type="number" step="0.01" name="amount" id="amount" class="form-control" value="<?php echo htmlspecialchars($_POST['amount'] ?? ''); ?>" required>
                                    </div>
                                    <div class="mb-3">
                                        <label for="description" class="form-label">Description</label>
                                        <textarea name="description" id="description" class="form-control" rows="4" required><?php echo htmlspecialchars($_POST['description'] ?? ''); ?></textarea>
                                    </div>
                                    <div class="mb-3">
                                        <label for="issued_by" class="form-label">Issued By</label>
                                        <input type="text" name="issued_by" id="issued_by" class="form-control" value="<?php echo htmlspecialchars($_POST['issued_by'] ?? ($_SESSION['user_name'] ?? 'System Admin')); ?>">
                                    </div>
                                    <button type="submit" class="btn btn-success">Send Receipt</button>
                                </form>
                            </div>
                        </div>
                    </div>

                    <div class="col-lg-6 mb-4">
                        <div class="card shadow-sm">
                            <div class="card-header bg-warning text-dark">
                                <h5 class="mb-0">Recent User Complaints</h5>
                            </div>
                            <div class="card-body">
                                <?php if (count($complaints) === 0): ?>
                                    <p class="text-muted mb-0">No complaints have been submitted yet.</p>
                                <?php else: ?>
                                    <div class="table-responsive">
                                        <table class="table table-bordered table-sm">
                                            <thead>
                                                <tr>
                                                    <th>ID</th>
                                                    <th>User</th>
                                                    <th>Subject</th>
                                                    <th>Status</th>
                                                    <th>Date</th>
                                                    <th>Action</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                <?php foreach ($complaints as $complaint): ?>
                                                    <tr>
                                                        <td><?php echo htmlspecialchars($complaint['id']); ?></td>
                                                        <td><?php echo htmlspecialchars($complaint['full_name'] ?? 'Guest'); ?></td>
                                                        <td><?php echo htmlspecialchars($complaint['subject']); ?></td>
                                                        <td><?php echo htmlspecialchars($complaint['status']); ?></td>
                                                        <td><?php echo htmlspecialchars($complaint['created_at']); ?></td>
                                                        <td><a href="complaint.php?id=<?php echo urlencode($complaint['id']); ?>" class="btn btn-sm btn-primary">View</a></td>
                                                    </tr>
                                                <?php endforeach; ?>
                                            </tbody>
                                        </table>
                                    </div>
                                <?php endif; ?>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
