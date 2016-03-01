<?php
class Validate {


    public static function IsDayOfWeek( $number ) {

        if (false === $var = filter_var($number, FILTER_VALIDATE_INT))
            return false;

            // 0 means all days
        return $var >= 0 && $var <= 7;
    }

}

?>