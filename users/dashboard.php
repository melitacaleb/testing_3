<?php
require_once __DIR__ . '/config.php';
requireLogin();

if (isAdmin()) {
    header('Location: ../admin/index.php');
    exit();
}

$user_id = getCurrentUserId();
$user = getRecordById($conn, 'user_account', $user_id);
$receipts = getUserReceipts($conn, $user_id);
$citations = getUserCitations($conn, $user_id);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>User Dashboard - <?php echo SITE_NAME; ?></title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
</head>
<body class="bg-light">
    <div class="container py-4">
        <div class="d-flex justify-content-between align-items-center mb-4">
            <div>
                <h1 class="h3">Welcome, <?php echo htmlspecialchars($user['full_name']); ?></h1>
                <p class="text-muted">Here is your account activity and any receipts or citations issued by the admin.</p>
            </div>
            <div>
                <a href="receipts.php" class="btn btn-outline-secondary me-2">My Receipts</a>
                <a href="complaints.php" class="btn btn-outline-secondary me-2">My Complaints</a>
                <a href="profile.php" class="btn btn-outline-primary me-2">Profile</a>
                <a href="logout.php" class="btn btn-danger">Logout</a>
            </div>
        </div>

        <div class="row gy-4">
            <div class="col-md-6">
                <div class="card shadow-sm">
                    <div class="card-body">
                        <h5 class="card-title">Account Summary</h5>
                        <p class="mb-2"><strong>Email:</strong> <?php echo htmlspecialchars($user['email']); ?></p>
                        <p class="mb-2"><strong>Role:</strong> <?php echo htmlspecialchars($user['role']); ?></p>
                        <p class="mb-0"><strong>Status:</strong> <?php echo htmlspecialchars($user['status']); ?></p>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card shadow-sm border-start border-4 border-primary">
                    <div class="card-body">
                        <h6 class="card-subtitle mb-2 text-muted">Receipts</h6>
                        <h2><?php echo count($receipts); ?></h2>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card shadow-sm border-start border-4 border-warning">
                    <div class="card-body">
                        <h6 class="card-subtitle mb-2 text-muted">Citations</h6>
                        <h2><?php echo count($citations); ?></h2>
                    </div>
                </div>
            </div>
        </div>

        <div class="row gy-4 mt-4">
            <div class="col-lg-6">
                <div class="card shadow-sm">
                    <div class="card-body">
                        <h5 class="card-title">Recent Receipts</h5>
                        <?php if (empty($receipts)): ?>
                            <p class="text-muted mb-0">You do not have any receipts yet.</p>
                        <?php else: ?>
                            <div class="list-group">
                                <?php foreach ($receipts as $receipt): ?>
                                    <div class="list-group-item">
                                        <div class="d-flex justify-content-between">
                                            <div>
                                                <h6 class="mb-1"><?php echo htmlspecialchars($receipt['title']); ?></h6>
                                                <small class="text-muted"><?php echo htmlspecialchars($receipt['description']); ?></small>
                                            </div>
                                            <div class="text-end">
                                                <span class="badge bg-success">KES <?php echo number_format($receipt['amount'], 2); ?></span>
                                                <div><small><?php echo htmlspecialchars($receipt['created_at']); ?></small></div>
                                            </div>
                                        </div>
                                    </div>
                                <?php endforeach; ?>
                            </div>
                        <?php endif; ?>
                    </div>
                </div>
            </div>
            <div class="col-lg-6">
                <div class="card shadow-sm">
                    <div class="card-body">
                        <h5 class="card-title">Recent Citations</h5>
                        <?php if (empty($citations)): ?>
                            <p class="text-muted mb-0">You do not have any citations at this time.</p>
                        <?php else: ?>
                            <div class="list-group">
                                <?php foreach ($citations as $citation): ?>
                                    <div class="list-group-item">
                                        <div class="d-flex justify-content-between">
                                            <div>
                                                <h6 class="mb-1"><?php echo htmlspecialchars($citation['violation']); ?></h6>
                                                <small class="text-muted"><?php echo htmlspecialchars($citation['notes']); ?></small>
                                            </div>
                                            <div class="text-end">
                                                <span class="badge bg-warning"><?php echo htmlspecialchars(ucfirst($citation['status'])); ?></span>
                                                <div><small><?php echo htmlspecialchars($citation['issued_at']); ?></small></div>
                                            </div>
                                        </div>
                                    </div>
                                <?php endforeach; ?>
                            </div>
                        <?php endif; ?>
                    </div>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
