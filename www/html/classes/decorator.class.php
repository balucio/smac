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

	public function decorateShedule($row, Mustache_LambdaHelper $helper) {

		list($t, $v) = explode('|', $helper->render($row));

		$t = substr($t, 0, 5);
		$v = $this->decorateTemperature($v);

		return "<tr>"
			. "<td>$t</td>"
			. "<td>"
				. "<span class=\"wi wi-thermometer\" aria-hidden=\"true\">"
				. "</span> $v <span class=\"wi wi-celsius fa-1x\" aria-hidden=\"true\"></span>"
			. "</td></tr>";
	}

	public function decorateShortDay($day, Mustache_LambdaHelper $helper = null) {

		$n = isset($helper) ? $helper->render($day) : $day;

		return strftime('%a', strtotime("Sunday + $n days"));

	}

	public function decorateDay($day, Mustache_LambdaHelper $helper = null) {

		$n = isset($helper) ? $helper->render($day) : $day;

		return strftime('%A', strtotime("Sunday + $n days"));

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

	public function decorateTime($time, Mustache_LambdaHelper $helper = null) {

		$t = isset($helper) ? $helper->render($time) : $time;

		return isset($time)
			? substr($t, 0, 5)
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