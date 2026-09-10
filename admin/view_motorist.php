<?php
require_once 'config.php';

$id = isset($_GET['id']) ? (int)$_GET['id'] : 0;

$motorist = getRecordById($conn, 'motorists', $id);

if (!$motorist) {
    header('Location: view_motorists.php');
    exit();
}

$bikes_sql = "SELECT mb.*, hd.*
              FROM motorbikes mb
              LEFT JOIN hire_details hd ON mb.id = hd.motorbike_id
              WHERE mb.motorist_id = ?";
$bikes = executeQuery($conn, $bikes_sql, 'i', [$id]);
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>View Motorist - <?php echo htmlspecialchars($motorist['full_name']); ?></title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        .sidebar { min-height: 100vh; background: linear-gradient(180deg, #2c3e50 0%, #3498db 100%); }
        .sidebar a { color: white; padding: 15px; text-decoration: none; display: block; transition: 0.3s; }
        .sidebar a:hover { background: rgba(255,255,255,0.1); padding-left: 25px; }
        .sidebar a.active { background: rgba(255,255,255,0.2); border-left: 4px solid #f1c40f; }
        .detail-card { background: white; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); padding: 20px; margin-bottom: 20px; }
        .purpose-badge { padding: 5px 15px; border-radius: 25px; font-weight: bold; display: inline-block; }
        .purpose-commercial { background: #ff6b6b; color: white; }
        .purpose-transport { background: #4ecdc4; color: white; }
        .purpose-hire { background: #f7d794; color: #2c3e50; }
        .hire-details { background: #f8f9fa; padding: 15px; border-radius: 8px; border-left: 4px solid #f7d794; margin-top: 10px; }
    </style>
</head>
<body>
    <div class="container-fluid">
        <div class="row">
            <?php require_once __DIR__ . '/sidebar.php'; ?>
            <div class="col-md-10 p-4">
                <div class="d-flex justify-content-between align-items-center mb-4">
                    <h2><i class="fas fa-user-circle me-2"></i>Motorist Details</h2>
                    <a href="view_motorists.php" class="btn btn-secondary">
                        <i class="fas fa-arrow-left me-2"></i>Back to List
                    </a>
                </div>

                <div class="detail-card">
                    <h4 class="mb-3">Personal Information</h4>
                    <div class="row">
                        <div class="col-md-6">
                            <p><strong>Full Name:</strong> <?php echo htmlspecialchars($motorist['full_name']); ?></p>
                            <p><strong>License Number:</strong> <?php echo htmlspecialchars($motorist['license_number']); ?></p>
                            <p><strong>Phone:</strong> <?php echo htmlspecialchars($motorist['phone_number']); ?></p>
                        </div>
                        <div class="col-md-6">
                            <p><strong>Email:</strong> <?php echo htmlspecialchars($motorist['email'] ?: 'Not provided'); ?></p>
                            <p><strong>Address:</strong> <?php echo htmlspecialchars($motorist['address'] ?: 'Not provided'); ?></p>
                            <p><strong>Registered:</strong> <?php echo date('d M Y', strtotime($motorist['date_registered'])); ?></p>
                        </div>
                    </div>
                </div>

                <div class="detail-card">
                    <h4 class="mb-3">Motorbikes Owned</h4>

                    <?php if($bikes && $bikes->num_rows > 0): ?>
                        <?php while($bike = $bikes->fetch_assoc()): ?>
                            <div class="border rounded p-3 mb-3">
                                <div class="row">
                                    <div class="col-md-8">
                                        <h5>
                                            <?php echo htmlspecialchars($bike['brand'] . ' ' . $bike['model']); ?>
                                            <span class="badge bg-secondary ms-2"><?php echo htmlspecialchars($bike['registration_number']); ?></span>
                                        </h5>
                                        <p class="mb-1">
                                            <strong>Color:</strong> <?php echo htmlspecialchars($bike['color'] ?: 'N/A'); ?> |
                                            <strong>Year:</strong> <?php echo htmlspecialchars($bike['manufacture_year']); ?>
                                        </p>
                                        <p>
                                            <strong>Purpose:</strong>
                                            <span class="purpose-badge purpose-<?php
                                                echo $bike['purpose'] == 'commercial' ? 'commercial' :
                                                    ($bike['purpose'] == 'personal_transport' ? 'transport' : 'hire'); ?>">
                                                <?php
                                                echo $bike['purpose'] == 'commercial' ? 'Commercial' :
                                                    ($bike['purpose'] == 'personal_transport' ? 'Personal Transport' : 'On Hire');
                                                ?>
                                            </span>
                                        </p>
                                    </div>
                                    <div class="col-md-4">
                                        <span class="badge bg-<?php echo $bike['status'] == 'active' ? 'success' : 'danger'; ?>">
                                            <?php echo ucfirst($bike['status']); ?>
                                        </span>
                                    </div>
                                </div>

                                <?php if($bike['purpose'] == 'hire' && $bike['owner_name']): ?>
                                <div class="hire-details">
                                    <h6 class="mb-2"><i class="fas fa-hand-holding-usd me-2"></i>Hire/Owner Details</h6>
                                    <div class="row">
                                        <div class="col-md-4">
                                            <small><strong>Owner:</strong> <?php echo htmlspecialchars($bike['owner_name']); ?></small>
                                        </div>
                                        <div class="col-md-4">
                                            <small><strong>Phone:</strong> <?php echo htmlspecialchars($bike['owner_phone']); ?></small>
                                        </div>
                                        <div class="col-md-4">
                                            <small><strong>Email:</strong> <?php echo htmlspecialchars($bike['owner_email'] ?: 'N/A'); ?></small>
                                        </div>
                                    </div>
                                    <div class="row mt-2">
                                        <div class="col-md-4">
                                            <small><strong>Hire Rate:</strong> KES <?php echo number_format($bike['hire_rate'], 2); ?>/day</small>
                                        </div>
                                        <div class="col-md-4">
                                            <small><strong>Start Date:</strong> <?php echo date('d M Y', strtotime($bike['hire_start_date'])); ?></small>
                                        </div>
                                        <div class="col-md-4">
                                            <small><strong>End Date:</strong> <?php echo date('d M Y', strtotime($bike['hire_end_date'])); ?></small>
                                        </div>
                                    </div>
                                    <?php if($bike['owner_address']): ?>
                                    <small class="d-block mt-2"><strong>Address:</strong> <?php echo htmlspecialchars($bike['owner_address']); ?></small>
                                    <?php endif; ?>
                                </div>
                                <?php endif; ?>
                            </div>
                        <?php endwhile; ?>
                    <?php else: ?>
                        <p class="text-muted">No motorbikes registered for this motorist.</p>
                    <?php endif; ?>

                    <a href="add_motorbike.php?motorist_id=<?php echo $id; ?>" class="btn btn-primary mt-2">
                        <i class="fas fa-plus-circle me-2"></i>Add Motorbike
                    </a>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
