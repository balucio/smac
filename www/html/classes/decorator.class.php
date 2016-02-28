<?php

class Decorator {

	private $locale;

	public function __construct() {

		$this->locale = localeconv();
	}

	public function decorateTemperature($number) {

		$n = $this->formatDecimal((double)($number));

		switch (true) {
			case is_null($number) : $class = "text-muted"; $n = 'ND'; break;
			case $n <= 0 : $class = "text-danger"; break;
			case $n <= 5 : $class = "text-warning"; break;
			default: $class = "text-info";
		}

		return '<span class="'. $class . '">' . $n . '</span>';
	}


	public function decorateShortDay($d) {

		return strftime('%a', strtotime("Sunday + $d days"));

	}

	public function decorateDay($d) {

		return strftime('%A', strtotime("Sunday + $d days"));

	}

	public function decorateUmidity($h) {

		return is_null($h) ? 'ND' : round((double)($h));
	}

	public function decorateDateTime($dt) {

		return isset($dt)
			? strtolower( strftime( '%c', strtotime($dt)))
			: 'ND';
	}

	public function decorateTime($t) {

		return isset($t) ? substr($t, 0, 5) : 'ND';

	}

	private function formatDecimal($n) {

		static $dec = 1;

		return floor( $n ) != $n
			? number_format(
				$n,
				$dec,
				$this->locale['decimal_point'],
				$this->locale['thousands_sep']
			) : round( $n )
		;
	}
}