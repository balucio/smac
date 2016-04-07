<?php

class Assets
{

	private static $assets = [
		'js' => [
			'/js/jquery.js',
			'/js/bootstrap.js',
			'/js/bootstrap-select.js',
			'/js/bootstrap-select-i18n/it_IT.js'
		],
		'css' => [
			'/css/bootstrap.css',
			'/css/bootstrap-theme.css',
			'/css/font-awesome.css',
			'/css/weather-icons.css',
			'/css/weather-icons-wind.css',
			'/css/bootstrap-select.css'
		],
		'internalCss' => [],
		'jsReady' => []
	];

	private function __construct() {}

	private function __clone() {}

	private function __wakeup() {}

	static public function get() {

		static $self = null;

		if( !isset( $self ) )
			$self = new Assets();

		return $self;
	}

	public function addJs($js) {

		!is_array($js)
			&& $js = [ $js ];

		foreach ($js as $j)
			self::$assets['js'][] = $j;

		return $this;
	}

	public function addOnReadyJs($js) {

		!is_array($js)
			&& $js = [ $js ];

		foreach ($js as $j)
			Self::$assets['jsReady'][] = $j;

		return $this;
	}

	public function addCss($css) {

		!is_array($css)
			&& $css = [ $css ];

		foreach ($css as $c )
			Self::$assets['css'][] = $c;

		return $this;
	}

	public function addInternalCss($css) {

		Self::$assets['internalCss'][] = $css;
		return $this;
	}

	public function Css() { return self::$assets['css']; }
	public function Js() { return self::$assets['js']; }
	public function InternalCss() { return self::$assets['internalCss']; }
	public function OnLoadJs() { return self::$assets['jsReady']; }
}

?>
