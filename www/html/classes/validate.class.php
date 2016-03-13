<?php
class Validate {


	public static function IsDayOfWeek( $num ) {

		if (false === $var = filter_var($num, FILTER_VALIDATE_INT))
			return false;

			// 0 means all days
		return $var >= 0 && $var <= 7;
	}

	public static function IsPositiveInt( $num ) {

		if (false === $var = filter_var($num, FILTER_VALIDATE_INT))
			return false;

		return $var > 0;
	}

	public static function IsInteger( $num ) {

		return false !== filter_var($num, FILTER_VALIDATE_INT);
	}

	public static function IsFloatInRange( $num, $min, $max ) {
		return is_numeric( $num ) && $num >= $min && $num <= $max;
	}

	public static function IsValidTimeStamp($ts) {

		return ((string) (int) $ts === $ts)
			&& ($ts <= PHP_INT_MAX)
			&& ($ts >= ~PHP_INT_MAX);
	}

}

?>