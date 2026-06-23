<?php
require_once 'config.php';

$search_results = [];
$search_term = '';

if (isset($_GET['search']) && !empty($_GET['search'])) {
    $search_term = $_GET['search'];
    $like = '%' . $search_term . '%';
    $sql = "SELECT m.*, mb.*, hd.*
            FROM motorists m
            LEFT JOIN motorbikes mb ON m.id = mb.motorist_id
            LEFT JOIN hire_details hd ON mb.id = hd.motorbike_id
            WHERE m.full_name LIKE ?
               OR m.license_number LIKE ?
               OR mb.registration_number LIKE ?
               OR mb.brand LIKE ?";
    $search_results = executeQuery($conn, $sql, '', [$like, $like, $like, $like]);
}

$total_motorists = $conn->query("SELECT COUNT(*) as count FROM motorists")->fetch_assoc()['count'];
$total_motorbikes = $conn->query("SELECT COUNT(*) as count FROM motorbikes")->fetch_assoc()['count'];
$commercial_count = $conn->query("SELECT COUNT(*) as count FROM motorbikes WHERE purpose='commercial'")->fetch_assoc()['count'];
$hire_count = $conn->query("SELECT COUNT(*) as count FROM motorbikes WHERE purpose='hire'")->fetch_assoc()['count'];
$personal_count = $conn->query("SELECT COUNT(*) as count FROM motorbikes WHERE purpose='personal_transport'")->fetch_assoc()['count'];
$admin_name = $_SESSION['user_name'] ?? 'Admin';
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Motorist Management System - Dashboard</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        .sidebar { min-height: 100vh; background: linear-gradient(180deg, #2c3e50 0%, #3498db 100%); }
        .sidebar a { color: white; padding: 15px; text-decoration: none; display: block; transition: 0.3s; }
        .sidebar a:hover { background: rgba(255,255,255,0.1); padding-left: 25px; }
        .sidebar a.active { background: rgba(255,255,255,0.2); border-left: 4px solid #f1c40f; }
        .stat-card { transition: transform 0.3s; border: none; border-radius: 15px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .stat-card:hover { transform: translateY(-5px); }
        .purpose-badge { padding: 5px 10px; border-radius: 20px; font-size: 0.8rem; font-weight: bold; }
        .purpose-commercial { background: #ff6b6b; color: white; }
        .purpose-transport { background: #4ecdc4; color: white; }
        .purpose-hire { background: #f7d794; color: #2c3e50; }
    </style>
</head>
<body>
    <div class="container-fluid">
        <div class="row">
            <div class="col-md-2 p-0 sidebar">
                <div class="text-center py-4">
                    <i class="fas fa-motorcycle fa-3x text-white"></i>
                    <h5 class="text-white mt-2">Motorist System</h5>
                </div>
                <a href="index.php" class="active"><i class="fas fa-dashboard me-2"></i> Dashboard</a>
                <a href="add_motorist.php"><i class="fas fa-user-plus me-2"></i> Add Motorist</a>
                <a href="add_motorbike.php"><i class="fas fa-plus-circle me-2"></i> Add Motorbike</a>
                <a href="view_motorists.php"><i class="fas fa-users me-2"></i> View All</a>
                <a href="reports.php"><i class="fas fa-chart-bar me-2"></i> Reports</a>
                <a href="user_communications.php"><i class="fas fa-envelope-open-text me-2"></i> User Communications</a>
                <a href="profile.php"><i class="fas fa-user-circle me-2"></i> Profile</a>
                <a href="logout.php"><i class="fas fa-sign-out-alt me-2"></i> Logout</a>
            </div>

            <div class="col-md-10 p-4">
                <h2 class="mb-4"><i class="fas fa-dashboard me-2"></i>Dashboard</h2>
                <p class="text-muted">Logged in as <?php echo htmlspecialchars($admin_name); ?>.</p>

                <div class="row mb-4">
                    <div class="col-md-8">
                        <form action="" method="GET" class="d-flex">
                            <input type="text" name="search" class="form-control me-2"
                                   placeholder="Search by name, license, or registration..."
                                   value="<?php echo htmlspecialchars($search_term); ?>">
                            <button type="submit" class="btn btn-primary">
                                <i class="fas fa-search"></i> Search
                            </button>
                        </form>
                    </div>
                </div>

                <div class="row mb-4">
                    <div class="col-md-3 mb-3">
                        <div class="card stat-card bg-primary text-white">
                            <div class="card-body">
                                <h5 class="card-title">Total Motorists</h5>
                                <h2 class="mb-0"><?php echo $total_motorists; ?></h2>
                                <i class="fas fa-users fa-2x position-absolute top-50 end-0 translate-middle-y me-3 opacity-50"></i>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-3 mb-3">
                        <div class="card stat-card bg-success text-white">
                            <div class="card-body">
                                <h5 class="card-title">Total Motorbikes</h5>
                                <h2 class="mb-0"><?php echo $total_motorbikes; ?></h2>
                                <i class="fas fa-motorcycle fa-2x position-absolute top-50 end-0 translate-middle-y me-3 opacity-50"></i>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-3 mb-3">
                        <div class="card stat-card bg-warning text-white">
                            <div class="card-body">
                                <h5 class="card-title">Commercial</h5>
                                <h2 class="mb-0"><?php echo $commercial_count; ?></h2>
                                <i class="fas fa-briefcase fa-2x position-absolute top-50 end-0 translate-middle-y me-3 opacity-50"></i>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-3 mb-3">
                        <div class="card stat-card bg-info text-white">
                            <div class="card-body">
                                <h5 class="card-title">On Hire</h5>
                                <h2 class="mb-0"><?php echo $hire_count; ?></h2>
                                <i class="fas fa-hand-holding-usd fa-2x position-absolute top-50 end-0 translate-middle-y me-3 opacity-50"></i>
                            </div>
                        </div>
                    </div>
                </div>

                <?php if (isset($_GET['search'])): ?>
                <div class="card">
                    <div class="card-header bg-dark text-white">
                        <h5 class="mb-0">Search Results for "<?php echo htmlspecialchars($search_term); ?>"</h5>
                    </div>
                    <div class="card-body">
                        <?php if ($search_results && $search_results->num_rows > 0): ?>
                            <div class="table-responsive">
                                <table class="table table-hover">
                                    <thead>
                                        <tr>
                                            <th>Motorist Name</th>
                                            <th>License</th>
                                            <th>Phone</th>
                                            <th>Registration</th>
                                            <th>Brand/Model</th>
                                            <th>Purpose</th>
                                            <th>Hire Owner</th>
                                            <th>Actions</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <?php while($row = $search_results->fetch_assoc()): ?>
                                        <tr>
                                            <td><?php echo htmlspecialchars($row['full_name']); ?></td>
                                            <td><?php echo htmlspecialchars($row['license_number']); ?></td>
                                            <td><?php echo htmlspecialchars($row['phone_number']); ?></td>
                                            <td><?php echo htmlspecialchars($row['registration_number'] ?? 'N/A'); ?></td>
                                            <td>
                                                <?php if($row['brand']): ?>
                                                    <?php echo htmlspecialchars($row['brand'] . ' ' . $row['model']); ?>
                                                <?php else: ?>
                                                    <span class="text-muted">No bike</span>
                                                <?php endif; ?>
                                            </td>
                                            <td>
                                                <?php if($row['purpose']): ?>
                                                    <span class="purpose-badge purpose-<?php
                                                        echo $row['purpose'] == 'commercial' ? 'commercial' :
                                                            ($row['purpose'] == 'personal_transport' ? 'transport' : 'hire'); ?>">
                                                        <?php
                                                        echo $row['purpose'] == 'commercial' ? 'Commercial' :
                                                            ($row['purpose'] == 'personal_transport' ? 'Transport' : 'On Hire');
                                                        ?>
                                                    </span>
                                                <?php endif; ?>
                                            </td>
                                            <td>
                                                <?php if($row['owner_name']): ?>
                                                    <small><?php echo htmlspecialchars($row['owner_name']); ?><br>
                                                    <?php echo htmlspecialchars($row['owner_phone']); ?></small>
                                                <?php else: ?>
                                                    <span class="text-muted">N/A</span>
                                                <?php endif; ?>
                                            </td>
                                            <td>
                                                <a href="view_motorist.php?id=<?php echo $row['id']; ?>" class="btn btn-sm btn-info">
                                                    <i class="fas fa-eye"></i>
                                                </a>
                                            </td>
                                        </tr>
                                        <?php endwhile; ?>
                                    </tbody>
                                </table>
                            </div>
                        <?php else: ?>
                            <p class="text-muted mb-0">No results found.</p>
                        <?php endif; ?>
                    </div>
                </div>
                <?php endif; ?>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
