<?php 
//session_start();
//include('../config/config.php');
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title><?php echo SITETITLE;?></title>
<link rel="stylesheet" type="text/css" href="\botanical/admin/style/admin.css">
<link rel="stylesheet" type="text/css" href="\botanical/admin/style/botanics.css">
<link rel="stylesheet" href="https://use.fontawesome.com/releases/v5.7.1/css/all.css">
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.4.1/css/bootstrap.min.css">
</head>
<body>

<div id="wrapper">

<div id="logo">
<a href="<?php echo DIRADMIN;?>"><img src="\botanical/images/logo1.png" alt="<?php echo SITETITLE;?>" border="0" /></a>
<h1 style="text-align:left;"><a href="<?php echo DIRADMIN;?>">NATURAL BOTANICALS</a></h1>
<style>
  h1, img{
	  display:inline;
	  line-height:30px;
  }
  a{
	color:black;
	text-decoration:none;
  }
  </style>
</div><br>

<!-- NAV -->
<div id="header">
<p>Hello <?php echo $_SESSION['username'] ; ?></p>
	<ul class="menu">
		<li><a href="<?php echo DIRADMIN;?>">Admin</a></li>		
		<li><a href="<?php echo DIR;?>" target="_blank">View Website</a></li>
		<li><a href="<?php echo DIR;?>?q=logout">Logout</a></li>
	</ul>
</div>