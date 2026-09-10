<?php
require_once __DIR__ . '/config.php';

$complaints = getAllComplaints($conn);
?>
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>Complaints - Admin</title>
</head>
<body>
<h1>Complaints</h1>
<p><a href="index.php">Back to dashboard</a></p>
<table border="1" cellpadding="6" cellspacing="0">
    <thead>
    <tr>
        <th>ID</th>
        <th>User</th>
        <th>Subject</th>
        <th>Status</th>
        <th>Submitted</th>
        <th>Action</th>
    </tr>
    </thead>
    <tbody>
    <?php foreach ($complaints as $c): ?>
        <tr>
            <td><?php echo htmlspecialchars($c['id']); ?></td>
            <td><?php echo htmlspecialchars($c['full_name'] ?? ($c['user_id'] ?? 'Guest')); ?> (<?php echo htmlspecialchars($c['email'] ?? ''); ?>)</td>
            <td><?php echo htmlspecialchars($c['subject']); ?></td>
            <td><?php echo htmlspecialchars($c['status']); ?></td>
            <td><?php echo htmlspecialchars($c['created_at']); ?></td>
            <td><a href="complaint.php?id=<?php echo urlencode($c['id']); ?>">View / Respond</a></td>
        </tr>
    <?php endforeach; ?>
    </tbody>
</table>
</body>
</html>
