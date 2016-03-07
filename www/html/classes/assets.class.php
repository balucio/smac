<?php

class Assets
{

	private static $assets = [
		'js' => [
			'/js/jquery.js',
			'/js/bootstrap.js',
			'/js/bootstrap-select.js',
			'/js/bootstrap-select-i18n/defaults-it_IT.min.js',
			'/js/highcharts.js',
			'/js/highcharts-i18n/defaults-it_IT.js'
		],
		'css' => [
			'/css/bootstrap.css',
			'/css/bootstrap-theme.css',
			'/css/font-awesome.css',
			'/css/weather-icons.css',
			'/css/weather-icons-wind.css',
			'/css/bootstrap-select.css'
		],
		'internalCss' => []
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

	public function addJs($js) { Self::$assets['js'][] = $js; return $this; }
	public function addCss($css) { Self::$assets['css'][] = $css; return $this; }
	public function addInternalCss($css) { Self::$assets['internalCss'][] = $css; return $this; }

	public function Css() { return Self::$assets['css']; }
	public function Js() { return Self::$assets['js']; }
	public function InternalCss() { return Self::$assets['internalCss']; }
}

?>