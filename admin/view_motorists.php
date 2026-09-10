<?php
require_once 'config.php';

error_reporting(E_ALL);

// Handle Delete Action via GET request
if (isset($_GET['action']) && $_GET['action'] == 'delete' && isset($_GET['id'])) {
    $id = (int)$_GET['id'];

    $conn->begin_transaction();

    try {
        $motorist = getRecordById($conn, 'motorists', $id);
        if (!$motorist) {
            throw new Exception("Motorist not found");
        }

        $stmt = executeQuery($conn, "DELETE FROM motorists WHERE id = ?", 'i', [$id]);

        if (!$stmt) {
            throw new Exception("Error deleting motorist");
        }

        $conn->commit();

        logActivity($conn, 'DELETE', "Deleted motorist: " . $motorist['full_name']);

        setFlashMessage('motorist_action', 'Motorist deleted successfully!', 'success');
    } catch (Exception $e) {
        $conn->rollback();
        setFlashMessage('motorist_action', $e->getMessage(), 'danger');
    }

    header('Location: view_motorists.php');
    exit();
}

// Handle AJAX Delete Request
if (isset($_POST['action']) && $_POST['action'] == 'ajax_delete' && isset($_POST['id'])) {
    header('Content-Type: application/json');

    $id = (int)$_POST['id'];
    $response = ['success' => false, 'message' => ''];

    $conn->begin_transaction();

    try {
        $motorist = getRecordById($conn, 'motorists', $id);
        if (!$motorist) {
            throw new Exception("Motorist not found");
        }

        $stmt = executeQuery($conn, "DELETE FROM motorists WHERE id = ?", 'i', [$id]);

        if (!$stmt) {
            throw new Exception("Error deleting motorist");
        }

        $conn->commit();

        $response['success'] = true;
        $response['message'] = "Motorist deleted successfully!";

        logActivity($conn, 'DELETE', "Deleted motorist: " . $motorist['full_name']);
    } catch (Exception $e) {
        $conn->rollback();
        $response['message'] = $e->getMessage();
    }

    echo json_encode($response);
    exit();
}

// Pagination
$page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
$limit = 10;
$offset = ($page - 1) * $limit;

// Search functionality
$search = isset($_GET['search']) ? sanitize($_GET['search']) : '';
$where_clause = '';
$params = [];

if (!empty($search)) {
    $where_clause = " WHERE m.full_name LIKE ? OR m.license_number LIKE ? OR m.phone_number LIKE ? OR m.email LIKE ?";
    $search_term = "%$search%";
    $params = [$search_term, $search_term, $search_term, $search_term];
}

$count_sql = "SELECT COUNT(DISTINCT m.id) as count FROM motorists m" . $where_clause;
$count_stmt = executeQuery($conn, $count_sql, '', $params);
$total_records = 0;

if ($count_stmt) {
    $total_records = (int) $count_stmt->fetch_assoc()['count'];
}
$total_pages = (int) ceil($total_records / $limit);

// Fetch motorists with their motorbikes (GROUP_CONCAT -> string_agg for Postgres)
$sql = "SELECT m.*,
               COUNT(mb.id) as bike_count,
               string_agg(DISTINCT mb.registration_number, ', ') as registrations,
               string_agg(DISTINCT mb.purpose, ', ') as purposes,
               string_agg(DISTINCT mb.id::text, ', ') as bike_ids
        FROM motorists m
        LEFT JOIN motorbikes mb ON m.id = mb.motorist_id
        $where_clause
        GROUP BY m.id
        ORDER BY m.full_name
        LIMIT ? OFFSET ?";

$params[] = $limit;
$params[] = $offset;

$stmt = executeQuery($conn, $sql, '', $params);
$motorists = $stmt;

$flash_message = getFlashMessage('motorist_action');

$stats = getDashboardStats($conn);
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>View Motorists - <?php echo SITE_NAME; ?></title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/sweetalert2@11/dist/sweetalert2.min.css">
    <style>
        :root {
            --primary-color: #2c3e50;
            --secondary-color: #3498db;
            --success-color: #27ae60;
            --warning-color: #f1c40f;
            --danger-color: #e74c3c;
            --info-color: #3498db;
        }
        body { background: #f8f9fa; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; }
        .sidebar { min-height: 100vh; background: linear-gradient(180deg, var(--primary-color) 0%, var(--secondary-color) 100%); box-shadow: 2px 0 10px rgba(0,0,0,0.1); position: fixed; width: 16.666%; }
        .sidebar a { color: white; padding: 15px 20px; text-decoration: none; display: block; transition: all 0.3s; border-left: 4px solid transparent; }
        .sidebar a:hover { background: rgba(255,255,255,0.1); padding-left: 30px; border-left-color: var(--warning-color); }
        .sidebar a.active { background: rgba(255,255,255,0.2); border-left-color: var(--warning-color); font-weight: bold; }
        .sidebar i { width: 25px; text-align: center; }
        .main-content { margin-left: 16.666%; padding: 20px; }
        .page-header { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px; display: flex; justify-content: space-between; align-items: center; }
        .stats-container { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 20px; }
        .stat-card { background: white; border-radius: 10px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); display: flex; align-items: center; transition: transform 0.3s; }
        .stat-card:hover { transform: translateY(-5px); box-shadow: 0 4px 8px rgba(0,0,0,0.15); }
        .stat-icon { width: 50px; height: 50px; border-radius: 10px; display: flex; align-items: center; justify-content: center; margin-right: 15px; font-size: 1.5rem; color: white; }
        .stat-icon.primary { background: var(--primary-color); }
        .stat-icon.success { background: var(--success-color); }
        .stat-icon.warning { background: var(--warning-color); }
        .stat-icon.info { background: var(--info-color); }
        .stat-details h3 { margin: 0; font-size: 1.5rem; font-weight: bold; }
        .stat-details p { margin: 0; color: #6c757d; font-size: 0.9rem; }
        .table-container { background: white; border-radius: 10px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 20px; }
        .table th { background: #f8f9fa; border-bottom: 2px solid #dee2e6; color: var(--primary-color); font-weight: 600; }
        .table td { vertical-align: middle; }
        .purpose-badge { padding: 5px 12px; border-radius: 20px; font-size: 0.8rem; font-weight: bold; display: inline-block; margin: 2px; }
        .btn-group-action { display: flex; gap: 5px; justify-content: center; }
        .btn-action { width: 35px; height: 35px; padding: 0; display: inline-flex; align-items: center; justify-content: center; border-radius: 8px; transition: all 0.3s; border: none; cursor: pointer; }
        .btn-action:hover { transform: translateY(-2px); box-shadow: 0 4px 8px rgba(0,0,0,0.2); }
        .btn-view { background: var(--info-color); color: white; }
        .btn-edit { background: var(--warning-color); color: white; }
        .btn-delete { background: var(--danger-color); color: white; }
        .search-box { max-width: 400px; }
        .empty-state { text-align: center; padding: 50px; color: #6c757d; }
        .empty-state i { font-size: 4rem; margin-bottom: 20px; opacity: 0.5; }
        .record-count { color: #6c757d; font-size: 0.9rem; }
    </style>
</head>
<body>
    <div class="container-fluid">
        <div class="row">
            <div class="col-md-2 p-0 sidebar">
                <div class="text-center py-4">
                    <i class="fas fa-motorcycle fa-3x text-white"></i>
                    <h5 class="text-white mt-2"><?php echo SITE_NAME; ?></h5>
                    <span class="badge bg-warning text-dark">v<?php echo getSystemVersion(); ?></span>
                </div>
                <?php require_once __DIR__ . '/sidebar.php'; ?>
                <hr class="bg-white opacity-25">
                <a href="logout.php"><i class="fas fa-sign-out-alt me-2"></i> Logout</a>
            </div>

            <div class="col-md-10 main-content">
                <div class="page-header">
                    <h2 class="mb-0"><i class="fas fa-users me-2 text-primary"></i>Motorists Management</h2>
                    <a href="add_motorist.php" class="btn btn-primary">
                        <i class="fas fa-plus-circle me-2"></i>Add New Motorist
                    </a>
                </div>

                <div class="stats-container">
                    <div class="stat-card">
                        <div class="stat-icon primary"><i class="fas fa-users"></i></div>
                        <div class="stat-details"><h3><?php echo $stats['total_motorists']; ?></h3><p>Total Motorists</p></div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-icon success"><i class="fas fa-motorcycle"></i></div>
                        <div class="stat-details"><h3><?php echo $stats['total_bikes']; ?></h3><p>Total Motorbikes</p></div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-icon warning"><i class="fas fa-hand-holding-usd"></i></div>
                        <div class="stat-details"><h3><?php echo $stats['hire_count']; ?></h3><p>Bikes on Hire</p></div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-icon info"><i class="fas fa-calendar-plus"></i></div>
                        <div class="stat-details"><h3><?php echo $stats['recent_registrations']; ?></h3><p>New this week</p></div>
                    </div>
                </div>

                <?php if ($flash_message): ?>
                    <?php echo showAlert($flash_message['message'], $flash_message['type']); ?>
                <?php endif; ?>

                <div class="row mb-4">
                    <div class="col-md-8">
                        <form action="" method="GET" class="d-flex">
                            <div class="input-group search-box">
                                <span class="input-group-text bg-white"><i class="fas fa-search text-muted"></i></span>
                                <input type="text" name="search" class="form-control"
                                       placeholder="Search by name, license, phone or email..."
                                       value="<?php echo sanitize($search); ?>">
                                <button class="btn btn-primary" type="submit">Search</button>
                                <?php if (!empty($search)): ?>
                                <a href="view_motorists.php" class="btn btn-outline-secondary"><i class="fas fa-times"></i> Clear</a>
                                <?php endif; ?>
                            </div>
                        </form>
                    </div>
                    <div class="col-md-4 text-end record-count">
                        <i class="fas fa-database me-1"></i>
                        Showing <?php echo min(($page-1)*$limit + 1, $total_records); ?> -
                        <?php echo min($page*$limit, $total_records); ?> of
                        <?php echo $total_records; ?> records
                    </div>
                </div>

                <div class="table-container">
                    <?php if ($motorists && $motorists->num_rows > 0): ?>
                    <div class="table-responsive">
                        <table class="table table-hover">
                            <thead>
                                <tr>
                                    <th>ID</th>
                                    <th>Full Name</th>
                                    <th>License Number</th>
                                    <th>Phone</th>
                                    <th>Email</th>
                                    <th class="text-center">Motorbikes</th>
                                    <th>Registration(s)</th>
                                    <th class="text-center">Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php while($motorist = $motorists->fetch_assoc()): ?>
                                <tr id="motorist-row-<?php echo $motorist['id']; ?>">
                                    <td><span class="badge bg-secondary">#<?php echo str_pad($motorist['id'], 4, '0', STR_PAD_LEFT); ?></span></td>
                                    <td>
                                        <strong><?php echo sanitize($motorist['full_name']); ?></strong><br>
                                        <small class="text-muted"><i class="fas fa-calendar-alt me-1"></i><?php echo formatDate($motorist['date_registered']); ?></small>
                                    </td>
                                    <td><code><?php echo sanitize($motorist['license_number']); ?></code></td>
                                    <td><i class="fas fa-phone-alt me-1 text-muted"></i><?php echo formatPhone($motorist['phone_number']); ?></td>
                                    <td>
                                        <?php if (validateEmail($motorist['email'])): ?>
                                        <i class="fas fa-envelope me-1 text-muted"></i>
                                        <a href="mailto:<?php echo sanitize($motorist['email']); ?>" class="text-decoration-none">
                                            <?php echo truncateText(sanitize($motorist['email']), 20); ?>
                                        </a>
                                        <?php else: ?>
                                        <span class="text-muted">—</span>
                                        <?php endif; ?>
                                    </td>
                                    <td class="text-center">
                                        <span class="badge bg-<?php echo $motorist['bike_count'] > 0 ? 'success' : 'secondary'; ?>">
                                            <i class="fas fa-motorcycle me-1"></i><?php echo $motorist['bike_count']; ?>
                                        </span>
                                    </td>
                                    <td>
                                        <?php
                                        if ($motorist['registrations']) {
                                            $registrations = explode(', ', $motorist['registrations']);
                                            $purposes = explode(', ', $motorist['purposes']);
                                            foreach($registrations as $index => $reg) {
                                                $purpose = $purposes[$index] ?? '';
                                                $badge_class = getPurposeBadgeClass($purpose);
                                                echo '<span class="badge ' . $badge_class . ' me-1 mb-1">' .
                                                     sanitize($reg) . '</span>';
                                            }
                                        } else {
                                            echo '<span class="text-muted fst-italic">No bikes registered</span>';
                                        }
                                        ?>
                                    </td>
                                    <td class="text-center">
                                        <div class="btn-group-action">
                                            <a href="view_motorist.php?id=<?php echo $motorist['id']; ?>" class="btn-action btn-view" title="View Details" data-bs-toggle="tooltip"><i class="fas fa-eye"></i></a>
                                            <a href="edit_motorist.php?id=<?php echo $motorist['id']; ?>" class="btn-action btn-edit" title="Edit Motorist" data-bs-toggle="tooltip"><i class="fas fa-edit"></i></a>
                                            <button type="button" class="btn-action btn-delete" title="Delete Motorist" data-bs-toggle="tooltip"
                                                    onclick="confirmDelete(<?php echo $motorist['id']; ?>, '<?php echo addslashes($motorist['full_name']); ?>')">
                                                <i class="fas fa-trash"></i>
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                                <?php endwhile; ?>
                            </tbody>
                        </table>
                    </div>

                    <?php
                    $url_pattern = '?page=%d' . (!empty($search) ? '&search=' . urlencode($search) : '');
                    echo paginate($page, $total_pages, $url_pattern);
                    ?>

                    <?php else: ?>
                    <div class="empty-state">
                        <i class="fas fa-users"></i>
                        <h4>No Motorists Found</h4>
                        <p class="text-muted">
                            <?php echo !empty($search) ? 'No results match your search criteria.' : 'Get started by adding your first motorist.'; ?>
                        </p>
                        <?php if (!empty($search)): ?>
                        <a href="view_motorists.php" class="btn btn-outline-primary"><i class="fas fa-times me-2"></i>Clear Search</a>
                        <?php else: ?>
                        <a href="add_motorist.php" class="btn btn-primary"><i class="fas fa-plus-circle me-2"></i>Add New Motorist</a>
                        <?php endif; ?>
                    </div>
                    <?php endif; ?>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>

    <script>
        document.addEventListener('DOMContentLoaded', function() {
            var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
            tooltipTriggerList.map(function(tooltipTriggerEl) { return new bootstrap.Tooltip(tooltipTriggerEl); });
        });

        setTimeout(function() {
            const alerts = document.querySelectorAll('.alert');
            alerts.forEach(alert => { const bsAlert = new bootstrap.Alert(alert); bsAlert.close(); });
        }, 5000);

        function confirmDelete(id, name) {
            Swal.fire({
                title: 'Are you sure?',
                html: `You are about to delete <strong>${name}</strong><br>This action cannot be undone!`,
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: '#e74c3c',
                cancelButtonColor: '#6c757d',
                confirmButtonText: 'Yes, delete it!',
                cancelButtonText: 'Cancel',
                showLoaderOnConfirm: true,
                preConfirm: () => {
                    return fetch('view_motorists.php', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                        body: 'action=ajax_delete&id=' + id
                    })
                    .then(response => {
                        if (!response.ok) throw new Error(response.statusText);
                        return response.json();
                    })
                    .then(data => {
                        if (!data.success) throw new Error(data.message);
                        return data;
                    })
                    .catch(error => { Swal.showValidationMessage(`Request failed: ${error}`); });
                },
                allowOutsideClick: () => !Swal.isLoading()
            }).then((result) => {
                if (result.isConfirmed) {
                    const row = document.getElementById('motorist-row-' + id);
                    if (row) {
                        row.style.transition = 'all 0.3s';
                        row.style.opacity = '0';
                        setTimeout(() => {
                            row.remove();
                            const tbody = document.querySelector('tbody');
                            if (tbody && tbody.children.length === 0) location.reload();
                        }, 300);
                    }
                    Swal.fire({ title: 'Deleted!', text: 'Motorist has been deleted successfully.', icon: 'success', timer: 2000, showConfirmButton: false });
                }
            });
        }

        document.addEventListener('keydown', function(e) {
            if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
                e.preventDefault();
                document.querySelector('input[name="search"]').focus();
            }
        });

        const searchInput = document.querySelector('input[name="search"]');
        if (searchInput) {
            searchInput.setAttribute('title', 'Press Ctrl+K to focus');
            searchInput.setAttribute('data-bs-toggle', 'tooltip');
            searchInput.setAttribute('data-bs-placement', 'right');
        }
    </script>
</body>
</html>
