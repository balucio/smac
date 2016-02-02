<?php

function AutoloadClass($className) {
    $file = SITE_ROOT_DIR . 'classes' . DIRECTORY_SEPARATOR . strtolower($className) . '.class.php';
    if (is_readable($file))
        require $file;
}

function AutoloadModel($className) {

    $file = SITE_ROOT_DIR . 'models' . DIRECTORY_SEPARATOR . strtolower(str_replace('Model', '', $className)) . '.php';

    if (is_readable($file))
        require $file;
}

function AutoloadController($className) {

    $file = SITE_ROOT_DIR . 'controllers' . DIRECTORY_SEPARATOR . strtolower(str_replace('Controller', '', $className)) . '.php';

    if (is_readable($file))
        require $file;
}

function AutoloadView($className) {

    $file = SITE_ROOT_DIR . 'views' . DIRECTORY_SEPARATOR . strtolower(str_replace('View', '', $className)) . '.php';

    if (is_readable($file))
        require $file;
}

function LoadConfig($config) {

    require_once SITE_ROOT_DIR . 'configs'  . DIRECTORY_SEPARATOR . $config . '.php';

}

function LoadLib($lib) {

    require(LIB_DIR . $lib . DIRECTORY_SEPARATOR . $lib . '.php');

}

function ErrorReporting() {

    ini_set('error_reporting', E_ALL);
    ini_set('display_errors', true);
    ini_set('html_errors', true);
}

define ('APP_NAME', 'Smac');

define('SITE_ROOT_DIR', __DIR__ . DIRECTORY_SEPARATOR);
define('ROOT_DIR', SITE_ROOT_DIR . '..' . DIRECTORY_SEPARATOR);
define('LIB_DIR', SITE_ROOT_DIR . 'lib' . DIRECTORY_SEPARATOR);

LoadLib('Kint');
Kint::enabled(DEBUG);
DEBUG && ErrorReporting();


define('REMOTE_IP', isset($_SERVER['HTTP_CLIENT_IP'])
    ? $_SERVER['HTTP_CLIENT_IP']
    :( isset($_SERVER['HTTP_X_FORWARDED_FOR'])
        ? $_SERVER['HTTP_X_FORWARDED_FOR']
        : $_SERVER['REMOTE_ADDR']
    )
);

spl_autoload_register('AutoloadClass');
spl_autoload_register('AutoloadModel');
spl_autoload_register('AutoloadController');
spl_autoload_register('AutoloadView');
