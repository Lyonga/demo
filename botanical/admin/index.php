<?php
include('../config/config.php');
include_once("b_header.php");
echo "<br>";
?>


<h3 class="side_bar">
	<ul id="navigation">
	 <li><h2><a id="active" href="../index.php"><i class="fas fa-home"></i>HOME</a></h2></li>
	 <li><a href="all_articles.php">ARTICLES</a>
	    <ul>
           <li><a href="all_articles.php">ALL ARTICLES</a></li>
		   <li><a href="create_article.php">ADD ARTICLE</a></li>
		</ul>
	  </li>
	  <li><a href="all_blogs.php"> BLOGS</a>
	    <ul>
		   <li><a href="all_blogs.php">ALL BLOGS</a></li>
		   <li><a href="create_blog.php">ADD BLOG</a></li>
		</ul>
      </li>
	  
	  <li><a href="all-users.php">USERS</a>
	       <ul>
		   <li><a href="all-users.php">ALL USERS</a></li>
		   <li><a href="../signup.php">ADD USERS</a></li>
		   <li><a href="#">YOUR PROFILE</a></li>
		   </ul>
	  </li>
	  <li><a href="#">SETTINGS</a></li>
	  <li><a href="password_reset.php">PASSWORD RESET</a></li>
	  <li><a href="logout.php">SIGN OUT</a></li>
	</ul>
</h3>
	<section class="top">
	 <ul>	
	   <li><a href="all_articles.php">ALL ARTICLES</a></li>
	   <li><a href="all_blogs.php">MY BLOGPOSTS</a></li>
	   <li><a href="all-users.php">ALL USERS</a></li>
     </ul>
</section> 
  </body>
  </html>