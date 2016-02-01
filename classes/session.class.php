<?php

class Session extends SessionHandler {

	const name   = 'smac';
	const lifetime = 1800;
	const change_thr = 5;		// session regeneration percent
	const ttl = 30 ;// time to live

	private
		$name,
		$cookie
	;

	public function __construct() {

		$this->name = self::name;

		$this->cookie = [
			'lifetime' => self::lifetime,
			'path' => ini_get('session.cookie_path'),
			'domain' => ini_get('session.cookie_domain'),
			'secure' => isset($_SERVER['HTTPS']),
			'httponly' => true
		];

		$this->setup();
	}

	private function setup() {

        ini_set('session.save_handler', 'files');
		ini_set('session.use_cookies', 1);
		ini_set('session.use_only_cookies', 1);

		session_name($this->name);

		session_set_cookie_params(
			$this->cookie['lifetime'],
			$this->cookie['path'],
			$this->cookie['domain'],
			$this->cookie['secure'],
			$this->cookie['httponly']
		);
	}

	public function start()  {

		if (session_id() === '') {
			if (session_start()) {
				return mt_rand(0, 100) <= self::change_thr ? $this->refresh() : true; // 1/5
			}
		}

		return false;
	}

	public function forget() {
		if (session_id() === '') {
			return false;
		}

		$_SESSION = [];

		setcookie(
			$this->name,
			'',
			time() - 42000,
			$this->cookie['path'],
			$this->cookie['domain'],
			$this->cookie['secure'],
			$this->cookie['httponly']
		);

		return session_destroy();
	}

	public function isExpired($ttl = self::ttl) {

		$last = isset($_SESSION['_last_activity'])
			? $_SESSION['_last_activity']
			: false;

		if ($last !== false && time() - $last > $ttl * 60)
			return true;

		$_SESSION['_last_activity'] = time();

		return false;
	}

	public function isFingerprint() {

		$hash = md5( $_SERVER['HTTP_USER_AGENT'] . REMOTE_IP );

		if (isset($_SESSION['_fingerprint']))
			return $_SESSION['_fingerprint'] === $hash;

		$_SESSION['_fingerprint'] = $hash;

		return true;
	}

	public function isValid()
	{
		return ! $this->isExpired() && $this->isFingerprint();
	}

}