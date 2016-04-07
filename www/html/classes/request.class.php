<?php

class Request {

    const DEFAULT_LOCALE = 'it_IT.UTF-8';


    public function __construct() {

        session_set_save_handler( new Session() );
        session_start();

        self::initLocale();
    }

    public static function Redirect($location) {
        header('Location: '. $location);
        die();
    }

    public static function Attr($name, $default = null) {

        return isset($_REQUEST[$name])
            ? $_REQUEST[$name]
            : $default
        ;
    }

	public static function ParseUri() {

		$path = trim(parse_url($_SERVER["REQUEST_URI"], PHP_URL_PATH), "/");
		$path = mb_ereg_replace('/[^a-zA-Z0-9]//', "", $path);

		@list($route, $action, $params) = explode("/", $path, 3);

		isset($params)
			&& $params = explode("/", $params);

		return [ $route, $action, $params ];
	}

	public static function IsAjax() {

		return !empty($_SERVER['HTTP_X_REQUESTED_WITH'])
			&& strtolower($_SERVER['HTTP_X_REQUESTED_WITH']) == 'xmlhttprequest'
		;
	}

    private static function initLocale() {

        $locale = self::guessLocale();

        putenv("LC_ALL=$locale");
        setlocale(LC_ALL, $locale);

        // bindtextdomain(APP_NAME, "./locale");
        // textdomain(APP_NAME);
    }

    private static function guessLocale() {

        $system_locale = explode("\n", shell_exec('locale -a'));
         // brosers use en-US, Linux uses en_US
        $browser_locale = explode(",",str_replace("-","_",$_SERVER["HTTP_ACCEPT_LANGUAGE"]));

        $locale = self::DEFAULT_LOCALE;

        for( $i = 0; $i < count($browser_locale); $i++ ) {

            //trick for "en;q=0.8"
            $lang = strtok( $browser_locale[$i], ';' );

            foreach ( $system_locale as $sys_locale ) {

                if ( $lang == substr( $sys_locale, 0, strlen($lang) ) ) {
                    $locale = $sys_locale;
                    break 2; // found and set, so no more check is needed
                }
            }
        }
        return $locale;
    }


}
