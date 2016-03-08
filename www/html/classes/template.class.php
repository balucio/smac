<?php

class Template {

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

			$tplh = new Twig_Environment($loader, array(
				'cache' => DEBUG ? false : ROOT_DIR . TplConfig::cache,
				'debug' => DEBUG,
				'strict_variables' => true
			));

			$tplh->addExtension(new TemplateExtension());
		}

		return $tplh;
	}


	static public function Error_505($msg) {

		header('HTTP/1.1 503 Service Temporarily Unavailable');
		header('Status: 503 Service Temporarily Unavailable');
		header('Retry-After: 3600');

		$tpl = Template::get()->loadTemplate('error_page.tpl');
		echo $tpl->render([ 'message' => $msg ]);
		exit();
	}
}

?>