<?php

ob_start();
session_start();

// db properties
define('DBHOST','localhost');
define('DBUSER','root');
define('DBPASS','');
define('DBNAME','botanical');

// make a connection to mysql here


// define site path
define('DIR','http://localhost/botanical/index.php');

// define admin site path
define('DIRADMIN','http://localhost/botanical/admin/index.php/');

// define site title for top of the browser
define('SITETITLE','NATURAL BOTANICALS');

//define include checker
define('included', 1);

//include('functions.php');
?>