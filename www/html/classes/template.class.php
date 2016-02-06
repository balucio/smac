<?php

class Template
{

	private function __construct() {}

	private function __clone() {}

	private function __wakeup() {}

	static public function get() {

		static $tplh = null;

		if( !isset( $tplh ) ) {

			LoadConfig('TplConfig');
			LoadLib('Twig');

			Twig_Autoloader::register();

			$loader = new Twig_Loader_Filesystem( ROOT_DIR . TplConfig::templates );
			self::$tplh = new Twig_Environment($loader, array(
    			'cache' => '',
			));

			$tplh = new Mustache_Engine(array(

				'cache' => ROOT_DIR . TplConfig::cache,
				'loader' => new Mustache_Loader_FilesystemLoader(
					ROOT_DIR . TplConfig::templates,
					[ 'extension' => TplConfig::extension]
				),
				'partials_loader' => new Mustache_Loader_FilesystemLoader(
					ROOT_DIR . TplConfig::partials,
					[ 'extension' => TplConfig::extension]
				),
				'logger' => new Mustache_Logger_StreamLogger('php://stderr'),
			));
		}

		return $tplh;
	}


	static public function Error_505($msg) {

		header('HTTP/1.1 503 Service Temporarily Unavailable');
		header('Status: 503 Service Temporarily Unavailable');
		header('Retry-After: 3600');

		$tpl = Template::get()->loadTemplate('error_page');
		echo $tpl->render([ 'message' => $msg ]);
		exit();
	}

}

?>