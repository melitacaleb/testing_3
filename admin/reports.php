<?php
require_once 'config.php';

$stats = [];
$stats['total_motorists'] = $conn->query("SELECT COUNT(*) as count FROM motorists")->fetch_assoc()['count'];
$stats['total_bikes'] = $conn->query("SELECT COUNT(*) as count FROM motorbikes")->fetch_assoc()['count'];

$purpose_result = $conn->query("SELECT purpose, COUNT(*) as count FROM motorbikes GROUP BY purpose");
$purpose_stats = [];
foreach ($purpose_result->fetch_all() as $row) {
    $purpose_stats[$row['purpose']] = $row['count'];
}

$top_motorists = $conn->query("
    SELECT m.full_name, COUNT(mb.id) as bike_count
    FROM motorists m
    LEFT JOIN motorbikes mb ON m.id = mb.motorist_id
    GROUP BY m.id, m.full_name
    ORDER BY bike_count DESC
    LIMIT 5
");

$recent = $conn->query("
    SELECT m.full_name, m.date_registered, COUNT(mb.id) as bike_count
    FROM motorists m
    LEFT JOIN motorbikes mb ON m.id = mb.motorist_id
    GROUP BY m.id, m.full_name, m.date_registered
    ORDER BY m.date_registered DESC
    LIMIT 5
");

$hire_stats = $conn->query("
    SELECT COUNT(*) as count, AVG(hire_rate) as avg_rate
    FROM hire_details
")->fetch_assoc();
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reports - Motorist System</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        .sidebar { min-height: 100vh; background: linear-gradient(180deg, #2c3e50 0%, #3498db 100%); }
        .sidebar a { color: white; padding: 15px; text-decoration: none; display: block; transition: 0.3s; }
        .sidebar a:hover { background: rgba(255,255,255,0.1); padding-left: 25px; }
        .sidebar a.active { background: rgba(255,255,255,0.2); border-left: 4px solid #f1c40f; }
        .report-card { background: white; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); padding: 20px; margin-bottom: 20px; height: 100%; }
    </style>
</head>
<body>
    <div class="container-fluid">
        <div class="row">
            <?php require_once __DIR__ . '/sidebar.php'; ?>
            <div class="col-md-10 p-4">
                <h2 class="mb-4"><i class="fas fa-chart-bar me-2"></i>Reports & Analytics</h2>

                <div class="row">
                    <div class="col-md-3 mb-4">
                        <div class="report-card text-center">
                            <i class="fas fa-users fa-3x text-primary mb-3"></i>
                            <h3><?php echo $stats['total_motorists']; ?></h3>
                            <p class="text-muted">Total Motorists</p>
                        </div>
                    </div>

                    <div class="col-md-3 mb-4">
                        <div class="report-card text-center">
                            <i class="fas fa-motorcycle fa-3x text-success mb-3"></i>
                            <h3><?php echo $stats['total_bikes']; ?></h3>
                            <p class="text-muted">Total Motorbikes</p>
                        </div>
                    </div>

                    <div class="col-md-3 mb-4">
                        <div class="report-card text-center">
                            <i class="fas fa-hand-holding-usd fa-3x text-warning mb-3"></i>
                            <h3><?php echo $hire_stats['count'] ?? 0; ?></h3>
                            <p class="text-muted">Bikes on Hire</p>
                        </div>
                    </div>

                    <div class="col-md-3 mb-4">
                        <div class="report-card text-center">
                            <i class="fas fa-chart-line fa-3x text-info mb-3"></i>
                            <h3>KES <?php echo number_format($hire_stats['avg_rate'] ?? 0, 2); ?></h3>
                            <p class="text-muted">Avg. Hire Rate/Day</p>
                        </div>
                    </div>
                </div>

                <div class="row">
                    <div class="col-md-6 mb-4">
                        <div class="report-card">
                            <h5 class="mb-3">Motorbike Purpose Distribution</h5>
                            <canvas id="purposeChart"></canvas>
                        </div>
                    </div>

                    <div class="col-md-6 mb-4">
                        <div class="report-card">
                            <h5 class="mb-3">Top Motorists by Bike Count</h5>
                            <table class="table table-hover">
                                <thead>
                                    <tr>
                                        <th>Motorist</th>
                                        <th>Number of Bikes</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php while($row = $top_motorists->fetch_assoc()): ?>
                                    <tr>
                                        <td><?php echo htmlspecialchars($row['full_name']); ?></td>
                                        <td><span class="badge bg-primary"><?php echo $row['bike_count']; ?> bikes</span></td>
                                    </tr>
                                    <?php endwhile; ?>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>

                <div class="row">
                    <div class="col-md-12 mb-4">
                        <div class="report-card">
                            <h5 class="mb-3">Recent Motorist Registrations</h5>
                            <table class="table table-hover">
                                <thead>
                                    <tr>
                                        <th>Motorist Name</th>
                                        <th>Registration Date</th>
                                        <th>Bikes Owned</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php while($row = $recent->fetch_assoc()): ?>
                                    <tr>
                                        <td><?php echo htmlspecialchars($row['full_name']); ?></td>
                                        <td><?php echo date('d M Y', strtotime($row['date_registered'])); ?></td>
                                        <td><?php echo $row['bike_count']; ?> bikes</td>
                                    </tr>
                                    <?php endwhile; ?>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        const ctx = document.getElementById('purposeChart').getContext('2d');
        new Chart(ctx, {
            type: 'pie',
            data: {
                labels: ['Commercial', 'Personal Transport', 'On Hire'],
                datasets: [{
                    data: [
                        <?php echo $purpose_stats['commercial'] ?? 0; ?>,
                        <?php echo $purpose_stats['personal_transport'] ?? 0; ?>,
                        <?php echo $purpose_stats['hire'] ?? 0; ?>
                    ],
                    backgroundColor: ['#ff6b6b', '#4ecdc4', '#f7d794'],
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                plugins: { legend: { position: 'bottom' } }
            }
        });
    </script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
