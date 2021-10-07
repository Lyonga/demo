<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>View-ARTICLE</title>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.css">
    <style type="text/css">
        .wrapper{
            width: 500px;
            margin: 0 auto;
        }
    </style>
</head>

<?php
include_once('includes/functions.php');
$user = new user();
$view_id =  trim($_GET["view_id"]);
$sql = $user->FetchOneArticle($view_id);
$cnt = 1;
while($row = mysqli_fetch_array($sql))
  {
    $title = $row["a_title"];
    $body = $row["a_body"];
    $author = $row["a_author"];
?>
<body>
    <div class="wrapper">
        <div class="container-fluid">
            <div class="row">
                <div class="col-md-12">
                    <div class="page-header">
                        <h1>View Article</h1>
                    </div>
                    <div class="form-group">
                        <label>Title</label>
                        <p class="form-control-static"><?php echo  $title;?></p>
                    </div><br>
                    <div class="form-group">
                        <label>Body</label>
                        <p class="form-control-static"><?php echo $body; ?></p>
                    </div><br>
                    <div class="form-group">
                        <label>Author</label>
                        <p class="form-control-static"><?php echo $author; ?></p>
                    </div>
                    <?php
                   }
                    ?>
                    <p><a href="all_blogs.php" class="btn btn-primary">Back</a></p>
                </div>
            </div>        
        </div>
    </div>

    <style>
	body{
		font-family:verdana;
	}
	.wrapper{width:800px;margin: 0 auto;}
	h1{line-height:25px;font-size:25px;}
    label{line-height:25px;font-size:25px;}
	p{display:block;width:850px;font-size:20px;margin:10px 0;}
</style>

</body>
</html>