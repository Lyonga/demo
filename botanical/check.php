<?Php
if(!(isset($_SESSION['username']) and strlen($_SESSION['username']) > 2)){
echo "<b>Please <a href=signin.php>login</a> to use this page!! </b>";
exit;
}else{
echo "Welcome $_SESSION[username] | <a href='logout.php'>Logout</a>|<a href='change.php'>Change Password</a>";
}
?>