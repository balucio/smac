<?php

class Decorator {

	private $locale;

	public function __construct() {

		$this->locale = localeconv();
	}

	public function decorateTemperature($number, Mustache_LambdaHelper $helper = null) {

		$number = isset($helper) ? $helper->render($number) : $number;

		$n = $this->formatDecimal((double)($number));

		switch (true) {
			case is_null($number) : $class = "text-muted"; $n = 'ND'; break;
			case $n <= 0 : $class = "text-danger"; break;
			case $n <= 5 : $class = "text-warning"; break;
			default: $class = "text-info";
		}

		return '<span class="'. $class . '">' . $n . '</span>';
	}

	public function decorateShortDay($day, Mustache_LambdaHelper $helper = null) {

		$n = isset($helper) ? $helper->render($day) : $day;

		return strftime('%a', strtotime("Sunday + 1 days"));

	}

	public function decorateDay($day, Mustache_LambdaHelper $helper = null) {

		$n = isset($helper) ? $helper->render($day) : $day;

		return strftime('%A', strtotime("Sunday + 1 days"));

	}

	public function decorateUmidity($number, Mustache_LambdaHelper $helper = null) {

		$n = isset($helper) ? $helper->render($number) : $number;

		return is_null($number) ? 'ND' : round((double)($n));
	}

	public function decorateDateTime($datetime, Mustache_LambdaHelper $helper = null) {

		$dt = isset($helper) ? $helper->render($datetime) : $datetime;

		return isset($datetime)
			? strtolower( strftime( '%c', strtotime($dt)))
			: 'ND';
	}

	private function formatDecimal($number) {

		static $decimals = 1;

		return floor( $number ) != $number
			? number_format(
				$number,
				$decimals,
				$this->locale['decimal_point'],
				$this->locale['thousands_sep']
			) : round( $number )
		;
	}

}