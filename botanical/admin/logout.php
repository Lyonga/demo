<?php
session_start();
include_once '../includes/functions.php';
$user = new User(); $UID1 = $_SESSION['username'];
if (!$user->get_session()){
    header("location:signin.php");
}
if (isset($_GET['q'])){
    $user->user_logout();
    header("../location:index.php");
}
?>