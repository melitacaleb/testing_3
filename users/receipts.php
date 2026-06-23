<?php
require_once __DIR__ . '/config.php';
requireLogin();
$user_id = getCurrentUserId();
$receipts = getUserReceipts($conn, $user_id);
?>
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>My Receipts - <?php echo SITE_NAME; ?></title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
</head>
<body class="bg-light">
<div class="container py-4">
    <div class="d-flex justify-content-between align-items-center mb-3">
        <h3>My Receipts</h3>
        <div>
            <a href="dashboard.php" class="btn btn-secondary">Dashboard</a>
            <a href="logout.php" class="btn btn-danger">Logout</a>
        </div>
    </div>
    <?php if (empty($receipts)): ?>
        <p class="text-muted">You have no receipts.</p>
    <?php else: ?>
        <div class="list-group">
            <?php foreach ($receipts as $r): ?>
                <div class="list-group-item">
                    <div class="d-flex justify-content-between">
                        <div>
                            <h6 class="mb-1"><?php echo htmlspecialchars($r['title']); ?></h6>
                            <small class="text-muted"><?php echo htmlspecialchars($r['description']); ?></small>
                        </div>
                        <div class="text-end">
                            <strong>KES <?php echo number_format($r['amount'],2); ?></strong>
                            <div><small><?php echo htmlspecialchars($r['created_at']); ?></small></div>
                        </div>
                    </div>
                </div>
            <?php endforeach; ?>
        </div>
    <?php endif; ?>
</div>
</body>
</html>
