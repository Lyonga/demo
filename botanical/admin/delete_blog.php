<?php
include_once('includes/functions.php');

if(isset($_GET['delete_id'])){

    $delete_id = $_GET['delete_id'];
    $user = new user();
    $sql = $user->DeleteBlog($delete_id);
    if($sql){
        echo "Blog deleted";
        header('Location:all_blogs.php');
    }else{
        echo "something went wrong";
    }
}
?>

<!Doctype html>
<html lang="en">
<head>
  <title></title>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
</head>
<body>
<form action="" method="post">
        <div class="alert alert-danger fade in">
            <input type="hidden" name="id" value="<?php echo trim($_GET["delete_id"]); ?>"/>
            <p>Are you sure you want to delete this record?</p><br>
            <p>
              <input type="submit" value="Yes" class="btn btn-danger">
              <a href="all_blogs.php" class="btn btn-default">No</a>
            </p>               
        </div>
 </form>
</body>
</html>