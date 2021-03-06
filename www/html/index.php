<?php

/**
 * smac entry point
 */

define('DEBUG', true);

/* loading core */
require_once 'smac.php';

new Request();

@list($route, $action, $param) = Request::ParseUri();


$fc = new FrontController($route, $action, $param);
$fc->run();