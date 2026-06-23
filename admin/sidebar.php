<?php
// Shared admin sidebar
?>
<div class="col-md-2 p-0 sidebar">
    <div class="text-center py-4">
        <i class="fas fa-motorcycle fa-3x text-white"></i>
        <h5 class="text-white mt-2">Motorist System</h5>
    </div>
    <a href="index.php" class="<?php echo (basename($_SERVER['PHP_SELF'])=='index.php')? 'active' : ''; ?>"><i class="fas fa-dashboard me-2"></i> Dashboard</a>
    <a href="add_motorist.php" class="<?php echo (basename($_SERVER['PHP_SELF'])=='add_motorist.php')? 'active' : ''; ?>"><i class="fas fa-user-plus me-2"></i> Add Motorist</a>
    <a href="add_motorbike.php" class="<?php echo (basename($_SERVER['PHP_SELF'])=='add_motorbike.php')? 'active' : ''; ?>"><i class="fas fa-plus-circle me-2"></i> Add Motorbike</a>
    <a href="view_motorists.php" class="<?php echo (basename($_SERVER['PHP_SELF'])=='view_motorists.php')? 'active' : ''; ?>"><i class="fas fa-users me-2"></i> View All</a>
    <a href="reports.php" class="<?php echo (basename($_SERVER['PHP_SELF'])=='reports.php')? 'active' : ''; ?>"><i class="fas fa-chart-bar me-2"></i> Reports</a>
    <a href="user_communications.php" class="<?php echo (basename($_SERVER['PHP_SELF'])=='user_communications.php')? 'active' : ''; ?>"><i class="fas fa-envelope-open-text me-2"></i> User Communications</a>
    <a href="profile.php" class="<?php echo (basename($_SERVER['PHP_SELF'])=='profile.php')? 'active' : ''; ?>"><i class="fas fa-user-circle me-2"></i> Profile</a>
    <a href="logout.php"><i class="fas fa-sign-out-alt me-2"></i> Logout</a>
</div>
