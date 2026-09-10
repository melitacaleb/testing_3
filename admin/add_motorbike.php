<?php
require_once 'config.php';

$message = '';
$message_type = '';

// Get motorists for dropdown
$motorists = $conn->query("SELECT id, full_name, license_number FROM motorists ORDER BY full_name");

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $motorist_id = $_POST['motorist_id'];
    $registration_number = trim($_POST['registration_number']);
    $brand = trim($_POST['brand']);
    $model = trim($_POST['model']);
    $color = trim($_POST['color']);
    $manufacture_year = $_POST['manufacture_year'];
    $purpose = $_POST['purpose'];

    $conn->begin_transaction();

    try {
        $sql = "INSERT INTO motorbikes (motorist_id, registration_number, brand, model, color, manufacture_year, purpose)
                VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id";

        $stmt = $conn->prepare($sql);
        $stmt->execute([$motorist_id, $registration_number, $brand, $model, $color, $manufacture_year, $purpose]);
        $row = $stmt->fetch_assoc();
        $motorbike_id = $row['id'];

        if ($purpose == 'hire' && isset($_POST['owner_name'])) {
            $owner_name = trim($_POST['owner_name']);
            $owner_phone = trim($_POST['owner_phone']);
            $owner_email = trim($_POST['owner_email']);
            $owner_address = trim($_POST['owner_address']);
            $hire_rate = $_POST['hire_rate'];
            $hire_start_date = $_POST['hire_start_date'] ?: null;
            $hire_end_date = $_POST['hire_end_date'] ?: null;

            $hire_sql = "INSERT INTO hire_details (motorbike_id, owner_name, owner_phone, owner_email, owner_address, hire_rate, hire_start_date, hire_end_date)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)";

            $hire_stmt = $conn->prepare($hire_sql);
            $hire_stmt->execute([$motorbike_id, $owner_name, $owner_phone, $owner_email, $owner_address, $hire_rate, $hire_start_date, $hire_end_date]);
        }

        $conn->commit();
        $message = "Motorbike added successfully!";
        $message_type = "success";
    } catch (Exception $e) {
        $conn->rollback();
        $message = "Error adding motorbike: " . $e->getMessage();
        $message_type = "danger";
    }
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Add Motorbike - Motorist System</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        .sidebar { min-height: 100vh; background: linear-gradient(180deg, #2c3e50 0%, #3498db 100%); }
        .sidebar a { color: white; padding: 15px; text-decoration: none; display: block; transition: 0.3s; }
        .sidebar a:hover { background: rgba(255,255,255,0.1); padding-left: 25px; }
        .sidebar a.active { background: rgba(255,255,255,0.2); border-left: 4px solid #f1c40f; }
        .form-container { max-width: 800px; margin: 0 auto; padding: 20px; background: white; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        .hire-section { background: #f8f9fa; padding: 20px; border-radius: 8px; margin-top: 20px; border-left: 4px solid #f7d794; }
    </style>
</head>
<body>
    <div class="container-fluid">
        <div class="row">
            <?php require_once __DIR__ . '/sidebar.php'; ?>
            <div class="col-md-10 p-4">
                <h2 class="mb-4"><i class="fas fa-plus-circle me-2"></i>Add New Motorbike</h2>

                <?php if($message): ?>
                    <div class="alert alert-<?php echo $message_type; ?> alert-dismissible fade show" role="alert">
                        <?php echo htmlspecialchars($message); ?>
                        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                    </div>
                <?php endif; ?>

                <div class="form-container">
                    <form method="POST" action="" id="motorbikeForm">
                        <div class="mb-3">
                            <label for="motorist_id" class="form-label">Select Motorist *</label>
                            <select class="form-control" id="motorist_id" name="motorist_id" required>
                                <option value="">-- Select Motorist --</option>
                                <?php while($motorist = $motorists->fetch_assoc()): ?>
                                    <option value="<?php echo $motorist['id']; ?>">
                                        <?php echo htmlspecialchars($motorist['full_name'] . ' (' . $motorist['license_number'] . ')'); ?>
                                    </option>
                                <?php endwhile; ?>
                            </select>
                        </div>

                        <div class="mb-3">
                            <label for="registration_number" class="form-label">Registration Number *</label>
                            <input type="text" class="form-control" id="registration_number" name="registration_number" required>
                        </div>

                        <div class="row">
                            <div class="col-md-6 mb-3">
                                <label for="brand" class="form-label">Brand *</label>
                                <input type="text" class="form-control" id="brand" name="brand" required>
                            </div>

                            <div class="col-md-6 mb-3">
                                <label for="model" class="form-label">Model *</label>
                                <input type="text" class="form-control" id="model" name="model" required>
                            </div>
                        </div>

                        <div class="row">
                            <div class="col-md-6 mb-3">
                                <label for="color" class="form-label">Color</label>
                                <input type="text" class="form-control" id="color" name="color">
                            </div>

                            <div class="col-md-6 mb-3">
                                <label for="manufacture_year" class="form-label">Manufacture Year</label>
                                <input type="number" class="form-control" id="manufacture_year" name="manufacture_year"
                                       min="1900" max="<?php echo date('Y'); ?>" value="<?php echo date('Y'); ?>">
                            </div>
                        </div>

                        <div class="mb-3">
                            <label for="purpose" class="form-label">Purpose *</label>
                            <select class="form-control" id="purpose" name="purpose" required onchange="toggleHireSection()">
                                <option value="">-- Select Purpose --</option>
                                <option value="commercial">Commercial (Business/Taxi)</option>
                                <option value="personal_transport">Personal Transport</option>
                                <option value="hire">On Hire</option>
                            </select>
                        </div>

                        <div id="hireSection" class="hire-section" style="display: none;">
                            <h5 class="mb-3"><i class="fas fa-hand-holding-usd me-2"></i>Hire/Owner Details</h5>

                            <div class="mb-3">
                                <label for="owner_name" class="form-label">Owner's Full Name *</label>
                                <input type="text" class="form-control" id="owner_name" name="owner_name">
                            </div>

                            <div class="mb-3">
                                <label for="owner_phone" class="form-label">Owner's Phone *</label>
                                <input type="tel" class="form-control" id="owner_phone" name="owner_phone">
                            </div>

                            <div class="mb-3">
                                <label for="owner_email" class="form-label">Owner's Email</label>
                                <input type="email" class="form-control" id="owner_email" name="owner_email">
                            </div>

                            <div class="mb-3">
                                <label for="owner_address" class="form-label">Owner's Address</label>
                                <textarea class="form-control" id="owner_address" name="owner_address" rows="2"></textarea>
                            </div>

                            <div class="row">
                                <div class="col-md-4 mb-3">
                                    <label for="hire_rate" class="form-label">Hire Rate (per day) *</label>
                                    <input type="number" step="0.01" class="form-control" id="hire_rate" name="hire_rate">
                                </div>

                                <div class="col-md-4 mb-3">
                                    <label for="hire_start_date" class="form-label">Hire Start Date</label>
                                    <input type="date" class="form-control" id="hire_start_date" name="hire_start_date">
                                </div>

                                <div class="col-md-4 mb-3">
                                    <label for="hire_end_date" class="form-label">Hire End Date</label>
                                    <input type="date" class="form-control" id="hire_end_date" name="hire_end_date">
                                </div>
                            </div>
                        </div>

                        <button type="submit" class="btn btn-primary">
                            <i class="fas fa-save me-2"></i>Save Motorbike
                        </button>
                        <a href="index.php" class="btn btn-secondary">
                            <i class="fas fa-times me-2"></i>Cancel
                        </a>
                    </form>
                </div>
            </div>
        </div>
    </div>

    <script>
        function toggleHireSection() {
            var purpose = document.getElementById('purpose').value;
            var hireSection = document.getElementById('hireSection');
            var hireFields = ['owner_name', 'owner_phone', 'hire_rate'];

            if (purpose === 'hire') {
                hireSection.style.display = 'block';
                hireFields.forEach(function(field) {
                    document.getElementById(field).required = true;
                });
            } else {
                hireSection.style.display = 'none';
                hireFields.forEach(function(field) {
                    document.getElementById(field).required = false;
                });
            }
        }
    </script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
