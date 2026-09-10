<?php
require_once __DIR__ . '/config.php';
requireLogin();

if (isAdmin()) {
    header('Location: ../admin/index.php');
    exit();
}

$user_id = getCurrentUserId();
$user = getRecordById($conn, 'user_account', $user_id);

// Get the motorist record linked to this user account
$motorist = null;
$bikes = [];

if ($user) {
    // First try: user_account.motorist_id (set during registration)
    if (!empty($user['motorist_id'])) {
        $motorist = getRecordById($conn, 'motorists', $user['motorist_id']);
    }

    // Fallback: match by email (in case motorist_id wasn't stored)
    if (!$motorist && !empty($user['email'])) {
        $stmt = executeQuery($conn,
            "SELECT * FROM motorists WHERE email = ? LIMIT 1",
            's', [$user['email']]
        );
        if ($stmt) $motorist = $stmt->fetch_assoc();
    }

    // Fetch motorbikes for this motorist
    if ($motorist) {
        $bikeStmt = executeQuery($conn,
            "SELECT mb.*, hd.owner_name, hd.owner_phone, hd.hire_rate, hd.hire_start_date, hd.hire_end_date
             FROM motorbikes mb
             LEFT JOIN hire_details hd ON mb.id = hd.motorbike_id
             WHERE mb.motorist_id = ?
             ORDER BY mb.id ASC",
            'i', [$motorist['id']]
        );
        if ($bikeStmt) $bikes = $bikeStmt->fetch_all();
    }
}

function purposeLabel($purpose) {
    switch ($purpose) {
        case 'commercial':        return ['Commercial', 'danger'];
        case 'personal_transport': return ['Personal Transport', 'success'];
        case 'hire':              return ['On Hire', 'warning'];
        default:                  return [ucfirst($purpose), 'secondary'];
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My Profile - <?php echo defined('SITE_NAME') ? htmlspecialchars(SITE_NAME) : 'Motorist System'; ?></title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        body { background: #f4f6fb; }
        .profile-card { border-radius: 16px; box-shadow: 0 4px 24px rgba(44,62,80,0.10); }
        .profile-avatar {
            width: 80px; height: 80px; border-radius: 50%;
            background: linear-gradient(135deg, #2c3e50 0%, #3498db 100%);
            display: flex; align-items: center; justify-content: center;
            font-size: 2.2rem; color: white; margin: 0 auto 16px;
        }
        .section-title {
            font-size: 0.78rem; font-weight: 700; letter-spacing: 0.10em;
            text-transform: uppercase; color: #7b8fa1; margin-bottom: 14px;
        }
        .info-row { display: flex; align-items: flex-start; padding: 8px 0; border-bottom: 1px solid #f0f2f5; }
        .info-row:last-child { border-bottom: none; }
        .info-label { min-width: 155px; font-size: 0.85rem; color: #7b8fa1; font-weight: 600; }
        .info-value { font-size: 0.95rem; color: #2c3e50; word-break: break-word; }
        .bike-card {
            border-radius: 12px; border: 1.5px solid #e8edf3;
            background: #fafdff; margin-bottom: 14px; padding: 18px 20px;
            transition: box-shadow 0.2s;
        }
        .bike-card:hover { box-shadow: 0 4px 16px rgba(52,152,219,0.12); }
        .bike-reg {
            font-size: 1.05rem; font-weight: 700; color: #2c3e50;
            background: #eaf3fb; padding: 3px 12px; border-radius: 20px;
            display: inline-block; margin-bottom: 2px;
        }
        .hire-block { background: #fff8e7; border-left: 4px solid #f7d794; border-radius: 8px; padding: 12px 16px; margin-top: 10px; }
        .no-bike { color: #aab4be; text-align: center; padding: 30px 0; }
        .top-bar { background: linear-gradient(90deg, #2c3e50 0%, #3498db 100%); color: white; padding: 14px 24px; border-radius: 16px 16px 0 0; }
    </style>
</head>
<body>
<div class="container py-4">

    <!-- Top navigation -->
    <div class="d-flex justify-content-between align-items-center mb-3">
        <h5 class="mb-0 fw-bold" style="color:#2c3e50;">
            <i class="fas fa-motorcycle me-2 text-primary"></i>Motorist System
        </h5>
        <div class="d-flex gap-2">
            <a href="dashboard.php" class="btn btn-sm btn-outline-secondary"><i class="fas fa-home me-1"></i>Dashboard</a>
            <a href="edit_profile.php" class="btn btn-sm btn-outline-primary"><i class="fas fa-edit me-1"></i>Edit Profile</a>
            <a href="logout.php" class="btn btn-sm btn-danger"><i class="fas fa-sign-out-alt me-1"></i>Logout</a>
        </div>
    </div>

    <div class="row g-4">

        <!-- LEFT: Account + Personal Info -->
        <div class="col-lg-4">
            <div class="card profile-card border-0">
                <div class="top-bar text-center">
                    <div class="profile-avatar">
                        <i class="fas fa-user"></i>
                    </div>
                    <h5 class="mb-0 fw-bold"><?php echo htmlspecialchars($user['full_name']); ?></h5>
                    <small class="opacity-75"><?php echo htmlspecialchars($user['email']); ?></small>
                    <div class="mt-2">
                        <span class="badge bg-<?php echo $user['status'] === 'active' ? 'success' : 'danger'; ?>">
                            <?php echo ucfirst(htmlspecialchars($user['status'])); ?>
                        </span>
                        <span class="badge bg-light text-dark ms-1"><?php echo ucfirst(htmlspecialchars($user['role'])); ?></span>
                    </div>
                </div>

                <div class="card-body">
                    <!-- Account info -->
                    <div class="section-title mt-2"><i class="fas fa-id-card me-1"></i>Account Information</div>
                    <div class="info-row">
                        <span class="info-label">Full Name</span>
                        <span class="info-value"><?php echo htmlspecialchars($user['full_name']); ?></span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Email</span>
                        <span class="info-value"><?php echo htmlspecialchars($user['email']); ?></span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Member Since</span>
                        <span class="info-value"><?php echo date('d M Y', strtotime($user['created_at'])); ?></span>
                    </div>

                    <?php if ($motorist): ?>
                    <!-- Motorist / personal info -->
                    <div class="section-title mt-4"><i class="fas fa-user-tie me-1"></i>Personal Information</div>
                    <div class="info-row">
                        <span class="info-label">License Number</span>
                        <span class="info-value"><code><?php echo htmlspecialchars($motorist['license_number']); ?></code></span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Phone</span>
                        <span class="info-value"><?php echo htmlspecialchars($motorist['phone_number']); ?></span>
                    </div>
                    <?php if (!empty($motorist['address'])): ?>
                    <div class="info-row">
                        <span class="info-label">Address</span>
                        <span class="info-value"><?php echo htmlspecialchars($motorist['address']); ?></span>
                    </div>
                    <?php endif; ?>
                    <div class="info-row">
                        <span class="info-label">Registered</span>
                        <span class="info-value"><?php echo date('d M Y', strtotime($motorist['date_registered'])); ?></span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Status</span>
                        <span class="info-value">
                            <span class="badge bg-<?php echo $motorist['status'] === 'active' ? 'success' : ($motorist['status'] === 'suspended' ? 'danger' : 'secondary'); ?>">
                                <?php echo ucfirst(htmlspecialchars($motorist['status'])); ?>
                            </span>
                        </span>
                    </div>
                    <?php else: ?>
                    <div class="alert alert-warning mt-3 py-2 px-3" style="font-size:0.87rem;">
                        <i class="fas fa-exclamation-triangle me-1"></i>
                        No motorist record linked to this account yet. Contact the admin.
                    </div>
                    <?php endif; ?>
                </div>
            </div>
        </div>

        <!-- RIGHT: Motorbike(s) -->
        <div class="col-lg-8">
            <div class="card profile-card border-0">
                <div class="card-body">
                    <div class="d-flex justify-content-between align-items-center mb-3">
                        <div class="section-title mb-0"><i class="fas fa-motorcycle me-1"></i>My Motorbike(s)</div>
                        <span class="badge bg-primary rounded-pill"><?php echo count($bikes); ?> registered</span>
                    </div>

                    <?php if (empty($bikes)): ?>
                    <div class="no-bike">
                        <i class="fas fa-motorcycle fa-3x mb-3 d-block"></i>
                        <p class="mb-0">No motorbikes registered to your account yet.</p>
                        <small>Contact the admin to have your motorbike(s) added.</small>
                    </div>
                    <?php else: ?>
                    <?php foreach ($bikes as $bike):
                        [$purposeText, $purposeColor] = purposeLabel($bike['purpose']);
                    ?>
                    <div class="bike-card">
                        <div class="d-flex justify-content-between align-items-start flex-wrap gap-2">
                            <div>
                                <span class="bike-reg"><?php echo htmlspecialchars($bike['registration_number']); ?></span>
                                <span class="ms-2 fw-semibold" style="color:#2c3e50;">
                                    <?php echo htmlspecialchars($bike['brand'] . ' ' . $bike['model']); ?>
                                </span>
                            </div>
                            <div class="d-flex gap-2 flex-wrap">
                                <span class="badge bg-<?php echo $purposeColor; ?> text-<?php echo $purposeColor === 'warning' ? 'dark' : 'white'; ?>">
                                    <?php echo $purposeText; ?>
                                </span>
                                <span class="badge bg-<?php echo $bike['status'] === 'active' ? 'success' : 'secondary'; ?>">
                                    <?php echo ucfirst(htmlspecialchars($bike['status'])); ?>
                                </span>
                            </div>
                        </div>

                        <div class="row mt-3 g-2">
                            <div class="col-sm-6 col-md-4">
                                <div class="info-row">
                                    <span class="info-label">Colour</span>
                                    <span class="info-value"><?php echo htmlspecialchars($bike['color'] ?: 'N/A'); ?></span>
                                </div>
                            </div>
                            <div class="col-sm-6 col-md-4">
                                <div class="info-row">
                                    <span class="info-label">Year</span>
                                    <span class="info-value"><?php echo htmlspecialchars($bike['manufacture_year'] ?: 'N/A'); ?></span>
                                </div>
                            </div>
                            <div class="col-sm-6 col-md-4">
                                <div class="info-row">
                                    <span class="info-label">Use Type</span>
                                    <span class="info-value">
                                        <span class="badge bg-<?php echo $purposeColor; ?> text-<?php echo $purposeColor === 'warning' ? 'dark' : 'white'; ?>">
                                            <?php echo $purposeText; ?>
                                        </span>
                                    </span>
                                </div>
                            </div>
                        </div>

                        <?php if ($bike['purpose'] === 'hire' && !empty($bike['owner_name'])): ?>
                        <div class="hire-block">
                            <div class="fw-semibold mb-2" style="font-size:0.85rem;color:#b8860b;">
                                <i class="fas fa-hand-holding-usd me-1"></i>Hire Details
                            </div>
                            <div class="row g-1">
                                <div class="col-sm-4">
                                    <small class="text-muted d-block">Owner</small>
                                    <span style="font-size:0.9rem;"><?php echo htmlspecialchars($bike['owner_name']); ?></span>
                                </div>
                                <div class="col-sm-4">
                                    <small class="text-muted d-block">Owner Phone</small>
                                    <span style="font-size:0.9rem;"><?php echo htmlspecialchars($bike['owner_phone'] ?? 'N/A'); ?></span>
                                </div>
                                <div class="col-sm-4">
                                    <small class="text-muted d-block">Rate/Day</small>
                                    <span style="font-size:0.9rem;">
                                        KES <?php echo number_format((float)($bike['hire_rate'] ?? 0), 2); ?>
                                    </span>
                                </div>
                                <?php if (!empty($bike['hire_start_date'])): ?>
                                <div class="col-sm-6 mt-1">
                                    <small class="text-muted d-block">Hire Start</small>
                                    <span style="font-size:0.9rem;"><?php echo date('d M Y', strtotime($bike['hire_start_date'])); ?></span>
                                </div>
                                <?php endif; ?>
                                <?php if (!empty($bike['hire_end_date'])): ?>
                                <div class="col-sm-6 mt-1">
                                    <small class="text-muted d-block">Hire End</small>
                                    <span style="font-size:0.9rem;"><?php echo date('d M Y', strtotime($bike['hire_end_date'])); ?></span>
                                </div>
                                <?php endif; ?>
                            </div>
                        </div>
                        <?php endif; ?>
                    </div>
                    <?php endforeach; ?>
                    <?php endif; ?>
                </div>
            </div>
        </div>

    </div>
</div>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
