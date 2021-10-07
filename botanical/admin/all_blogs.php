<?php
include_once('includes/functions.php');
include_once("b_header.php");
?>
<!Doctype html>
<html lang="en">
<head>
  <title>ALL-BLOGS</title>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.css">
  <link rel="stylesheet" href="https://use.fontawesome.com/releases/v5.7.1/css/all.css">
</head>



        <a href='index.php' class='btn btn-info m-b-1em'>DASHBOARD</a>
        <a href='create_blog.php' class='btn btn-primary m-b-1em'>CREATE NEW BLOG</a>
    <table border='2' class="table table-bordred table-striped">
        <tr>
            <th>ID</th>
            <th>TITLE</th>
            <th width='50%'>CONTENT</th>
            <th>AUTHOR</th>
            <th colspan = '3'>ACTION</th>
        </tr>
        <?php
     $user = new User();
     $sql = $user->FetchBlog();
     $cnt = 1;
     while($row = mysqli_fetch_array($sql))
     {
     ?>
            <tr>
                <td><?php echo htmlentities($cnt);?></td>
                <td><?php echo htmlentities($row['b_title']); ?></td>
                <td><?php echo htmlentities($row['b_body']); ?></td>
                <td><?php echo htmlentities($row['b_author']); ?></td>
                 <td>
                 <a href="view_blog.php?view_id=<?php echo htmlentities($row['b_id']);?>" title='View Record' data-toggle='tooltip'><span class='btn btn-info m-r-1em'>View</span></a>
                 <a href="edit_blog.php?update_id=<?php echo htmlentities($row['b_id']);?>" title='Update Record' data-toggle='tooltip'><span class='btn btn-primary m-r-1em'>Update</span></a>
                 <a href="delete_blog.php?delete_id=<?php echo htmlentities($row['b_id']);?>" title='Delete Record' data-toggle='tooltip'><span class='btn btn-danger'>Delete</span></a>
                </td>
            </tr> 
            <?php
            // for serial number increment
           $cnt++;
            } ?>   
        
        </table>
        



</html>
