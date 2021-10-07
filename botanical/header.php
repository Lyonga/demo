<?php
//session_start();
?>
<!Doctype html>
<html lang="en">
<head>
  <title>FRUITS-AND-DESSERTS</title>
  <meta charset="utf-8">
  <meta name="descrription" content="Fresh organic tropical fruits">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="stylesheet" type="text/css" href="fruitas.css">
  <link rel="stylesheet" href="https://use.fontawesome.com/releases/v5.7.1/css/all.css">
  <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.4.1/css/bootstrap.min.css">
  
</head>

<body id="big_wrapper">
   <div>
	 <header id="topheader"  style="background:crimson; color:white; font-size:16px;">
     <div id="callout">
	   <p>call us at <b>00237 675  879 800<br>00237 699 900 897</p>
	 </div>
	 <img src="\tropico-fruitas/images/logo.png"/>
	 <h1 style="text-align:left">NATURAL BOTANICALS</h1>
	 </header>
	 <style>
  h1, img{
	  display:inline;
	  line-height:30px;
  }

  p {text-align:right; 
  }
  </style>

  <nav id="topmenu">
	<ul id="navigation">
	  <li><a id="active" href="index.php">HOME</a></li>
	  <li><a href="#">PRODUCTS</a>
	     <ul id="subnav">
		   <li><a href="pages/apples.php">APPLES</a></li>
		   <li><a href="pages/carrots.php">CARROTS</a></li>
		   <li><a href="pages/oranges.php">ORANGES</a></li>
		   <li><a href="pages/pineapples.php">PINEAPPLES</a></li>
		 </ul>
	  </li>
	  <li><a href="pages/blog.php">BLOG</a></li>
	  <li><a href="pages/about.php">ABOUT US</a></li>
	  <li><a href="pages/contact.php">CONTACT US</a></li>
	  <li><a href="pages/our_shop.php">OUR SHOP</a></li>
	    <div style="text-align:right">
		<?php
        if(isset($_SESSION['username'])){
         echo ' <form action="includes/logout.php" method="POST">
		 <button type="submit" name="logout_btn" class="btn btn-danger">SignOut</button>
	 </form>';
           }
       else{
		   echo
	        '<a href="signin.php" class="btn btn-success">SIGN IN!</a>
	         <a href="register.php" class="btn btn-primary">SIGN UP!</a>';
	}
          ?>

		</div>
	</ul> 
  </nav>